# VPN Native Runtime 记录

这份文档记录当前 HarmonyOS VPN native runtime 主线。当前实现不再使用
`tun2socks` / TUN-to-SOCKS 适配层，而是把 Harmony VPN fd 交给 Xray 原生
TUN 入站处理。

## 当前链路

```text
User taps Start
  -> vpnExtension.startVpnExtensionAbility(...)
  -> HeyVpnAbility.onCreate(want)
  -> vpnExtension.createVpnConnection(context)
  -> vpnConnection.create(vpnConfig)
  -> TUN fd
  -> libheyvpn.so dlopen(libxray.so)
  -> CGoSetTunFd(tunFd)
  -> CGoRunXrayFromJSON(config)
  -> Xray native TUN inbound
  -> Xray outbound
```

HAP 运行时只需要两个 native 文件：

- `libheyvpn.so`：ArkTS N-API bridge。
- `libxray.so`：Xray Go shared library，导出 `CGoSetTunFd` 和 Xray 控制接口。

## Native 接口

`entry/src/main/cpp/napi_init.cpp`

- 进程内 `dlopen(libxray.so)`，不再启动 native 子进程。
- 在启动 Xray 前调用 `CGoSetTunFd(tunFd)`，让 Xray 的 TUN 入站读取 Harmony VPN fd。
- 通过 `CGoRunXrayFromJSON`、`CGoStopXray`、`CGoPing` 控制 Xray。
- native runtime 状态只暴露 `xrayRunning` / `tunRunning` / 流量统计。

`scripts/build_libxray_ohos.sh`

- 使用 `GOOS=android GOARCH=arm64` 配合 OHOS clang 构建，规避 Harmony loader
  对 Linux Go TLS relocation 的不兼容。
- 生成最小 Android log stub，补齐 Go Android runtime 需要的 `android/log.h`
  和 `-llog`。
- 只导出 `CGoRunXrayFromJSON`、`CGoStopXray`、`CGoPing`、`CGoSetTunFd`。
- 构建时 patch `gvisor.dev/gvisor/pkg/tcpip/link/fdbased`，让 Xray Android
  TUN fd 路径固定走非 socket `Readv` dispatcher，避免 Harmony VPN fd 上的
  `Fstat` 权限问题。

## 已移除内容

- 不再生成、打包或调用 TUN-to-SOCKS 适配层。
- 不再依赖 `tun2socks` 进程转发 VPN 数据面。
- 不再注入额外 Go 适配层文件到 `libxray.so`。
- 不再导出适配层专用 C 符号。
- 不再监听本地 SOCKS bridge 端口作为 VPN 数据面。
- 旧独立构建脚本和适配层源码已删除。

## Xray 配置

运行时 Xray 配置使用 `protocol: "tun"` 入站：

```json
{
  "tag": "tun-in",
  "protocol": "tun",
  "settings": {
    "name": "vpn-tun",
    "MTU": 1400,
    "userLevel": 0
  }
}
```

节点延迟测试仍然可以临时生成本地 SOCKS 测试入站，但它只用于 per-node
delay test，不参与 VPN 数据面。

## 验证方式

检查 `libxray.so` 导出符号：

```shell
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native/llvm/bin/llvm-nm -D \
  entry/src/main/cpp/prebuilt/arm64-v8a/libxray.so | \
  rg 'CGo'
```

期望只看到：

```text
CGoRunXrayFromJSON
CGoStopXray
CGoPing
CGoSetTunFd
```

检查最终签名 HAP 里打包的 `libxray.so` 是否来自 patched gVisor：

```shell
rm -rf /tmp/hey-hap-check
mkdir -p /tmp/hey-hap-check
unzip -q entry/build/default/outputs/default/entry-default-signed.hap \
  libs/arm64-v8a/libxray.so -d /tmp/hey-hap-check
go version -m /tmp/hey-hap-check/libs/arm64-v8a/libxray.so | rg 'gvisor.dev/gvisor|=>'
```

期望能看到 `gvisor.dev/gvisor => .../build/native/libxray-ohos/gvisor-patched`。

安装后点击连接，成功时 `hilog` 应该能看到类似顺序：

```text
Native config preflight passed. libXray is available.
VPN created. tunFd=...
Xray TUN fd configured.
Xray started.
Native VPN bridge started.
```

## 维护命令

重新生成 Xray native core：

```shell
GOPROXY=https://proxy.golang.org,direct \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
./scripts/build_libxray_ohos.sh
```

构建并安装 HAP：

```shell
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
./scripts/device_vpn_smoke_test.sh build

DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
./scripts/device_vpn_smoke_test.sh install
```

`device_vpn_smoke_test.sh build` 会先执行 `hvigor clean`，避免 native
prebuilt 更新后 HAP 仍复用旧 intermediates。
