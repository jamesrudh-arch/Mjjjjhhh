#!/usr/bin/env python3
"""Compose the LEVERAGE main-menu key art from the HUD-free dusk gameplay
capture (tests/render_out/m_09_keyart_clean.png): upscale to 1920x1080,
apply a neon-noir dusk grade (amber highlights, teal shadows, contrast,
vignette) and write assets/ui/keyart/menu_bg_0.png."""
from PIL import Image, ImageEnhance, ImageFilter
import sys

SRC = "/home/z/my-project/leverage/tests/render_out/m_09_keyart_clean.png"
DST = "/home/z/my-project/leverage/assets/ui/keyart/menu_bg_0.png"

im = Image.open(SRC).convert("RGB")
im = im.resize((1920, 1080), Image.LANCZOS)

# --- neon-noir dusk grade ---
r, g, b = im.split()

# warm the highlights (amber lift), cool the shadows (teal)
r = r.point(lambda v: min(255, int(v * 1.14 + 6)))
g = g.point(lambda v: min(255, int(v * 1.02 + 2)))
b = b.point(lambda v: min(255, int(v * 0.92 + 4)))
im = Image.merge("RGB", (r, g, b))

im = ImageEnhance.Contrast(im).enhance(1.16)
im = ImageEnhance.Color(im).enhance(1.12)
im = ImageEnhance.Brightness(im).enhance(0.94)

# soft bloom on bright areas (window glow / lights)
bright = im.point(lambda v: 0 if v < 190 else v)
bright = bright.filter(ImageFilter.GaussianBlur(18))
im = Image.blend(im, Image.composite(bright, im, Image.new("L", im.size, 255)), 0.28)

# vignette
mask = Image.new("L", im.size, 0)
px = mask.load()
w, h = im.size
cx, cy = w / 2, h / 2
maxd = (cx ** 2 + cy ** 2) ** 0.5
for y in range(0, h, 4):
    for x in range(0, w, 4):
        d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / maxd
        val = int(max(0, (d - 0.55)) * 210)
        for yy in range(y, min(y + 4, h)):
            for xx in range(x, min(x + 4, w)):
                px[xx, yy] = val
black = Image.new("RGB", im.size, (4, 3, 6))
im = Image.composite(black, im, mask)

im.save(DST, quality=95)
print("composed", DST, im.size)
