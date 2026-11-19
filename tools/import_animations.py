#!/usr/bin/env python3
"""Pack the original Frozen Bubble menu and animation frames into WoW TGA atlases."""
import argparse
import json
import math
from pathlib import Path
import shutil
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("upstream", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
src = args.upstream / "share/gfx"
dst = root / "FrozenBubble/Media"
metadata = {}


def power(n):
    return 2 ** math.ceil(math.log2(n))


def atlas(name, files):
    images = [Image.open(f).convert("RGBA") for f in files]
    pack_images(name, images)


def pack_images(name, images):
    w, h = images[0].size
    assert all(im.size == (w, h) for im in images)
    columns = min(len(images), max(1, int(math.sqrt(len(images) * h / w))))
    rows = math.ceil(len(images) / columns)
    tw, th = power(columns * w), power(rows * h)
    assert tw <= 2048 and th <= 2048
    sheet = Image.new("RGBA", (tw, th))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % columns) * w, (i // columns) * h))
    sheet.save(dst / f"{name}.tga")
    metadata[name] = dict(w=w, h=h, tw=tw, th=th, columns=columns, frames=len(images))


def solo_glow(source, pivot):
    """Port overlook_ from CStuff.xs. Each frame retains the previous white trail."""
    alpha = Image.open(source).convert("RGBA").getchannel("A")
    original = alpha.load()
    width, height = alpha.size
    right = alpha.getbbox()[2]
    width = min(width, math.ceil(pivot + (right - pivot) / 0.9) + 2)
    previous = bytearray(width * height)
    frames = []
    for step in range(70):
        for x in range(width):
            sx = pivot + (x - pivot) * (1 - step / 700)
            ix = math.floor(sx)
            dx = sx - ix
            sy_scale = 1 - step / 150 * min(pivot, abs(x - pivot) + pivot // 3) / pivot
            for y in range(height):
                sy = height // 2 + (y - height // 2) * sy_scale
                iy = math.floor(sy)
                dy = sy - iy
                a = 0
                if 0 <= ix < alpha.width - 1 and 0 <= iy < height - 1:
                    top = original[ix, iy] * (1 - dx) + original[ix + 1, iy] * dx
                    bottom = original[ix, iy + 1] * (1 - dx) + original[ix + 1, iy + 1] * dx
                    a = int(top * (1 - dy) + bottom * dy)
                index = y * width + x
                previous[index] = int(max(a * (1 - step / 70), previous[index] * 0.9))
        frame = Image.new("RGBA", (width, height), "white")
        frame.putalpha(Image.frombytes("L", frame.size, bytes(previous)))
        frames.append(frame)
    return frames


static = {
    "solo-panel": "menu/1p_panel.png", "training-clock": "void_mp_training.png",
    "solo-off": "menu/txt_menu_1p_off.png", "solo-over": "menu/txt_menu_1p_over.png",
    "menu-background": "menu/back_start.png", "menu-logo": "menu/fblogo.png",
    "menu-stamp": "menu/stamp.png", "solo-background": "back_one_player.png",
    "versus-background": "backgrnd.png", "panel": "menu/void_panel.png",
    "compressor": "compressor_main.png", "compressor-ext": "compressor_ext.png",
    "prelight": "balls/bubble_prelight.png", "frozen": "balls/bubble_lose.png",
    "win-panel": "win_panel_1player.png", "lose-panel": "lose_panel.png",
    "ui-button": "select_level_background.png",
    "next-rim": "on_top_next.png", "hurry": "hurry_p1.png",
    "penalty-one": "banane.png", "penalty-seven": "tomate.png",
    "progress-red": "dot_red.png", "progress-green": "dot_green.png",
}
for color in ("green", "purple"):
    for side in ("left", "right"):
        static[f"blink-{color}-{side}"] = f"menu/backgrnd-closedeye-{side}-{color}.png"
for key in ("1pgame", "2pgame", "langame", "netgame", "editor", "graphics", "keys", "highscores"):
    for state in ("off", "over"):
        static[f"menu-{key}-{state}"] = f"menu/txt_{key}_{state}.png"
for name, pivot in (("play_all_levels", 90), ("pick_start_level", 135), ("play_random_levels", 82), ("multiplayer_training", 105)):
    static["solo-" + name] = f"menu/txt_{name}_outlined_text.png"
    pack_images("glow-" + name, solo_glow(src / f"menu/txt_{name}_text.png", pivot))
for name, path in static.items():
    atlas(name, [src / path])
for name in ("1pgame", "p1p2", "langame", "netgame", "editor", "gfx-l1", "gfx-l2", "gfx-l3", "keys", "highscore"):
    atlas("hover-" + name, sorted((src / "menu/anims").glob(name + "_*.png")))
for player in ("p1", "p2"):
    for animation in ("anime-shooter", "wait", "win", "loose"):
        atlas(animation + "-" + player, sorted((src / "pinguins").glob(animation + "_" + player + "_*.png")))
atlas("pause", sorted(src.glob("pause_00*.png")))
atlas("stick", [src / f"balls/stick_effect_{i}.png" for i in range(7)])
for name in ("introzik", "menu_change", "menu_selected", "pause", "cancel", "noh", "newroot"):
    shutil.copy(args.upstream / "share/snd" / f"{name}.ogg", dst / f"{name}.ogg")
(root / "FrozenBubble/MediaInfo.lua").write_text(
    "-- Original frame dimensions and atlas layout. Generated by tools/import_animations.py.\nlocal _, FB = ...\nFB.MediaInfo = {\n"
    + "".join('    ["' + name + '"] = {' + ", ".join(f"{k}={v}" for k, v in info.items()) + "},\n"
              for name, info in sorted(metadata.items())) + "}\n")
print(f"Packed {sum(v['frames'] for v in metadata.values())} original frames into {len(metadata)} textures")
