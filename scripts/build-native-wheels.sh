#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

ensure_ndk
setup_android_env
"$(cd "$(dirname "$0")" && pwd)/build-host-python.sh"

PY_MAJMIN="$(python_xy)"
PY_TAG="$(python_tag)"
WHEEL_PLATFORM_TAG="$(android_wheel_platform_tag)"
WHEELHOUSE_DIR="$(android_wheelhouse_dir)"
CROSSENV_DIR="${BUILD_DIR}/crossenv-${ANDROID_ABI}"
MESON_CROSS_FILE="${BUILD_DIR}/meson-android-${ANDROID_ABI}.ini"
STAGED_RUNTIME="${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}"
TARGET_PYTHON="${STAGED_RUNTIME}/bin/python${PY_MAJMIN}.bin"
SYSCONFIGDATA_FILE="${STAGED_RUNTIME}/lib/python${PY_MAJMIN}/_sysconfigdata__linux_.py"

if [[ ! -x "${TARGET_PYTHON}" ]]; then
  printf 'Target Python not found: %s\nRun ./scripts/build-cpython.sh first.\n' "${TARGET_PYTHON}" >&2
  exit 1
fi

if [[ ! -f "${SYSCONFIGDATA_FILE}" ]]; then
  printf 'Target sysconfigdata not found: %s\nRun ./scripts/build-cpython.sh first.\n' "${SYSCONFIGDATA_FILE}" >&2
  exit 1
fi

function meson_cpu_family() {
  case "${ANDROID_ABI}" in
    x86_64)
      printf '%s\n' "x86_64"
      ;;
    arm64-v8a)
      printf '%s\n' "aarch64"
      ;;
    armeabi-v7a)
      printf '%s\n' "arm"
      ;;
    x86)
      printf '%s\n' "x86"
      ;;
  esac
}

function meson_cpu() {
  case "${ANDROID_ABI}" in
    x86_64)
      printf '%s\n' "x86_64"
      ;;
    arm64-v8a)
      printf '%s\n' "aarch64"
      ;;
    armeabi-v7a)
      printf '%s\n' "armv7"
      ;;
    x86)
      printf '%s\n' "i686"
      ;;
  esac
}

function longdouble_format() {
  case "${ANDROID_ABI}" in
    x86_64|arm64-v8a)
      printf '%s\n' "IEEE_QUAD_LE"
      ;;
    armeabi-v7a|x86)
      printf '%s\n' "IEEE_DOUBLE_LE"
      ;;
  esac
}

function write_meson_cross_file() {
  mkdir -p "${BUILD_DIR}"
  cat > "${MESON_CROSS_FILE}" <<EOF
[binaries]
c = '${CC}'
cpp = '${CXX}'
ar = '${AR}'
strip = '${STRIP}'
pkg-config = 'pkg-config'

[host_machine]
system = 'android'
cpu_family = '$(meson_cpu_family)'
cpu = '$(meson_cpu)'
endian = 'little'

[properties]
needs_exe_wrapper = true
sys_root = '${SYSROOT}'
longdouble_format = '$(longdouble_format)'

[built-in options]
c_args = ['--sysroot=${SYSROOT}', '-fPIC', '-I${STAGED_RUNTIME}/include/python${PY_MAJMIN}']
cpp_args = ['--sysroot=${SYSROOT}', '-fPIC', '-I${STAGED_RUNTIME}/include/python${PY_MAJMIN}']
c_link_args = ['--sysroot=${SYSROOT}', '-L${STAGED_RUNTIME}/lib', '-lpython${PY_MAJMIN}']
cpp_link_args = ['--sysroot=${SYSROOT}', '-L${STAGED_RUNTIME}/lib', '-lpython${PY_MAJMIN}']
EOF
}

function ensure_crossenv() {
  log "Preparing crossenv for Android ${ANDROID_ABI}"
  "${HOSTPY_DIR}/bin/python3" -m pip install --upgrade crossenv
  rm -rf "${CROSSENV_DIR}"
  "${HOSTPY_DIR}/bin/python3" -m crossenv \
    --cc "${CC}" \
    --cxx "${CXX}" \
    --ar "${AR}" \
    --sysroot "${SYSROOT}" \
    --platform-tag "${WHEEL_PLATFORM_TAG}" \
    --sysconfigdata-file "${SYSCONFIGDATA_FILE}" \
    "${TARGET_PYTHON}" \
    "${CROSSENV_DIR}"

  "${CROSSENV_DIR}/bin/build-pip" install --upgrade \
    pip \
    setuptools \
    wheel \
    build \
    meson \
    meson-python \
    ninja \
    Cython \
    pyproject-metadata \
    packaging \
    pybind11 \
    versioneer
  "${CROSSENV_DIR}/bin/build-pip" install "numpy==${NUMPY_VERSION}"
}

function retag_wheel() {
  local wheel="$1"
  local new_tag="${PY_TAG}-${PY_TAG}-${WHEEL_PLATFORM_TAG}"
  local ext_abi="${PY_TAG/cp/cpython-}"
  local target_ext_suffix=".${ext_abi}.so"

  if [[ "${wheel}" == *"${new_tag}.whl" ]]; then
    printf '%s\n' "${wheel}"
    return
  fi

  "${HOSTPY_DIR}/bin/python3" - "$wheel" "$PY_TAG" "$new_tag" "$target_ext_suffix" <<'PY'
from pathlib import Path
from wheel.wheelfile import WheelFile
import re
import sys
import tempfile

wheel = Path(sys.argv[1])
py_tag = sys.argv[2]
new_tag = sys.argv[3]
target_ext_suffix = sys.argv[4]
wheel_tag_re = re.compile(rf"{re.escape(py_tag)}-{re.escape(py_tag)}-[^.]+(?=\.whl$)")
if not wheel_tag_re.search(wheel.name):
    raise SystemExit(f"Cannot retag wheel with unexpected tag: {wheel}")
out = wheel.with_name(wheel_tag_re.sub(new_tag, wheel.name))
ext_re = re.compile(rf"(\.cpython-\d+)-[^/]+\.so$")

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    with WheelFile(wheel) as wf:
        wf.extractall(root)

    for path in sorted(root.rglob("*.so")):
        match = ext_re.search(path.name)
        if not match:
            continue
        new_name = path.name[: match.start()] + target_ext_suffix
        path.rename(path.with_name(new_name))

    dist_info = next(root.glob("*.dist-info"))
    wheel_metadata = dist_info / "WHEEL"
    lines = wheel_metadata.read_text().splitlines()
    lines = [line for line in lines if not line.startswith("Tag: ")]
    lines.append(f"Tag: {new_tag}")
    wheel_metadata.write_text("\n".join(lines) + "\n")

    if out.exists():
        out.unlink()

    with WheelFile(out, "w") as wf:
        for path in sorted(root.rglob("*")):
            if not path.is_file():
                continue
            if path == dist_info / "RECORD":
                continue
            wf.write(path, path.relative_to(root).as_posix())

print(out)
PY
  rm -f "${wheel}"
}

function retag_pure_wheel_any() {
  local wheel="$1"

  "${HOSTPY_DIR}/bin/python3" - "$wheel" <<'PY'
from pathlib import Path
from wheel.wheelfile import WheelFile
import re
import sys
import tempfile

wheel = Path(sys.argv[1])
if wheel.name.endswith("-py3-none-any.whl"):
    print(wheel)
    raise SystemExit

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    with WheelFile(wheel) as wf:
        wf.extractall(root)

    if any(root.rglob("*.so")):
        raise SystemExit(f"Refusing to retag non-pure wheel: {wheel}")

    out = wheel.with_name(re.sub(r"-py3-none-[^.]+(?=\.whl$)", "-py3-none-any", wheel.name))
    dist_info = next(root.glob("*.dist-info"))
    wheel_metadata = dist_info / "WHEEL"
    lines = wheel_metadata.read_text().splitlines()
    lines = [line for line in lines if not line.startswith("Tag: ")]
    lines.append("Tag: py3-none-any")
    wheel_metadata.write_text("\n".join(lines) + "\n")

    if out.exists():
        out.unlink()

    with WheelFile(out, "w") as wf:
        for path in sorted(root.rglob("*")):
            if not path.is_file():
                continue
            if path == dist_info / "RECORD":
                continue
            wf.write(path, path.relative_to(root).as_posix())

print(out)
PY
  rm -f "${wheel}"
}

function build_wheel() {
  local package_spec="$1"
  shift
  local package_name="${package_spec%%==*}"
  local wheel_name
  wheel_name="$(printf '%s' "${package_name}" | tr '[:upper:]' '[:lower:]' | tr '-' '_')"
  local existing_wheel
  existing_wheel="$(find "${WHEELHOUSE_DIR}" -maxdepth 1 -type f -name "${wheel_name}-*-${PY_TAG}-${PY_TAG}-${WHEEL_PLATFORM_TAG}.whl" | sort | tail -n 1)"
  if [[ -n "${existing_wheel}" ]]; then
    log "Android wheel already available: $(basename "${existing_wheel}")"
    return
  fi

  log "Building Android wheel: ${package_spec}"
  PATH="${CROSSENV_DIR}/build/bin:${CROSSENV_DIR}/bin:${PATH}" \
  CC="${CC}" \
  CXX="${CXX}" \
  AR="${AR}" \
  NPY_BLAS_ORDER= \
  NPY_LAPACK_ORDER= \
  "${CROSSENV_DIR}/bin/cross-pip" wheel \
    --no-cache-dir \
    --no-binary=:all: \
    --no-build-isolation \
    --wheel-dir "${WHEELHOUSE_DIR}" \
    "$@" \
    "${package_spec}"

  local built_wheel
  built_wheel="$(find "${WHEELHOUSE_DIR}" -maxdepth 1 -type f -name "${wheel_name}-*-${PY_TAG}-${PY_TAG}-*.whl" | sort | tail -n 1)"
  if [[ -z "${built_wheel}" ]]; then
    printf 'Built wheel not found for %s in %s\n' "${package_name}" "${WHEELHOUSE_DIR}" >&2
    exit 1
  fi

  retag_wheel "${built_wheel}" >/dev/null
}

function build_pure_wheels() {
  log "Downloading pure wheels needed by uiautomator2"
  "${HOSTPY_DIR}/bin/python3" -m pip wheel \
    --no-cache-dir \
    --only-binary=:all: \
    --no-deps \
    --wheel-dir "${WHEELHOUSE_DIR}" \
    "uiautomator2==${UIAUTOMATOR2_VERSION}" \
    "adbutils>=2.9.3,<3" \
    "retry2>=0.9.5,<0.10.0" \
    "deprecation>=2.0.6,<3.0" \
    decorator \
    packaging

  local wheel
  while IFS= read -r -d '' wheel; do
    retag_pure_wheel_any "${wheel}" >/dev/null
  done < <(find "${WHEELHOUSE_DIR}" -maxdepth 1 -type f -name '*-py3-none-*.whl' ! -name '*-py3-none-any.whl' -print0)
}

function build_lxml_wheel() {
  local wheel_name="lxml"
  local existing_wheel
  existing_wheel="$(find "${WHEELHOUSE_DIR}" -maxdepth 1 -type f -name "${wheel_name}-*-${PY_TAG}-${PY_TAG}-${WHEEL_PLATFORM_TAG}.whl" | sort | tail -n 1)"
  if [[ -n "${existing_wheel}" ]]; then
    log "Android wheel already available: $(basename "${existing_wheel}")"
    return
  fi

  local lxml_build_dir="${BUILD_DIR}/lxml-${LXML_VERSION}-${ANDROID_ABI}"
  local lxml_archive="${DOWNLOADS_DIR}/lxml-${LXML_VERSION}.tar.gz"
  download_if_missing \
    "https://files.pythonhosted.org/packages/source/l/lxml/lxml-${LXML_VERSION}.tar.gz" \
    "${lxml_archive}"
  rm -rf "${lxml_build_dir}"
  mkdir -p "${lxml_build_dir}"
  tar -xzf "${lxml_archive}" -C "${lxml_build_dir}" --strip-components=1

  # lxml adds -lrt for any Linux build host. Android/Bionic does not provide librt.
  sed -i "s/standard_libs.append('rt')/pass  # Android has no librt/" "${lxml_build_dir}/setupinfo.py"

  log "Building Android wheel: lxml==${LXML_VERSION}"
  PATH="${CROSSENV_DIR}/build/bin:${CROSSENV_DIR}/bin:${PATH}" \
  CC="${CC}" \
  CXX="${CXX}" \
  AR="${AR}" \
  STATIC_DEPS=false \
  "${CROSSENV_DIR}/bin/cross-pip" wheel \
    --no-cache-dir \
    --no-build-isolation \
    --wheel-dir "${WHEELHOUSE_DIR}" \
    --no-deps \
    "${lxml_build_dir}"

  local built_wheel
  built_wheel="$(find "${WHEELHOUSE_DIR}" -maxdepth 1 -type f -name "lxml-*-${PY_TAG}-${PY_TAG}-*.whl" | sort | tail -n 1)"
  if [[ -z "${built_wheel}" ]]; then
    printf 'Built wheel not found for lxml in %s\n' "${WHEELHOUSE_DIR}" >&2
    exit 1
  fi

  retag_wheel "${built_wheel}" >/dev/null
}

mkdir -p "${WHEELHOUSE_DIR}"
write_meson_cross_file
ensure_crossenv

build_wheel \
  "numpy==${NUMPY_VERSION}" \
  -Csetup-args="--cross-file=${MESON_CROSS_FILE}" \
  -Csetup-args="-Dblas=none" \
  -Csetup-args="-Dlapack=none"

"${CROSSENV_DIR}/bin/cross-pip" install \
  --no-index \
  --find-links "${WHEELHOUSE_DIR}" \
  "numpy==${NUMPY_VERSION}"

build_wheel \
  "pandas==${PANDAS_VERSION}" \
  --no-deps \
  -Csetup-args="--cross-file=${MESON_CROSS_FILE}"

build_wheel \
  "Pillow==${PILLOW_VERSION}" \
  -Cjpeg=disable \
  -Czlib=disable \
  -Cplatform-guessing=disable

build_lxml_wheel

build_pure_wheels

log "Native Android wheels ready in ${WHEELHOUSE_DIR}"
