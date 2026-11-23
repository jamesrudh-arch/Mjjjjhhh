#!/usr/bin/env python3
"""make_billboard_poster.py - D12 fix: authored billboard poster texture.
Replaces the stretched metal noise on the billboard prop's face with a
clean poster read: dark panel, framed ad blocks, lettering bars, subtle
grain only (no fine noise -> no streak artifacts at distance).
Patches assets/props/billboard.glb image 0 (M_Metal baseColor)."""
import io
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glb_edit import read_glb, write_glb, material_image_indices, image_bytes  # noqa: E402
import struct  # noqa: E402
import json    # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

BB = "/home/z/my-project/leverage/assets/props/billboard.glb"


def poster():
    W, H = 512, 256
    im = Image.new("RGB", (W, H), (24, 26, 30))
    dr = ImageDraw.Draw(im)
    # poster frame
    dr.rectangle([6, 6, W - 7, H - 7], outline=(58, 62, 68), width=4)
    # ad blocks with bold color fields (read at distance, no fine texture)
    blocks = [
        (26, 26, 250, 120, (196, 62, 48)),      # big red field
        (262, 26, 486, 120, (240, 163, 60)),    # amber field
        (26, 132, 150, 226, (52, 120, 128)),    # teal field
        (162, 132, 486, 226, (38, 40, 46)),     # dark info block
    ]
    for x0, y0, x1, y1, c in blocks:
        dr.rectangle([x0, y0, x1, y1], fill=c)
    # fake lettering: light bars inside each block
    dr.rectangle([40, 48, 200, 66], fill=(240, 238, 232))
    dr.rectangle([40, 78, 160, 92], fill=(214, 210, 204))
    dr.rectangle([276, 48, 460, 66], fill=(30, 26, 24))
    dr.rectangle([276, 78, 400, 92], fill=(30, 26, 24))
    dr.rectangle([40, 152, 130, 168], fill=(226, 232, 230))
    dr.rectangle([40, 180, 110, 194], fill=(200, 206, 204))
    dr.rectangle([176, 152, 340, 168], fill=(210, 214, 218))
    dr.rectangle([176, 180, 300, 194], fill=(190, 194, 198))
    # small tag corner
    dr.rectangle([440, 200, 486, 226], fill=(240, 163, 60))
    return im


def flat_neutral(kind):
    """Tiny semantically-correct maps for non-albedo slots."""
    if kind == "normal":
        im = Image.new("RGB", (4, 4), (128, 128, 255))      # flat normal
    else:  # metallicRoughness: R unused, G roughness, B metallic
        im = Image.new("RGB", (4, 4), (128, 153, 0))        # rough ~0.6, metal 0
    b = io.BytesIO()
    im.save(b, "PNG")
    return b.getvalue()


def main():
    png = io.BytesIO()
    poster().save(png, "PNG")
    poster_bytes = png.getvalue()

    js, bin_data = read_glb(BB)
    # which image does M_Metal use, per slot?
    m = next(x for x in js.get("materials", []) if x.get("name") == "M_Metal")
    slots = {}
    pbr = m.get("pbrMetallicRoughness", {})
    if "baseColorTexture" in pbr:
        slots.setdefault("baseColor", []).append(js["textures"][pbr["baseColorTexture"]["index"]]["source"])
    if "metallicRoughnessTexture" in pbr:
        slots.setdefault("mr", []).append(js["textures"][pbr["metallicRoughnessTexture"]["index"]]["source"])
    if "normalTexture" in m:
        slots.setdefault("normal", []).append(js["textures"][m["normalTexture"]["index"]]["source"])
    print("M_Metal slots -> images:", slots)

    import glb_edit
    old = os.path.getsize(BB)
    for i in slots.get("baseColor", []):
        glb_edit.replace_image(BB, i, poster_bytes)
    for i in slots.get("mr", []):
        glb_edit.replace_image(BB, i, flat_neutral("mr"))
    for i in slots.get("normal", []):
        glb_edit.replace_image(BB, i, flat_neutral("normal"))
    new = os.path.getsize(BB)
    print(f"billboard.glb: size {old} -> {new}")
    js2, _ = read_glb(BB)
    print("images:", len(js2.get("images", [])), "mats:", [(x.get('name'), bool(x.get('pbrMetallicRoughness', {}).get('baseColorTexture'))) for x in js2.get('materials', [])])
    return 0


if __name__ == "__main__":
    sys.exit(main())
