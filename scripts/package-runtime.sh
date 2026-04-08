#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

PY_MAJMIN="$(python_xy)"
STAGED_RUNTIME="${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}"

if [[ ! -d "${STAGED_RUNTIME}" ]]; then
  printf 'Staging runtime not found: %s\nRun ./scripts/build-cpython.sh first.\n' "${STAGED_RUNTIME}" >&2
  exit 1
fi

rm -rf "${RUNTIME_DIR}/full" "${RUNTIME_DIR}/minimal"
rm -rf "${RUNTIME_DIR}/slim"
mkdir -p "${RUNTIME_DIR}/full" "${RUNTIME_DIR}/minimal" "${RUNTIME_DIR}/slim"

function install_launcher() {
  local runtime_root="$1"
  mkdir -p "${runtime_root}/bin"
  cat > "${runtime_root}/bin/python3" <<EOF
#!/system/bin/sh
set -eu

SELF_DIR=\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)
ROOT_DIR=\$(CDPATH= cd -- "\${SELF_DIR}/.." && pwd)
LIB_DIR="\${ROOT_DIR}/lib"
PY_LIB_DIR="\${LIB_DIR}/python${PY_MAJMIN}"

export PYTHONHOME="\${ROOT_DIR}"
export PYTHONPATH="\${LIB_DIR}/python${PY_MAJMIN}.zip:\${PY_LIB_DIR}:\${PY_LIB_DIR}/lib-dynload"
export LD_LIBRARY_PATH="\${LIB_DIR}\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
export LD_PRELOAD="\${LIB_DIR}/libpython${PY_MAJMIN}.so\${LD_PRELOAD:+:\${LD_PRELOAD}}"
export TMPDIR="\${TMPDIR:-/data/local/tmp}"
export HOME="\${HOME:-/data/local/tmp}"
export LANG="\${LANG:-C.UTF-8}"
export LC_ALL="\${LC_ALL:-C.UTF-8}"
export SSL_CERT_FILE="\${ROOT_DIR}/etc/ssl/cert.pem"

if [ -x "\${SELF_DIR}/python${PY_MAJMIN}.bin" ]; then
  exec "\${SELF_DIR}/python${PY_MAJMIN}.bin" "\$@"
fi

exec "\${SELF_DIR}/python3.bin" "\$@"
EOF
  chmod 0755 "${runtime_root}/bin/python3"

  cat > "${runtime_root}/bin/python" <<EOF
#!/system/bin/sh
exec "\$(dirname "\$0")/python3" "\$@"
EOF
  chmod 0755 "${runtime_root}/bin/python"
}

function copy_base_runtime() {
  local variant_root="$1"
  rsync -a "${STAGED_RUNTIME}/" "${variant_root}/"

  if [[ -x "${variant_root}/bin/python3.bin" && ! -e "${variant_root}/bin/python${PY_MAJMIN}.bin" ]]; then
    cp "${variant_root}/bin/python3.bin" "${variant_root}/bin/python${PY_MAJMIN}.bin"
  fi

  install_launcher "${variant_root}"
  mkdir -p "${variant_root}/tests"
  cp "${ROOT_DIR}/tests/"*.py "${variant_root}/tests/"
  if [[ -f "${STAGED_RUNTIME}/BUNDLED-PACKAGES.txt" ]]; then
    cp "${STAGED_RUNTIME}/BUNDLED-PACKAGES.txt" "${variant_root}/"
  fi

  find "${variant_root}" -type d -name '__pycache__' -prune -exec rm -rf {} +
}

function prune_common_noise() {
  local variant_root="$1"

  rm -rf \
    "${variant_root}/lib/python${PY_MAJMIN}/test" \
    "${variant_root}/lib/python${PY_MAJMIN}/tkinter" \
    "${variant_root}/lib/python${PY_MAJMIN}/idlelib"
}

function prune_helper_bins() {
  local variant_root="$1"

  rm -f \
    "${variant_root}/bin/2to3" \
    "${variant_root}/bin/2to3-${PY_MAJMIN}" \
    "${variant_root}/bin/idle3" \
    "${variant_root}/bin/idle3.${PY_MAJMIN#*.}" \
    "${variant_root}/bin/idle3.${PY_MAJMIN}" \
    "${variant_root}/bin/pydoc3" \
    "${variant_root}/bin/pydoc3.${PY_MAJMIN#*.}" \
    "${variant_root}/bin/pydoc3.${PY_MAJMIN}" \
    "${variant_root}/bin/python3-config" \
    "${variant_root}/bin/python3.${PY_MAJMIN#*.}-config" \
    "${variant_root}/bin/python${PY_MAJMIN}-config"
}

function write_manifest() {
  local variant_root="$1"
  local variant_name="$2"
  cat > "${variant_root}/BUILD-INFO.txt" <<EOF
variant=${variant_name}
python_version=${PYTHON_VERSION}
android_abi=${ANDROID_ABI}
android_api=${ANDROID_API}
ndk_version=${ANDROID_NDK_VERSION}
openssl_version=${OPENSSL_VERSION}
zlib_version=${ZLIB_VERSION}
bzip2_version=${BZIP2_VERSION}
xz_version=${XZ_VERSION}
libffi_version=${LIBFFI_VERSION}
sqlite_version=${SQLITE_VERSION}
build_date_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF
}

copy_base_runtime "${RUNTIME_DIR}/full"
write_manifest "${RUNTIME_DIR}/full" "full"
prune_common_noise "${RUNTIME_DIR}/full"

copy_base_runtime "${RUNTIME_DIR}/minimal"
write_manifest "${RUNTIME_DIR}/minimal" "minimal"
prune_common_noise "${RUNTIME_DIR}/minimal"

copy_base_runtime "${RUNTIME_DIR}/slim"
write_manifest "${RUNTIME_DIR}/slim" "slim"
prune_common_noise "${RUNTIME_DIR}/slim"

FULL_STDLIB="${RUNTIME_DIR}/full/lib/python${PY_MAJMIN}"
MIN_STDLIB="${RUNTIME_DIR}/minimal/lib/python${PY_MAJMIN}"
MIN_ZIP="${RUNTIME_DIR}/minimal/lib/python${PY_MAJMIN}.zip"
SLIM_STDLIB="${RUNTIME_DIR}/slim/lib/python${PY_MAJMIN}"
SLIM_ZIP="${RUNTIME_DIR}/slim/lib/python${PY_MAJMIN}.zip"

mkdir -p "${RUNTIME_DIR}/minimal/lib"
mkdir -p "${RUNTIME_DIR}/slim/lib"

pushd "${MIN_STDLIB}" >/dev/null
rm -rf test tkinter idlelib config-${PY_MAJMIN}-*
find . -type d -name '__pycache__' -prune -exec rm -rf {} +
zip -q -r "${MIN_ZIP}" . \
  -x 'lib-dynload/*' \
  -x 'site-packages/*'
popd >/dev/null

find "${MIN_STDLIB}" -mindepth 1 -maxdepth 1 \
  ! -name 'lib-dynload' \
  ! -name 'site-packages' \
  -exec rm -rf {} +

pushd "${SLIM_STDLIB}" >/dev/null
rm -rf test tkinter idlelib ensurepip venv config-${PY_MAJMIN}-*
find . -type d -name '__pycache__' -prune -exec rm -rf {} +
zip -q -r "${SLIM_ZIP}" . \
  -x 'lib-dynload/*' \
  -x 'site-packages/*'
popd >/dev/null

find "${SLIM_STDLIB}" -mindepth 1 -maxdepth 1 \
  ! -name 'lib-dynload' \
  ! -name 'site-packages' \
  -exec rm -rf {} +

rm -rf \
  "${RUNTIME_DIR}/slim/include" \
  "${RUNTIME_DIR}/slim/share" \
  "${RUNTIME_DIR}/slim/tests" \
  "${RUNTIME_DIR}/slim/lib/pkgconfig"
prune_helper_bins "${RUNTIME_DIR}/slim"

rm -f \
  "${DIST_DIR}/python-android-${ANDROID_ABI}-full.tar.gz" \
  "${DIST_DIR}/python-android-${ANDROID_ABI}-minimal.tar.gz" \
  "${DIST_DIR}/python-android-${ANDROID_ABI}-slim.tar.gz"
tar -C "${RUNTIME_DIR}/full" -czf "${DIST_DIR}/python-android-${ANDROID_ABI}-full.tar.gz" .
tar -C "${RUNTIME_DIR}/minimal" -czf "${DIST_DIR}/python-android-${ANDROID_ABI}-minimal.tar.gz" .
tar -C "${RUNTIME_DIR}/slim" -czf "${DIST_DIR}/python-android-${ANDROID_ABI}-slim.tar.gz" .

log "Runtime packages generated in ${DIST_DIR}"
