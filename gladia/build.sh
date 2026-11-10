#!/usr/bin/env bash
# onnxruntime-gpu for CUDA 13 with the B200 / B300 kernels (sm_100 / sm_103) that no upstream wheel
# has (gladiaio/gladia-enterprise#3621). Builds an upstream release tag as is: only the CUDA
# architectures change. Run in the gladia-enterprise -cu130 images' builder base, by
# .github/workflows/release.yml:
#
#   docker run --rm -e MAX_JOBS=16 -e CCACHE_DIR=/ccache -v "$PWD/src:/src" -v "$PWD/dist:/out" \
#       -v "$PWD/ccache:/ccache" -v "$PWD/gladia:/gladia:ro" \
#       nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04 bash /gladia/build.sh <version> <REV> /out
#
# usage: build.sh <upstream version> <REV> <out dir>
set -euxo pipefail
VERSION="${1:?upstream version}"; REV="${2:?REV}"; OUT="${3:-/out}"
MAX_JOBS="${MAX_JOBS:-16}"
# PyPI's 1.31.1 SASS (sm_75, 80, 86, 89, 90a, 120a) plus sm_100 (B200) and sm_103 (B300): every
# other GPU keeps the kernels it has today. ORT's build makes 90, 100, 103 and 120 the `a` variants.
ARCHS="${ARCHS:-75-real;80-real;86-real;89-real;90a-real;100-real;103-real;120a-real}"
HERE="$(cd "$(dirname "$0")" && pwd)"
export DEBIAN_FRONTEND=noninteractive
for i in 1 2 3 4 5; do apt-get update -qq && break; sleep 30; done
apt-get install -y -qq git python3 python3-dev python3-venv ninja-build build-essential ccache \
    ca-certificates >/dev/null
nvcc --version
python3 -m venv /venv
. /venv/bin/activate
pip install -q numpy packaging wheel setuptools 'cmake>=3.28,<4' sympy flatbuffers protobuf
mkdir -p "$OUT"
cd /src
# the checkout is mounted from the runner's user, this container is root: git refuses it otherwise
git config --global --add safe.directory /src
test "$(cat VERSION_NUMBER)" = "$VERSION"
python3 tools/ci_build/build.py --build_dir /build --config Release \
  --update --build --build_wheel --parallel "$MAX_JOBS" --nvcc_threads 1 --skip_tests \
  --allow_running_as_root --use_cache --skip_submodule_sync --use_cuda \
  --cuda_home /usr/local/cuda --cudnn_home /usr \
  --cmake_generator Ninja \
  --cmake_extra_defines "CMAKE_CUDA_ARCHITECTURES=$ARCHS" onnxruntime_BUILD_UNIT_TESTS=OFF
python3 "$HERE/retag.py" /build/Release/dist/onnxruntime_gpu-*.whl "cu130.gladia${REV}" \
  manylinux_2_39_x86_64 "$OUT"
cd "$OUT"
sha256sum ./*.whl > SHA256SUMS
cuda="$(nvcc --version | sed -n 's/.*release \([0-9.]*\),.*/\1/p')"
printf '{"upstream": "%s", "rev": %s, "cuda": "%s", "archs": "%s"}\n' \
  "$VERSION" "$REV" "$cuda" "$ARCHS" > build.json
cat SHA256SUMS build.json
