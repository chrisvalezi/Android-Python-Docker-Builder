#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

REDROID_CONTAINER="${REDROID_CONTAINER:-android-15}"
RUNTIME_VARIANT="${RUNTIME_VARIANT:-minimal}"
LOCAL_RUNTIME="${LOCAL_RUNTIME:-${ROOT_DIR}/output/runtime/${RUNTIME_VARIANT}}"
REMOTE_RUNTIME="${REMOTE_RUNTIME:-/data/local/tmp/${ANDROID_ABI}/$(runtime_slug)}"
INSTALL_SYSTEM_WRAPPER="${INSTALL_SYSTEM_WRAPPER:-1}"
SYSTEM_BIN_PYTHON3="${SYSTEM_BIN_PYTHON3:-python3}"
SYSTEM_BIN_PYTHON="${SYSTEM_BIN_PYTHON:-python}"
SYSTEM_BIN_PIP="${SYSTEM_BIN_PIP:-pip}"

if [[ ! -d "${LOCAL_RUNTIME}" ]]; then
  printf 'Local runtime not found: %s\nRun the build first.\n' "${LOCAL_RUNTIME}" >&2
  exit 1
fi

docker exec "${REDROID_CONTAINER}" sh -lc "rm -rf '${REMOTE_RUNTIME}' && mkdir -p '${REMOTE_RUNTIME}'"
docker cp "${LOCAL_RUNTIME}/." "${REDROID_CONTAINER}:${REMOTE_RUNTIME}"
docker exec "${REDROID_CONTAINER}" sh -lc "chmod 0755 '${REMOTE_RUNTIME}/bin/python3' '${REMOTE_RUNTIME}/bin/python' || true"

if [[ "${INSTALL_SYSTEM_WRAPPER}" == "1" ]]; then
  docker exec "${REDROID_CONTAINER}" sh -lc "rm -f /system/bin/python3-android /system/bin/python-android /system/bin/pip-android || true
cat > '/system/bin/${SYSTEM_BIN_PYTHON3}' <<'EOF'
#!/system/bin/sh
exec '${REMOTE_RUNTIME}/bin/python3' \"\$@\"
EOF
chmod 0755 '/system/bin/${SYSTEM_BIN_PYTHON3}'
cat > '/system/bin/${SYSTEM_BIN_PYTHON}' <<'EOF'
#!/system/bin/sh
exec '${REMOTE_RUNTIME}/bin/python' \"\$@\"
EOF
chmod 0755 '/system/bin/${SYSTEM_BIN_PYTHON}'
cat > '/system/bin/${SYSTEM_BIN_PIP}' <<'EOF'
#!/system/bin/sh
exec '${REMOTE_RUNTIME}/bin/python3' -m pip \"\$@\"
EOF
chmod 0755 '/system/bin/${SYSTEM_BIN_PIP}'"
fi

printf 'Runtime copied to %s:%s\n' "${REDROID_CONTAINER}" "${REMOTE_RUNTIME}"
