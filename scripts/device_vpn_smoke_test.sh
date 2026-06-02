#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk}"
HVIGOR="${HVIGOR:-/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw}"
HDC="${HDC:-${DEVECO_SDK_HOME}/default/openharmony/toolchains/hdc}"
HAP="${ROOT_DIR}/entry/build/default/outputs/default/app/entry-default.hap"

usage() {
  printf 'Usage: %s {build|install|logs|targets|doctor}\n' "$0"
}

require_hdc() {
  if [[ ! -x "${HDC}" ]]; then
    printf 'hdc not found: %s\n' "${HDC}" >&2
    exit 1
  fi
}

case "${1:-}" in
  build)
    DEVECO_SDK_HOME="${DEVECO_SDK_HOME}" "${HVIGOR}" assembleApp --no-daemon --stacktrace
    unzip -l "${HAP}" | awk '/libs\/arm64-v8a\/(libhey|libxray).*\.so/ { print }'
    ;;
  install)
    require_hdc
    if [[ ! -f "${HAP}" ]]; then
      printf 'HAP not found, run build first: %s\n' "${HAP}" >&2
      exit 1
    fi
    "${HDC}" install -r "${HAP}"
    ;;
  logs)
    require_hdc
    "${HDC}" shell hilog | awk '/HeyVpn|HeyVpnAbility|HeyNative|NetworkVpnManager|NETMANAGER_EXT|vpndialog|connectAbility/ { print; fflush(); }'
    ;;
  targets)
    require_hdc
    "${HDC}" list targets
    ;;
  doctor)
    require_hdc
    printf 'Targets:\n'
    "${HDC}" list targets
    printf '\nSystem:\n'
    "${HDC}" shell 'param get const.product.model; param get const.product.software.version; param get const.ohos.apiversion'
    printf '\nVPN dialog package:\n'
    vpn_dialog_dump="$("${HDC}" shell 'bm dump -n com.huawei.hmos.vpndialog 2>&1' || true)"
    if grep -qiE 'failed|not exist|no bundle|no valid extension' <<<"${vpn_dialog_dump}"; then
      printf 'MISSING: com.huawei.hmos.vpndialog is not installed. VPN authorization cannot complete on this target.\n'
      printf '%s\n' "${vpn_dialog_dump}"
    else
      printf 'OK: com.huawei.hmos.vpndialog is installed.\n'
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
