#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
OHOS_NATIVE_HOME="${OHOS_NATIVE_HOME:-${SDK_HOME}/default/openharmony/native}"
CC_BIN="${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang"
CXX_BIN="${OHOS_NATIVE_HOME}/llvm/bin/aarch64-unknown-linux-ohos-clang++"
AR_BIN="${OHOS_NATIVE_HOME}/llvm/bin/llvm-ar"
WORK_DIR="${ROOT_DIR}/build/native/libxray-ohos"
SRC_DIR="${WORK_DIR}/src"
OUT_DIR="${ROOT_DIR}/entry/src/main/cpp/prebuilt/arm64-v8a"
LIBXRAY_REPO="${LIBXRAY_REPO:-https://github.com/XTLS/libXray.git}"
TUN2SOCKS_VERSION="${TUN2SOCKS_VERSION:-v2.6.0}"
GVISOR_VERSION="${GVISOR_VERSION:-v0.0.0-20250523182742-eede7a881b20}"
EXPORTS_FILE="${WORK_DIR}/libxray.exports"
GO_LDFLAGS_DEFAULT="-s -w -linkmode external -extldflags \"-Wl,--version-script=${EXPORTS_FILE} -Wl,-z,lazy\""
GOOS_TARGET="${GOOS_TARGET:-android}"
ANDROID_STUB_DIR="${WORK_DIR}/android-stub"

mkdir -p "${WORK_DIR}" "${OUT_DIR}"
rm -rf "${SRC_DIR}"
cat > "${EXPORTS_FILE}" <<'MAP'
{
  global:
    CGoRunXrayFromJSON;
    CGoStopXray;
    CGoPing;
    CGoSetTunFd;
    HeyTun2SocksStart;
    HeyTun2SocksStop;
    HeyTun2SocksUploadBytes;
    HeyTun2SocksDownloadBytes;
    HeyTun2SocksLastError;
  local: *;
};
MAP

if [[ "${GOOS_TARGET}" == "android" ]]; then
  mkdir -p "${ANDROID_STUB_DIR}/android"
  cat > "${ANDROID_STUB_DIR}/android/log.h" <<'H'
#pragma once
#include <stdarg.h>
#define ANDROID_LOG_FATAL 6
#ifdef __cplusplus
extern "C" {
#endif
int __android_log_vprint(int prio, const char* tag, const char* fmt, va_list ap);
#ifdef __cplusplus
}
#endif
H
  cat > "${ANDROID_STUB_DIR}/android_log_stub.c" <<'C'
#include <stdarg.h>
#include <stdio.h>
int __android_log_vprint(int prio, const char* tag, const char* fmt, va_list ap) {
    (void)prio;
    if (tag != 0) {
        fprintf(stderr, "%s: ", tag);
    }
    int n = vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    return n;
}
C
  "${CC_BIN}" -c "${ANDROID_STUB_DIR}/android_log_stub.c" -o "${ANDROID_STUB_DIR}/android_log_stub.o"
  "${AR_BIN}" rcs "${ANDROID_STUB_DIR}/liblog.a" "${ANDROID_STUB_DIR}/android_log_stub.o"
  export CGO_CFLAGS="${CGO_CFLAGS:-} -I${ANDROID_STUB_DIR}"
  export CGO_LDFLAGS="${CGO_LDFLAGS:-} -L${ANDROID_STUB_DIR}"
fi

if [[ -n "${LIBXRAY_SRC:-}" ]]; then
  cp -R "${LIBXRAY_SRC}" "${SRC_DIR}"
else
  git clone --depth 1 "${LIBXRAY_REPO}" "${SRC_DIR}"
fi

cd "${SRC_DIR}"
cp build/template/main.gotemplate main.go
python3 - <<'PY'
from pathlib import Path

for path in Path(".").glob("*.go"):
    text = path.read_text()
    path.write_text(text.replace("package libXray\n", "package main\n"))
PY

if [[ "${GOOS_TARGET}" == "android" ]]; then
  python3 - <<'PY'
from pathlib import Path

path = Path("main.go")
text = path.read_text()
for block in [
    """//export CGoInitDns
func CGoInitDns(base64Text *C.char) *C.char {
\ttext := C.GoString(base64Text)
\treturn C.CString(InitDns(text))
}

""",
    """//export CGoResetDns
func CGoResetDns() *C.char {
\treturn C.CString(ResetDns())
}

""",
]:
    if block not in text:
        raise SystemExit(f"expected Android-incompatible export block not found: {block.splitlines()[0]}")
    text = text.replace(block, "")
path.write_text(text)
PY
fi

cat > hey_tun2socks.go <<'GO'
package main

/*
#include <stdint.h>
*/
import "C"

import (
	"fmt"
	"sync/atomic"

	"github.com/xjasonlyu/tun2socks/v2/engine"
	"github.com/xjasonlyu/tun2socks/v2/tunnel/statistic"
)

var heyTun2SocksRunning atomic.Bool
var heyTun2SocksLastError atomic.Value

//export HeyTun2SocksStart
func HeyTun2SocksStart(tunFd C.int, socksHost *C.char, socksPort C.int, mtu C.int) C.int {
	host := C.GoString(socksHost)
	if err := heyStartTun2Socks(int(tunFd), host, int(socksPort), int(mtu)); err != nil {
		heyTun2SocksLastError.Store(err.Error())
		return -1
	}
	heyTun2SocksLastError.Store("")
	return 0
}

//export HeyTun2SocksStop
func HeyTun2SocksStop() {
	heyStopTun2Socks()
}

//export HeyTun2SocksUploadBytes
func HeyTun2SocksUploadBytes() C.int64_t {
	return C.int64_t(statistic.DefaultManager.Snapshot().UploadTotal)
}

//export HeyTun2SocksDownloadBytes
func HeyTun2SocksDownloadBytes() C.int64_t {
	return C.int64_t(statistic.DefaultManager.Snapshot().DownloadTotal)
}

//export HeyTun2SocksLastError
func HeyTun2SocksLastError() *C.char {
	value := heyTun2SocksLastError.Load()
	if text, ok := value.(string); ok {
		return C.CString(text)
	}
	return C.CString("")
}

func heyStartTun2Socks(tunFd int, socksHost string, socksPort int, mtu int) error {
	if heyTun2SocksRunning.Load() {
		return nil
	}
	if tunFd < 0 || socksHost == "" || socksPort <= 0 || mtu <= 0 {
		return fmt.Errorf("invalid tun2socks arguments: tunFd=%d host=%q port=%d mtu=%d", tunFd, socksHost, socksPort, mtu)
	}

	engine.Insert(&engine.Key{
		MTU:      mtu,
		Device:   fmt.Sprintf("fd://%d", tunFd),
		Proxy:    fmt.Sprintf("socks5://%s:%d", socksHost, socksPort),
		LogLevel: "warn",
	})
	if err := engine.StartWithError(); err != nil {
		return err
	}
	heyTun2SocksRunning.Store(true)
	return nil
}

func heyStopTun2Socks() {
	if heyTun2SocksRunning.Swap(false) {
		if err := engine.StopWithError(); err != nil {
			heyTun2SocksLastError.Store(err.Error())
		}
	}
}
GO

go get "github.com/xjasonlyu/tun2socks/v2@${TUN2SOCKS_VERSION}"
PATCHED_TUN2SOCKS_DIR="${WORK_DIR}/tun2socks-patched"
if [[ -d "${PATCHED_TUN2SOCKS_DIR}" ]]; then
  chmod -R u+w "${PATCHED_TUN2SOCKS_DIR}"
fi
rm -rf "${PATCHED_TUN2SOCKS_DIR}"
cp -R "$(go env GOMODCACHE)/github.com/xjasonlyu/tun2socks/v2@${TUN2SOCKS_VERSION}" "${PATCHED_TUN2SOCKS_DIR}"
chmod -R u+w "${PATCHED_TUN2SOCKS_DIR}"
cat > "${PATCHED_TUN2SOCKS_DIR}/engine/start_error.go" <<'GO'
package engine

func StartWithError() error {
	return start()
}

func StopWithError() error {
	return stop()
}
GO
cat > "${PATCHED_TUN2SOCKS_DIR}/core/device/fdbased/open_linux.go" <<'GO'
package fdbased

import (
	"fmt"
	"os"

	"github.com/xjasonlyu/tun2socks/v2/core/device"
	"github.com/xjasonlyu/tun2socks/v2/core/device/iobased"
)

func open(fd int, mtu uint32, offset int) (device.Device, error) {
	f := &FD{fd: fd, mtu: mtu}
	ep, err := iobased.New(os.NewFile(uintptr(fd), f.Name()), mtu, offset)
	if err != nil {
		return nil, fmt.Errorf("create endpoint: %w", err)
	}
	f.LinkEndpoint = ep

	return f, nil
}
GO
go mod edit -replace="github.com/xjasonlyu/tun2socks/v2=${PATCHED_TUN2SOCKS_DIR}"
go mod edit -require="gvisor.dev/gvisor@${GVISOR_VERSION}"
go mod edit -replace="gvisor.dev/gvisor=gvisor.dev/gvisor@${GVISOR_VERSION}"
go mod download gvisor.dev/gvisor
go mod tidy

CGO_ENABLED=1 \
GOOS="${GOOS_TARGET}" \
GOARCH=arm64 \
CC="${CC_BIN}" \
CXX="${CXX_BIN}" \
go build \
  -tags "${GO_TAGS:-netgo}" \
  -trimpath \
  -ldflags="${GO_LDFLAGS:-${GO_LDFLAGS_DEFAULT}}" \
  -buildmode=c-shared \
  -o "${OUT_DIR}/libxray.so" \
  .

echo "Built ${OUT_DIR}/libxray.so"
