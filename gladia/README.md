# gladiaio/onnxruntime: onnxruntime-gpu for CUDA 13 with B200 / B300 kernels

`main` mirrors microsoft/onnxruntime. The `gladia` branch holds this folder only: the recipe that
builds an upstream release tag for CUDA 13 with the SASS of every upstream wheel **plus sm_100
(B200) and sm_103 (B300)**, which no published `onnxruntime-gpu` carries (upstream 1.31.1: sm_75,
80, 86, 89, 90a, 120a, no PTX). Nothing else changes: same sources, same tag.

Used by the `-cu130` inference images of gladiaio/gladia-enterprise (`ORT_CUDA13` in
`inference/Dockerfile.unified`, pinned with its sha256). Why and how it is verified:
`docs/internal/inference-env/ort-blackwell.md` there (#3621).

## Releases

| | |
|---|---|
| Tag | `v<upstream>-gladia-cu130.<REV>`, e.g. `v1.31.1-gladia-cu130.1` |
| Wheel | `onnxruntime_gpu-<upstream>+cu130.gladia<REV>-cp312-cp312-manylinux_2_39_x86_64.whl`: a local version of the upstream release, so pip-audit and OSV see the upstream version |
| Assets | the wheel, `SHA256SUMS`, `build.json` (upstream version, REV, CUDA, archs) |
| Toolkit | `nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04` (the images' builder base; glibc 2.39) |
| Archs | `75-real;80-real;86-real;89-real;90a-real;100-real;103-real;120a-real` (ORT's CMake makes 100 / 103 the `a` variants: `sm_100a`, `sm_103a`) |

## Build

```bash
git clone --branch gladia https://github.com/gladiaio/onnxruntime.git && cd onnxruntime
docker run --rm -v "$PWD:/src" nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04 \
    bash /src/gladia/build.sh 1.31.1 1 /src/out 64
gh release create v1.31.1-gladia-cu130.1 --target gladia out/*.whl out/SHA256SUMS out/build.json
```

About 1 h 30 on 64 cores (no GPU needed). The upstream optional extras (`[cuda]`, `[cudnn]`) are
not declared: the images take CUDA's libraries from their base and torch's wheels.
