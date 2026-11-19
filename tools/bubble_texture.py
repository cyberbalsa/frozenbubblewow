"""Convert the original 32px GIF bubble to straight-alpha RGBA for the WoW board."""
from math import hypot
from PIL import Image


def bubble_texture(original):
    # Work in original pixel units. The solid interior includes the original
    # highlights and marbling. At the rim, the GIF was shaded into black.
    if original.size != (32, 32):
        raise ValueError(f"Expected a 32x32 Frozen Bubble sprite, got {original.size}")
    scale = 4
    size = 32 * scale
    artwork = original.convert("RGB").resize((size, size), Image.Resampling.BICUBIC)
    source = artwork.load()
    result = Image.new("RGBA", (size, size))
    pixels = result.load()
    for y in range(size):
        for x in range(size):
            dx, dy = (x + 0.5) / scale - 16, (y + 0.5) / scale - 16
            radius = hypot(dx, dy)
            if radius <= 13.75:
                pixels[x, y] = (*source[x, y], 255)
                continue
            # Extend nearby real color into the outline and transparent texels,
            # so bilinear sampling can't pick up white GIF transparency or black matte.
            factor = 13.75 / radius
            sx = round((16 + dx * factor) * scale - 0.5)
            sy = round((16 + dy * factor) * scale - 0.5)
            rim = source[sx, sy]
            mix = min(1, (radius - 13.75) / 1.4)
            shade = 1 - 0.28 * mix
            rgb = tuple(round(((1 - mix) * c + mix * r) * shade)
                        for c, r in zip(source[x, y], rim))
            coverage = min(1, max(0, (15.96 - radius) / 0.54))
            pixels[x, y] = (*rgb, round(255 * coverage))
    return result
