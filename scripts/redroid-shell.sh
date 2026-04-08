#!/usr/bin/env bash
set -euo pipefail

REDROID_CONTAINER="${REDROID_CONTAINER:-android-15}"
docker exec -it "${REDROID_CONTAINER}" sh
