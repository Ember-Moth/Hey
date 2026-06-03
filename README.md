# Hey VPN

Hey VPN is a HarmonyOS VPN client MVP built with ArkTS, Stage model abilities,
and a native Xray core. It is designed to import proxy nodes,
generate an Xray runtime config, start a HarmonyOS VPN Extension, and route the
device TUN flow through Xray's native TUN inbound.

The current native path is:

```text
User connects
  -> vpnExtension.startVpnExtensionAbility(...)
  -> HeyVpnAbility.onCreate(want)
  -> vpnExtension.createVpnConnection(context)
  -> vpnConnection.create(vpnConfig)
  -> TUN fd
  -> libheyvpn.so dlopen(libxray.so)
  -> CGoSetTunFd(tunFd)
  -> CGoRunXrayFromJSON(config)
  -> Xray native TUN inbound reads the Harmony VPN fd
  -> Xray outbound
```

## Status

This repository is an active MVP. The UI, share-link import, subscription
loading, Xray config generation, native bridge packaging, and VPN extension
startup path are present. Full closed-loop traffic validation should be done on
a real HarmonyOS device because some emulator/system images do not include the
VPN authorization component.

## Features

- HarmonyOS Stage app with `EntryAbility`, `HeyVpnAbility`, and backup ability.
- Node list, search, selection, start/stop/restart controls, and runtime status.
- Import of subscription URLs, Xray outbound JSON, and share links.
- Share-link parsing for `vless://`, `vmess://`, `trojan://`, and `ss://`.
- Xray config generation with native TUN inbound plus proxy/direct/block
  outbounds.
- Native N-API bridge for packaged `libxray.so`, including TUN fd setup and
  Xray lifecycle entry points.
- Diagnostic log panel and native runtime stat display.
- Scaffolded pages for routing, settings, per-app proxy, user assets, scanner,
  subscriptions, logs, and about.

## Project Layout

```text
AppScope/                         App-level HarmonyOS metadata and resources
entry/src/main/ets/               ArkTS UI, services, storage, VPN ability
entry/src/main/cpp/               Native N-API bridge and prebuilt core notes
entry/src/main/cpp/prebuilt/      Packaged arm64-v8a native libraries
scripts/                          Native build and device smoke-test scripts
docs/                             Real-device test documentation
```

## Requirements

- DevEco Studio / HarmonyOS SDK 6.1.1, API 24.
- A HarmonyOS phone or tablet for end-to-end VPN testing.
- Go and DevEco native toolchains when rebuilding the Xray shared library.

## Build

Build the app with the project smoke-test script:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk ./scripts/device_vpn_smoke_test.sh build
```

The output HAP is expected at:

```text
entry/build/default/outputs/default/entry-default-signed.hap
```

Rebuild the Xray native core when needed:

```bash
./scripts/build_libxray_ohos.sh
```

The script places `libxray.so` and `libxray.h` under
`entry/src/main/cpp/prebuilt/arm64-v8a/`.

## Install And Test

List connected targets:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk ./scripts/device_vpn_smoke_test.sh targets
```

Install the HAP:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk ./scripts/device_vpn_smoke_test.sh install
```

Watch VPN and native bridge logs:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk ./scripts/device_vpn_smoke_test.sh logs
```

For the manual closed-loop checklist, see
[`docs/real-device-vpn-test.md`](docs/real-device-vpn-test.md).

## Native Core

The native bridge builds `libheyvpn.so` and loads one packaged Go shared
library, `libxray.so`. That library exports Xray control symbols plus
`CGoSetTunFd`, documented in
[`entry/src/main/cpp/README.md`](entry/src/main/cpp/README.md).

Hey VPN does not bundle or invoke `tun2socks` for the VPN data path. HarmonyOS
creates the VPN TUN fd, `libheyvpn.so` passes that fd into Xray with
`CGoSetTunFd`, and the generated runtime config uses Xray's native
`protocol: "tun"` inbound. A local SOCKS inbound may still be generated for
per-node delay tests, but it is separate from VPN traffic forwarding.

## Roadmap

- Real-device VPN traffic validation across more HarmonyOS versions.
- Delay testing, sorting, duplicate cleanup, export/share, and QR generation.
- Protocol editors for SOCKS, HTTP, WireGuard, Hysteria2, TUIC, and advanced
  VLESS/VMess/Trojan/Shadowsocks fields.
- Multi-subscription groups and automatic subscription refresh.
- Routing rulesets, geo asset management, and per-app proxy persistence.
- HarmonyOS deep-link import, shortcuts, and platform-specific automation.
