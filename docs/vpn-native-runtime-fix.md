# VPN Native Runtime 修复记录

这份文档记录 HarmonyOS VPN 客户端从“能启动界面但浏览器不通”到“native VPN 桥真正跑起来”的修复思路。当前可工作的主线是：HAP 里只打包一个组合版 `libxray.so`，它同时导出 Xray 和 tun2socks 的 C 接口，由 `libheyvpn.so` 在同一个进程内 `dlopen` 调用。

## 问题现象

HAP 可以安装，界面也能发起 VPN 启动，但浏览器无法访问 Google。排查时最有用的命令是：

```shell
hdc shell 'hilog -x | grep -E "A00001/com.lmlm.hey|HeyNative|HeyVpnAbility|Error relocating|SIG|tun2socks" | tail -300'
hdc shell 'ps -ef | grep -E "hey|xray|tun2socks" | grep -v grep || true'
hdc shell 'netstat -an | grep -E "10808|10825" || true'
```

实际踩到的问题是分层出现的：

- 最早 `libxray.so` 没有被打进 HAP，运行时自然找不到核心。
- 把 `.so` 当成可执行文件用 `posix_spawn` 跑，在真机上会遇到权限限制。
- `GOOS=linux` 编出来的 Go shared library 在 Harmony loader 下会出现 `R_AARCH64_TLS_*` 这类 TLS relocation 问题，导致 `dlopen` 失败。
- Xray 和 tun2socks 如果分别做成两个 Go `c-shared` 动态库，并在同一个 VPN extension 进程里加载，会因为多个 Go runtime 冲突而崩。
- tun2socks 的 `engine.Start()` 内部会 `log.Fatalf`，启动失败时直接把进程 `os.Exit(1)` 掉，日志不够好看，也不利于恢复。
- tun2socks 原 Linux fd 路径使用 gVisor `link/fdbased.New`，会对 Harmony 传入的 `tunFd` 做 `Fstat`，设备上返回 `permission denied`。

## 最终方案

HAP 运行时保留两个 native 文件：

- `libheyvpn.so`：ArkTS N-API bridge。
- `libxray.so`：组合版 Go shared library，内部包含 Xray 和 tun2socks。

启动链路如下：

```text
VpnExtensionAbility
  -> 创建 TUN fd
  -> libheyvpn.so dlopen(libxray.so)
  -> CGoRunXrayFromJSON(config)
  -> HeyTun2SocksStart(tunFd, 127.0.0.1, 10808, mtu)
  -> tun2socks 把 TUN 流量转发到 Xray SOCKS inbound
  -> Xray outbound 出站
```

关键点是 `libheyvpn.so` 不再启动子进程，也不再同时加载多个 Go 动态库，而是只加载一个 `libxray.so`，直接调用它导出的 C 函数。

## 关键修改

`entry/src/main/cpp/CMakeLists.txt`

- HAP native 输出目录只保留并打包 `libxray.so`。
- 构建时清掉历史遗留的 `libheytun2socks.so`、`libheyxrayexec.so`、`libheytun2socksexec.so`，避免旧产物被误打包。

`entry/src/main/cpp/napi_init.cpp`

- 删除 `posix_spawn` 子进程启动逻辑，改成进程内 `dlopen(libxray.so)`。
- Xray 通过 `CGoRunXrayFromJSON`、`CGoStopXray`、`CGoPing` 调用。
- tun2socks 通过同一个 `libxray.so` 里的 `HeyTun2SocksStart`、`HeyTun2SocksStop` 和流量统计接口调用。
- 读取 `HeyTun2SocksLastError()`，让 tun2socks 启动失败原因进入 `hilog`，避免只看到进程退出。

`scripts/build_libxray_ohos.sh`

- 使用 `GOOS=android GOARCH=arm64` 配合 OHOS clang 构建，规避 Harmony loader 对 Linux Go TLS relocation 的不兼容。
- 生成一个最小 Android log stub，补齐 Go Android runtime 需要的 `android/log.h` 和 `-llog`。
- 用 version script 只导出实际需要的 `CGo*` 和 `HeyTun2Socks*` 符号。
- 构建时注入 `hey_tun2socks.go`，把 tun2socks 编进同一个 `libxray.so`，共享同一个 Go runtime。
- 构建时 patch tun2socks：
  - 增加 `engine.StartWithError()` / `engine.StopWithError()`，绕开 `engine.Start()` 的 `log.Fatalf`；
  - 把 Linux fd 打开路径改成 `iobased.New(os.NewFile(...))`，避免 Harmony 上 `Fstat(tunFd)` 被拒。
- pin/replace `gvisor.dev/gvisor` 到 tun2socks v2.6.0 匹配的版本。

`entry/src/main/cpp/prebuilt/arm64-v8a/libxray.so`

- 重新生成的组合版 native core，包含 Xray 和 tun2socks。

`entry/src/main/cpp/prebuilt/arm64-v8a/libxray.h`

- 随 `libxray.so` 重新生成，能看到 `HeyTun2Socks*` 导出声明。

`scripts/device_vpn_smoke_test.sh`

- build 检查里把 `libxray.so` 也列出来，便于确认 HAP 最终到底打进了哪些 native 库。

## 已删除或不再使用的方案

- 不再使用独立的 `libheytun2socks.so` 作为运行时路径。
- 不再打包或调用 `libheyxrayexec.so`、`libheytun2socksexec.so`。
- `scripts/build_tun2socks_ohos.sh` 已恢复成原来的独立构建脚本；它可以留作参考，但不是当前可工作的 VPN runtime 主线。
- 不再在 VPN extension 里加载多个 Go `c-shared` 动态库。
- 不再在嵌入式路径里直接调用 tun2socks `engine.Start()`。
- 排查过程里生成的 `android-stub/` 目录和 `libheytun2socks.exports` 已删除，最终 stub 只在 `build/native/libxray-ohos/` 临时生成，不提交到 prebuilt 目录。
- 未验证的 IPv6 route 改动已撤回；这次问题根因在 native runtime，不在 ArkTS 路由配置。

## 不纳入本次修复的改动

当前工作区里还有一些 UI、图标和应用名相关改动，例如节点菜单、节点卡片视觉、`Hey VPN` 改 `Hey`、应用图标资源等。它们和本次 native VPN 连通修复无关，不应写进这条修复链路；是否保留应按产品/UI 需求单独决定。

## 验证方式

检查组合版 `libxray.so` 是否导出需要的符号：

```shell
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/llvm-nm -D \
  entry/src/main/cpp/prebuilt/arm64-v8a/libxray.so | \
  rg 'CGo|HeyTun2Socks'
```

期望至少包含：

```text
CGoRunXrayFromJSON
CGoStopXray
CGoPing
HeyTun2SocksStart
HeyTun2SocksStop
HeyTun2SocksUploadBytes
HeyTun2SocksDownloadBytes
HeyTun2SocksLastError
```

检查 Harmony 不兼容的 TLS relocation 是否消失：

```shell
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/llvm-readelf -r \
  entry/src/main/cpp/prebuilt/arm64-v8a/libxray.so | \
  rg 'R_AARCH64_TLS|res_search'
```

这条命令应该没有输出。若只看到 lazy `setuid` jump slot，不属于这次导致 loader 失败的 TLS 问题。

安装后点击连接，成功时 `hilog` 应该能看到类似顺序：

```text
Native config preflight passed. libXray is available.
VPN created. tunFd=...
Xray core started.
tun2socks adapter started.
Native VPN bridge started.
```

设备侧检查：

```shell
hdc shell 'ps -ef | grep -E "com.lmlm.hey|vpn" | grep -v grep'
hdc shell 'netstat -an | grep 10808'
hdc shell 'ping -c 1 -W 3 8.8.8.8'
```

期望 `com.lmlm.hey:vpn` 保持存活，`127.0.0.1:10808` 处于监听状态，设备流量经由 `vpn-tun` 转发。

## 维护命令

重新生成组合版 core：

```shell
GOPROXY=https://proxy.golang.org,direct \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
./scripts/build_libxray_ohos.sh
```

清理并构建 HAP：

```shell
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw clean --no-daemon --stacktrace

DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
./scripts/device_vpn_smoke_test.sh build
```

如果后面又出现启动失败，先看 `hilog` 里的 `HeyTun2SocksLastError`，再决定是否要调整 native runtime 结构。
