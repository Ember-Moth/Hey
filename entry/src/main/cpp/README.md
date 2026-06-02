# Hey VPN Native Core

`libheyvpn.so` is the ArkTS N-API bridge. It loads one packaged Go shared
library beside it:

- `libxray.so`: built from XTLS/libXray with cgo exports plus the tun2socks
  adapter exports. Required symbols:
  - `CGoRunXrayFromJSON(const char* base64Request) -> char*`
  - `CGoStopXray() -> char*`
  - `CGoPing(const char* base64Request) -> char*` (used by per-node outbound
    delay testing; the bridge `dlopen`s `libxray.so` and calls this with a
    base64 JSON request `{datDir, configPath, timeout, url, proxy}` and parses
    the base64 `{success, data, err}` response for the delay in ms).
  - `HeyTun2SocksStart(int tunFd, const char* socksHost, int socksPort, int mtu) -> int`
  - `HeyTun2SocksStop() -> void`
  - optional `HeyTun2SocksUploadBytes() -> int64_t`
  - optional `HeyTun2SocksDownloadBytes() -> int64_t`
  - optional `HeyTun2SocksLastError() -> char*`

Build the combined core from the project root:

```shell
./scripts/build_libxray_ohos.sh
```

The script places `libxray.so` and `libxray.h` in
`entry/src/main/cpp/prebuilt/arm64-v8a/`. CMake copies only `libxray.so` into
the HAP native library directory after building `libheyvpn.so`, and removes old
standalone tun2socks / executable wrapper artifacts from the build output.

Why tun2socks is built into `libxray.so`: Harmony can load one Android-mode Go
`c-shared` runtime reliably here, but loading separate Go shared libraries in
the same VPN extension process caused runtime/TLS crashes. Keeping Xray and
tun2socks in one shared library avoids a second Go runtime.

Note: the current Go toolchain does not expose `GOOS=ohos`. The build uses
`GOOS=android GOARCH=arm64` with DevEco's `aarch64-unknown-linux-ohos-clang` as
the cgo compiler, plus a tiny Android log stub for `android/log.h` and `-llog`.
This avoids the `R_AARCH64_TLS_*` relocations produced by the Linux Go runtime
that Harmony's loader rejects.

See `docs/vpn-native-runtime-fix.md` for the debugging notes and verification
commands.
