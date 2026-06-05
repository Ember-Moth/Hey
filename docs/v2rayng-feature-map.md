# v2rayNG Feature Parity Map

This project targets feature parity with the Android reference v2rayNG
(<https://github.com/2dust/v2rayNG>) without copying Android/Kotlin source,
XML layouts, drawable assets, launcher artwork, strings, or package branding.

Status below is verified against the actual code as of 2026-06-03. For the
phased delivery plan, see [`development-plan.md`](development-plan.md). For an
in-depth analysis of v2rayNG's features and design, see
[`v2rayng-analysis/`](v2rayng-analysis/README.md).

## Page Map

| Android reference area | Harmony page | Current status |
| --- | --- | --- |
| MainActivity / MainRecyclerAdapter | Nodes | Present. Lists subscription nodes, search, select current node, start/stop/restart VPN. |
| Add config menu | Add | Present. Imports share links, outbound JSON, or subscription URL; protocol tabs are scaffolded. |
| ScannerActivity / ScScannerActivity | Scan | Present. Paste/import path is wired; camera QR capture still pending. |
| SubSettingActivity / SubEditActivity | Subs | Multi-group model present. Save/update/select/enable-disable/delete are wired; dedicated edit form and reorder pending. |
| ServerActivity protocol editors | Add | Partial. Field-level editor is present for VLESS/VMess/Trojan/Shadowsocks/SOCKS/HTTP (generates outbound JSON into import buffer). WireGuard/Hysteria2/TUIC editors still pending. |
| ServerCustomConfigActivity | Add | Raw outbound JSON import works. Full custom config import pending. |
| RoutingSettingActivity / RoutingEditActivity | Route | Partial. Traffic mode (global/rules/direct), domain strategy, and bypass-LAN/CN persist and feed generated Xray routing. Ad-block and custom-ruleset presets are display-only dialogs that do NOT yet affect the generated config. Rule editor pending. |
| SettingsActivity | Config | Core, VPN DNS, SOCKS port, mux, sniffing, log level and routing strategy persist and feed generated Xray config. Dedicated pickers and full advanced options pending. |
| PerAppProxyActivity | Apps | Scaffolded. Per-app toggle persists, but app rows only log; Harmony bundle enumeration and blocked/allowed app mapping pending. |
| UserAssetActivity / UserAssetUrlActivity | Assets | Present. geoip/geosite download (Loyalsoldier rules), custom asset URL CRUD, and clipboard backup/restore are implemented. |
| LogcatActivity | Logs | Present. App diagnostic logs and native runtime stats are visible. |
| AboutActivity | About | Present. Harmony-specific about/license note. |
| TaskerActivity / shortcuts / widgets / QS tile | Platform equivalents | Pending. Android-only entry points need Harmony shortcuts/widgets equivalents. |
| UrlSchemeActivity | Import entry | Pending. Harmony Want/deep-link import route needed. |

## Business Function Map

| Function | Current status |
| --- | --- |
| Subscription URL fetch and parse | Present for `vless://`, `vmess://`, `trojan://`, `ss://`, `socks://`, `http://`, `https://`, `wireguard://`, `hysteria2://`, `hy2://`. |
| Node select and save current profile | Present. |
| Xray config generation | Present for outbound + native TUN inbound + basic direct/block outbounds. |
| Persistent app settings | Present for core VPN, DNS, mux, sniffing, log and routing strategy; selected values are applied at connection start. |
| VPN Extension start/stop | Present, with emulator timeout diagnostics. Needs real-device validation. |
| Xray native TUN runtime | Present in HAP via `CGoSetTunFd` + Xray TUN inbound. Needs real-device closed-loop verification. |
| VMess/VLESS/Trojan/Shadowsocks parsing | Present. |
| SOCKS/HTTP/WireGuard/Hysteria2 parsing | Present for share-link import and subscription discovery. Runtime connection for WireGuard/Hysteria2 still needs core validation. |
| TUIC parsing | Pending. |
| Delay test / real ping / sort by delay | Present. Per-node real outbound delay via libXray `CGoPing` (own SOCKS test inbound on port 10825), persisted per node, with sort-by-delay. Falls back to direct URL test when the native core is unavailable (e.g. emulator). Needs real-device validation. |
| Delete all / duplicate / invalid configs | Pending. |
| Export/share configs and QR generation | Partial. Plain-text share-link export (Export page) present. QR code generation pending. |
| Multi-subscription groups | Present with legacy single-subscription migration. Rename/reorder and batch update all pending. |
| Routing rulesets and geo assets | Partial. Geo asset download/management present (Assets page). Routing config only emits a single bypass-LAN/CN rule; ad-block and custom rulesets not yet wired into config generation. |
| Per-app proxy | Pending. Toggle persists; no real bundle enumeration or app mapping. |
| Auto subscription update | Pending. No interval/background refresh. |
| Boot/startup automation | Pending and platform-dependent. |

## Native Bridge Status

`libxray.so` exports 13 CGo functions; `napi_init.cpp` currently wires 4.

- Wired: `CGoRunXrayFromJSON`, `CGoStopXray`, `CGoPing`, `CGoSetTunFd`.
- Idle: `CGoQueryStats` (real traffic stats), `CGoReadGeoFiles` / `CGoCountGeoData`
  (geo validation), `CGoTestXray` (pre-connect config check), `CGoXrayVersion`,
  `CGoConvertShareLinksToXrayJson`, `CGOConvertXrayJsonToShareLinks`,
  `CGoGetFreePorts`, `CGoRunXray`.

The current `getStats()` returns a C++-side approximate counter, not kernel
stats. Wiring `CGoQueryStats` is tracked in roadmap Phase 1.
