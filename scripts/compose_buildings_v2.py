#!/usr/bin/env python3
"""Compose LEVERAGE v2.5 buildings from Quaternius Downtown City MegaKit
modules (CC0). v2 of the composer:
  - keeps ALL geometries per module (walls, glass, trim, fake interiors)
  - window interiors get a warm emissiveFactor -> lit windows at night
  - exports .gltf with ONE shared external texture set (megakit_tex/),
    one mesh with per-material primitives -> single multi-surface
    MeshInstance3D in Godot (multimesh-friendly), tiny per-building files
  - flat roofs tiled with Roof_4x4 modules
Overwrites assets/buildings/<name>.gltf slots. city_builder points at .gltf.
"""
import os, sys, math, json, base64, struct
import numpy as np
import trimesh
import fast_simplification
from PIL import Image

KIT = "/home/z/my-project/tools/assets_raw/megakit/Exports/glTF (Godot)"
OUT = "/home/z/my-project/leverage/assets/buildings"
TEXDIR_NAME = "megakit_tex"
TEXDIR = os.path.join(OUT, TEXDIR_NAME)
SRC_TEX = "/home/z/my-project/tools/assets_raw/megakit/Textures"
TEX_SIZE = 512

_scene_cache = {}
def mod(name):
    """Load a module scene (all geometries, materials preserved)."""
    if name not in _scene_cache:
        _scene_cache[name] = trimesh.load(os.path.join(KIT, name + ".gltf"))
    return _scene_cache[name]


def yaw_deg(deg):
    return trimesh.transformations.rotation_matrix(math.radians(deg), [0, 1, 0])


class Builder:
    def __init__(self):
        self.parts = []          # (geometry, material_name, transform)

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

    def wall_row(self, module, filler, x0, x1, y, z, rot, pattern="alt"):
        slots = int((x1 - x0) / 2.0)
        for i in range(slots):
            cx = x0 + 1.0 + i * 2.0
            use_win = (pattern == "all") or (pattern == "alt" and i % 2 == 0)
            self.add(module if use_win else filler, cx, y, z, rot)

    def cornice_ring(self, family, w, d, y):
        c = f"Cornice_{family}_Center"
        ca_l = f"Cornice_{family}_90Angle_L"
        ca_r = f"Cornice_{family}_90Angle_R"
        for zpos, rot in [(-d / 2, 180.0), (d / 2, 0.0)]:
            x = -w / 2 + 1.0
            while x < w / 2 - 1.5:
                self.add(c, x, y, zpos, rot)
                x += 2.0
        for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
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
            (-w / 2 + 0.2, d / 2 - 0.2, 90.0),
            (-w / 2 + 0.2, -d / 2 + 0.2, 180.0),
            (w / 2 - 0.2, -d / 2 + 0.2, 270.0),
        ]
        for x, z, r in specs:
            self.add(name, x, y, z, r)

    def roof_tiles(self, w, d, y):
        tx = -w / 2 + 2.0
        while tx < w / 2 - 0.5:
            tz = -d / 2 + 2.0
            while tz < d / 2 - 0.5:
                self.add("Roof_4x4", tx, y, tz, 0.0)
                tz += 4.0
            tx += 4.0


def build_parts(spec):
    b = Builder()
    fam = spec["family"]
    w, d, floors = spec["w"], spec["d"], spec["floors"]
    win = f"{fam}_Window_Trim_Single" if fam == "Brick" else (
        "Metal_Window_Half" if fam == "Metal" else "Trim_Window")
    fill = f"{fam}_Plain_3"
    if spec.get("storefront"):
        b.wall_row("Metal_FullWindow", fill, -w / 2 + 2, w / 2 - 2, 0, -d / 2, 180.0, "all")
        b.add("DoorFrame_Metal_Single", 0, 0, d / 2, 0.0)
        b.wall_row("Metal_FullWindow", fill, -w / 2 + 2, -2, 0, d / 2, 0.0, "all")
        b.wall_row("Metal_FullWindow", fill, 2, w / 2 - 2, 0, d / 2, 0.0, "all")
        for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
            z = -d / 2 + 1.0
            while z < d / 2 - 1.5:
                b.add(fill, xpos, 0, z, rot)
                z += 2.0
    else:
        b.wall_row(win, fill, -w / 2 + 2, w / 2 - 2, 0, -d / 2, 180.0, "alt")
        b.add("DoorFrame_Wooden", 0, 0, d / 2, 0.0)
        for cx in [x for x in range(int(-w / 2 + 2), int(w / 2 - 1), 2)]:
            if abs(cx) < 1.5:
                continue
            b.add(win, cx + 1.0, 0, d / 2, 0.0)
        for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
            z = -d / 2 + 1.0
            while z < d / 2 - 1.5:
                b.add(win if int(z / 2) % 2 == 0 else fill, xpos, 0, z, rot)
                z += 2.0
    b.corners(fam, w, d, 0)
    for f in range(1, floors):
        y = f * 3.0
        b.wall_row(win, fill, -w / 2 + 2, w / 2 - 2, y, -d / 2, 180.0, "alt")
        b.wall_row(win, fill, -w / 2 + 2, w / 2 - 2, y, d / 2, 0.0, "alt")
        for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
            z = -d / 2 + 1.0
            while z < d / 2 - 1.5:
                b.add(win if int(z / 2) % 2 == 0 else fill, xpos, y, z, rot)
                z += 2.0
        b.corners(fam, w, d, y)
    top = floors * 3.0
    b.cornice_ring(fam, w, d, top)
    b.roof_tiles(w, d, top + 0.05)
    return b.parts


# ---------------------------------------------------------------- glTF writer
def mat_defs_from_kit():
    """Collect raw material JSON (pbrMetallicRoughness etc.) per material
    name from the kit, with texture image URIs resolved to basenames."""
    defs = {}
    needed = set()
    for spec in SPECS.values():
        fam = spec["family"]
        needed.update([f"{fam}_Window_Trim_Single", f"{fam}_Plain_3", f"Cornice_{fam}_Center",
                       "Metal_FullWindow", "DoorFrame_Metal_Single", "DoorFrame_Wooden",
                       "Roof_4x4", "Brick_CornerColumn_Center", "Trim_Column_Center",
                       "Metal_Column_Center"])
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
            m = json.loads(json.dumps(mat))     # deep copy
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
    return defs


def write_shared_textures(image_names):
    """Downscale kit textures once into assets/buildings/megakit_tex/."""
    os.makedirs(TEXDIR, exist_ok=True)
    for name in image_names:
        src = os.path.join(SRC_TEX, name)
        dst = os.path.join(TEXDIR, name)
        if os.path.exists(dst):
            continue
        im = Image.open(src)
        if im.mode != "RGB":
            im = im.convert("RGB")
        if max(im.size) > TEX_SIZE:
            im = im.resize((TEX_SIZE, TEX_SIZE), Image.LANCZOS)
        im.save(dst, optimize=True)
        print("TEX", name, "%d KB" % (os.path.getsize(dst) // 1024))


def build_gltf(name, parts, mat_defs, spec_budget=3200):
    """Merge parts by material -> one mesh with per-material primitives.
    Images referenced externally (shared megakit_tex/)."""
    groups = {}
    for g, mname, M in parts:
        groups.setdefault(mname, []).append((g, M))
    total_group_tris = 0
    for mname in groups:
        for g, M in groups[mname]:
            total_group_tris += len(g.faces)
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
        # warm lit interiors at night (world ramps emission energy)
        if mname == "MI_FakeInterior":
            d["emissiveFactor"] = [1.0, 0.68, 0.38]
        mat_index[mname] = len(mat_json)
        mat_json.append(d)

    buffer = bytearray()
    buffer_views = []
    accessors = []
    primitives = []

    def add_view(np_arr, target):
        if target == 34963:      # index buffer: ALWAYS integers
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
    tri_budget = int(spec_budget)
    # proportional per-material budgets (glass/interior stay cheap anyway)
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
        # decimate to the mobile budget (proportional to this material's share)
        budget = max(64, int(tri_budget * len(F) / max(1, total_group_tris)))
        if len(F) > budget:
            V, F = fast_simplification.simplify(V, F, target_count=budget)
            # decimation reindexes vertices; UVs follow the new vertex order only
            # when welding was lossless - rebuild UVs by closest original vertex.
            from scipy.spatial import cKDTree
            tree = cKDTree(np.vstack(verts))
            _, idx = tree.query(V, k=1)
            U = np.vstack(uvs)[idx]
        N = np.zeros_like(V)
        # flat-ish normals: recompute smooth vertex normals
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
        "asset": {"version": "2.0", "generator": "LEVERAGE compose_buildings_v2"},
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
    # discover the shared texture set up-front
    all_parts_preview = []
    for name in only:
        all_parts_preview.extend(build_parts(SPECS[name]))
    images_needed = set()
    for g, mname, M in all_parts_preview:
        if mname in mat_defs:
            d = mat_defs[mname]
            pbr = d.get("pbrMetallicRoughness", {})
            for key in ["baseColorTexture", "metallicRoughnessTexture"]:
                if key in pbr and "__image" in pbr[key]:
                    images_needed.add(pbr[key]["__image"])
            if "normalTexture" in d and "__image" in d["normalTexture"]:
                images_needed.add(d["normalTexture"]["__image"])
    # concrete roof texture comes via Roof_4x4 modules (MetalConcrete)
    write_shared_textures(sorted(images_needed))
    total_kb = 0
    for name in only:
        parts = build_parts(SPECS[name])
        path, tris, prims = build_gltf(name, parts, mat_defs)
        kb = os.path.getsize(path) // 1024
        total_kb += kb
        print(f"{name:14s} {tris:6d} tris  {prims} prims  {kb:4d} KB")
    print(f"TOTAL gltf: {total_kb // 1024} MB + shared textures")
