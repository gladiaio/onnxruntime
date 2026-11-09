"""Give a wheel built from an upstream onnxruntime release its gladia local version and its
manylinux platform tag: onnxruntime_gpu-1.31.1-cp312-cp312-linux_x86_64.whl ->
onnxruntime_gpu-1.31.1+cu130.gladia<REV>-cp312-cp312-manylinux_2_39_x86_64.whl.

    python retag.py <wheel> <local version, e.g. cu130.gladia1> <platform tag> <out dir>
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path


def main() -> None:
    wheel, local, platform, out = Path(sys.argv[1]), sys.argv[2], sys.argv[3], Path(sys.argv[4])
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([sys.executable, "-m", "wheel", "unpack", str(wheel), "-d", tmp], check=True)
        (root,) = Path(tmp).iterdir()
        name, version = root.name.rsplit("-", 1)
        new = f"{version}+{local}"
        (info,) = root.glob("*.dist-info")
        meta = info / "METADATA"
        text = meta.read_text(encoding="utf-8")
        text = re.sub(r"^Version: .*$", f"Version: {new}", text, count=1, flags=re.MULTILINE)
        meta.write_text(text, encoding="utf-8")
        wheel_file = info / "WHEEL"
        tags = wheel_file.read_text(encoding="utf-8").replace("linux_x86_64", platform)
        wheel_file.write_text(tags, encoding="utf-8")
        info.rename(root / f"{name}-{new}.dist-info")
        dest = root.rename(Path(tmp) / f"{name}-{new}")
        subprocess.run([sys.executable, "-m", "wheel", "pack", str(dest), "-d", str(out)], check=True)
    for w in out.glob("*.whl"):
        print(w)


if __name__ == "__main__":
    main()
