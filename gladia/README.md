# gladiaio/onnxruntime: onnxruntime-gpu for CUDA 13 with B200 / B300 kernels

`main` mirrors microsoft/onnxruntime. The `gladia` branch holds this folder and the release workflow
only: the recipe that builds an upstream release tag for CUDA 13 with the SASS of every upstream
wheel **plus sm_100 (B200) and sm_103 (B300)**, which no published `onnxruntime-gpu` carries
(upstream 1.31.1: sm_75, 80, 86, 89, 90a, 120a, no PTX). Nothing else changes: same sources, same
tag.

Used by the `-cu130` inference images of gladiaio/gladia-enterprise (`ORT_CUDA13` in
`inference/Dockerfile.unified`, pinned with its sha256). Why and how it is verified:
`docs/internal/inference-env/ort-blackwell.md` there (#3621).

## Releases

| | |
|---|---|
| Tag | `v<upstream>-gladia-cu130.<REV>`, e.g. `v1.31.1-gladia-cu130.1` |
| Wheel | `onnxruntime_gpu-<upstream>+cu130.gladia<REV>-cp312-cp312-manylinux_2_39_x86_64.whl`: a local version of the upstream release, so pip-audit and OSV see the upstream version |
| Assets | the wheel, `SHA256SUMS`, `build.json` (upstream version, REV, CUDA, archs, SASS) |
| Toolkit | `nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04` (the images' builder base; glibc 2.39) |
| Archs | `75-real;80-real;86-real;89-real;90a-real;100-real;103-real;120a-real` (ORT's build makes 90, 100, 103 and 120 the `a` variants: `sm_100a`, `sm_103a`) |
| Provenance | every wheel is attested by the release workflow (`actions/attest-build-provenance`) |

## The routine and its schedule

| When (UTC) | What |
|---|---|
| 00:41 daily | plan PyPI's latest `onnxruntime-gpu` release, skip it if `v<version>-gladia-cu130.<REV>` is released, else build, check, scan, attest and publish |

The workflow (`.github/workflows/release.yml`) runs these steps:

1. **plan**: `gladia/plan.sh` reads PyPI's latest version (or the dispatch input) and the tag it
   would release, and says whether to build.
2. **build**: checks out upstream at `v<version>` and runs `gladia/build.sh` in the CUDA devel
   image, with ccache kept across runs (`actions/cache`). A cold build of 1.31.1 took 1 h 25 on 64
   cores; the hosted runner has 4 (16 GB RAM, a 24 GB swap file), so the job's ceiling is 6 h and a
   cold build is expected to use most of it.
3. **check**: `gladia/check_wheel.py` checks the file name, the METADATA version, and the SASS of
   the CUDA provider with `cuobjdump`: every architecture of the recipe, `sm_100a` and `sm_103a`
   included. The wheel is then installed and imported (no GPU).
4. **release**: Trivy gates on fixable HIGH / CRITICAL findings in the unpacked wheel, the wheel is
   attested, and the release is published with `SHA256SUMS` and `build.json`.

## Force a rebuild or a version

- Now, the latest release: `gh workflow run release.yml -R gladiaio/onnxruntime`.
- A given upstream version: `-f version=1.32.0`.
- Replace a published release (this changes its sha256, so the pin must move with it): `-f force=true`.
- Build and check without publishing (to try a recipe change): `-f dry_run=true`.
- A recipe change (`gladia/*`): bump `REV` in the workflow. The next run publishes
  `v<version>-gladia-cu130.<REV+1>`.

## Verify

- **sha256**: `curl -fsSL https://github.com/gladiaio/onnxruntime/releases/download/<tag>/SHA256SUMS`,
  compared with the `#sha256=` of `ORT_CUDA13`. uv refuses any other file at install time.
- **provenance**: `gh attestation verify <wheel> -R gladiaio/onnxruntime --signer-workflow
  gladiaio/onnxruntime/.github/workflows/release.yml`.
- **on the GPU**: the b300 (sm_103) or a B200, `docs/internal/inference-env/ort-blackwell.md` in
  gladia-enterprise: each add-on session reports `CUDAExecutionProvider` and `/stats`
  `ort_arena.cpu_fallback` stays empty.

## When to drop it

Upstream publishes a CUDA 13 wheel with sm_100 / sm_103 (its `release.yml` adds them to the arch
list). Then pin PyPI's again in `ORT_CUDA13`, disable this workflow and archive the `gladia` branch.
