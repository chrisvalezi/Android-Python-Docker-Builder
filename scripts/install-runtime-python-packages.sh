#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

"$(cd "$(dirname "$0")" && pwd)/build-host-python.sh"

PY_MAJMIN="$(python_xy)"
STAGED_RUNTIME="${PYTHON_TARGET_STAGING}/${RUNTIME_PREFIX}"
SITE_PACKAGES_DIR="${STAGED_RUNTIME}/lib/python${PY_MAJMIN}/site-packages"
TOOLS_VENV="${BUILD_DIR}/runtime-package-tools"

if [[ ! -d "${STAGED_RUNTIME}" ]]; then
  printf 'Staging runtime not found: %s\nRun ./scripts/build-cpython.sh first.\n' "${STAGED_RUNTIME}" >&2
  exit 1
fi

if [[ -z "${BUNDLED_PYTHON_PACKAGES// }" ]]; then
  log "No bundled Python packages requested"
  exit 0
fi

log "Preparing host-side package tooling"
rm -rf "${TOOLS_VENV}"
python3 -m venv "${TOOLS_VENV}"
"${TOOLS_VENV}/bin/pip" install --upgrade pip setuptools wheel

mkdir -p "${SITE_PACKAGES_DIR}"
find "${SITE_PACKAGES_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

log "Installing bundled pure Python packages into staging: ${BUNDLED_PYTHON_PACKAGES}"
MARKUPSAFE_NO_SPEEDUPS=1 \
PIP_NO_COMPILE=1 \
PIP_DISABLE_PIP_VERSION_CHECK=1 \
"${TOOLS_VENV}/bin/pip" install \
  --no-cache-dir \
  --no-compile \
  --no-binary=:all: \
  --target "${SITE_PACKAGES_DIR}" \
  ${BUNDLED_PYTHON_PACKAGES}

find "${SITE_PACKAGES_DIR}" -type d -name '__pycache__' -prune -exec rm -rf {} +

PYTHONPATH="${SITE_PACKAGES_DIR}" \
"${TOOLS_VENV}/bin/python" - <<'EOF' > "${STAGED_RUNTIME}/BUNDLED-PACKAGES.txt"
from importlib.metadata import distributions
import os

site_packages = os.environ["PYTHONPATH"]
for dist in sorted(distributions(path=[site_packages]), key=lambda d: d.metadata["Name"].lower()):
    print(f"{dist.metadata['Name']}=={dist.version}")
EOF

log "Bundled pure Python packages installed into ${SITE_PACKAGES_DIR}"
