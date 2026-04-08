#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

ensure_sources

if [[ -x "${HOSTPY_DIR}/bin/python3" ]]; then
  log "Host Python already available at ${HOSTPY_DIR}"
  exit 0
fi

reset_build_dir "${PYTHON_HOST_BUILD_DIR}"
mkdir -p "${HOSTPY_DIR}"

pushd "${PYTHON_HOST_BUILD_DIR}" >/dev/null
log "Configuring host Python ${PYTHON_VERSION}"
"${PYTHON_SRC_DIR}/configure" \
  --prefix="${HOSTPY_DIR}" \
  --without-ensurepip

log "Building host Python ${PYTHON_VERSION}"
make -j"${JOBS}"
make install
popd >/dev/null

log "Host Python ready: ${HOSTPY_DIR}/bin/python3"
