#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"${SCRIPT_DIR}/build-host-python.sh"
"${SCRIPT_DIR}/build-deps.sh"
"${SCRIPT_DIR}/build-cpython.sh"
"${SCRIPT_DIR}/install-runtime-python-packages.sh"
"${SCRIPT_DIR}/package-runtime.sh"
"${SCRIPT_DIR}/export-artifacts.sh"
