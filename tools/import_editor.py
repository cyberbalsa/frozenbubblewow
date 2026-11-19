#!/usr/bin/env python3
"""Import the editor's wooden controls, SDL bitmap lettering and dialog artwork."""
import argparse
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "FrozenBubble"


def glyphs(font):
    # SFont encodes the advance and overhang of each character in row zero.
    positions = []
    x = 0
    while x < font.width:
        if font.getpixel((x, 0))[:3] == (255, 0, 255):
            positions.append(x)
            while x < font.width - 1 and font.getpixel((x, 0))[:3] == (255, 0, 255):
                x += 1
            positions.append(x)
        x += 1
    result = {}
    for k in range(1, len(positions)-2, 2):
        left, start, end, right = positions[k-1:k+3]
        result[chr(33+k//2)] = ((left+start)//2, (end+right)//2, (start-left+1)//2, end-start)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("upstream", type=Path)
    src = parser.parse_args().upstream / "share/gfx"
    out = ROOT / "Media/Editor"
    out.mkdir(exist_ok=True)
    font = Image.open(src / "font.png").convert("RGBA")
    letters = glyphs(font)
    board = Image.open(src / "level_editor.png").convert("RGBA")

    def label(x, y, caption):
        for ch in caption:
            if ch == " ":
                x += letters["!"][3]
                continue
            l, r, overhang, advance = letters[ch]
            board.alpha_composite(font.crop((l, 1, r, font.height)), (x-overhang, y))
            x += advance

    for x,y,caption in [(5,36,"CHOOSE BUBBLE"),(20,217,"NAVIGATION"),(518,38,"LEVELSET"),(533,257,"LEVEL"),
                        (75,255,"PREV"),(20,295,"NEXT"),(75,335,"FIRST"),(20,375,"LAST"),
                        (563,76,"NEW"),(523,116,"OPEN"),(563,156,"SAVE"),(500,196,"DELETE"),
                        (558,295,"INSERT"),(508,335,"APPEND"),(563,375,"DELETE"),(508,434,"HELP!")]:
        label(x,y,caption)

    # Preserve the clean editor backdrop for the original list-browser thumbnails.
    files = {"boards": board, "font": font, "help": Image.open(src/"key_shortcuts.png"),
             "font-hi": Image.open(src/"font-hi.png"), "start-field": Image.open(src/"select_level_background.png"),
             "up-more": Image.open(src/"list_arrow_up_more.png"), "down-more": Image.open(src/"list_arrow_down_more.png"),
             "files": Image.open(src/"file_list_background.png"), "scroll": Image.open(src/"scroll_list_background.png"),
             "up": Image.open(src/"list_arrow_up.png"), "down": Image.open(src/"list_arrow_down.png"),
             "selected": Image.open(src/"purple_hover.gif"), "hover": Image.open(src/"hover.gif")}
    rows = ["-- Generated from the pinned Frozen Bubble editor and font.png.", "local _,FB=...", "local media=FB.MediaInfo"]
    for name,image in files.items():
        w,h=image.size
        tw,th=1<<(w-1).bit_length(),1<<(h-1).bit_length()
        sheet=Image.new("RGBA",(tw,th)); sheet.paste(image.convert("RGBA"))
        sheet.save(out / (name+".tga"))
        rows.append(f'media["Editor\\\\{name}"]={{w={w},h={h},tw={tw},th={th},columns=1,frames=1}}')
    rows.append("FB.EditorGlyphs={")
    for ch,metrics in letters.items():
        rows.append(f'    [{ord(ch)}]={{{",".join(map(str,metrics))}}},')
    rows.append("}")
    (ROOT/"EditorArt.lua").write_text("\n".join(rows)+"\n")

if __name__ == "__main__":
    main()
