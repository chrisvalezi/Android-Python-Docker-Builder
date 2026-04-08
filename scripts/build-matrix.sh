#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ANDROID_ABIS="${ANDROID_ABIS:-x86_64 arm64-v8a armeabi-v7a}"

for abi in ${ANDROID_ABIS}; do
  printf '\n==> Building ABI %s\n' "${abi}"
  (
    cd "${ROOT_DIR}"
    ANDROID_ABI="${abi}" "${SCRIPT_DIR}/build-all.sh"
  )
done
