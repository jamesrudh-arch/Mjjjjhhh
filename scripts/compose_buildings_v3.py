#!/usr/bin/env python3
"""Compose LEVERAGE v2.5 buildings v3 - clean low-poly modular buildings:
  - kit plain wall modules (6-34 tris) for the massing, KEEPING kit textures
  - custom ultra-cheap window units (frame + glass + random lit pane, ~40 tris)
    drawn in code - no 500-tri kit window modules, no fake-interior shards
  - kit cornices/corner columns, own doors, tiled roofs + AC units
  - NO decimation (buildings land at 1.2-2.6k tris each; city ~460k total)
  - exports .gltf, one shared texture set (megakit_tex/), multi-primitive
    single mesh -> one multi-surface MeshInstance3D in Godot
"""
import os, sys, math, json, base64
import numpy as np
import trimesh
from PIL import Image

KIT = "/home/z/my-project/tools/assets_raw/megakit/Exports/glTF (Godot)"
OUT = "/home/z/my-project/leverage/assets/buildings"
TEXDIR_NAME = "megakit_tex"
TEXDIR = os.path.join(OUT, TEXDIR_NAME)
SRC_TEX = "/home/z/my-project/tools/assets_raw/megakit/Textures"
TEX_SIZE_BASE = 1024
TEX_SIZE_AUX = 512

_scene_cache = {}
def mod(name):
    if name not in _scene_cache:
        _scene_cache[name] = trimesh.load(os.path.join(KIT, name + ".gltf"))
    return _scene_cache[name]


def yaw_deg(deg):
    return trimesh.transformations.rotation_matrix(math.radians(deg), [0, 1, 0])


# custom factor materials (no textures) for windows/doors/roof props
CUSTOM_MATS = {
    "LG_Glass": {"name": "LG_Glass", "pbrMetallicRoughness": {
        "baseColorFactor": [0.08, 0.11, 0.16, 1.0], "metallicFactor": 0.65, "roughnessFactor": 0.22}},
    "LG_Frame": {"name": "LG_Frame", "pbrMetallicRoughness": {
        "baseColorFactor": [0.88, 0.86, 0.80, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.7}},
    "LG_WindowLit": {"name": "LG_WindowLit", "emissiveFactor": [1.0, 0.78, 0.42],
        "pbrMetallicRoughness": {"baseColorFactor": [1.0, 0.85, 0.58, 1.0],
                                  "metallicFactor": 0.0, "roughnessFactor": 0.6}},
    "LG_Door": {"name": "LG_Door", "pbrMetallicRoughness": {
        "baseColorFactor": [0.13, 0.11, 0.09, 1.0], "metallicFactor": 0.1, "roughnessFactor": 0.7}},
    "LG_AC": {"name": "LG_AC", "pbrMetallicRoughness": {
        "baseColorFactor": [0.58, 0.60, 0.63, 1.0], "metallicFactor": 0.5, "roughnessFactor": 0.5}},
    "LG_RoofBox": {"name": "LG_RoofBox", "pbrMetallicRoughness": {
        "baseColorFactor": [0.30, 0.28, 0.26, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.95}},
    "LG_NeonPink": {"name": "LG_NeonPink", "emissiveFactor": [2.4, 0.35, 1.1],
        "pbrMetallicRoughness": {"baseColorFactor": [1.0, 0.4, 0.8, 1.0], "roughnessFactor": 0.4}},
    "LG_NeonCyan": {"name": "LG_NeonCyan", "emissiveFactor": [0.3, 1.9, 2.2],
        "pbrMetallicRoughness": {"baseColorFactor": [0.5, 0.95, 1.0, 1.0], "roughnessFactor": 0.4}},
    "LG_NeonOrange": {"name": "LG_NeonOrange", "emissiveFactor": [2.4, 1.1, 0.25],
        "pbrMetallicRoughness": {"baseColorFactor": [1.0, 0.6, 0.25, 1.0], "roughnessFactor": 0.4}},
    "LG_NeonGreen": {"name": "LG_NeonGreen", "emissiveFactor": [0.4, 2.1, 0.8],
        "pbrMetallicRoughness": {"baseColorFactor": [0.5, 1.0, 0.6, 1.0], "roughnessFactor": 0.4}},
}
NEON_NAMES = ["LG_NeonPink", "LG_NeonCyan", "LG_NeonOrange", "LG_NeonGreen"]


def quad(w, h, mat):
    """Flat quad on XY, facing +Z."""
    m = trimesh.Trimesh(vertices=[[-w/2,-h/2,0],[w/2,-h/2,0],[w/2,h/2,0],[-w/2,h/2,0]],
                        faces=[[0,2,1],[0,3,2]], process=False)
    m.visual = trimesh.visual.TextureVisuals(
        uv=np.array([[0,0],[1,0],[1,1],[0,1]], dtype=np.float64),
        material=trimesh.visual.material.PBRMaterial(name=mat))
    return m


def box(w, h, d, mat):
    m = trimesh.creation.box([w, h, d])
    m.visual = trimesh.visual.TextureVisuals(
        uv=np.zeros((len(m.vertices), 2)),
        material=trimesh.visual.material.PBRMaterial(name=mat))
    return m


class Builder:
    def __init__(self, seed):
        self.parts = []           # (geometry, material_name, transform)
        self.rng = np.random.default_rng(seed)

    def add(self, name, x, y, z, rot_y=0.0, scale=1.0):
        sc = mod(name)
        T = np.eye(4)
        T[:3, :3] *= scale
        M = yaw_deg(rot_y).dot(T)
        M[:3, 3] = [x, y, z]
        for g in sc.geometry.values():
            mat = getattr(g.visual, "material", None)
            mname = getattr(mat, "name", "MI_Default") if mat is not None else "MI_Default"
            self.parts.append((g, mname, M))

    def add_geo(self, g, x, y, z, rot_y=0.0):
        M = yaw_deg(rot_y)
        M[:3, 3] = [x, y, z]
        self.parts.append((g, g.visual.material.name, M))

    def wall_row(self, module, x0, x1, y, z, rot):
        x = x0 + 1.0
        while x < x1 - 0.5:
            self.add(module, x, y, z, rot)
            x += 2.0

    def window(self, x, y, z, rot_y, lit=False):
        """Custom window unit: trim frame + glass pane (+ optional lit pane)."""
        frame = box(1.9, 1.5, 0.16, "LG_Frame")
        self.add_geo(frame, x, y + 1.55, z, rot_y)
        pane = quad(1.55, 1.15, "LG_WindowLit" if lit else "LG_Glass")
        self.add_geo(pane, x, y + 1.55, z + 0.09, rot_y)
        sill = box(2.05, 0.1, 0.22, "LG_Frame")
        self.add_geo(sill, x, y + 0.74, z + 0.03, rot_y)

    def neon_signs(self, w, d):
        """Neon strip dressing: horizontal sign band + optional blade sign."""
        pick = NEON_NAMES[int(self.rng.integers(0, 4))]
        band_w = min(w - 3.0, 3.0 + self.rng.random() * 4.0)
        band = box(band_w, 0.7, 0.18, pick)
        self.add_geo(band, self.rng.uniform(-w/2 + 2.5, w/2 - 2.5), 3.35, d / 2 + 0.22, 0.0)
        if self.rng.random() < 0.45:
            pick2 = NEON_NAMES[int(self.rng.integers(0, 4))]
            blade = box(0.16, 2.2, 0.9, pick2)
            bx = self.rng.choice([-1.0, 1.0]) * (w / 2 - 1.4)
            self.add_geo(blade, bx, 4.4, d / 2 + 0.55, 0.0)

    def door(self, x, z, rot_y=0.0):
        d = box(1.3, 2.5, 0.16, "LG_Door")
        self.add_geo(d, x, 1.25, z, rot_y)
        canopy = box(1.8, 0.14, 0.55, "LG_Frame")
        self.add_geo(canopy, x, 2.62, z + 0.16, rot_y)

    def cornice_ring(self, family, w, d, y):
        c = f"Cornice_{family}_Center"
        ca_l = f"Cornice_{family}_90Angle_L"
        ca_r = f"Cornice_{family}_90Angle_R"
        for zpos, rot in [(-d / 2, 180.0), (d / 2, 0.0)]:
            x = -w / 2 + 1.0
            while x < w / 2 - 1.5:
                self.add(c, x, y, zpos, rot)
                x += 2.0
        for xpos, rot in [(-w / 2, 270.0), (w / 2, 90.0)]:
            z = -d / 2 + 1.0
            while z < d / 2 - 1.5:
                self.add(c, xpos, y, z, rot)
                z += 2.0
        self.add(ca_l, -w / 2 + 1.0, y, -d / 2 + 1.0, 180.0)
        self.add(ca_r, w / 2 - 1.0, y, -d / 2 + 1.0, 270.0)
        self.add(ca_l, w / 2 - 1.0, y, d / 2 - 1.0, 0.0)
        self.add(ca_r, -w / 2 + 1.0, y, d / 2 - 1.0, 90.0)

    def corners(self, family, w, d, y):
        if family == "Brick":
            name = "Brick_CornerColumn_Center"
        elif family == "Trim":
            name = "Trim_Column_Center"
        else:
            name = "Metal_Column_Center"
        specs = [
            (w / 2 - 0.2, d / 2 - 0.2, 0.0),
            (-w / 2 + 0.2, d / 2 - 0.2, 270.0),
            (-w / 2 + 0.2, -d / 2 + 0.2, 180.0),
            (w / 2 - 0.2, -d / 2 + 0.2, 90.0),
        ]
        for x, z, r in specs:
            self.add(name, x, y, z, r)

    def roof_details(self, w, d, y, floors):
        # gravel slab + roof tiles
        slab = box(w - 0.6, 0.25, d - 0.6, "LG_RoofBox")
        self.add_geo(slab, 0, y + 0.16, 0)
        tx = -w / 2 + 2.0
        while tx < w / 2 - 0.5:
            tz = -d / 2 + 2.0
            while tz < d / 2 - 0.5:
                self.add("Roof_4x4", tx, y + 0.3, tz, 0.0)
                tz += 4.0
            tx += 4.0
        # AC units / roof access hut
        n_units = 1 + int(self.rng.integers(0, 3))
        for i in range(n_units):
            ac = box(1.4, 0.9, 1.1, "LG_AC")
            ax = self.rng.uniform(-w / 2 + 2.5, w / 2 - 2.5)
            az = self.rng.uniform(-d / 2 + 2.5, d / 2 - 2.5)
            self.add_geo(ac, ax, y + 0.85, az)
        if floors >= 4:
            hut = box(2.6, 2.2, 2.2, "LG_RoofBox")
            self.add_geo(hut, -w / 2 + 2.2, y + 1.45, -d / 2 + 2.2)
            hd = box(0.9, 1.6, 0.1, "LG_Door")
            self.add_geo(hd, -w / 2 + 2.2, y + 1.1, -d / 2 + 3.35)


def build_parts(spec, seed):
    b = Builder(seed)
    fam = spec["family"]
    w, d, floors = spec["w"], spec["d"], spec["floors"]
    fill = f"{fam}_Plain_3"
    storefront = spec.get("storefront", False)
    # ground floor (south face is storefront glass when requested)
    b.wall_row(fill, -w / 2 + 1, w / 2 - 1, 0, -d / 2, 180.0)
    if not storefront:
        b.wall_row(fill, -w / 2 + 1, w / 2 - 1, 0, d / 2, 0.0)
    for xpos, rot in [(-w / 2, 270.0), (w / 2, 90.0)]:
        z = -d / 2 + 1.0
        while z < d / 2 - 0.5:
            b.add(fill, xpos, 0, z, rot)
            z += 2.0
    if storefront:
        # glass front: kit full-window modules on the south face + own door
        x = -w / 2 + 1.0
        while x < w / 2 - 0.5:
            if abs(x) < 1.6:
                x += 2.0
                continue
            b.add("Metal_FullWindow", x, 0, d / 2, 0.0)
            x += 2.0
        b.door(0, d / 2 + 0.05, 0.0)
        b.neon_signs(w, d)
    else:
        b.door(0, d / 2 + 0.05, 0.0)
    b.corners(fam, w, d, 0)
    # upper floors: plain walls + custom windows on all four street faces
    for f in range(1, floors):
        y = f * 3.0
        for zpos, rot in [(-d / 2, 180.0), (d / 2, 0.0)]:
            b.wall_row(fill, -w / 2 + 1, w / 2 - 1, y, zpos, rot)
            # windows along this face (skip slots randomly for variety)
            x = -w / 2 + 2.0
            while x < w / 2 - 1.0:
                if b.rng.random() < 0.78:
                    lit = b.rng.random() < 0.35
                    off = 0.13 if rot == 0.0 else -0.13
                    b.window(x, y, zpos + off, rot, lit)
                x += 4.0
        for xpos, rot in [(-w / 2, 270.0), (w / 2, 90.0)]:
            z = -d / 2 + 1.0
            while z < d / 2 - 0.5:
                b.add(fill, xpos, y, z, rot)
                z += 2.0
            z = -d / 2 + 2.0
            while z < d / 2 - 1.0:
                if b.rng.random() < 0.55:
                    lit = b.rng.random() < 0.30
                    off = 0.13 if rot == 90.0 else -0.13
                    b.window(xpos + off, y, z, rot, lit)
                z += 4.0
        b.corners(fam, w, d, y)
    top = floors * 3.0
    b.cornice_ring(fam, w, d, top)
    b.roof_details(w, d, top, floors)
    return b.parts


# ---------------------------------------------------------------- glTF writer
def mat_defs_from_kit():
    defs = {}
    needed = set()
    for spec in SPECS.values():
        fam = spec["family"]
        needed.update([f"{fam}_Plain_3", f"Cornice_{fam}_Center", "Roof_4x4",
                       "Brick_CornerColumn_Center", "Trim_Column_Center", "Metal_Column_Center",
                       "Metal_FullWindow"])
    for name in sorted(needed):
        p = os.path.join(KIT, name + ".gltf")
        if not os.path.exists(p):
            continue
        d = json.load(open(p))
        imgs = [os.path.basename(im.get("uri", "")) for im in d.get("images", [])]
        texs = d.get("textures", [])
        for mat in d.get("materials", []):
            if mat["name"] in defs:
                continue
            m = json.loads(json.dumps(mat))
            pbr = m.get("pbrMetallicRoughness", {})
            for key in ["baseColorTexture", "metallicRoughnessTexture"]:
                if key in pbr and pbr[key].get("index", -1) < len(texs):
                    src = texs[pbr[key]["index"]].get("source", -1)
                    pbr[key]["__image"] = imgs[src] if 0 <= src < len(imgs) else None
            if "normalTexture" in m and m["normalTexture"].get("index", -1) < len(texs):
                src = texs[m["normalTexture"]["index"]].get("source", -1)
                m["normalTexture"]["__image"] = imgs[src] if 0 <= src < len(imgs) else None
            if "occlusionTexture" in m:
                del m["occlusionTexture"]
            defs[mat["name"]] = m
    for k, v in CUSTOM_MATS.items():
        defs[k] = json.loads(json.dumps(v))
    return defs


def write_shared_textures(image_names):
    os.makedirs(TEXDIR, exist_ok=True)
    for name in image_names:
        src = os.path.join(SRC_TEX, name)
        dst = os.path.join(TEXDIR, name)
        if os.path.exists(dst):
            continue
        im = Image.open(src)
        if im.mode != "RGB":
            im = im.convert("RGB")
        target = TEX_SIZE_AUX if ("_Normal" in name or "_ORM" in name) else TEX_SIZE_BASE
        if max(im.size) > target:
            im = im.resize((target, target), Image.LANCZOS)
        im.save(dst, optimize=True)
        print("TEX", name, "%d KB" % (os.path.getsize(dst) // 1024))


def build_gltf(name, parts, mat_defs):
    groups = {}
    for g, mname, M in parts:
        groups.setdefault(mname, []).append((g, M))
    images_used = []
    mat_json = []
    mat_index = {}
    for mname in sorted(groups.keys()):
        d = json.loads(json.dumps(mat_defs.get(mname, {"name": mname})))
        pbr = d.get("pbrMetallicRoughness", {})
        for key in ["baseColorTexture", "metallicRoughnessTexture"]:
            if key in pbr:
                img = pbr.pop(key).get("__image")
                if img and img not in images_used:
                    images_used.append(img)
                pbr[key] = {"index": images_used.index(img)} if img else None
                if pbr[key] is None:
                    del pbr[key]
        if "normalTexture" in d:
            img = d["normalTexture"].pop("__image", None)
            if img and img not in images_used:
                images_used.append(img)
            d["normalTexture"] = {"index": images_used.index(img)} if img else None
            if d["normalTexture"] is None:
                del d["normalTexture"]
        mat_index[mname] = len(mat_json)
        mat_json.append(d)

    buffer = bytearray()
    buffer_views = []
    accessors = []
    primitives = []

    def add_view(np_arr, target):
        if target == 34963:
            data = np.ascontiguousarray(np_arr).astype("<u4").tobytes()
        elif np_arr.dtype.kind == "f":
            data = np.ascontiguousarray(np_arr).astype("<f4").tobytes()
        else:
            data = np.ascontiguousarray(np_arr).astype("<u4").tobytes()
        off = len(buffer)
        buffer.extend(data)
        buffer_views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(buffer_views) - 1

    def add_accessor_f(np_arr, target, count, mins, maxs):
        view = add_view(np_arr, target)
        typ = "VEC2" if (np_arr.ndim == 2 and np_arr.shape[1] == 2) else "VEC3"
        acc = {"bufferView": view, "componentType": 5126, "count": count, "type": typ}
        if mins is not None:
            acc["min"] = mins
        if maxs is not None:
            acc["max"] = maxs
        accessors.append(acc)
        return len(accessors) - 1

    total_tris = 0
    for mname in sorted(groups.keys()):
        verts, faces, uvs = [], [], []
        off = 0
        for g, M in groups[mname]:
            gg = g.copy()
            gg.apply_transform(M)
            v = np.array(gg.vertices, dtype=np.float64)
            f = np.array(gg.faces, dtype=np.int64) + off
            uv = None
            if gg.visual is not None and getattr(gg.visual, "uv", None) is not None:
                uv = np.array(gg.visual.uv, dtype=np.float64)
            if uv is None or len(uv) != len(v):
                uv = np.zeros((len(v), 2))
            verts.append(v)
            faces.append(f)
            uvs.append(uv)
            off += len(v)
        V = np.vstack(verts)
        F = np.vstack(faces)
        U = np.vstack(uvs)
        N = np.zeros_like(V)
        for tri in F:
            a, b, c = V[tri[0]], V[tri[1]], V[tri[2]]
            n = np.cross(b - a, c - a)
            N[tri[0]] += n
            N[tri[1]] += n
            N[tri[2]] += n
        ln = np.linalg.norm(N, axis=1, keepdims=True)
        ln[ln == 0] = 1.0
        N = N / ln
        pos_acc = add_accessor_f(V, 34962, len(V), V.min(axis=0).tolist(), V.max(axis=0).tolist())
        norm_acc = add_accessor_f(N, 34962, len(N), None, None)
        uv_acc = add_accessor_f(U, 34962, len(U), None, None)
        view = add_view(F.astype(np.uint32), 34963)
        accessors.append({"bufferView": view, "componentType": 5125, "count": len(F) * 3, "type": "SCALAR"})
        idx_acc = len(accessors) - 1
        if int(F.max()) >= len(V):
            raise RuntimeError(f"{name}: index {int(F.max())} >= vertex count {len(V)}")
        primitives.append({"attributes": {"POSITION": pos_acc, "NORMAL": norm_acc, "TEXCOORD_0": uv_acc},
                           "indices": idx_acc, "material": mat_index[mname]})
        total_tris += len(F)

    b64 = base64.b64encode(bytes(buffer)).decode("ascii")
    doc = {
        "asset": {"version": "2.0", "generator": "LEVERAGE compose_buildings_v3"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": name}],
        "meshes": [{"name": name, "primitives": primitives}],
        "materials": mat_json,
        "textures": [{"source": i} for i in range(len(images_used))],
        "images": [{"uri": f"{TEXDIR_NAME}/{n}"} for n in images_used],
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"uri": "data:application/octet-stream;base64," + b64, "byteLength": len(buffer)}],
    }
    path = os.path.join(OUT, name + ".gltf")
    with open(path, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    return path, total_tris, len(primitives)


SPECS = {
    "b_brick2":    {"family": "Brick", "w": 12, "d": 12, "floors": 3},
    "b_brick3":    {"family": "Brick", "w": 13, "d": 11, "floors": 4},
    "b_brick4":    {"family": "Brick", "w": 12, "d": 12, "floors": 3, "storefront": True},
    "b_brick_tan": {"family": "Brick", "w": 11, "d": 11, "floors": 3},
    "b_ware1":     {"family": "Metal", "w": 16, "d": 14, "floors": 2},
    "b_ware2":     {"family": "Metal", "w": 20, "d": 15, "floors": 2},
    "b_ware3":     {"family": "Metal", "w": 18, "d": 16, "floors": 1},
    "b_tower1":    {"family": "Metal", "w": 14, "d": 14, "floors": 6},
    "b_tower2":    {"family": "Metal", "w": 12, "d": 12, "floors": 7},
    "b_tower3":    {"family": "Metal", "w": 16, "d": 13, "floors": 5},
    "b_shop1":     {"family": "Metal", "w": 10, "d": 10, "floors": 2, "storefront": True},
    "b_shop2":     {"family": "Metal", "w": 12, "d": 10, "floors": 2, "storefront": True},
    "b_shop3":     {"family": "Brick", "w": 14, "d": 12, "floors": 3, "storefront": True},
    "b_house1":    {"family": "Brick", "w": 9,  "d": 9,  "floors": 2},
    "b_house2":    {"family": "Trim",  "w": 11, "d": 9,  "floors": 2},
    "b_house3":    {"family": "Trim",  "w": 10, "d": 10, "floors": 3},
    "b_bank":      {"family": "Trim",  "w": 15, "d": 15, "floors": 3},
    "b_hospital":  {"family": "Metal", "w": 18, "d": 15, "floors": 5},
    "b_hotel":     {"family": "Brick", "w": 16, "d": 14, "floors": 6, "storefront": True},
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:] or list(SPECS.keys())
    mat_defs = mat_defs_from_kit()
    images_needed = set()
    preview = []
    for i, name in enumerate(only):
        preview.extend(build_parts(SPECS[name], seed=1000 + i * 37))
    for g, mname, M in preview:
        if mname in mat_defs:
            d = mat_defs[mname]
            pbr = d.get("pbrMetallicRoughness", {})
            for key in ["baseColorTexture", "metallicRoughnessTexture"]:
                if key in pbr and "__image" in pbr[key]:
                    images_needed.add(pbr[key]["__image"])
            if "normalTexture" in d and "__image" in d["normalTexture"]:
                images_needed.add(d["normalTexture"]["__image"])
    write_shared_textures(sorted(images_needed))
    total_kb = 0
    for i, name in enumerate(only):
        parts = build_parts(SPECS[name], seed=1000 + i * 37)
        path, tris, prims = build_gltf(name, parts, mat_defs)
        kb = os.path.getsize(path) // 1024
        total_kb += kb
        print(f"{name:14s} {tris:6d} tris  {prims} prims  {kb:4d} KB")
    print(f"TOTAL gltf: {total_kb // 1024} MB + shared textures")
