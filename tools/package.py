#!/usr/bin/env python3
"""Build a deterministic installable ZIP containing only the addon directory."""
import argparse
import hashlib
import re
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]


def package(version: str) -> Path:
    if not re.fullmatch(r"v?\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?", version):
        raise ValueError("Expected a semantic version such as v0.1.0-alpha.10")
    version = version.removeprefix("v")
    addon = ROOT / "FrozenBubble"
    toc = (addon / "FrozenBubble.toc").read_text()
    for line in toc.splitlines():
        if line.strip() and not line.startswith("#"):
            assert (addon / line.strip()).is_file(), f"Missing TOC file: {line}"
    out = ROOT / "dist"
    out.mkdir(exist_ok=True)
    archive = out / f"FrozenBubbleForever-v{version}.zip"
    allowed = {".lua", ".toc", ".tga", ".ogg", ".md"}
    with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=9) as z:
        for file in sorted(addon.rglob("*")):
            if not file.is_file():
                continue
            if file.suffix not in allowed and file.name not in {"COPYING", "AUTHORS.upstream"}:
                raise ValueError(f"Unexpected file in addon package: {file.relative_to(ROOT)}")
            data = file.read_bytes()
            if file.suffix == ".toc":
                data = re.sub(rb"(?m)^## Version: .*$", f"## Version: {version}".encode(), data)
            elif file.name == "Bootstrap.lua":
                data = re.sub(rb'FB.version = "[^"]+"', f'FB.version = "{version}"'.encode(), data)
            entry = ZipInfo(file.relative_to(ROOT).as_posix(), (2026, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            z.writestr(entry, data)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(f"{digest}  {archive.name}\n")
    print(archive)
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", nargs="?", default="0.1.0-alpha.10")
    package(parser.parse_args().version)
