#!/usr/bin/env python3
"""Compose LEVERAGE v2.5 buildings from Quaternius Downtown City MegaKit
modules (CC0). Writes single-GLB buildings (multi-mesh, materials preserved)
over the existing assets/buildings/*.glb slots so city_builder keeps working.

Module conventions (measured):
  walls: X-centered, Y 0..3, thin Z, outside = +Z
  corner columns: occupy -X..0.2 / -Z..0.2 from pivot (rot 0)
  cornice: X-centered, hangs -Z (place like walls, outside +Z)
  roof_4x4: centered, top at pivot y
"""
import os, sys, math
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.transformations import rotation_matrix

KIT = "/home/z/my-project/tools/assets_raw/megakit/Exports/glTF (Godot)"
OUT = "/home/z/my-project/leverage/assets/buildings"
TEX = "/home/z/my-project/tools/assets_raw/megakit/Textures"

_cache = {}
def mod(name):
    """Load a module geometry (single trimesh with material) centered as authored."""
    if name not in _cache:
        s = trimesh.load(os.path.join(KIT, name + ".gltf"))
        g = list(s.geometry.values())[0]
        _cache[name] = g
    return _cache[name]

def yaw_deg(deg):
    return rotation_matrix(math.radians(deg), [0, 1, 0])

class Composer:
    def __init__(self):
        self.parts = []   # (geometry_copy, transform)

    def add(self, name, x, y, z, rot_y=0.0, scale=1.0):
        g = mod(name).copy()
        T = np.eye(4)
        T[:3, :3] *= scale
        R = yaw_deg(rot_y)
        M = R.dot(T)
        M[:3, 3] = [x, y, z]
        self.parts.append((g, M))

    def wall_row(self, module, filler, x0, x1, y, z, rot, pattern="alt"):
        """Place modules along a 2m grid from x0..x1 at fixed z."""
        slots = int((x1 - x0) / 2.0)
        for i in range(slots):
            cx = x0 + 1.0 + i * 2.0
            use_win = (pattern == "all") or (pattern == "alt" and i % 2 == 0)
            name = module if use_win else filler
            self.add(name, cx, y, z, rot)

    def cornice_ring(self, family, w, d, y):
        c = f"Cornice_{family}_Center"
        ca_l = f"Cornice_{family}_90Angle_L"
        ca_r = f"Cornice_{family}_90Angle_R"
        # north (z=-d/2, face -Z, rot 180), south (rot 0)
        for zpos, rot in [(-d / 2, 180.0), (d / 2, 0.0)]:
            x = -w / 2 + 1.0
            while x < w / 2 - 1.5:
                self.add(c, x, y, zpos, rot)
                x += 2.0
        # west (x=-w/2, rot 90), east (rot 270)
        for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
            z = -d / 2 + 1.0
            while z < d / 2 - 1.5:
                self.add(c, xpos, y, z, rot)
                z += 2.0
        # corners
        self.add(ca_l, -w / 2 + 1.0, y, -d / 2 + 1.0, 180.0)
        self.add(ca_r, w / 2 - 1.0, y, -d / 2 + 1.0, 270.0)
        self.add(ca_l, w / 2 - 1.0, y, d / 2 - 1.0, 0.0)
        self.add(ca_r, -w / 2 + 1.0, y, d / 2 - 1.0, 90.0)

    def corners(self, family, w, d, y):
        name = f"{family}_CornerColumn_Center" if family in ("Brick", "Trim") else "Metal_Column_Center"
        # pivot inside each corner; rotations cover all 4 handednesses
        specs = [
            (w / 2 - 0.2, d / 2 - 0.2, 0.0),
            (-w / 2 + 0.2, d / 2 - 0.2, 90.0),
            (-w / 2 + 0.2, -d / 2 + 0.2, 180.0),
            (w / 2 - 0.2, -d / 2 + 0.2, 270.0),
        ]
        for x, z, r in specs:
            self.add(name, x, y, z, r)

    def roof_slab(self, w, d, y):
        """Concrete roof slab as a simple box (cheap tris)."""
        box = trimesh.creation.box([w - 0.4, 0.3, d - 0.4])
        box.visual = trimesh.visual.TextureVisuals(
            uv=np.zeros((len(box.vertices), 2)),
            material=PBRMaterial(
                name="MI_Concrete",
                baseColorTexture=_pil("T_Concrete_BaseColor.png"),
                metallicRoughnessTexture=_pil("T_Concrete_ORM.png"),
                normalTexture=_pil("T_Concrete_Normal.png")))
        T = np.eye(4)
        T[:3, 3] = [0, y, 0]
        self.parts.append((box, T))

    def build(self, spec):
        fam = spec["family"]          # Brick | Metal | Trim
        w, d, floors = spec["w"], spec["d"], spec["floors"]
        win = f"{fam}_Window_Trim_Single" if fam == "Brick" else (
            "Metal_Window_Half" if fam == "Metal" else "Trim_Window")
        fill = f"{fam}_Plain_3"
        corner_fam = fam
        # ground floor
        if spec.get("storefront"):
            # storefront glass + doors on the south face, plain elsewhere
            self.wall_row("Metal_FullWindow", fill, -w / 2 + 2, w / 2 - 2, 0, -d / 2, 180.0, "all")
            self.add("DoorFrame_Metal_Single", 0, 0, d / 2, 0.0)
            self.wall_row("Metal_FullWindow", fill, -w / 2 + 2, -2, 0, d / 2, 0.0, "all")
            self.wall_row("Metal_FullWindow", fill, 2, w / 2 - 2, 0, d / 2, 0.0, "all")
            for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
                z = -d / 2 + 1.0
                while z < d / 2 - 1.5:
                    self.add(fill, xpos, 0, z, rot)
                    z += 2.0
        else:
            self.wall_row(win, fill, -w / 2 + 2, w / 2 - 2, 0, -d / 2, 180.0, "alt")
            # front (south) with a door
            self.add("DoorFrame_Wooden", 0, 0, d / 2, 0.0)
            for cx in [x for x in range(int(-w / 2 + 2), int(w / 2 - 1), 2)]:
                if abs(cx) < 1.5:
                    continue
                self.add(win, cx + 1.0, 0, d / 2, 0.0)
            for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
                z = -d / 2 + 1.0
                while z < d / 2 - 1.5:
                    self.add(win if int(z / 2) % 2 == 0 else fill, xpos, 0, z, rot)
                    z += 2.0
        self.corners(corner_fam, w, d, 0)
        # upper floors
        for f in range(1, floors):
            y = f * 3.0
            self.wall_row(win, fill, -w / 2 + 2, w / 2 - 2, y, -d / 2, 180.0, "alt")
            self.wall_row(win, fill, -w / 2 + 2, w / 2 - 2, y, d / 2, 0.0, "alt")
            for xpos, rot in [(-w / 2, 90.0), (w / 2, 270.0)]:
                z = -d / 2 + 1.0
                while z < d / 2 - 1.5:
                    self.add(win if int(z / 2) % 2 == 0 else fill, xpos, y, z, rot)
                    z += 2.0
            self.corners(corner_fam, w, d, y)
        top = floors * 3.0
        self.cornice_ring(fam, w, d, top)
        self.roof_slab(w, d, top + 0.45)
        # assemble one scene: merge parts by material for fewer meshes
        groups = {}
        for g, M in self.parts:
            key = id(g.visual.material) if g.visual.material is not None else 0
            groups.setdefault(key, []).append((g, M))
        scene = trimesh.Scene()
        for i, (key, items) in enumerate(groups.items()):
            merged = None
            for g, M in items:
                gg = g.copy()
                gg.apply_transform(M)
                merged = gg if merged is None else trimesh.util.concatenate([merged, gg])
            scene.add_geometry(merged, node_name=f"part_{i}")
        return scene

_pil_cache = {}
def _pil(name):
    from PIL import Image
    if name not in _pil_cache:
        _pil_cache[name] = Image.open(os.path.join(TEX, name)).convert("RGB")
    return _pil_cache[name]

SPECS = {
    # Old Quarter - warm brick walk-ups
    "b_brick2":    {"family": "Brick", "w": 12, "d": 12, "floors": 3},
    "b_brick3":    {"family": "Brick", "w": 13, "d": 11, "floors": 4},
    "b_brick4":    {"family": "Brick", "w": 12, "d": 12, "floors": 3, "storefront": True},
    "b_brick_tan": {"family": "Brick", "w": 11, "d": 11, "floors": 3},
    # Docklands / Ironworks - low metal warehouses
    "b_ware1":     {"family": "Metal", "w": 16, "d": 14, "floors": 2},
    "b_ware2":     {"family": "Metal", "w": 20, "d": 15, "floors": 2},
    "b_ware3":     {"family": "Metal", "w": 18, "d": 16, "floors": 1},
    # Kestrel - corporate towers
    "b_tower1":    {"family": "Metal", "w": 14, "d": 14, "floors": 6},
    "b_tower2":    {"family": "Metal", "w": 12, "d": 12, "floors": 7},
    "b_tower3":    {"family": "Metal", "w": 16, "d": 13, "floors": 5},
    # Neon Strip - glass storefronts
    "b_shop1":     {"family": "Metal", "w": 10, "d": 10, "floors": 2, "storefront": True},
    "b_shop2":     {"family": "Metal", "w": 12, "d": 10, "floors": 2, "storefront": True},
    "b_shop3":     {"family": "Brick", "w": 14, "d": 12, "floors": 3, "storefront": True},
    # Heights - classical rowhouses
    "b_house1":    {"family": "Brick", "w": 9,  "d": 9,  "floors": 2},
    "b_house2":    {"family": "Trim",  "w": 11, "d": 9,  "floors": 2},
    "b_house3":    {"family": "Trim",  "w": 10, "d": 10, "floors": 3},
    # Civic
    "b_bank":      {"family": "Trim",  "w": 15, "d": 15, "floors": 3},
    "b_hospital":  {"family": "Metal", "w": 18, "d": 15, "floors": 5},
    "b_hotel":     {"family": "Brick", "w": 16, "d": 14, "floors": 6, "storefront": True},
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:] or list(SPECS.keys())
    for name in only:
        spec = SPECS[name]
        c = Composer()
        scene = c.build(spec)
        path = os.path.join(OUT, name + ".glb")
        data = scene.export(path)
        tris = sum(len(g.faces) for g in scene.geometry.values())
        ext = (scene.bounds[1] - scene.bounds[0]).round(1)
        size = os.path.getsize(path)
        print(f"{name:14s} {tris:6d} tris  {size//1024:4d} KB  bounds {ext}")
