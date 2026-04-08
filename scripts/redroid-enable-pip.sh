#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

REDROID_CONTAINER="${REDROID_CONTAINER:-android-15}"
REMOTE_RUNTIME="${REMOTE_RUNTIME:-/data/local/tmp/${ANDROID_ABI}/$(runtime_slug)}"
PIP_UPGRADE="${PIP_UPGRADE:-0}"
SYSTEM_BIN_PIP="${SYSTEM_BIN_PIP:-pip}"

"${ROOT_DIR}/scripts/redroid-push.sh"

docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' -m ensurepip --default-pip"

if [[ "${PIP_UPGRADE}" == "1" ]]; then
  docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' -m pip install --upgrade pip"
fi

docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' -m pip --version"
docker exec "${REDROID_CONTAINER}" sh -lc "'/system/bin/${SYSTEM_BIN_PIP}' --version"
