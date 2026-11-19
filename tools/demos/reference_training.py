"""Summarize each second of a desktop demo1 frame capture for the Lua tests."""
import json
import re
import sys
from pathlib import Path


def main(path):
    checksum = 0
    print("-- Generated from the desktop demo1 SDL trace by tools/demos/reference_training.py.")
    print("return {")
    for line in path.read_text().splitlines():
        tick, _, background, foreground, sounds = json.loads(line)
        grid = [0] * 104
        for sprite, x, y in background:
            match = re.fullmatch(r"balls/bubble-(\d)\.gif", sprite)
            if not match:
                continue
            if y == 440:
                preview = match[1]
            else:
                grid[(y - 44) // 28 * 8 + (x - 190) // 32] = int(match[1])

        # SDL draws the flying shot immediately before the loaded bubble.
        flight = "-"
        for sprite, x, y in foreground:
            color = re.fullmatch(r"balls/bubble-(\d)\.gif", sprite)[1]
            if (x, y) == (302, 390):
                loaded = color
                break
            flight = f"{color},{x},{y}"
        row = "|".join(("".join(map(str, grid)), loaded, preview, flight, ",".join(sounds))) + "\n"
        for byte in row.encode("ascii"):
            checksum = (checksum * 131 + byte) % 2147483647
        if tick % 50 == 0:
            print(f"    [{tick}]={checksum},")
    if tick % 50:
        print(f"    [{tick}]={checksum},")
    print("}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
