#!/usr/bin/env bash
# Plan the release of an upstream onnxruntime release for CUDA 13 with the datacenter Blackwell
# architectures: what to build, under which tag, or that it is already released. Prints KEY=VALUE
# lines (the workflow appends them to $GITHUB_OUTPUT).
#
#   plan.sh <upstream version, empty for PyPI's latest> <REV> <force>
#
# force=true: plan a build even when the release exists (a dry run, or a REV bump).
set -euo pipefail
REQ_VERSION="${1:-}"
REV="${2:?REV}"
FORCE="${3:-false}"
VERSION="${REQ_VERSION:-$(curl -fsSL https://pypi.org/pypi/onnxruntime-gpu/json |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["info"]["version"])')}"
TAG="v${VERSION}-gladia-cu130.${REV}"
LOCAL="${VERSION}+cu130.gladia${REV}"
BUILD=true
if [ "${FORCE}" != true ] && gh release view "$TAG" >/dev/null 2>&1; then
    BUILD=false
fi
echo "version=${VERSION}"
echo "tag=${TAG}"
echo "local_version=${LOCAL}"
echo "build=${BUILD}"
