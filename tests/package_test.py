import hashlib
import importlib.util
import math
from pathlib import Path
import re
import struct
import unittest
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package", ROOT / "tools/package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class Packaging(unittest.TestCase):
    def test_deterministic_installable_package(self):
        path = package.package("v0.1.0-alpha.1")
        first = path.read_bytes()
        package.package("v0.1.0-alpha.1")
        self.assertEqual(first, path.read_bytes())
        with ZipFile(path) as z:
            self.assertTrue(all(p.startswith("FrozenBubble/") for p in z.namelist()))
            toc = z.read("FrozenBubble/FrozenBubble.toc").decode()
            for line in toc.splitlines():
                if line.strip() and not line.startswith("#"):
                    self.assertIn("FrozenBubble/" + line.strip(), z.namelist())
            self.assertIn("## Version: 0.1.0-alpha.1", toc)
            self.assertIn("## X-Curse-Project-ID: 1815958", toc)
            self.assertIn("FrozenBubble/COPYING", z.namelist())
            self.assertIn("FrozenBubble/AUTHORS.upstream", z.namelist())
            for member in z.namelist():
                if member.endswith(".tga"):
                    header = z.read(member)[:18]
                    width, height = struct.unpack_from("<HH", header, 12)
                    self.assertEqual(width & (width - 1), 0)
                    self.assertEqual(height & (height - 1), 0)
                    self.assertEqual(header[16], 32)
        digest = hashlib.sha256(first).hexdigest()
        self.assertTrue(path.with_suffix(".zip.sha256").read_text().startswith(digest))

    def test_asset_references_exist(self):
        self.assertTrue((ROOT / "art/curseforge-icon.png").is_file())
        for color in range(1, 9):
            self.assertTrue((ROOT / f"FrozenBubble/Media/bubble{color}.tga").is_file())
        for lua in (ROOT / "FrozenBubble").glob("*.lua"):
            for sound in re.findall(r'FB.Sound\("([a-z_]+)"\)', lua.read_text()):
                self.assertTrue((ROOT / f"FrozenBubble/Media/{sound}.ogg").is_file(), sound)

    def test_title_spotlight_can_address_every_frame(self):
        data = (ROOT / "FrozenBubble/LogoData.lua").read_text()
        centers, frames = data.split("}, centers={")[1].split("}, frames={")
        centers = list(map(int, re.findall(r"\d+", centers)))
        frames = list(map(int, re.findall(r"\d+", frames)))
        self.assertEqual(len(frames), 3142)
        self.assertEqual(set(frames), set(range(len(centers))))
        for tick, frame in enumerate(frames):
            x = int(190 / (2.5 + 0.3 * math.sin(tick / 500)) * math.sin(tick / 100) + 95)
            y = int(119 / (2.5 + 0.3 * math.cos(tick / 500)) * math.cos(tick / 100) + 69)
            self.assertEqual(centers[frame], x + 256 * y)
        media = ROOT / "FrozenBubble/Media/Title"
        for page in range((len(centers) + 255) // 256):
            raw = (media / f"glint-{page+1}.blp").read_bytes()
            self.assertEqual(struct.unpack_from("<4sI4B2I", raw),
                             (b"BLP2", 1, 1, 0, 0, 0, 1024, 1024))
            self.assertEqual(len(raw), 1172 + 1024**2)
        self.assertTrue(all((media / f"{name}.tga").is_file() for name in ("logo", "noise", "flake")))

    def test_board_reveal_masks_load_as_one_bit_bc1(self):
        reveals = ROOT / "FrozenBubble/Media/Reveals"
        specs = (ROOT / "FrozenBubble/RevealData.lua").read_text()
        names = set()
        for key, steps, capacity in re.findall(r'\["([^"]+)"\]=\{w=\d+,h=\d+,steps=(\d+),cols=\d+,capacity=(\d+)', specs):
            for page in range(1, (int(steps) - 1) // int(capacity) + 2):
                names.add(f"{key}-{page}.blp")
        self.assertTrue({"bars-1.blp","circle-in-4.blp","arena-light-4.blp","mini-bubble-symbol8-dark-1.blp"} <= names)
        for key in ("compressor","progress-red","bubble-symbol1","mini-rim"):
            self.assertTrue((reveals / (key+"-cut.blp")).is_file())
        self.assertEqual(names, {p.name for p in reveals.glob("*.blp") if not p.name.endswith("-cut.blp")})
        for path in reveals.glob("*.blp"):
            with path.open("rb") as f:
                header = f.read(148)
            magic, version, encoding, depth, alpha, mip, w, h = struct.unpack_from("<4sI4B2I", header)
            self.assertEqual((magic, version, encoding, depth, alpha, mip), (b"BLP2", 1, 2, 1, 0, 0))
            self.assertEqual((w & (w-1), h & (h-1)), (0,0))
            self.assertEqual((struct.unpack_from("<I",header,20)[0],struct.unpack_from("<I",header,84)[0]), (1172,w*h//2))
            self.assertEqual(path.stat().st_size,1172+w*h//2)

        # The desktop reveals twelve rows at a time in alternating 40px bars.
        # Decode every texel of every compacted frame without an image library.
        data = (reveals / "bars-1.blp").read_bytes()
        width = struct.unpack_from("<I", data,12)[0]
        for step in range(40):
            for y in range(40):
                for col in range(16):
                    x = step*16+col
                    offset = 1172 + 8*((y//4)*(width//4)+x//4)
                    palette = (data[offset+4+y%4] >> (2*(x%4))) & 3
                    self.assertEqual(palette==0, (y if col%2==0 else 39-y)<=step)

    def test_bubble_edges_have_partial_coverage(self):
        names = [f"bubble{prefix}{color}" for prefix in ("", "-symbol") for color in range(1, 9)]
        for name in names:
            with self.subTest(name=name):
                data = (ROOT / f"FrozenBubble/Media/{name}.tga").read_bytes()
                self.assertEqual((data[2], data[16]), (2, 32))  # uncompressed BGRA
                width, height = struct.unpack_from("<HH", data, 12)
                self.assertEqual((width, height), (128, 128))
                start = 18 + data[0]
                alpha = data[start + 3:start + width * height * 4:4]
                self.assertEqual(alpha[0], 0)
                self.assertEqual(alpha[64 * width + 64], 255)
                self.assertGreater(len(set(alpha)), 32)

    def test_upscaled_textures_keep_atlas_coordinates(self):
        metadata = (ROOT / "FrozenBubble/MediaInfo.lua").read_text()
        for name in ("menu-background", "versus-background", "solo-background", "ui-button", "menu-logo"):
            with self.subTest(texture=name):
                line = next(line for line in metadata.splitlines() if f'["{name}"]' in line)
                atlas = {k: int(v) for k, v in re.findall(r"(\w+)=(\d+)", line)}
                with (ROOT / f"FrozenBubble/Media/{name}.tga").open("rb") as texture:
                    size = struct.unpack_from("<HH", texture.read(18), 12)
                self.assertEqual(size, (atlas["tw"] * 2, atlas["th"] * 2))


if __name__ == "__main__":
    unittest.main()
