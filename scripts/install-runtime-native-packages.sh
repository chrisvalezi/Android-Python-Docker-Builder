#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

PY_MAJMIN="$(python_xy)"
PY_TAG="$(python_tag)"
WHEEL_PLATFORM_TAG="$(android_wheel_platform_tag)"
WHEELHOUSE_DIR="$(android_wheelhouse_dir)"
STAGED_RUNTIME="${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}"
SITE_PACKAGES_DIR="${STAGED_RUNTIME}/lib/python${PY_MAJMIN}/site-packages"
TOOLS_VENV="${BUILD_DIR}/runtime-native-package-tools"

if [[ ! -d "${STAGED_RUNTIME}" ]]; then
  printf 'Staging runtime not found: %s\nRun ./scripts/build-cpython.sh first.\n' "${STAGED_RUNTIME}" >&2
  exit 1
fi

if [[ -z "${BUNDLED_NATIVE_PYTHON_PACKAGES// }" ]]; then
  log "No bundled native Python packages requested"
  exit 0
fi

if [[ ! -d "${WHEELHOUSE_DIR}" ]]; then
  cat >&2 <<EOF
Native Python packages requested: ${BUNDLED_NATIVE_PYTHON_PACKAGES}

Native packages such as numpy and pandas need Android wheels. Put compatible
wheels in:

  ${WHEELHOUSE_DIR}

Expected target:

  python tag: ${PY_TAG}
  abi tag: ${PY_TAG}
  platform: ${WHEEL_PLATFORM_TAG}

Example wheel names:

  numpy-*-cp312-cp312-${WHEEL_PLATFORM_TAG}.whl
  pandas-*-cp312-cp312-${WHEEL_PLATFORM_TAG}.whl

You can override the directory with ANDROID_WHEELHOUSE_DIR and the platform tag
with ANDROID_WHEEL_PLATFORM_TAG.
EOF
  exit 1
fi

if ! compgen -G "${WHEELHOUSE_DIR}/*.whl" >/dev/null; then
  printf 'No .whl files found in native wheelhouse: %s\n' "${WHEELHOUSE_DIR}" >&2
  exit 1
fi

"$(cd "$(dirname "$0")" && pwd)/build-host-python.sh"

log "Preparing host-side native package tooling"
rm -rf "${TOOLS_VENV}"
python3 -m venv "${TOOLS_VENV}"
"${TOOLS_VENV}/bin/pip" install --upgrade pip setuptools wheel

mkdir -p "${SITE_PACKAGES_DIR}"

log "Installing bundled native Android packages into staging: ${BUNDLED_NATIVE_PYTHON_PACKAGES}"
PIP_NO_COMPILE=1 \
PIP_DISABLE_PIP_VERSION_CHECK=1 \
"${TOOLS_VENV}/bin/pip" install \
  --no-cache-dir \
  --no-compile \
  --upgrade \
  --only-binary=:all: \
  --find-links "${WHEELHOUSE_DIR}" \
  --platform "${WHEEL_PLATFORM_TAG}" \
  --implementation cp \
  --python-version "${PY_MAJMIN}" \
  --abi "${PY_TAG}" \
  --target "${SITE_PACKAGES_DIR}" \
  ${BUNDLED_NATIVE_PYTHON_PACKAGES}

find "${SITE_PACKAGES_DIR}" -type d -name '__pycache__' -prune -exec rm -rf {} +

PYTHONPATH="${SITE_PACKAGES_DIR}" \
"${TOOLS_VENV}/bin/python" - <<'EOF' > "${STAGED_RUNTIME}/BUNDLED-PACKAGES.txt"
from importlib.metadata import distributions
import os

site_packages = os.environ["PYTHONPATH"]
for dist in sorted(distributions(path=[site_packages]), key=lambda d: d.metadata["Name"].lower()):
    print(f"{dist.metadata['Name']}=={dist.version}")
EOF

log "Bundled native Python packages installed into ${SITE_PACKAGES_DIR}"
