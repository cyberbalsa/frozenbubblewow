import hashlib
import importlib.util
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
