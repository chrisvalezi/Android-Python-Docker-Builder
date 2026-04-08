#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DISTCLEAN=0

if [[ "${1:-}" == "--distclean" ]]; then
  DISTCLEAN=1
fi

rm -rf \
  "${ROOT_DIR}/output/build" \
  "${ROOT_DIR}/output/staging" \
  "${ROOT_DIR}/output/dist" \
  "${ROOT_DIR}/output/runtime" \
  "${ROOT_DIR}/output/prefix" \
  "${ROOT_DIR}/output/hostpython"

mkdir -p "${ROOT_DIR}/output"
touch "${ROOT_DIR}/output/.gitkeep"

if [[ "${DISTCLEAN}" -eq 1 ]]; then
  rm -rf \
    "${ROOT_DIR}/output/downloads" \
    "${ROOT_DIR}/output/sources" \
    "${ROOT_DIR}/output/toolchains"
fi
