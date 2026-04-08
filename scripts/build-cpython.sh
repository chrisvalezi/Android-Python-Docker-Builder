#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

ensure_sources
ensure_ndk
setup_android_env
"$(cd "$(dirname "$0")" && pwd)/build-host-python.sh"
"$(cd "$(dirname "$0")" && pwd)/build-deps.sh"

reset_build_dir "${PYTHON_TARGET_BUILD_DIR}"
rm -rf "${PYTHON_TARGET_STAGING}"
mkdir -p "${PYTHON_TARGET_STAGING}"

CONFIG_SITE_FILE="$(write_python_config_site)"
BUILD_TRIPLET="$(build_triplet)"
PY_MAJMIN="$(python_xy)"

cat > "${PYTHON_SRC_DIR}/Modules/Setup.local" <<EOF
# Mantem o build no modo default e apenas ajuda a detectar dependencias Android.
*disabled*
_tkinter
_curses
_curses_panel
readline
grp
spwd
nis
ossaudiodev
EOF

pushd "${PYTHON_TARGET_BUILD_DIR}" >/dev/null
log "Configuring CPython ${PYTHON_VERSION} for Android ${ANDROID_ABI}"
CONFIG_SITE="${CONFIG_SITE_FILE}" \
LIBFFI_CFLAGS="-I${PREFIX_DIR}/include" \
LIBFFI_LIBS="-L${PREFIX_DIR}/lib -lffi" \
"${PYTHON_SRC_DIR}/configure" \
  --build="${BUILD_TRIPLET}" \
  --host="${ANDROID_TRIPLE}" \
  --prefix="${RUNTIME_PREFIX}" \
  --enable-shared \
  --without-ensurepip \
  --with-build-python="${HOSTPY_DIR}/bin/python3" \
  --with-openssl="${PREFIX_DIR}" \
  --with-openssl-rpath=no

# Ajustes pragmáticos para Android/Bionic:
# - desabilita modulos Unix com baixa portabilidade no shell puro
# - força _sqlite3 usando os flags detectados pelo configure
sed -i \
  -e 's/^grp grpmodule.c/#grp grpmodule.c/' \
  -e 's/^ossaudiodev ossaudiodev.c/#ossaudiodev ossaudiodev.c/' \
  -e 's/^_sqlite3 /#_sqlite3 /' \
  "${PYTHON_TARGET_BUILD_DIR}/Modules/Setup.stdlib"
printf '%s\n' "_sqlite3 _sqlite/blob.c _sqlite/connection.c _sqlite/cursor.c _sqlite/microprotocols.c _sqlite/module.c _sqlite/prepare_protocol.c _sqlite/row.c _sqlite/statement.c _sqlite/util.c -I${PREFIX_DIR}/include -L${PREFIX_DIR}/lib -lsqlite3 -lz -lm" \
  >> "${PYTHON_TARGET_BUILD_DIR}/Modules/Setup.local"

log "Building CPython ${PYTHON_VERSION} for Android ${ANDROID_ABI}"
make -j"${JOBS}" \
  CROSS_COMPILE=yes \
  BLDSHARED="${CC} -shared" \
  LDSHARED="${CC} -shared"

log "Installing staging runtime"
make install DESTDIR="${PYTHON_TARGET_STAGING}"
popd >/dev/null

if [[ -f "${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}/bin/python${PY_MAJMIN}" ]]; then
  mv \
    "${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}/bin/python${PY_MAJMIN}" \
    "${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}/bin/python${PY_MAJMIN}.bin"
fi

if [[ -f "${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}/bin/python3" ]]; then
  mv \
    "${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}/bin/python3" \
    "${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}/bin/python3.bin"
fi

install -Dm644 /etc/ssl/certs/ca-certificates.crt \
  "${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}/etc/ssl/cert.pem"

log "CPython target staging ready at ${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}"
