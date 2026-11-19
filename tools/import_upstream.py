#!/usr/bin/env python3
"""Reproduce imported game assets. Requires Pillow and a Frozen Bubble source checkout."""
import argparse
import json
from pathlib import Path
import shutil
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("upstream", type=Path)
args = parser.parse_args()
src = args.upstream
dst = Path(__file__).resolve().parents[1] / "FrozenBubble"
levels = []
for block in (src / "share/data/levels").read_text().strip().split("\n\n"):
    rows = ["".join("." if c == "-" else str(int(c) + 1) for c in row.split())
            for row in block.splitlines() if row.strip()]
    if rows:
        levels.append(rows)
assert len(levels) == 100
(dst / "Levels.lua").write_text(
    "-- Original Frozen Bubble levels, GPL-2.0-only. See AUTHORS.upstream.\nlocal _, FB = ...\nFB.Levels = {\n"
    + "".join("  {" + ", ".join(json.dumps(row) for row in rows) + "},\n" for rows in levels) + "}\n")
textures = {f"bubble{i}": f"balls/bubble-{i}.gif" for i in range(1, 9)}
textures.update(background="back_one_player.png", shooter="shooter.png")
for name, path in textures.items():
    im = Image.open(src / "share/gfx" / path).convert("RGBA")
    if name == "background":
        im = im.resize((1024, 512))
    if name == "shooter":
        padded = Image.new("RGBA", (128, 128))
        padded.paste(im, (14, 14))
        im = padded
    im.save(dst / "Media" / f"{name}.tga")
for name in ["launch", "stick", "rebound", "destroy_group", "lose", "applause", "malus", "hurry",
             "newroot_solo", "frozen-mainzik-1p", "frozen-mainzik-2p"]:
    shutil.copy(src / "share/snd" / f"{name}.ogg", dst / "Media" / f"{name}.ogg")
shutil.copy(src / "COPYING", dst / "COPYING")
shutil.copy(src / "AUTHORS", dst / "AUTHORS.upstream")
print("Imported 100 levels and original media. See THIRD_PARTY.md for the pinned source commit.")
