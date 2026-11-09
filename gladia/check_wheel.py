"""Check a wheel built by gladia/build.sh before it is released: its file name, its METADATA
version, its platform tag, and the SASS of its CUDA provider, which must hold every architecture of
the recipe, the datacenter Blackwells included (the whole point of the build, #3621).

    check_wheel.py <wheel> --version <upstream> --rev <REV> --archs "75-real;..."
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

# ORT's build makes an architecture-specific variant (`a`) of the ones it has kernels for: 100-real
# becomes sm_100a
def expected_sass(archs: str) -> set[str]:
    out = set()
    for arch in archs.split(";"):
        number = arch.split("-")[0]
        out.add(f"sm_{number}a" if number in ("90", "100", "103", "120") else f"sm_{number}")
    return out


def actual_sass(provider: Path) -> set[str]:
    cuobjdump = shutil.which("cuobjdump")
    if cuobjdump is None:
        raise SystemExit("check_wheel: no cuobjdump (run it in the CUDA devel image)")
    listing = subprocess.run(  # noqa: S603 — a fixed tool on a file of the build
        [cuobjdump, "--list-elf", str(provider)], capture_output=True, text=True, check=True
    ).stdout
    return set(re.findall(r"sm_[0-9]+[a-z]?", listing))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("wheel", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--rev", required=True)
    parser.add_argument("--archs", required=True)
    args = parser.parse_args()
    local = f"{args.version}+cu130.gladia{args.rev}"
    name = args.wheel.name
    bad: list[str] = []
    if not re.fullmatch(
        rf"onnxruntime_gpu-{re.escape(local)}-cp312-cp312-manylinux_2_39_x86_64\.whl", name
    ):
        bad.append(f"file name {name} is not onnxruntime_gpu-{local}-cp312-...manylinux_2_39")
    with zipfile.ZipFile(args.wheel) as wheel:
        metadata = next(n for n in wheel.namelist() if n.endswith(".dist-info/METADATA"))
        version = next(
            line.split(": ", 1)[1]
            for line in wheel.read(metadata).decode().splitlines()
            if line.startswith("Version: ")
        )
        if version != local:
            bad.append(f"METADATA version {version} is not {local}")
        with tempfile.TemporaryDirectory() as tmp:
            provider = Path(tmp) / "libonnxruntime_providers_cuda.so"
            with wheel.open("onnxruntime/capi/libonnxruntime_providers_cuda.so") as src, \
                    provider.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            wanted, found = expected_sass(args.archs), actual_sass(provider)
    missing = wanted - found
    if missing:
        bad.append(f"no SASS for {sorted(missing)} (has {sorted(found)})")
    if "sm_100a" not in found or "sm_103a" not in found:
        bad.append(f"no B200 / B300 kernel: {sorted(found)}")
    if bad:
        raise SystemExit("check_wheel: " + "; ".join(bad))
    sys.stdout.write(f"check_wheel: {name}: SASS {sorted(found)}\n")


if __name__ == "__main__":
    main()
