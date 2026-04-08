#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

mkdir -p "${DIST_DIR}"

if compgen -G "${DIST_DIR}/*.tar.gz" >/dev/null; then
  (
    cd "${DIST_DIR}"
    sha256sum *.tar.gz > SHA256SUMS
  )
else
  printf 'No tar.gz artifacts found in %s\n' "${DIST_DIR}" >&2
  exit 1
fi

cat > "${DIST_DIR}/ARTIFACTS.txt" <<EOF
Artifacts generated from:
- python ${PYTHON_VERSION}
- abi ${ANDROID_ABI}
- api ${ANDROID_API}
- ndk ${ANDROID_NDK_VERSION}

Files:
$(cd "${DIST_DIR}" && ls -1 *.tar.gz SHA256SUMS)
EOF

log "Artifact manifest ready in ${DIST_DIR}"
