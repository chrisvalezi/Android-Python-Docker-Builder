#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

ensure_sources
ensure_ndk
setup_android_env

mkdir -p "${PREFIX_DIR}/lib/pkgconfig"

function remove_android_unsupported_libs() {
  find "${PREFIX_DIR}/bin" "${PREFIX_DIR}/lib" -type f \
    \( -name '*-config' -o -name '*.pc' -o -name '*.la' -o -name '*.sh' \) \
    -exec sed -i 's/[[:space:]]-lrt\([[:space:]]\\|$\)/ /g' {} +
}

function build_zlib() {
  if [[ -f "${PREFIX_DIR}/lib/libz.a" ]]; then
    log "zlib already built"
    return
  fi

  pushd "${ZLIB_SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  CHOST="${ANDROID_TRIPLE}" CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" CFLAGS="${CFLAGS}" \
    ./configure --static --prefix="${PREFIX_DIR}"
  make -j"${JOBS}"
  make install
  popd >/dev/null

  cat > "${PREFIX_DIR}/lib/pkgconfig/zlib.pc" <<EOF
prefix=${PREFIX_DIR}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: zlib
Description: zlib compression library
Version: ${ZLIB_VERSION}
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
EOF
}

function build_bzip2() {
  if [[ -f "${PREFIX_DIR}/lib/libbz2.a" ]]; then
    log "bzip2 already built"
    return
  fi

  pushd "${BZIP2_SRC_DIR}" >/dev/null
  make clean >/dev/null 2>&1 || true
  make -j"${JOBS}" libbz2.a \
    CC="${CC}" \
    AR="${AR}" \
    RANLIB="${RANLIB}" \
    CFLAGS="${CFLAGS}"
  install -Dm644 libbz2.a "${PREFIX_DIR}/lib/libbz2.a"
  install -Dm644 bzlib.h "${PREFIX_DIR}/include/bzlib.h"
  popd >/dev/null

  cat > "${PREFIX_DIR}/lib/pkgconfig/bzip2.pc" <<EOF
prefix=${PREFIX_DIR}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: bzip2
Description: bzip2 compression library
Version: ${BZIP2_VERSION}
Libs: -L\${libdir} -lbz2
Cflags: -I\${includedir}
EOF
}

function build_xz() {
  if [[ -f "${PREFIX_DIR}/lib/liblzma.a" ]]; then
    log "xz/liblzma already built"
    return
  fi

  pushd "${XZ_SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  ./configure \
    --host="${ANDROID_TRIPLE}" \
    --prefix="${PREFIX_DIR}" \
    --disable-shared \
    --enable-static \
    --disable-xz \
    --disable-xzdec \
    --disable-lzmadec \
    --disable-lzmainfo \
    --disable-scripts \
    --disable-doc
  make -j"${JOBS}"
  make install
  remove_android_unsupported_libs
  popd >/dev/null
}

function build_libffi() {
  if [[ -f "${PREFIX_DIR}/lib/libffi.a" ]]; then
    log "libffi already built"
    return
  fi

  pushd "${LIBFFI_SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  ./configure \
    --host="${ANDROID_TRIPLE}" \
    --prefix="${PREFIX_DIR}" \
    --disable-shared \
    --enable-static \
    --with-pic
  make -j"${JOBS}"
  make install
  remove_android_unsupported_libs
  popd >/dev/null
}

function build_sqlite() {
  if [[ -f "${PREFIX_DIR}/lib/libsqlite3.a" ]]; then
    log "sqlite already built"
    return
  fi

  pushd "${SQLITE_SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  ./configure \
    --host="${ANDROID_TRIPLE}" \
    --prefix="${PREFIX_DIR}" \
    --disable-shared \
    --enable-static \
    --disable-readline \
    --enable-threadsafe \
    --disable-load-extension
  make -j"${JOBS}"
  make install
  remove_android_unsupported_libs
  popd >/dev/null
}

function build_openssl() {
  if [[ -f "${PREFIX_DIR}/lib/libssl.a" && -f "${PREFIX_DIR}/lib/libcrypto.a" ]]; then
    log "OpenSSL already built"
    return
  fi

  pushd "${OPENSSL_SRC_DIR}" >/dev/null
  make clean >/dev/null 2>&1 || true
  export ANDROID_NDK_ROOT="${NDK_DIR}"
  export PATH="${TOOLCHAIN}/bin:${PATH}"
  ./Configure \
    "$(android_openssl_target)" \
    no-tests \
    no-shared \
    no-module \
    --prefix="${PREFIX_DIR}" \
    --openssldir="${PREFIX_DIR}/ssl" \
    -D__ANDROID_API__="${ANDROID_API}"
  make -j"${JOBS}"
  make install_sw
  popd >/dev/null
}

function build_libxml2() {
  if [[ -f "${PREFIX_DIR}/lib/libxml2.a" ]]; then
    log "libxml2 already built"
    return
  fi

  pushd "${LIBXML2_SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  ./configure \
    --host="${ANDROID_TRIPLE}" \
    --prefix="${PREFIX_DIR}" \
    --disable-shared \
    --enable-static \
    --without-python \
    --without-iconv \
    --without-lzma \
    --with-zlib="${PREFIX_DIR}"
  make -j"${JOBS}"
  make install
  remove_android_unsupported_libs
  popd >/dev/null
}

function build_libxslt() {
  if [[ -f "${PREFIX_DIR}/lib/libxslt.a" ]]; then
    log "libxslt already built"
    return
  fi

  pushd "${LIBXSLT_SRC_DIR}" >/dev/null
  make distclean >/dev/null 2>&1 || true
  ./configure \
    --host="${ANDROID_TRIPLE}" \
    --prefix="${PREFIX_DIR}" \
    --disable-shared \
    --enable-static \
    --without-python \
    --without-crypto \
    --with-libxml-prefix="${PREFIX_DIR}"
  make -j"${JOBS}"
  make install
  remove_android_unsupported_libs
  popd >/dev/null
}

log "Building Android third-party dependencies for ${ANDROID_ABI}"
build_zlib
build_bzip2
build_xz
build_libffi
build_sqlite
build_openssl
build_libxml2
build_libxslt
log "All dependencies finished"
