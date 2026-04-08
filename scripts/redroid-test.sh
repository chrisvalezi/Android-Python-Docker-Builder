#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

REDROID_CONTAINER="${REDROID_CONTAINER:-android-15}"
REMOTE_RUNTIME="${REMOTE_RUNTIME:-/data/local/tmp/${ANDROID_ABI}/$(runtime_slug)}"
SYSTEM_BIN_PYTHON3="${SYSTEM_BIN_PYTHON3:-python3}"
SYSTEM_BIN_PYTHON="${SYSTEM_BIN_PYTHON:-python}"
RUN_NETWORK_TESTS="${RUN_NETWORK_TESTS:-1}"

"${ROOT_DIR}/scripts/redroid-push.sh"

function redroid_prop() {
  docker exec "${REDROID_CONTAINER}" sh -lc "getprop '$1'" 2>/dev/null || true
}

function fail_with_runtime_diagnostics() {
  local binary="${REMOTE_RUNTIME}/bin/python3.12.bin"
  printf 'Failed to execute runtime on %s.\n' "${REDROID_CONTAINER}" >&2
  printf 'Requested ABI: %s\n' "${ANDROID_ABI}" >&2
  printf 'uname -m: %s\n' "$(docker exec "${REDROID_CONTAINER}" sh -lc 'uname -m' 2>/dev/null || true)" >&2
  printf 'ro.product.cpu.abi: %s\n' "$(redroid_prop ro.product.cpu.abi)" >&2
  printf 'ro.product.cpu.abilist: %s\n' "$(redroid_prop ro.product.cpu.abilist)" >&2
  printf 'ro.dalvik.vm.native.bridge: %s\n' "$(redroid_prop ro.dalvik.vm.native.bridge)" >&2
  printf 'Target binary: %s\n' "$(docker exec "${REDROID_CONTAINER}" sh -lc "file '${binary}'" 2>/dev/null || true)" >&2
  cat >&2 <<'EOF'
The container may advertise secondary ABIs, but the Android shell still needs to be able to execute the target ELF directly.
If the shell reports "not executable: 64-bit ELF file" or the linker reports an ELF machine mismatch, this Redroid image is not exposing ARM native-bridge execution to shell binaries.
EOF
  exit 1
}

if ! docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' --version"; then
  fail_with_runtime_diagnostics
fi

docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' '${REMOTE_RUNTIME}/tests/android_smoke_test.py'"
docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' '${REMOTE_RUNTIME}/tests/external_hello.py'"

if [[ "${RUN_NETWORK_TESTS}" == "1" ]]; then
  docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' '${REMOTE_RUNTIME}/tests/network_tls_test.py'"
fi

docker exec "${REDROID_CONTAINER}" sh -lc "'/system/bin/${SYSTEM_BIN_PYTHON3}' --version"
docker exec "${REDROID_CONTAINER}" sh -lc "'/system/bin/${SYSTEM_BIN_PYTHON}' --version"
