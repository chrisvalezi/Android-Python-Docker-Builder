#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT_DIR}/config/build.env"

JOBS="${JOBS:-$(nproc)}"

function normalize_android_abi() {
  case "$1" in
    x86_64|arm64-v8a|armeabi-v7a|x86)
      printf '%s\n' "$1"
      ;;
    arm64|aarch64)
      printf '%s\n' "arm64-v8a"
      ;;
    armv7|armv7a|armeabi)
      printf '%s\n' "armeabi-v7a"
      ;;
    *)
      printf 'Unsupported ANDROID_ABI: %s\n' "$1" >&2
      exit 1
      ;;
  esac
}

ANDROID_ABI="$(normalize_android_abi "${ANDROID_ABI}")"

function derive_android_triple() {
  case "${ANDROID_ABI}" in
    x86_64)
      printf '%s\n' "x86_64-linux-android"
      ;;
    arm64-v8a)
      printf '%s\n' "aarch64-linux-android"
      ;;
    armeabi-v7a)
      printf '%s\n' "armv7a-linux-androideabi"
      ;;
    x86)
      printf '%s\n' "i686-linux-android"
      ;;
  esac
}

if [[ -z "${ANDROID_TRIPLE}" ]]; then
  ANDROID_TRIPLE="$(derive_android_triple)"
fi

OUTPUT_DIR="${ROOT_DIR}/output"
DOWNLOADS_DIR="${OUTPUT_DIR}/downloads"
SOURCES_DIR="${OUTPUT_DIR}/sources"
BUILD_DIR="${OUTPUT_DIR}/build"
STAGING_DIR="${OUTPUT_DIR}/staging"
DIST_DIR="${OUTPUT_DIR}/dist"
RUNTIME_DIR="${OUTPUT_DIR}/runtime"
PREFIX_DIR="${OUTPUT_DIR}/prefix/${ANDROID_ABI}"
HOSTPY_DIR="${OUTPUT_DIR}/hostpython/${PYTHON_VERSION}"
NDK_PARENT_DIR="${OUTPUT_DIR}/toolchains"
NDK_DIR="${NDK_PARENT_DIR}/android-ndk-${ANDROID_NDK_VERSION}"

PYTHON_SRC_NAME="Python-${PYTHON_VERSION}"
PYTHON_SRC_DIR="${SOURCES_DIR}/${PYTHON_SRC_NAME}"
PYTHON_HOST_BUILD_DIR="${BUILD_DIR}/hostpython-${PYTHON_VERSION}"
PYTHON_TARGET_BUILD_DIR="${BUILD_DIR}/cpython-${ANDROID_ABI}"
PYTHON_TARGET_STAGING="${STAGING_DIR}/${ANDROID_ABI}"

OPENSSL_SRC_DIR="${SOURCES_DIR}/openssl-${OPENSSL_VERSION}"
ZLIB_SRC_DIR="${SOURCES_DIR}/zlib-${ZLIB_VERSION}"
BZIP2_SRC_DIR="${SOURCES_DIR}/bzip2-${BZIP2_VERSION}"
XZ_SRC_DIR="${SOURCES_DIR}/xz-${XZ_VERSION}"
LIBFFI_SRC_DIR="${SOURCES_DIR}/libffi-${LIBFFI_VERSION}"
SQLITE_SRC_DIR="${SOURCES_DIR}/${SQLITE_AUTOCONF}"

function log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

function ensure_dirs() {
  mkdir -p \
    "${DOWNLOADS_DIR}" \
    "${SOURCES_DIR}" \
    "${BUILD_DIR}" \
    "${STAGING_DIR}" \
    "${DIST_DIR}" \
    "${RUNTIME_DIR}" \
    "${PREFIX_DIR}" \
    "${NDK_PARENT_DIR}"
}

function download_if_missing() {
  local url="$1"
  local dst="$2"
  if [[ ! -f "${dst}" ]]; then
    log "Downloading ${url}"
    curl -L --fail --retry 5 --retry-delay 3 -o "${dst}" "${url}"
  fi
}

function extract_if_missing() {
  local archive="$1"
  local target_dir="$2"
  local strip_components="${3:-0}"

  if [[ -d "${target_dir}" ]]; then
    return
  fi

  mkdir -p "${target_dir}"
  case "${archive}" in
    *.tar.gz|*.tgz)
      tar -xzf "${archive}" -C "${target_dir}" --strip-components="${strip_components}"
      ;;
    *.tar.xz)
      tar -xJf "${archive}" -C "${target_dir}" --strip-components="${strip_components}"
      ;;
    *.zip)
      unzip -q "${archive}" -d "${target_dir}"
      ;;
    *)
      printf 'Unsupported archive format: %s\n' "${archive}" >&2
      exit 1
      ;;
  esac
}

function fetch_sources() {
  ensure_dirs

  download_if_missing "${PYTHON_URL}" "${DOWNLOADS_DIR}/${PYTHON_SRC_NAME}.tgz"
  download_if_missing "${OPENSSL_URL}" "${DOWNLOADS_DIR}/openssl-${OPENSSL_VERSION}.tar.gz"
  download_if_missing "${ZLIB_URL}" "${DOWNLOADS_DIR}/zlib-${ZLIB_VERSION}.tar.gz"
  download_if_missing "${BZIP2_URL}" "${DOWNLOADS_DIR}/bzip2-${BZIP2_VERSION}.tar.gz"
  download_if_missing "${XZ_URL}" "${DOWNLOADS_DIR}/xz-${XZ_VERSION}.tar.gz"
  download_if_missing "${LIBFFI_URL}" "${DOWNLOADS_DIR}/libffi-${LIBFFI_VERSION}.tar.gz"
  download_if_missing "${SQLITE_URL}" "${DOWNLOADS_DIR}/${SQLITE_AUTOCONF}.tar.gz"
}

function ensure_sources() {
  fetch_sources

  extract_if_missing "${DOWNLOADS_DIR}/${PYTHON_SRC_NAME}.tgz" "${PYTHON_SRC_DIR}" 1
  extract_if_missing "${DOWNLOADS_DIR}/openssl-${OPENSSL_VERSION}.tar.gz" "${OPENSSL_SRC_DIR}" 1
  extract_if_missing "${DOWNLOADS_DIR}/zlib-${ZLIB_VERSION}.tar.gz" "${ZLIB_SRC_DIR}" 1
  extract_if_missing "${DOWNLOADS_DIR}/bzip2-${BZIP2_VERSION}.tar.gz" "${BZIP2_SRC_DIR}" 1
  extract_if_missing "${DOWNLOADS_DIR}/xz-${XZ_VERSION}.tar.gz" "${XZ_SRC_DIR}" 1
  extract_if_missing "${DOWNLOADS_DIR}/libffi-${LIBFFI_VERSION}.tar.gz" "${LIBFFI_SRC_DIR}" 1
  extract_if_missing "${DOWNLOADS_DIR}/${SQLITE_AUTOCONF}.tar.gz" "${SQLITE_SRC_DIR}" 1
}

function ensure_ndk() {
  ensure_dirs
  if [[ -d "${NDK_DIR}" ]]; then
    return
  fi

  local archive="${DOWNLOADS_DIR}/android-ndk-${ANDROID_NDK_VERSION}-linux.zip"
  download_if_missing "${ANDROID_NDK_URL}" "${archive}"

  rm -rf "${NDK_PARENT_DIR}/android-ndk-${ANDROID_NDK_VERSION}.tmp"
  mkdir -p "${NDK_PARENT_DIR}/android-ndk-${ANDROID_NDK_VERSION}.tmp"
  unzip -q "${archive}" -d "${NDK_PARENT_DIR}/android-ndk-${ANDROID_NDK_VERSION}.tmp"
  mv "${NDK_PARENT_DIR}/android-ndk-${ANDROID_NDK_VERSION}.tmp/android-ndk-${ANDROID_NDK_VERSION}" "${NDK_DIR}"
  rmdir "${NDK_PARENT_DIR}/android-ndk-${ANDROID_NDK_VERSION}.tmp"
}

function setup_android_env() {
  export TOOLCHAIN="${NDK_DIR}/toolchains/llvm/prebuilt/linux-x86_64"
  export PATH="${TOOLCHAIN}/bin:${PATH}"
  export AR="${TOOLCHAIN}/bin/llvm-ar"
  export AS="${TOOLCHAIN}/bin/llvm-as"
  export CC="${TOOLCHAIN}/bin/${ANDROID_TRIPLE}${ANDROID_API}-clang"
  export CXX="${TOOLCHAIN}/bin/${ANDROID_TRIPLE}${ANDROID_API}-clang++"
  export LD="${TOOLCHAIN}/bin/ld"
  export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
  export STRIP="${TOOLCHAIN}/bin/llvm-strip"
  export READELF="${TOOLCHAIN}/bin/llvm-readelf"
  export SYSROOT="${TOOLCHAIN}/sysroot"

  export CPPFLAGS="-I${PREFIX_DIR}/include"
  export CFLAGS="--sysroot=${SYSROOT} -fPIC -O2 -I${PREFIX_DIR}/include"
  export CXXFLAGS="${CFLAGS}"
  export LDFLAGS="--sysroot=${SYSROOT} -L${PREFIX_DIR}/lib"
  export PKG_CONFIG_LIBDIR="${PREFIX_DIR}/lib/pkgconfig:${PREFIX_DIR}/share/pkgconfig"
  export PKG_CONFIG_SYSROOT_DIR=""
  export PKG_CONFIG_PATH="${PKG_CONFIG_LIBDIR}"
  export ac_cv_func_malloc_0_nonnull=yes
  export ac_cv_func_realloc_0_nonnull=yes
}

function build_triplet() {
  "${PYTHON_SRC_DIR}/config.guess"
}

function write_python_config_site() {
  local dst="${BUILD_DIR}/python-android-${ANDROID_ABI}.config.site"
  cat > "${dst}" <<EOF
ac_cv_file__dev_ptmx=yes
ac_cv_file__dev_ptc=no
ac_cv_func_getentropy=yes
ac_cv_buggy_getaddrinfo=no
ac_cv_func_sem_open=yes
ac_cv_little_endian_double=yes
EOF
  printf '%s\n' "${dst}"
}

function python_xy() {
  printf '%s' "${PYTHON_VERSION%.*}"
}

function runtime_slug() {
  printf 'python-android-%s' "${ANDROID_ABI}"
}

function reset_build_dir() {
  local dir="$1"
  rm -rf "${dir}"
  mkdir -p "${dir}"
}
