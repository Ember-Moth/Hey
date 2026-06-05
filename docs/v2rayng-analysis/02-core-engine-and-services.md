# v2rayNG 核心引擎与系统服务

> 领域二：Xray 核心启停、VPN/TUN 与仅代理模式、系统集成、测速、DNS/分应用/路由的运行时配置。
> 代码位置基于 v2rayNG 源码（`app/src/main/java/com/v2ray/ang`）。

## 1. Xray 核心启动与管理

### 1.1 Native 调用封装（`core/CoreNativeManager.kt`）

通过 `libv2ray.Libv2ray` JNI 调用原生 Go 代码：
- `Seq.setContext()`：初始化 Go 运行上下文
- `Libv2ray.initCoreEnv(assetPath, deviceId)`：初始化核心资源与设备标识
- `Libv2ray.newCoreController(handler)`：创建核心控制器
- `Libv2ray.measureOutboundDelay()`：测速接口
- `Libv2ray.reconcileBrowserDialer()`：浏览器拨号器支持

初始化（`CoreNativeManager.kt:29-43`）线程安全单例（`AtomicBoolean`）。

### 1.2 生命周期控制（`core/CoreServiceManager.kt`）

**启动流程**：
1. UI 触发 `startVService()` / `startVServiceFromToggle()`（`:67-100`）：校验服务器、选择模式、启动前台服务
2. 后台核心循环 `startCoreLoop()`（`:205-281`）：生成 JSON 配置、注册广播、配置拨号器、`coreController.startLoop(configJson, tunFd)`
3. 配置构建 `CoreConfigManager.getV2rayConfig()`（`:33-49`）：模板加载 → `CoreConfigContextBuilder` 分析出站 → `CoreOutboundBuilder` 转换协议 → DNS/路由/Inbound/Outbound

**关键数据结构**：
```
CoreConfigContext { resolvedOutbounds, isCustom }
ResolvedOutbound { tag, profile, resolvedProfiles, resolvedType(NORMAL/POLICYGROUP/PROXYCHAIN) }
```

**停止流程** `stopCoreLoop()`（`:288-318`）：异步停核 → 关拨号器 → 发停止消息 → 注销广播 → 关 VPN 接口。

**流量统计** `queryAllOutboundTrafficStats()`（`:324-347`）：解析 Go 侧 `tag,direction,value;...` 返回三元组。

## 2. VPN/TUN 与仅代理模式

### 2.1 模式选择（`CoreServiceManager.kt:175-182`）
```kotlin
val isVpnMode = SettingsManager.isVpnMode()
val intent = if (isVpnMode) Intent(.., CoreVpnService::class.java)
             else Intent(.., CoreProxyOnlyService::class.java)
```

### 2.2 VPN 模式（`service/CoreVpnService.kt`）

继承 `VpnService`。接口建立 `configureVpnService()`（`:179-210`）：
1. **网络地址** `configureNetworkSettings`：`addAddress(ipv4, 30)` + `addRoute("0.0.0.0", 0)` + IPv6
2. **分应用代理** `configurePerAppProxy`：allow/disallow 两模式
3. **平台特性** `configurePlatformFeatures`：requestNetwork(P+)、setMetered(Q+)、setHttpProxy(Q+)
4. **建立接口** `builder.establish()`

地址方案：`enums/VpnInterfaceAddressConfig.kt` 定义 7 种预设（OPTION_1~7，含 IPv4/IPv6 Client/Router）。
DNS：`SettingsManager.getVpnDnsServers().forEach { builder.addDnsServer(it) }`。

### 2.3 TUN 与 tun2socks（`service/TProxyService.kt`）

两种 TUN 实现：
- **A. Xray 原生 TUN**：核心直接处理 TUN，`tunFd` 传给核心
- **B. HEV-Socks5-Tunnel**：JNI 调 `libhev-socks5-tunnel.so`，把 TUN 流量转 SOCKS5；启用条件 `SettingsManager.isUsingHevTun()`

HEV 配置（YAML，`:60-98`）：`tunnel(mtu/ipv4/ipv6)` + `socks5(port/address/udp/auth)` + `misc(读写超时)`。
启动（`:42-57`）：写 YAML → `TProxyStartService(configPath, vpnInterface.fd)`。

### 2.4 仅代理模式（`service/CoreProxyOnlyService.kt`）

继承标准 `Service`，**无 VPN 接口**，仅提供 SOCKS/HTTP 代理，应用需显式配置代理。

## 3. 系统集成能力

| 能力 | 文件 | 要点 |
|------|------|------|
| 开机自启 | `receiver/BootReceiver.kt` | `ACTION_BOOT_COMPLETED` → 检查 `decodeStartOnBoot()` + 已选服务器 → `startVService()` + `SubscriptionUpdater.sync()`；需 `RECEIVE_BOOT_COMPLETED` 权限 |
| 快速设置磁贴 | `service/QSTileService.kt` | 下拉磁贴开关，长按显示当前服务器名；`onClick()` 按状态启停；监听广播同步状态 |
| 桌面小组件 | `receiver/WidgetProvider.kt` | `widget_switch.xml`，按运行态切换图标/背景；点击启停 |
| Tasker 自动化 | `receiver/TaskerReceiver.kt` | `TASKER_EXTRA_BUNDLE` 含 `switch`+`guid`；`Default` 用当前服务器，否则按 guid 启动 |
| URL Scheme | `ui/UrlSchemeActivity.kt` | `ACTION_SEND` 文本 / `ACTION_VIEW` `install-config`/`install-sub` → `importBatchConfig()` |
| 快捷方式 | `ui/Sc*.kt` | start/stop/switch/scan 四种 |

URL 示例：
```
v2rayng://install-config?url=https://example.com/config.json
v2rayng://install-sub?url=https://example.com/sub?token=abc
```

## 4. 测速与延迟检测

### 4.1 RealPing 批量测速

`service/CoreTestService.kt`（前台服务+任务管理）+ `service/RealPingWorkerService.kt`（并发工作池）。

- 启动 `handleMeasureStart`（`CoreTestService.kt:78-107`）：取待测列表（指定 guids / 订阅 / 全部）→ 创建 worker
- 并发 `start()`（`RealPingWorkerService.kt:35-63`）：`getRealPingConcurrency()` 决定线程池大小，`measureOutboundDelay(config, url)` 单测
- 结果 `handleWorkerEvent`（`:109-134`）：进度/结果/完成事件 → `encodeServerTestDelayMillis` + 发 UI 消息

### 4.2 单次延迟（`CoreServiceManager.kt:354-393`）

`coreController.measureDelay(url)`，失败尝试备用 URL；成功后取 IP 信息（`SpeedtestManager.getRemoteIPInfo()`）。

### 4.3 测速专用配置简化（`CoreConfigManager.kt:56-75`）

`postProcessForSpeedtest`：清空 inbounds/routing.rules、置空 dns/fakedns/stats/policy、禁用 mux。

## 5. DNS / 分应用 / IPv6 / 路由（运行时）

### 5.1 DNS（`CoreConfigManager.kt:570-773`）

架构：本地 DNS inbound(:10853) → 路由规则(dns-out) → FakeDNS / Remote DNS(proxy) / Domestic DNS(direct)。
- FakeDNS 启用（`:521-527`）保留 IP 池供路由查询
- Remote DNS 用于代理域名、Domestic DNS 用于直连域名（`skipFallback=true`）
- CN 特殊处理用 `expectIPs=[GEOIP_CN]`
- `enableParallelQuery`（服务器 >2 时）

### 5.2 分应用代理（`CoreVpnService.kt:294-327`）

- 未启用：`addDisallowedApplication(self)`
- 代理模式（白名单）：`addAllowedApplication(app)`
- 旁路模式（黑名单）：`addDisallowedApplication(app)`

### 5.3 IPv6

VPN 接口（`:237-245`）：`addAddress(ipv6, 126)`，旁路 LAN 时 `addRoute("2000::",3)+("fc00::",18)`，否则 `("::",0)`。
DNS（`:793-826`）：Happy Eyeballs `prioritizeIPv6` + `interleave=2`。

### 5.4 路由与分流（`CoreConfigManager.kt:877-953`）

- `domainStrategy`（默认 AsIs）
- 遍历用户规则集 `appendRoutingUserRule`：domain（geosite/regexp/full）、ip（geoip:cn→`ext:geoip-only-cn-private.dat:cn`）、process（包名→UID，Android Q+）、策略组改写为 balancerTag
- 规则优先级：策略组 Balancer → 用户规则 → DNS 规则 → 兜底

**策略组/负载均衡**（`:329-388`）：展开成员 → 建 `BalancerBean(tag/selector/strategy)` → 需探测时配 `ObservatoryObject(probeUrl/probeInterval/enableConcurrency)`。

## 6. 浏览器拨号器（`service/DialerNativeService.kt`）

使 Xray 内 HTTP/WS 请求经 OkHttp 发送，获得更好的 TLS/流量特征掩护。
支持 WebSocket、xhttp Streaming GET、xhttp Unary。模式 `OkHttp` / `WebView`（`CoreServiceManager.kt:266-276`）。

## 7. 消息通信（`AppConfig.kt:155-172`）

状态：`MSG_STATE_RUNNING/START_SUCCESS/START_FAILURE/STOP_SUCCESS`。
测速：`MSG_MEASURE_DELAY/CONFIG_START/SUCCESS/NOTIFY/FINISH`。
广播：`BROADCAST_ACTION_SERVICE/ACTIVITY/WIDGET_CLICK`。

## 8. 关键代码位置汇总

| 功能 | 文件 | 关键方法 |
|------|------|---------|
| 核心启停 | `core/CoreServiceManager.kt` | `startCoreLoop()` / `stopCoreLoop()` |
| VPN 模式 | `service/CoreVpnService.kt` | `configureVpnService()` |
| TUN 处理 | `service/TProxyService.kt` | `TProxyStartService()` |
| 配置构建 | `core/CoreConfigManager.kt` | `getV2rayConfig()` |
| 测速 | `service/RealPingWorkerService.kt` | `startRealPing()` |
| QSTile | `service/QSTileService.kt` | `onClick()` |
| 开机自启 | `receiver/BootReceiver.kt` | `onReceive()` |
| URL Scheme | `ui/UrlSchemeActivity.kt` | `parseUri()` |
