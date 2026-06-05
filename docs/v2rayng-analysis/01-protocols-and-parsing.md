# v2rayNG 协议支持与配置解析

> 领域一：代理协议、传输方式、安全层、分享链接解析、高级特性与解析层抽象。
> 代码位置基于 v2rayNG 源码（`app/src/main/java/com/v2ray/ang`）。

## 1. 支持的代理协议及其特性

### 1.1 协议枚举定义

文件：`enums/EConfigType.kt`

v2rayNG 支持的协议共 10 种：

| 协议 | 编码值 | URL 协议头 | 状态 | 备注 |
|------|------|---------|------|------|
| VMESS | 1 | `vmess://` | ✅ 完全支持 | V2Ray 原生协议，支持多种传输方式 |
| VLESS | 5 | `vless://` | ✅ 完全支持 | V2Ray 新协议，轻量化版本 |
| Shadowsocks | 3 | `ss://` | ✅ 完全支持 | 支持 SIP002 标准和传统格式 |
| SOCKS | 4 | `socks://` `socks4://` `socks5://` | ✅ 完全支持 | SOCKS 代理协议 |
| Trojan | 6 | `trojan://` | ✅ 完全支持 | 模拟 HTTP/HTTPS 的隧道协议 |
| WireGuard | 7 | `wireguard://` | ✅ 完全支持 | VPN 协议，支持配置文件解析 |
| Hysteria2 | 9 | `hysteria2://` `hy2://` | ✅ 完全支持 | 高性能代理协议，支持多端口 |
| Hysteria | 900 | `hysteria://` | ✅ 完全支持 | Hysteria v1 版本 |
| HTTP | 10 | `http://` | ✅ 支持 | HTTP 代理 |
| CUSTOM | 2 | (空) | ✅ 支持 | 自定义 V2Ray 配置 JSON |
| TUIC | 8 | `tuic://` | ❌ 注释 | 暂未启用 |

### 1.2 传输方式（Network Type）

文件：`enums/NetworkType.kt`

| 传输方式 | 类型值 | 支持协议 | 配置参数 |
|---------|-------|--------|--------|
| TCP | `tcp` | VMESS, VLESS, Trojan, SS | `headerType`(none/http), `host`, `path` |
| KCP | `kcp` | VMESS | `seed`, `headerType`, `mtu`, `tti` |
| WebSocket | `ws` | VMESS, VLESS, Trojan | `host`, `path` |
| HTTP Upgrade | `httpupgrade` | VMESS, VLESS, Trojan | `host`, `path` |
| XHTTPv2 | `xhttp` | VMESS, VLESS | `host`, `path`, `mode`, `extra` |
| gRPC | `grpc` | VMESS, VLESS, Trojan | `serviceName`, `authority`, `mode` |
| HTTP/2 | `h2` | VMESS, VLESS | `host`, `path` |
| HTTP | `http` | VMESS, VLESS | `host`, `path` |
| Hysteria | `hysteria` | Hysteria2, Hysteria | 协议本身的传输层 |

> 注：`quic` 传输方式在代码中被注释（`NetworkType.kt:12`），暂未启用。

### 1.3 安全层支持

文件：`AppConfig.kt:225-226`

| 安全层 | 常量 | 支持情况 | 配置参数 |
|-------|-----|--------|--------|
| TLS | `TLS = "tls"` | ✅ 完全支持 | `sni`, `alpn`, `fingerPrint`(uTLS), `insecure` |
| REALITY | `REALITY = "reality"` | ✅ 完全支持 | `publicKey`, `shortId`, `spiderX`, `mldsa65Verify` |
| 无加密 | `null` / `"none"` | ✅ 支持 | 仅 Hysteria2、SOCKS 等 |

## 2. 分享链接（URL Scheme）解析格式

### 2.1 协议解析器架构

文件：`handler/AngConfigManager.kt:34-46`

```kotlin
private val configFmtParsers: Map<String, (String) -> ProfileItem?> by lazy {
    mapOf(
        "vmess://" to VmessFmt::parse,
        "ss://" to ShadowsocksFmt::parse,
        "socks://" to SocksFmt::parse,
        "socks4://" to SocksFmt::parse,
        "socks5://" to SocksFmt::parse,
        "trojan://" to TrojanFmt::parse,
        "vless://" to VlessFmt::parse,
        "wireguard://" to WireguardFmt::parse,
        "hysteria2://" to Hysteria2Fmt::parse,
        "hy2://" to Hysteria2Fmt::parse
    )
}
```

### 2.2 各协议分享链接详细格式

**VMESS**（`fmt/VmessFmt.kt`）支持两种格式：
- JSON 编码（传统）：`vmess://BASE64(JSON)`，字段含 `v/ps/add/port/id/aid/scy/net/type/host/path/tls/sni/fp/alpn/insecure`
- 标准 URI：`vmess://uuid@server:port?network=tcp&headerType=none&security=tls&sni=xxx#remarks`

**VLESS**（`fmt/VlessFmt.kt`）：
`vless://uuid@server:port?encryption=none&security=tls&sni=xxx&fp=xxx#remarks`
查询参数含 `encryption/security/type/sni/fp/alpn/flow` 及 Reality 的 `publicKey/shortId/spiderX`。

**Trojan**（`fmt/TrojanFmt.kt`）：
`trojan://password@server:port?security=tls&sni=xxx&type=tcp#remarks`，无查询参数时默认 TLS。

**Shadowsocks**（`fmt/ShadowsocksFmt.kt`）支持两种：
- SIP002：`ss://method:password@server:port/?plugin=obfs-http;obfs-host=xxx#remarks`
- 传统：`ss://base64(method:password)@server:port#remarks`

**SOCKS**（`fmt/SocksFmt.kt`）：`socks://username:password@server:port#remarks`，账号密码可选、可 base64。

**WireGuard**（`fmt/WireguardFmt.kt`）：
`wireguard://privateKey@server:port?publickey=xxx&address=10.0.0.2&mtu=1420&presharedkey=xxx&reserved=0,0,0#remarks`，
也支持 `[Interface]/[Peer]` 配置文件格式。

**Hysteria2**（`fmt/Hysteria2Fmt.kt`）：
`hysteria2://password@server:port?security=tls&sni=xxx&alpn=h3&obfs=salamander&obfs-password=xxx&mport=xxx-xxx&pinSHA256=xxx#remarks`，
特有参数 `obfs/obfs-password/mport(多端口)/mportHopInt(跳变间隔)/pinSHA256`。

**CUSTOM**（`fmt/CustomFmt.kt`）：完整 V2Ray JSON（`remarks/outbounds/inbounds/routing`）。

### 2.3 通用查询参数

文件：`fmt/FmtBase.kt:43-94`，所有协议通用：

| 参数 | 含义 | 参数 | 含义 |
|------|------|------|------|
| `type` | 传输方式 | `pbk` | REALITY 公钥 |
| `security` | 安全层 | `sid` | REALITY 短 ID |
| `sni` | SNI | `spx` | REALITY SpiderX |
| `fp` | uTLS 指纹 | `pqv` | ML-DSA-65 验证 |
| `alpn` | ALPN | `flow` | 流控模式 |
| `insecure` | 跳过证书验证 | `ech` | ECH 配置 |
| `pcs` | Pin CA 证书 SHA256 | `fm` | 最终掩码配置 |

## 3. 配置导入方式

入口：`ui/UrlSchemeActivity.kt`，四种方式：
1. **URL Scheme**：`v2rayng://install-config?url=...`、`v2rayng://install-sub?url=...`
2. **分享文本**：`ACTION_SEND` + `text/plain`，支持单条或批量（逐行）
3. **剪贴板**：扫描分享链接、粘贴配置
4. **订阅**：订阅 URL，自动周期更新

批量导入核心：`handler/AngConfigManager.kt:177-195` `importBatchConfig()`：
1. 尝试 Base64 解码 → 2. 逐行解析（`.lines().distinct()`）→ 3. 协议识别 →
4. 订阅 URL 单独导入 → 5. 自定义配置/WireGuard 文件识别。

批量保存优化（`AngConfigManager.kt:279-299`）：单次 I/O，4 层优先级匹配已选中节点
（完全匹配 → remarks → server+port+password → server+port → server）。

## 4. 高级特性支持

| 特性 | 关键文件 | 说明 |
|------|--------|------|
| Reality | `FmtBase.kt:72-75`、`CoreOutboundBuilder.kt` | `pbk/sid/spx/pqv`；`realitySettings` 与 `tlsSettings` 互斥 |
| uTLS Fingerprint | `FmtBase.kt:84`、`VmessFmt.kt:84` | `fp`：chrome/firefox/safari/edge |
| 流控 Flow | `FmtBase.kt:93,115`、`V2rayConfig.kt:109` | `xtls-rprx-vision` 等 |
| 多路复用 Mux | `V2rayConfig.kt:334-339`、`AppConfig.kt:38-41` | `enabled/concurrency/xudpConcurrency/xudpProxyUDP443` |
| TLS 增强 | `V2rayConfig.kt:243-264` | ALPN、ECH、证书钉住、按名验证、会话恢复、allowInsecure |
| 最终掩码 FinalMask | `V2rayConfig.kt:287-331` | tcp/udp 掩码、QUIC 参数、Fragment、Noise |
| Hysteria 特性 | `Hysteria2Fmt.kt:38-105` | obfs 混淆、多端口、端口跳变、证书钉住、带宽限制 |

## 5. 设计架构抽象

### 5.1 `FmtBase` 基类（`fmt/FmtBase.kt`）

提供三类统一抽象：
- **URI 构建**：`toUri(config, userInfo, dicQuery)`，自动处理编码/fragment/IPv6
- **查询参数处理**：`getQueryParam` / `getItemFormQuery` / `getQueryDic`
- **参数映射规范**：按传输方式动态选择相关参数（TCP→headerType/host；KCP→seed/mtu/tti；WS/HTTP→host/path；gRPC→mode/authority/serviceName）

### 5.2 `ProfileItem` 统一数据模型（`dto/entities/ProfileItem.kt`）

所有协议共用一个结构体，含基础信息 / 传输配置 / 安全配置 / Reality / 高级特性 / WireGuard 专有字段。
优点：新增协议只需加字段，简化 UI 绑定与校验。

### 5.3 解析器注册机制（`AngConfigManager.kt:34-46`）

`prefix → parser` 的 lazy 映射表，解耦识别与解析，新增协议仅一行注册，支持多 scheme 别名。

## 6. 协议兼容性矩阵

| 特性 | VMESS | VLESS | Trojan | SS | SOCKS | WG | HY2 |
|------|------|------|--------|----|----|---|----|
| TCP | ✅ | ✅ | ✅ | ✅ | ✅ | - | - |
| WebSocket | ✅ | ✅ | ✅ | - | - | - | - |
| HTTP/2 | ✅ | ✅ | ✅ | - | - | - | - |
| gRPC | ✅ | ✅ | ✅ | - | - | - | - |
| KCP | ✅ | - | - | - | - | - | - |
| XHTTPv2 | ✅ | ✅ | - | - | - | - | - |
| TLS | ✅ | ✅ | ✅ | - | - | - | ✅ |
| REALITY | ✅ | ✅ | ✅ | - | - | - | ✅ |
| Mux | ✅ | ✅ | ✅ | - | - | - | - |
| Flow(XTLS) | ✅ | ✅ | ✅ | - | - | - | - |
| uTLS 指纹 | ✅ | ✅ | ✅ | - | - | - | ✅ |
| Obfs 混淆 | - | - | - | ✅ | - | - | ✅ |
| 多端口跳跃 | - | - | - | - | - | - | ✅ |

## 7. 关键代码位置索引

| 功能 | 文件 | 行号 |
|------|------|------|
| 协议枚举 | `enums/EConfigType.kt` | 5-19 |
| 传输方式 | `enums/NetworkType.kt` | 3-19 |
| 协议常量 | `AppConfig.kt` | 179-192, 221-226 |
| 配置数据模型 | `dto/entities/ProfileItem.kt` | 7-73 |
| V2Ray 配置 DTO | `dto/V2rayConfig.kt` | 7-524 |
| FmtBase 基类 | `fmt/FmtBase.kt` | 11-176 |
| 批量导入核心 | `handler/AngConfigManager.kt` | 177-502 |
| URL Scheme 入口 | `ui/UrlSchemeActivity.kt` | 19-87 |
