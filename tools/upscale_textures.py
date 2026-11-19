#!/usr/bin/env python3
"""Build double-resolution WoW textures from the original PNGs with Upscayl."""
import argparse
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

from PIL import Image

TEXTURES = {
    "menu-background": "menu/back_start.png",
    "solo-background": "back_one_player.png",
    "versus-background": "backgrnd.png",
    "ui-button": "select_level_background.png",
    "menu-logo": "menu/fblogo.png",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("upstream", type=Path)
    parser.add_argument("--binary", default="upscayl-bin")
    parser.add_argument("--models", type=Path, required=True)
    parser.add_argument("--gpu", default="0")
    args = parser.parse_args()
    media = Path(__file__).resolve().parents[1] / "FrozenBubble" / "Media"
    with TemporaryDirectory() as work:
        work = Path(work)
        for name, source in TEXTURES.items():
            original = args.upstream / "share" / "gfx" / source
            rendered = work / (name + ".png")
            subprocess.run([
                args.binary, "-i", str(original), "-o", str(rendered),
                "-m", str(args.models), "-n", "digital-art-4x", "-z", "4",
                "-s", "2", "-g", args.gpu, "-f", "png",
            ], check=True)
            with Image.open(original) as image, Image.open(rendered) as output:
                size = (image.width * 2, image.height * 2)
                if output.size != size:
                    raise ValueError(f"{name}: expected {size}, got {output.size}")
                # Keep the speckled ice and wood grain that the model smooths out.
                filtered = image.convert("RGB").resize(size, Image.Resampling.BILINEAR)
                pixels = Image.blend(filtered, output.convert("RGB"), 0.70).convert("RGBA")
                alpha = image.convert("RGBA").getchannel("A")
                pixels.putalpha(alpha.resize(size, Image.Resampling.BILINEAR))
                # Both image and padding double, preserving the original Lua UVs.
                canvas = Image.new("RGBA", tuple(1 << (n - 1).bit_length() for n in size))
                canvas.paste(pixels, (0, 0))
                canvas.save(work / (name + ".tga"))
        for name in TEXTURES:
            (media / (name + ".tga")).write_bytes((work / (name + ".tga")).read_bytes())


if __name__ == "__main__":
    main()
