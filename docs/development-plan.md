# Hey 未来开发计划（对标 v2rayNG · 稳步推进版）

> 制定日期：2026-06-05
> 基线：基于真实代码核对，而非声称状态。
> 关联文档：能力对照见 [`v2rayng-feature-map.md`](v2rayng-feature-map.md)，
> 早期评估见 [`roadmap.md`](roadmap.md)（本计划取代其中的阶段规划部分）。

本计划的原则是**稳步前进**：每个里程碑都是一个可独立验收、可单独发布的小闭环，
先打通"地基"（真机数据通路 + 内核能力），再逐层叠加体验与高级特性，避免在未验证的
通路上堆功能。

---

## 一、现状快照（2026-06-05 实测）

自 2026-06-03 路线图以来已落地：

- ✅ 相机扫码：`pages/Scanner.ets` 已接入 `@kit.ScanKit`（`scanBarcode.startScanForResult`）
- ✅ 分应用代理枚举：`pages/PerApp.ets` 已用 `bundleManager` 枚举已安装应用
- ✅ Assets 页模块化、NodeEdit 组件化、8 协议手动配置与解析

仍是关键缺口：

| 领域 | 现状 | 缺口 |
| --- | --- | --- |
| 真机 VPN 闭环 | 代码就位，验证状态未知 | **最高风险，仍是阻塞项** |
| Native 桥接 | `napi_init.cpp` 仅接通 4 个 CGo 函数 | `CGoQueryStats`/`CGoTestXray`/`CGoXrayVersion`/`CGoReadGeoFiles`/`CGoConvertShareLinks` 头文件已就绪但**未接线** |
| 路由规则 | `buildRoutingRules` 仅 `geosite:cn` 旁路一条 | 广告拦截、自定义规则集、规则编辑器均未生效 |
| 订阅 | 多分组 + 手动更新 | **无自动更新、无去重、无正则过滤、无自定义 UA** |
| 分享导出 | 仅文本 | **无二维码生成** |
| 深链导入 | 无 | **URL Scheme / Want 导入未实现** |
| 高级路由 | 无 | 负载均衡 / 策略组 / 代理链均无 |
| 云备份 | 仅本地 ZIP | **无 WebDAV** |

---

## 二、里程碑总览

```text
M0 真机闭环验证 ──┬─→ M1 内核能力补全 ──→ M2 路由系统 ──→ M5 高级路由(可选)
（阻塞一切）       └─→ M3 订阅与体验闭环  // 可与 M1/M2 并行
                                        └─→ M4 平台集成与分享  // 体验层，随时插入
```

每个里程碑控制在 1～2 周可验收的粒度。优先级：**M0 > M1 > M2 ≈ M3 > M4 > M5**。

---

## 三、里程碑详情

### M0 · 真机数据通路闭环（最高优先 · 阻塞项）

**目标**：在真机上跑通 `连接 → TUN → Xray → 出站 → 真实可上网`，得出"已验证"结论。

**任务**
- 真机安装 HAP，验证 `CGoSetTunFd` + Xray `tun` inbound 的真实转发
- 确认 DNS、IPv4/IPv6 路由在真机生效，修复暴露的问题
- 用一个真实可用节点端到端验证 TCP/UDP 出站

**v2rayNG 对照**：`CoreVpnService` / `TProxyService` 的 TUN 建立与转发。
**验收标准**：真机浏览器可访问被墙站点；`docs/real-device-vpn-test.md` 清单全绿。
**依赖**：无。**这一步不过，后续全部功能都建立在未验证通路上。**

---

### M1 · Native 内核能力补全（投入小、解锁多）

**目标**：把已编译进 `libxray.so` 但未接线的 CGo 函数接入 `napi_init.cpp`。

**任务**（按性价比排序）
1. `CGoQueryStats` → 真实上下行流量统计，替换当前 C++ 侧近似计数
2. `CGoTestXray` → 连接前配置预检，减少启动失败、提前报错
3. `CGoXrayVersion` → About 页显示真实内核版本
4. `CGoReadGeoFiles` → geo 文件校验与计数（Assets 页展示条目数）

**v2rayNG 对照**：`CoreServiceManager.queryAllOutboundTrafficStats()`、配置预检逻辑。
**验收标准**：运行态面板显示真实流量；非法配置在连接前被拦截并提示。
**依赖**：M0。

---

### M2 · 路由规则系统（核心能力差距）

**目标**：让 Route 页的开关真正影响生成的 Xray 配置，而非仅弹窗说明。

**任务**
- 扩展 `core/XrayConfig.ets` 的 `buildRoutingRules`：支持多规则、广告拦截
  （`geosite:category-ads-all` → `block`）、用户自定义 域名/IP/端口/协议 规则
- 自定义规则集的持久化模型（参考 v2rayNG `RulesetItem`：
  `domain/ip/port/process/protocol/network/outboundTag/enabled`）
- 新建规则编辑器页（增删改 + 拖拽排序 + 启用开关）
- 预设规则集导入（白名单/黑名单/全局，对应 v2rayNG assets 内置规则）

**v2rayNG 对照**：`RoutingSettingActivity` / `RoutingEditActivity` / `RulesetItem`。
**验收标准**：开启广告拦截后广告域名走 block；自定义规则在连接后实际生效。
**依赖**：M0（需真机验证规则生效）。

---

### M3 · 订阅与节点体验闭环（可与 M1/M2 并行）

**目标**：补齐订阅自动化与节点批量管理，达到日常可用。

**任务**
- **订阅自动更新**：用鸿蒙后台任务/定时（`backgroundTaskManager` 或 `reminderAgent`）
  按 `updateInterval` 周期刷新；最小间隔保护（如 15 分钟）
- **正则过滤** `filter`：按节点名筛选导入
- **自定义 User-Agent** 与 `allowInsecureUrl`
- **代理经由更新**：运行中时通过本地 http 端口拉取订阅（GFW 内更新）
- **节点批量操作**：删除重复（去重键 = server+port+password）、批量测速后自动排序、
  测速后自动删除超时节点（`removeInvalidNodes` 已有，补"测速后自动"触发）

**v2rayNG 对照**：`SubscriptionUpdater`（WorkManager）、`AngConfigManager.updateConfigViaSub`、
`MainViewModel` 的批量操作。
**验收标准**：订阅到点自动刷新；去重/过滤/自动排序可用。
**依赖**：M0（测速依赖真机通路）。

---

### M4 · 平台集成与分享（体验层 · 可随时插入）

**目标**：补齐导入/分享/平台入口，对齐 v2rayNG 的便捷体验。

**任务**
- **URL Scheme / Want 深链导入**：对应 v2rayNG `v2rayng://install-config` 与
  `install-sub`，在 `EntryAbility.onCreate/onNewWant` 解析 Want 并导入
- **二维码生成**：节点分享生成 QR（鸿蒙 `@ohos.graphics` 或二维码库），
  补齐"显示二维码 / 单行链接 / 完整 JSON"三种分享形态
- **桌面服务卡片 / 快捷方式**：一键启停、扫码（对应 QSTile/Widget/Shortcuts）
- **常驻速度通知**：上下行实时显示（依赖 M1 的 `CGoQueryStats`）

**v2rayNG 对照**：`UrlSchemeActivity`、`share2QRCode`、`WidgetProvider`/`QSTileService`/`shortcuts.xml`。
**验收标准**：外部链接可一键导入；节点可生成二维码被另一台设备扫入。
**依赖**：M1（速度通知）；其余独立。

---

### M5 · 高级路由与云备份（进阶 · 可选）

**目标**：面向中高级用户的差异化能力。

**任务**
- **负载均衡（Balancer）**：`leastPing/leastLoad/random/roundRobin` +
  `observatory` 探测，生成 `routing.balancers`
- **策略组（PolicyGroup）**：从订阅按正则动态选成员
- **代理链（ProxyChain）**：多段代理串联
- **WebDAV 云备份/恢复**：BASIC 认证 + `MKCOL` 建目录 + 上传/下载 ZIP

**v2rayNG 对照**：`BalancerStrategyType`、`ServerGroupActivity`、`ServerProxyChainActivity`、
`WebDavManager`。
**验收标准**：策略组按延迟自动择优；WebDAV 备份可跨设备恢复。
**依赖**：M2（路由系统）、M3（订阅）。

---

## 四、协议与解析的并行点检（穿插各里程碑）

不单列里程碑，随手补齐：

- Reality 全参数（`spiderX`、`mldsa65`/`pqv`）解析与下发
- `flow`（`xtls-rprx-vision`）字段
- uTLS fingerprint（`fp`）
- Hysteria2 端口跳跃（`mport`）与 `obfs`
- WireGuard `.conf` 文件整段解析
- SOCKS 端口/动态端口/认证、VPN MTU、绕过局域网、代理共享等设置项

---

## 五、依赖关系与排期建议

| 周期 | 主线 | 并行 |
| --- | --- | --- |
| 第 1 段 | **M0 真机闭环** | 协议点检（解析层，纯逻辑可先做） |
| 第 2 段 | M1 内核接线 | M3 订阅自动更新 |
| 第 3 段 | M2 路由系统 | M3 批量操作 + M4 深链导入 |
| 第 4 段 | M4 二维码/卡片/通知 | — |
| 第 5 段 | M5 高级路由 / WebDAV | — |

---

## 六、进度记录

| 日期 | 里程碑 | 变更 |
| --- | --- | --- |
| 2026-06-05 | — | 基于实测建立"稳步推进版"开发计划；确认扫码/分应用已落地，标注内核接线、路由、订阅自动更新、深链、二维码为后续重点 |
