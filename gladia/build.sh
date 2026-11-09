#!/usr/bin/env bash
# onnxruntime-gpu for CUDA 13 with the B200 / B300 kernels (sm_100 / sm_103) that no upstream
# wheel has (gladiaio/gladia-enterprise#3621). Builds an upstream release tag as is: only the CUDA
# architectures change. Runs in the gladia-enterprise -cu130 images' builder base:
#
#   docker run --rm -v "$PWD:/src" nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04 \
#       bash /src/gladia/build.sh 1.31.1 1 /src/out 64
#
# usage: build.sh <upstream version> <REV> <out dir> <parallel jobs>
# out: onnxruntime_gpu-<version>+cu130.gladia<REV>-cp312-cp312-manylinux_2_39_x86_64.whl,
#      SHA256SUMS, build.json
set -euxo pipefail
VERSION="$1"; REV="$2"; OUT="$3"; PAR="$4"
# PyPI's 1.31.1 SASS (sm_75, 80, 86, 89, 90a, 120a) plus sm_100 (B200) and sm_103 (B300): every
# other GPU keeps the kernels it has today
ARCHS="75-real;80-real;86-real;89-real;90a-real;100-real;103-real;120a-real"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-/work}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git python3 python3-dev python3-venv ninja-build build-essential ca-certificates >/dev/null
nvcc --version
python3 -m venv /venv
. /venv/bin/activate
pip install -q numpy packaging wheel setuptools 'cmake>=3.28,<4' sympy flatbuffers protobuf
mkdir -p "$WORK" "$OUT"
cd "$WORK"
[ -d onnxruntime ] || git clone --depth 1 --branch "v${VERSION}" --recursive https://github.com/microsoft/onnxruntime.git
cd onnxruntime
test "$(cat VERSION_NUMBER)" = "$VERSION"
python3 tools/ci_build/build.py --build_dir "$WORK/build" --config Release \
  --update --build --build_wheel --parallel "$PAR" --nvcc_threads 1 --skip_tests --allow_running_as_root \
  --use_cuda --cuda_home /usr/local/cuda --cudnn_home /usr --cmake_generator Ninja \
  --cmake_extra_defines "CMAKE_CUDA_ARCHITECTURES=$ARCHS" onnxruntime_BUILD_UNIT_TESTS=OFF
python3 "$HERE/retag.py" "$WORK"/build/Release/dist/onnxruntime_gpu-*.whl "cu130.gladia${REV}" manylinux_2_39_x86_64 "$OUT"
cd "$OUT"
sha256sum ./*.whl > SHA256SUMS
cuda="$(nvcc --version | sed -n 's/.*release \([0-9.]*\),.*/\1/p')"
printf '{"upstream": "%s", "rev": %s, "cuda": "%s", "archs": "%s"}\n' "$VERSION" "$REV" "$cuda" "$ARCHS" > build.json
cat SHA256SUMS build.json
