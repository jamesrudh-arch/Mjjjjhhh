#!/usr/bin/env python3
"""LEVERAGE texture forge — procedural PBR textures (albedo + roughness + normal).
All textures authored for this project (CC0-equivalent, original)."""
import os, math, random
import numpy as np
from PIL import Image

OUT = "/home/z/my-project/leverage/assets/textures"
rng = random.Random(20261123)

def _noise2(w, h, scale, octaves=4, seed=0):
    """Value noise, multiple octaves, 0..1"""
    rs = np.random.RandomState(seed)
    total = np.zeros((h, w), dtype=np.float32)
    amp = 1.0; tot_amp = 0.0
    for o in range(octaves):
        sc = max(2, int(scale >> o))
        grid = rs.rand(sc, sc).astype(np.float32)
        # bilinear upsample
        gy = np.linspace(0, sc - 1, h).astype(np.float32)
        gx = np.linspace(0, sc - 1, w).astype(np.float32)
        y0 = np.floor(gy).astype(int); x0 = np.floor(gx).astype(int)
        y1 = np.minimum(y0 + 1, sc - 1); x1 = np.minimum(x0 + 1, sc - 1)
        fy = (gy - y0).reshape(h, 1); fx = (gx - x0).reshape(1, w)
        top = grid[np.ix_(y0, x0)] * (1 - fx) + grid[np.ix_(y0, x1)] * fx
        bot = grid[np.ix_(y1, x0)] * (1 - fx) + grid[np.ix_(y1, x1)] * fx
        total += (top * (1 - fy) + bot * fy) * amp
        tot_amp += amp; amp *= 0.5
    return total / tot_amp

def _tilable(hm, size):
    """Make an image tilable by mirroring edges (cheap, seamless)."""
    return np.concatenate([np.concatenate([hm, hm[:, ::-1]], axis=1),
                           np.concatenate([hm[::-1, :], hm[::-1, ::-1]], axis=0)], axis=0)[:size, :size]

def normal_from_height(height, strength=1.0):
    """Sobel-based normal map from height array (0..1)."""
    h, w = height.shape
    hx = np.zeros_like(height); hy = np.zeros_like(height)
    hx[:, 1:-1] = height[:, 2:] - height[:, :-2]
    hy[1:-1, :] = height[2:, :] - height[:-2, :]
    nx = -hx * strength * 8.0; ny = -hy * strength * 8.0; nz = np.ones_like(height)
    n = np.stack([nx, ny, nz], axis=-1)
    n /= (np.linalg.norm(n, axis=-1, keepdims=True) + 1e-6)
    n = (n * 0.5 + 0.5) * 255.0
    return np.clip(n, 0, 255).astype(np.uint8)

def save(texset, name, size):
    d = os.path.join(OUT); os.makedirs(d, exist_ok=True)
    for suffix, arr in texset.items():
        if arr is None: continue
        img = Image.fromarray(arr)
        img.save(os.path.join(d, f"{name}_{suffix}.png"))
    print("texture:", name, size)

def col(base, mod, mul=(1,1,1)):
    """base RGB tuple, mod: HxW 0..1 variation, mul per-channel multiplier"""
    m = np.clip(mod, 0, 1)[..., None]
    b = np.array(base, dtype=np.float32) * np.array(mul)
    out = b[None, None, :] * (0.82 + 0.36 * m)
    return np.clip(out, 0, 255).astype(np.uint8)

# ---------------------------------------------------------------- asphalt + road markings
def tex_asphalt():
    S = 512
    n = _noise2(S, S, 128, 5, 7)
    grit = _noise2(S, S, 256, 2, 11)
    patch = _noise2(S, S, 16, 3, 13)
    base = col((72, 71, 70), n * 0.6 + grit * 0.4)
    # darker patches (tar repair), lighter wear
    patch = patch ** 1.6
    base = base.astype(np.float32)
    base *= (1 - 0.25 * patch)[..., None]
    base += (np.float32(255) - base) * 0.06 * (1 - patch)[..., None]
    alb = np.clip(base, 0, 255).astype(np.uint8)
    rough = np.clip(210 - 60 * (n * 0.5 + grit * 0.5), 120, 255).astype(np.uint8)
    rough = np.stack([rough]*3, axis=-1)
    hmap = (n * 0.5 + grit * 0.5)
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(hmap, 0.55)}, "asphalt", S)

def tex_road_line(w=512, dashed=True, color=(235,225,200)):
    """Road texture with center dashed line + edge lines, tiled along road length."""
    S = w
    alb = np.zeros((S, S, 3), dtype=np.uint8)
    rng2 = np.random.RandomState(5)
    n = _noise2(S, S, 128, 4, 9)
    base = col((70, 69, 68), n)
    alb = base.copy()
    # edge lines (2% margin)
    m = int(S * 0.035)
    for x in range(m, m + max(2, S // 48)):
        shade = (0.85 + 0.15 * rng2.rand(S))[:, None]
        alb[:, x] = np.array(color) * shade
        alb[:, S - 1 - x] = np.array(color) * (0.85 + 0.15 * rng2.rand(S))[:, None]
    # center dash
    cw = max(3, S // 42)
    cx = S // 2
    if dashed:
        dash, gap = S // 4, S // 6
        for y in range(0, S, dash + gap):
            for yy in range(y, min(y + dash, S)):
                alb[yy, cx - cw // 2: cx + (cw + 1) // 2] = np.array(color)
    rough = np.full((S, S, 3), 215, dtype=np.uint8)
    # paint slightly smoother
    rough[:, m:m + max(2, S // 48)] = 160
    rough[:, S - 1 - (m + max(2, S // 48)):S - 1 - m + 1] = 160
    h = _noise2(S, S, 96, 3, 21) * 0.6 + 0.2
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(h, 0.4)}, "road_line", S)

def tex_crosswalk():
    S = 256
    alb = col((70, 69, 68), _noise2(S, S, 64, 4, 31))
    stripes = 7
    sw = S // (stripes * 2)
    paint = np.array((228, 220, 195))
    for i in range(stripes):
        x0 = i * 2 * sw
        alb[:, x0:x0 + sw] = paint
    rough = np.full((S, S, 3), 200, dtype=np.uint8)
    save({"albedo": alb, "rough": rough}, "crosswalk", S)

# ---------------------------------------------------------------- brick
def tex_brick(hue=(128, 62, 52), mortar=(188, 180, 170), name="brick_red"):
    S = 512
    rows, bw, bh = 16, 96, 32   # pixels per brick unit area (S/bw bricks per row)
    n = _noise2(S, S, 64, 4, 41)
    alb = np.zeros((S, S, 3), dtype=np.float32)
    rng2 = np.random.RandomState(42)
    bh_px = S // rows; bw_px = S // (S // bw + 1)
    y = 0; r = 0
    while y < S:
        offset = 0 if r % 2 == 0 else bh_px // 2
        x = -offset
        while x < S:
            tone = 0.72 + rng2.rand() * 0.5
            shade = np.array(hue) * tone
            xx0, xx1 = max(0, x), min(S, x + bw_px - 3)
            yy0, yy1 = max(0, y), min(S, y + bh_px - 3)
            if xx1 > xx0 and yy1 > yy0:
                alb[yy0:yy1, xx0:xx1] = shade
            x += bw_px
        y += bh_px; r += 1
    # mortar lines
    alb = alb * 0.9
    for yy in range(0, S, bh_px):
        alb[yy:yy + 3, :] = np.array(mortar) * (0.85 + 0.25 * rng2.rand())
    for xx in range(0, S, bw_px):
        alb[:, xx:xx + 3] *= 0.94
    var = (0.9 + 0.2 * n)[..., None]
    alb = np.clip(alb * var, 0, 255).astype(np.uint8)
    rough = np.full((S, S, 3), 235, dtype=np.uint8)
    h = np.zeros((S, S), dtype=np.float32)
    for yy in range(0, S, bh_px): h[yy:yy + 2, :] = 0.8
    for xx in range(0, S, bw_px): h[:, xx:xx + 2] = 0.7
    h = h * 0.4 + _noise2(S, S, 96, 3, 43) * 0.6
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(h, 0.7)}, name, S)

# ---------------------------------------------------------------- concrete/stucco/sidewalk
def tex_concrete(name="concrete", base=(126, 124, 118), panel=False):
    S = 512
    n = _noise2(S, S, 96, 5, 51)
    stain = _noise2(S, S, 24, 3, 53) ** 2.2
    alb = col(base, n * 0.55 + 0.45)
    alb = alb.astype(np.float32) * (1 - 0.28 * stain[..., None])
    if panel:
        for x in range(0, S, S // 4):
            alb[:, x:x + 3] *= 0.7; alb[x:x + 3, :] = np.array((90, 88, 84))
    alb = np.clip(alb, 0, 255).astype(np.uint8)
    rough = np.full((S, S, 3), 225, dtype=np.uint8)
    h = n * 0.5 + 0.1
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(h, 0.35)}, name, S)

def tex_pavement():
    S = 512
    n = _noise2(S, S, 128, 4, 61)
    grid = 64
    alb = col((120, 116, 110), n)
    rng2 = np.random.RandomState(62)
    # slab joints
    for x in range(0, S, grid):
        alb[:, x:x + 2] = np.array((88, 86, 82)) * (0.9 + 0.2 * rng2.rand())
        alb[x:x + 2, :] = np.array((88, 86, 82)) * (0.9 + 0.2 * rng2.rand())
    # per-slab tone
    for gy in range(0, S, grid):
        for gx in range(0, S, grid):
            t = 0.88 + rng2.rand() * 0.24
            alb[gy:gy + grid, gx:gx + grid] = (alb[gy:gy + grid, gx:gx + grid].astype(np.float32) * t).clip(0, 255).astype(np.uint8)
    rough = np.full((S, S, 3), 230, dtype=np.uint8)
    h = _noise2(S, S, 64, 3, 63) * 0.4
    for x in range(0, S, grid): h[:, x:x + 2] = 0.85; h[x:x + 2, :] = 0.85
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(h, 0.5)}, "pavement", S)

# ---------------------------------------------------------------- fabric / clothing
def tex_fabric(name, base, weave=8, thread=(1.0, 1.05), roughness=235):
    S = 256
    n = _noise2(S, S, 48, 3, 71)
    alb = col(base, n * 0.5 + 0.5)
    alb = alb.astype(np.float32)
    # weave pattern
    wv = (np.sin(np.arange(S)[:, None] * math.pi * weave / S) * 0.5 + 0.5)
    ww = np.zeros((S, S, 3), dtype=np.float32)
    for c in range(3):
        ww[:, :, c] = (wv * thread[0] + (wv.T * thread[1]) - 0.55)
    alb = np.clip(alb * (1 + ww * 0.06), 0, 255).astype(np.uint8)
    rough = np.full((S, S, 3), roughness, dtype=np.uint8)
    save({"albedo": alb, "rough": rough, "normal": normal_from_height((n + wv * 0.3), 0.35)}, name, S)

def tex_denim():
    S = 256
    base = (52, 62, 92)
    n = _noise2(S, S, 32, 4, 81)
    diag = np.zeros((S, S), dtype=np.float32)
    for i in range(-S, S, 8):
        idx = np.arange(S)
        diag += (np.abs(idx[None, :] - idx[:, None] + i) < 3).astype(np.float32)
    alb = col(base, n * 0.4 + np.clip(diag, 0, 1) * 0.2 + 0.4)
    rough = np.full((S, S, 3), 240, dtype=np.uint8)
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(n * 0.6 + diag * 0.2, 0.5)}, "denim", S)

def tex_leather():
    S = 256
    n = _noise2(S, S, 64, 5, 91) ** 1.2
    wr = _noise2(S, S, 16, 3, 93)
    alb = col((44, 30, 22), n * 0.6 + wr * 0.4)
    rough = np.clip(150 + 70 * (1 - n), 0, 255).astype(np.uint8)
    rough = np.stack([rough] * 3, axis=-1)
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(n * 0.7 + wr * 0.3, 0.9)}, "leather", S)

def tex_skin():
    S = 256
    n = _noise2(S, S, 96, 4, 101)
    pore = _noise2(S, S, 256, 2, 103)
    alb = col((168, 128, 100), n * 0.25 + 0.85)
    rough = np.clip(120 + 60 * pore, 0, 255).astype(np.uint8)
    rough = np.stack([rough] * 3, axis=-1)
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(pore * 0.4, 0.25)}, "skin", S)

# ---------------------------------------------------------------- vegetation
def tex_leaf():
    S = 256
    n = _noise2(S, S, 64, 4, 111)
    veins = np.zeros((S, S), dtype=np.float32)
    for k in range(6):
        ang = k * math.pi / 6
        d = np.abs(np.arange(S)[:, None] * math.sin(ang) - np.arange(S)[None, :] * math.cos(ang)) % 24
        veins += (d < 2).astype(np.float32) * 0.5
    alb = col((64, 92, 44), n * 0.5 + veins * 0.3 + 0.5)
    rough = np.full((S, S, 3), 240, dtype=np.uint8)
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(n * 0.5 + veins * 0.3, 0.6)}, "leaf", S)

def tex_bark():
    S = 256
    n = _noise2(S, S, 32, 4, 121)
    fib = _noise2(S, S, 128, 3, 123)
    alb = col((74, 58, 44), n * 0.5 + fib * 0.3 + 0.4)
    rough = np.full((S, S, 3), 245, dtype=np.uint8)
    h = (n ** 1.4) * 0.8 + fib * 0.2
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(h, 0.8)}, "bark", S)

def tex_grass():
    S = 512
    n = _noise2(S, S, 96, 4, 131)
    blades = _noise2(S, S, 256, 2, 133)
    alb = col((86, 100, 62), n * 0.45 + blades * 0.35 + 0.3)
    # dirt patches
    dirt = _noise2(S, S, 12, 3, 135) ** 2.0
    alb = alb.astype(np.float32) * (1 - 0.5 * dirt[..., None]) + np.array((110, 92, 66)) * (0.5 * dirt[..., None])
    alb = np.clip(alb, 0, 255).astype(np.uint8)
    rough = np.full((S, S, 3), 240, dtype=np.uint8)
    save({"albedo": alb, "rough": rough}, "grass", S)

# ---------------------------------------------------------------- metal / glass-ish
def tex_metal():
    S = 256
    n = _noise2(S, S, 128, 3, 141)
    alb = col((140, 138, 134), n * 0.3 + 0.8)
    rough = np.clip(90 + 80 * n, 0, 255).astype(np.uint8)
    rough = np.stack([rough] * 3, axis=-1)
    save({"albedo": alb, "rough": rough, "normal": normal_from_height(n * 0.3, 0.3)}, "metal", S)

def tex_storefront():
    S = 512
    n = _noise2(S, S, 64, 3, 151)
    alb = col((188, 176, 160), n)
    # awning stripes + sign band
    alb = alb.astype(np.float32)
    sign_h = int(S * 0.18)
    sign = np.array((26, 30, 38))
    alb[:sign_h, :] = sign
    stripes = 8
    sw = S // stripes
    for i in range(stripes):
        if i % 2 == 0:
            alb[:sign_h, i * sw:(i + 1) * sw] = np.array((200, 60, 48)) * (0.9 + 0.15 * (i % 3 == 0))
    rough = np.full((S, S, 3), 180, dtype=np.uint8)
    save({"albedo": alb.astype(np.uint8), "rough": rough}, "storefront", S)

if __name__ == "__main__":
    tex_asphalt(); tex_road_line(); tex_crosswalk()
    tex_brick(); tex_brick((150, 130, 100), (170, 164, 152), "brick_tan")
    tex_concrete(); tex_concrete("concrete_panel", (132, 130, 124), True); tex_pavement()
    tex_fabric("fabric_cotton", (60, 72, 108)); tex_fabric("fabric_gray", (90, 92, 96))
    tex_denim(); tex_leather(); tex_skin()
    tex_leaf(); tex_bark(); tex_grass(); tex_metal(); tex_storefront()
    print("ALL TEXTURES DONE")
