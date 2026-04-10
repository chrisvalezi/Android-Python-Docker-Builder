#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

ensure_sources

if [[ -x "${HOSTPY_DIR}/bin/python3" ]]; then
  if "${HOSTPY_DIR}/bin/python3" - <<'PY' >/dev/null 2>&1
import ssl
import sqlite3
import zlib
import ensurepip
PY
  then
    log "Host Python already available at ${HOSTPY_DIR}"
    exit 0
  fi

  log "Host Python at ${HOSTPY_DIR} is missing required modules; rebuilding"
  rm -rf "${HOSTPY_DIR}" "${PYTHON_HOST_BUILD_DIR}"
fi

reset_build_dir "${PYTHON_HOST_BUILD_DIR}"
mkdir -p "${HOSTPY_DIR}"

pushd "${PYTHON_HOST_BUILD_DIR}" >/dev/null
log "Configuring host Python ${PYTHON_VERSION}"
"${PYTHON_SRC_DIR}/configure" \
  --prefix="${HOSTPY_DIR}" \
  --with-ensurepip=install

log "Building host Python ${PYTHON_VERSION}"
make -j"${JOBS}"
make install
popd >/dev/null

log "Host Python ready: ${HOSTPY_DIR}/bin/python3"
