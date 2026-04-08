#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/scripts/lib/common.sh"

REDROID_CONTAINER="${REDROID_CONTAINER:-android-15}"
REMOTE_RUNTIME="${REMOTE_RUNTIME:-/data/local/tmp/${ANDROID_ABI}/$(runtime_slug)}"

if [[ "$#" -lt 1 ]]; then
  printf 'Usage: %s <package> [pip args...]\n' "$0" >&2
  exit 1
fi

quoted_args=()
for arg in "$@"; do
  quoted_args+=("$(printf '%q' "${arg}")")
done

import_name="${1//-/_}"

"${ROOT_DIR}/scripts/redroid-enable-pip.sh"

docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' -m pip install ${quoted_args[*]}"
docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' -m pip show '$1' || true"
docker exec "${REDROID_CONTAINER}" sh -lc "'${REMOTE_RUNTIME}/bin/python3' -c 'import ${import_name}; print(${import_name}.__name__)' || true"
