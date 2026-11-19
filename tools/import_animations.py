#!/usr/bin/env python3
"""Pack the original Frozen Bubble menu and animation frames into WoW TGA atlases."""
import argparse
import json
import math
import random
from pathlib import Path
import shutil
import subprocess
import tempfile
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


def pack_images(name, images, columns=None):
    w, h = images[0].size
    assert all(im.size == (w, h) for im in images)
    columns = columns or min(len(images), max(1, int(math.sqrt(len(images) * h / w))))
    rows = math.ceil(len(images) / columns)
    tw, th = power(columns * w), power(rows * h)
    assert tw <= 2048 and th <= 2048
    sheet = Image.new("RGBA", (tw, th))
    for i, im in enumerate(images):
        sheet.paste(im, ((i % columns) * w, (i // columns) * h))
    sheet.save(dst / f"{name}.tga")
    metadata[name] = dict(w=w, h=h, tw=tw, th=th, columns=columns, frames=len(images))


def cannon_angles():
    # init_game pre-renders the barrel with this exact Catmull-Rom sampler.
    source = (args.upstream / "lib/Games/FrozenBubble/CStuff.xs").read_text()
    start = source.index("static inline double\ntransform_cubic")
    stop = source.index("void flipflop_", start)
    barrel = Image.open(src / "shooter.png").convert("RGBA")
    assert barrel.size == (100, 100)
    with tempfile.TemporaryDirectory() as build:
        build = Path(build)
        (build / "rotation.inc").write_text(source[start:stop])
        exe = build / "cannon"
        subprocess.run(["cc", "-std=c99", "-O2", "-I", str(build), str(root / "tools/cannon_surface.c"),
                        "-lm", "-o", str(exe)], check=True)
        raw = subprocess.run([str(exe)], input=barrel.tobytes(), capture_output=True, check=True).stdout

    stride = 100 * 100 * 4
    assert len(raw) == 201 * stride
    frames = [Image.frombytes("RGBA", barrel.size, raw[i:i+stride]) for i in range(0, len(raw), stride)]
    boxes = [frame.getchannel("A").getbbox() for frame in frames]
    # Carry one transparent pixel around the common crop for texture filtering.
    x0, y0 = max(0, min(b[0] for b in boxes)-1), max(0, min(b[1] for b in boxes)-1)
    x1, y1 = min(100, max(b[2] for b in boxes)+1), min(100, max(b[3] for b in boxes)+1)
    cropped = [frame.crop((x0, y0, x1, y1)) for frame in frames]
    w, h = cropped[0].size
    columns = min(range(math.ceil(201 / (2048//h)), 2048//w + 1), key=lambda n: power(n*w) * power(math.ceil(201/n)*h))
    pack_images("cannon-angles", cropped, columns)
    metadata["cannon-angles"].update(left=x0-50, top=y0-50)


def campaign_previews():
    # display_highscores aligns the SDL source rectangle to four pixels before
    # shrinking it. shrink_ takes the integer mean of each 4 x 4 RGB block.
    crop = (188, 44, 444, 380)
    background = Image.open(src / "back_one_player.png").convert("RGBA").crop(crop)
    levels = (args.upstream / "share/data/levels").read_text().strip().split("\n\n")
    assert len(levels) == 100
    for name, prefix in (("score-boards", "bubble-"), ("score-boards-symbol", "bubble-colourblind-")):
        balls = [Image.open(src / f"balls/{prefix}{n}.gif").convert("RGBA") for n in range(1, 9)]
        previews = []
        for level in levels:
            board = background.copy()
            for row, line in enumerate(level.splitlines()):
                for col, value in enumerate(line.split()):
                    if value != "-":
                        x = 190 - crop[0] + 32 * col + 16 * (row % 2)
                        board.alpha_composite(balls[int(value)], (x, 28 * row))
            channels = [channel.convert("F").reduce(4).convert("L") for channel in board.convert("RGB").split()]
            previews.append(Image.merge("RGB", channels).convert("RGBA"))
        pack_images(name, previews)


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
    "scores-background": "back_hiscores.png", "scores-frame": "hiscore_frame.png",
    "scores-campaign": "hiscore-levelset.png", "scores-training": "hiscore-mptraining.png",
    "editor-background": "level_editor.png",
    "solo-panel": "menu/1p_panel.png", "training-clock": "void_mp_training.png",
    "solo-off": "menu/txt_menu_1p_off.png", "solo-over": "menu/txt_menu_1p_over.png",
    "menu-background": "menu/back_start.png", "menu-logo": "menu/fblogo.png",
    "menu-stamp": "menu/stamp.png", "solo-background": "back_one_player.png",
    "versus-background": "backgrnd.png", "panel": "menu/void_panel.png",
    "compressor": "compressor_main.png", "compressor-ext": "compressor_ext.png",
    "aim-dot": "shooter-lowgfx.png",
    "prelight": "balls/bubble_prelight.png", "frozen": "balls/bubble_lose.png",
    "chat-input": "void_chat.png", "chat-peer": "void_chat_small_p2.png",
    "local-win-p1": "win_panel_p1.png", "local-win-p2": "win_panel_p2.png",
    "net-win-local": "win_panel_p1_net.png", "net-win-remote": "win_panel_rp3.png",
    "net-lose-local": "net_lose_p1.png", "net-lose-remote": "net_lose_rp3.png",
    "hurry-remote": "hurry_p2.png",
    "win-panel": "win_panel_1player.png", "lose-panel": "lose_panel.png",
    "ui-button": "select_level_background.png",
    "next-rim": "on_top_next.png", "hurry": "hurry_p1.png",
    "penalty-one": "banane.png", "penalty-seven": "tomate.png",
    "progress-red": "dot_red.png", "progress-green": "dot_green.png",
}
for credit in ("artwork", "soundtrack", "cpucontrol", "leveleditor"):
    static["banner-" + credit] = f"menu/banner_{credit}.png"
for color in ("green", "purple"):
    for side in ("left", "right"):
        static[f"blink-{color}-{side}"] = f"menu/backgrnd-closedeye-{side}-{color}.png"
for key in ("1pgame", "2pgame", "langame", "netgame", "editor", "graphics", "keys", "highscores"):
    for state in ("off", "over"):
        static[f"menu-{key}-{state}"] = f"menu/txt_{key}_{state}.png"
for name, pivot in (("play_all_levels", 90), ("pick_start_level", 135), ("play_random_levels", 82), ("multiplayer_training", 105)):
    static["solo-" + name] = f"menu/txt_{name}_outlined_text.png"
    pack_images("glow-" + name, solo_glow(src / f"menu/txt_{name}_text.png", pivot))
campaign_previews()
# CStuff::pixelize multiplies each inactive icon pixel's half-opacity alpha by
# (0.2 + rand(100)/100). A 60% opacity sprite times this mask gives that range.
noise = random.Random(2002)
masks = []
for _ in range(30):
    mask = Image.new("RGBA", (40, 30), "white")
    mask.putalpha(Image.frombytes("L", mask.size, bytes(round(255 * (20 + noise.randrange(100)) / 120)
                                                       for _ in range(40 * 30))))
    masks.append(mask)
pack_images("menu-static", masks)
cannon_angles()
for name, path in static.items():
    atlas(name, [src / path])
for name in ("1pgame", "p1p2", "langame", "netgame", "editor", "gfx-l1", "gfx-l2", "gfx-l3", "keys", "highscore"):
    frames = sorted((src / "menu/anims").glob(name + "_*.png"))
    atlas("hover-" + name, frames[:70] if name == "langame" else frames)
for player in ("p1", "p2"):
    for animation in ("anime-shooter", "wait", "win", "loose"):
        atlas(animation + "-" + player, sorted((src / "pinguins").glob(animation + "_" + player + "_*.png")))
atlas("pause", sorted(src.glob("pause_00*.png")))
atlas("stick", [src / f"balls/stick_effect_{i}.png" for i in range(7)])
for name in ("introzik", "menu_change", "menu_selected", "pause", "cancel", "noh", "newroot", "typewriter", "chatted"):
    shutil.copy(args.upstream / "share/snd" / f"{name}.ogg", dst / f"{name}.ogg")
(root / "FrozenBubble/MediaInfo.lua").write_text(
    "-- Original frame dimensions and atlas layout. Generated by tools/import_animations.py.\nlocal _, FB = ...\nFB.MediaInfo = {\n"
    + "".join('    ["' + name + '"] = {' + ", ".join(f"{k}={v}" for k, v in info.items()) + "},\n"
              for name, info in sorted(metadata.items())) + "}\n")
print(f"Packed {sum(v['frames'] for v in metadata.values())} original frames into {len(metadata)} textures")
