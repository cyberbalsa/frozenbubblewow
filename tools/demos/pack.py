#!/usr/bin/env python3
"""Compile the four upstream SDL captures into sprite changes on the 50 Hz game clock."""
import argparse
import json
import re
import struct
from pathlib import Path
from PIL import Image, ImageChops

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("upstream", type=Path)
parser.add_argument("captures", type=Path, help="parent of trace1 through trace4")
args = parser.parse_args()
addon = Path(__file__).resolve().parents[2] / "FrozenBubble"
media = addon / "Media"
gfx = args.upstream / "share/gfx"
alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
sprites = []
indices = {}
pictures = {}
sounds = []
pages = []
page_size = 1024
pen_x = pen_y = row_height = 0


def number(value):
    assert 0 <= value < 4096, value
    return alphabet[value // 64] + alphabet[value % 64]


def sprite(*record):
    if record not in indices:
        sprites.append(record)
        indices[record] = len(sprites)
    return indices[record]


def picture(image, role="", alternative=0):
    """Pack cropped SDL sprites and HUD changes with one pixel of edge padding."""
    global pen_x, pen_y, row_height
    image = image.convert("RGBA")
    w, h = image.size
    key = (w, h, image.tobytes(), role, alternative)
    if key in pictures:
        return pictures[key]
    if pen_x + w + 2 > page_size:
        pen_x = 0
        pen_y += row_height
        row_height = 0
    if not pages or pen_y + h + 2 > page_size:
        pages.append(Image.new("RGBA", (page_size, page_size)))
        pen_x = pen_y = row_height = 0
    x, y = pen_x + 1, pen_y + 1
    sheet = pages[-1]
    sheet.paste(image, (x, y))
    sheet.paste(image.crop((0, 0, w, 1)), (x, y-1))
    sheet.paste(image.crop((0, h-1, w, h)), (x, y+h))
    sheet.paste(sheet.crop((x, y-1, x+1, y+h+1)), (x-1, y-1))
    sheet.paste(sheet.crop((x+w-1, y-1, x+w, y+h+1)), (x+w, y-1))
    pen_x += w + 2
    row_height = max(row_height, h + 2)
    index = sprite("atlas", len(pages), x, y, w, h, role, alternative)
    pictures[key] = index
    return index


def asset(name, trace):
    if name.startswith(("barrel/", "mini-barrel/")):
        angle = int(name.split("/")[1])
        if name.startswith("mini"):
            data = (trace / f"cannon-{angle}.rgba").read_bytes()
            w, h, x, y = struct.unpack_from("<4H", data)
            # The crop surface has masks R=0xff000000, G=0xff0000, B=0xff00, A=0xff.
            image = Image.frombytes("RGBA", (w,h), data[8:], "raw", "ABGR")
            index = picture(image, "barrel")
            return sprite("cannon", index, angle, 30, x-25, y-25)
        return sprite("cannon", 0, angle, 60, -45, -45)
    bubble = re.fullmatch(r"balls/bubble-(\d)(-mini\.png|\.gif)", name)
    if bubble:
        color = int(bubble[1])
        if bubble[2].startswith("-mini"):
            symbol = picture(Image.open(gfx / f"balls/bubble-colourblind-{color}-mini.png"))
            return picture(Image.open(gfx / name), alternative=symbol)
        return sprite("bubble", color)
    penguin = re.fullmatch(r"pinguins/([a-z-]+)_(r?p\d)_(\d+)\.png", name)
    if penguin and not penguin[2].startswith("r"):
        return sprite("media", f"{penguin[1]}-{penguin[2]}", int(penguin[3]), "penguin")
    if name == "on_top_next.png":
        return sprite("media", "next-rim", 1)
    if name == "balls/bubble_prelight.png":
        return sprite("media", "prelight", 1)
    effect = re.fullmatch(r"balls/stick_effect_(\d)\.png", name)
    if effect:
        return sprite("media", "stick", int(effect[1]) + 1, "effect")
    role = "penguin" if penguin else "effect" if "stick_effect" in name else ""
    return picture(Image.open(gfx / name), role)


def backdrop_tiles(current, base):
    difference = ImageChops.difference(current, base)
    for y in range(0, 480, 32):
        for x in range(0, 640, 32):
            box = (x, y, x+32, y+32)
            diff = difference.crop(box)
            if diff.getbbox():
                patch = current.crop(box).convert("RGBA")
                r, g, b = diff.split()
                patch.putalpha(ImageChops.lighter(r, ImageChops.lighter(g,b)).point(lambda v: 255 if v else 0))
                yield 1 + y//32*20 + x//32, (picture(patch), x, y)


def scene(index, base_name, texture):
    trace = args.captures / f"trace{index}"
    base = Image.open(gfx / base_name).convert("RGB")
    tiles, previous, assets, sockets = {}, {}, {}, {}
    frames = []
    for line in (trace / "frames.jsonl").open():
        frame, background, board, foreground, cues = json.loads(line)
        assert frame == len(frames) + 1
        if background:
            tiles = dict(backdrop_tiles(Image.open(trace / background).convert("RGB"), base))
        current = tiles.copy()
        for moving, items in enumerate((board, foreground)):
            for order, (name, x, y) in enumerate(items):
                if name not in assets:
                    assets[name] = asset(name, trace)
                if moving:
                    slot = 1500 + order
                else:
                    # Attached bubbles keep a slot when other clusters disappear.
                    slot = sockets.setdefault((x, y, "on_top_next" in name), 301 + len(sockets))
                    assert slot < 1500
                current[slot] = assets[name], x, y
        events = []
        for slot in sorted(previous.keys() | current.keys()):
            value = current.get(slot)
            if value != previous.get(slot):
                art, x, y = value or (0, 0, 0)
                events.extend(map(number, (slot, art, x+512, y+512)))
        for cue in cues:
            assert (media / (cue + ".ogg")).exists()
            if cue not in sounds:
                sounds.append(cue)
            events.extend(map(number, (0, sounds.index(cue)+1, 0, 0)))
        frames.append('"' + ''.join(events) + '"')
        previous = current
    assert len(frames) == (997, 999, 998, 999)[index-1]
    return '{background="' + texture + '", frames={\n' + ',\n'.join(frames) + '\n}}'


def lua_row(record):
    return "{" + ",".join(json.dumps(v) for v in record) + "}"


scenes = [scene(i, source, texture) for i, (source, texture) in enumerate([
    ("back_one_player.png", "solo-background"), ("backgrnd.png", "versus-background"),
    ("back_multiplayer.png", "arena-background"), ("back_multiplayer.png", "arena-background")], 1)]
arena = Image.open(gfx / "back_multiplayer.png").convert("RGBA")
canvas = Image.new("RGBA", (1024, 512))
canvas.paste(arena, (0,0))
canvas.save(media / "arena-background.tga")
# CStuff.xs blacken_ closes a band from each edge and darkens eight bands ahead.
wipe = Image.new("RGBA", (64, 512))
brightness = [255]*480
for step in range(1, 36):
    edge = step*480//70
    for y in range((step-1)*480//70, edge):
        brightness[y] = brightness[479-y] = 0
    for y in range(edge, (step+8)*480//70):
        for row in (y, 479-y):
            brightness[row] = brightness[row]*3//4
    for y, light in enumerate(brightness):
        wipe.putpixel((step-1, y), (0, 0, 0, 255-light))
wipe.save(media / "demo-wipe.tga")
for index, page in enumerate(pages, 1):
    page.save(media / f"demo-art-{index}.tga")
(addon / "DemoData.lua").write_text(
    "-- Generated from the four original Frozen Bubble replays by tools/demos.\nlocal _, FB = ...\n"
    + "FB.DemoData = {sounds=" + lua_row(sounds) + ", sprites={\n"
    + ",\n".join(map(lua_row, sprites)) + "\n}, scenes={\n" + ",\n".join(scenes) + "\n}}\n")
print(f"{len(sprites)} sprites, {len(pages)} atlas pages, {len(scenes)} recordings")
