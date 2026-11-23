#!/usr/bin/env python3
"""LEVERAGE building generator (Blender 4.5, background).
Parametric buildings for 5 district styles with inset windows, doors,
cornices, storefronts, balconies, roofs. Output: assets/buildings/*.glb.
Usage: blender -b -P build_building.py -- <specs.json> [ids...]
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix

TEX = "/home/z/my-project/leverage/assets/textures"
OUT = "/home/z/my-project/leverage/assets/buildings"
ZONES = ["wall", "trim", "glass", "door", "light", "metal", "roof"]
ZI = {z: i for i, z in enumerate(ZONES)}

_img_cache = {}
def _tex(path, srgb=False):
    if not os.path.exists(path):
        return None
    if path in _img_cache:
        return _img_cache[path]
    img = bpy.data.images.load(path)
    if srgb:
        try:
            img.colorspace_settings.name = 'sRGB'
        except Exception:
            pass
    _img_cache[path] = img
    return img

def mat_textured(name, base, color, metallic=0.0, rough=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    ns = mat.node_tree
    nodes, links = ns.nodes, ns.links
    bsdf = nodes["Principled BSDF"]
    alb = _tex(os.path.join(TEX, base + "_albedo.png"), srgb=True)
    if alb:
        n = nodes.new('ShaderNodeTexImage'); n.image = alb; n.label = 'albedo'
        if color and tuple(color) != (1.0, 1.0, 1.0):
            mix = nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
            mix.inputs['Factor'].default_value = 1.0
            rgb = nodes.new('ShaderNodeRGB'); rgb.outputs[0].default_value = (*color, 1.0)
            links.new(n.outputs['Color'], mix.inputs['A'])
            links.new(rgb.outputs['Color'], mix.inputs['B'])
            links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
        else:
            links.new(n.outputs['Color'], bsdf.inputs['Base Color'])
    else:
        bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    rgh = _tex(os.path.join(TEX, base + "_rough.png"))
    if rgh:
        n = nodes.new('ShaderNodeTexImage'); n.image = rgh; n.label = 'rough'
        links.new(n.outputs['Color'], bsdf.inputs['Roughness'])
    nrm = _tex(os.path.join(TEX, base + "_normal.png"))
    if nrm:
        n = nodes.new('ShaderNodeTexImage'); n.image = nrm; n.label = 'normal'
        nm = nodes.new('ShaderNodeNormalMap')
        links.new(n.outputs['Color'], nm.inputs['Color'])
        links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    if metallic:
        bsdf.inputs['Metallic'].default_value = metallic
    if rough is not None:
        bsdf.inputs['Roughness'].default_value = rough
    return mat

def mat_plain(name, color, rough=0.7, metallic=0.0, emission=None, energy=3.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metallic
    if emission is not None:
        bsdf.inputs['Emission Color'].default_value = (*emission, 1.0)
        bsdf.inputs['Emission Strength'].default_value = energy
    return mat

def _basis(d):
    d = d.normalized()
    up = Vector((0, 0, 1))
    if abs(d.dot(up)) > 0.9:
        up = Vector((0, 1, 0))
    x = d.cross(up).normalized()
    y = x.cross(d).normalized()
    return x, y

def tube(bm, path, radii, zone, segs=12, cap_s=False, cap_e=False, arc=(0.0, 2 * math.pi)):
    uvl = bm.loops.layers.uv.verify()
    rings = []
    n = len(path)
    closed = abs(arc[1] - arc[0] - 2 * math.pi) < 1e-4
    for i in range(n):
        if n == 1:
            d = Vector((0, 0, 1))
        elif i == 0:
            d = (path[1] - path[0]).normalized()
        elif i == n - 1:
            d = (path[i] - path[i - 1]).normalized()
        else:
            d = (path[i + 1] - path[i - 1]).normalized()
        x, y = _basis(d)
        rx, ry = radii[i]
        ring = []
        s_count = segs if closed else max(2, int(segs * (arc[1] - arc[0]) / (2 * math.pi)))
        for s in range(s_count):
            t = (arc[1] - arc[0]) * s / s_count + arc[0]
            ring.append(bm.verts.new(path[i] + x * math.cos(t) * rx + y * math.sin(t) * ry))
        rings.append(ring)
    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(len(r0)):
            if not closed and s == len(r0) - 1:
                continue
            s2 = (s + 1) % len(r0)
            try:
                f = bm.faces.new((r0[s], r0[s2], r1[s2], r1[s]))
                f.smooth = False
                f.material_index = ZI[zone]
                for loop in f.loops:
                    loop[uvl].uv = (s / len(r0) * 3.0, i / max(1, n - 1) * 3.0)
            except ValueError:
                pass
    if cap_s:
        _cap(bm, rings[0], zone)
    if cap_e:
        _cap(bm, rings[-1], zone)
    return rings

def _cap(bm, ring, zone):
    c = bm.verts.new((sum((v.co for v in ring), Vector())) / len(ring))
    uvl = bm.loops.layers.uv.verify()
    for s in range(len(ring)):
        s2 = (s + 1) % len(ring)
        try:
            f = bm.faces.new((c, ring[s], ring[s2]))
            f.smooth = False
            f.material_index = ZI[zone]
            for loop in f.loops:
                loop[uvl].uv = (0.5, 0.5)
        except ValueError:
            pass

def box(bm, center, size, zone, rot=None, uv_scale=1.0):
    x, y, z = size
    uvl = bm.loops.layers.uv.verify()
    idx = [(-1, -1, -1), (-1, -1, 1), (-1, 1, -1), (-1, 1, 1), (1, -1, -1), (1, -1, 1), (1, 1, -1), (1, 1, 1)]
    vs = []
    for (sx, sy, sz) in idx:
        p = Vector((sx * x / 2, sy * y / 2, sz * z / 2))
        if rot is not None:
            p = rot @ p
        vs.append(bm.verts.new(center + p))
    quads = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    for q in quads:
        try:
            f = bm.faces.new((vs[q[0]], vs[q[1]], vs[q[2]], vs[q[3]]))
            f.smooth = False
            f.material_index = ZI[zone]
            for loop in f.loops:
                loop[uvl].uv = (0.5, 0.5)
        except ValueError:
            pass

def panel(bm, corners, zone, nx=4, ny=2):
    uvl = bm.loops.layers.uv.verify()
    grid = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            u = i / nx; v = j / ny
            p = corners[0].lerp(corners[1], u).lerp(corners[3].lerp(corners[2], u), v)
            grid[(i, j)] = bm.verts.new(p)
    for j in range(ny):
        for i in range(nx):
            try:
                f = bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
                f.smooth = False
                f.material_index = ZI[zone]
                for loop in f.loops:
                    loop[uvl].uv = (0.5, 0.5)
            except ValueError:
                pass

# Buildings are authored with front toward -Y (Blender), which maps to +Z in Godot
# (same convention as the UAL rig: front = -Y Blender).
FRONT = -1.0  # sign of Y for the street-facing side

class BuildingBuilder:
    def __init__(self, spec):
        self.s = spec
        self.bm = bmesh.new()
        self.w = spec.get("w", 12.0)
        self.d = spec.get("d", 12.0)
        self.floors = spec.get("floors", 3)
        self.fh = spec.get("floor_h", 3.2)
        self.style = spec.get("style", "brick")
        self.H = self.floors * self.fh

    def build(self):
        st = self.style
        if st == "brick":
            self.brick()
        elif st == "warehouse":
            self.warehouse()
        elif st == "tower":
            self.tower()
        elif st == "shop":
            self.shop()
        elif st == "house":
            self.house()
        self.roof_junk()

    def walls(self, inset=0.0):
        bm = self.bm
        # simple: box for the main volume, subdivided by window bands
        z0 = 0.0
        z1 = self.H
        box(bm, Vector((0, 0, (z0 + z1) / 2 + inset)), (self.w - 2 * inset, self.d - 2 * inset, z1 - z0), "wall")
        # base plinth
        box(bm, Vector((0, 0, 0.18)), (self.w + 0.3, self.d + 0.3, 0.36), "trim")

    def windows(self, rows=None, cols=None, y_face=FRONT, glass_z0=1.2, glass_h=1.6, w_in=1.15, d_in=0.25):
        """Window band per floor: recessed dark glass + frame strip on the front face."""
        bm = self.bm
        rows = rows if rows else self.floors
        cols = cols if cols else max(2, int(self.w / 2.6))
        for fi in range(rows):
            zc = self.fh * fi + self.fh / 2
            span = self.w * 0.86
            cw = span / cols
            for ci in range(cols):
                xc = -span / 2 + cw * (ci + 0.5)
                # glass quad slightly inset
                box(bm, Vector((xc, y_face * (self.d / 2 - d_in), zc)), (w_in, 0.06, glass_h), "glass")
                # sill + header
                box(bm, Vector((xc, y_face * (self.d / 2 - d_in + 0.02), zc - glass_h / 2 - 0.09)), (w_in + 0.2, 0.1, 0.14), "trim")
                box(bm, Vector((xc, y_face * (self.d / 2 - d_in + 0.02), zc + glass_h / 2 + 0.09)), (w_in + 0.2, 0.1, 0.14), "trim")
        # side windows (both X faces) sparse
        for fi in range(rows):
            zc = self.fh * fi + self.fh / 2
            ns = max(1, int(self.d / 3.4))
            for ni in range(ns):
                yc = -self.d * 0.4 + self.d * 0.8 * (ni + 0.5) / ns
                for sx in (-1, 1):
                    box(bm, Vector((sx * (self.w / 2 - d_in), yc, zc)), (0.06, 1.5, glass_h), "glass")

    def door(self, double=True):
        bm = self.bm
        dw = 2.2 if double else 1.3
        box(bm, Vector((0, FRONT * (self.d / 2 - 0.18), 1.25)), (dw, 0.14, 2.5), "door")
        box(bm, Vector((0, FRONT * (self.d / 2 - 0.1), 2.62)), (dw + 0.5, 0.2, 0.24), "trim")

    def cornice(self):
        bm = self.bm
        box(bm, Vector((0, 0, self.H + 0.22)), (self.w + 0.5, self.d + 0.5, 0.44), "trim")
        box(bm, Vector((0, 0, self.H + 0.55)), (self.w + 0.2, self.d + 0.2, 0.24), "wall")
        # floor bands
        for fi in range(1, self.floors):
            box(bm, Vector((0, 0, self.fh * fi)), (self.w + 0.24, self.d + 0.24, 0.16), "trim")

    def brick(self):
        self.walls()
        self.windows()
        self.door()
        self.cornice()

    def warehouse(self):
        bm = self.bm
        self.walls()
        # clerestory strip windows high
        self.windows(rows=1, glass_z0=0, glass_h=1.4, w_in=1.4)
        # loading dock + roller door
        box(bm, Vector((0, FRONT * (self.d / 2 - 0.12), 1.6)), (4.0, 0.2, 3.2), "metal")
        box(bm, Vector((0, FRONT * (self.d / 2 + 0.6), 0.6)), (6.0, 2.4, 1.2), "trim")
        # parapet
        box(bm, Vector((0, 0, self.H + 0.3)), (self.w + 0.3, self.d + 0.3, 0.6), "trim")

    def tower(self):
        bm = self.bm
        self.walls()
        # glass curtain: continuous vertical glazing bands
        cols = max(3, int(self.w / 2.2))
        for fi in range(self.floors):
            zc = self.fh * fi + self.fh / 2
            span = self.w * 0.9
            cw = span / cols
            for ci in range(cols):
                xc = -span / 2 + cw * (ci + 0.5)
                box(bm, Vector((xc, FRONT * (self.d / 2 - 0.15), zc)), (cw * 0.86, 0.08, self.fh * 0.72), "glass")
            box(bm, Vector((0, FRONT * (self.d / 2 - 0.1), self.fh * (fi + 1))), (span, 0.2, 0.5), "trim")
        # mullion columns
        for ci in range(cols + 1):
            xc = -self.w * 0.9 / 2 + self.w * 0.9 * ci / cols
            box(bm, Vector((xc, FRONT * (self.d / 2 - 0.08), self.H / 2)), (0.3, 0.24, self.H), "wall")
        self.door()
        box(bm, Vector((0, 0, self.H + 0.35)), (self.w + 0.4, self.d + 0.4, 0.7), "trim")

    def shop(self):
        bm = self.bm
        self.walls()
        # storefront glass + awning + sign
        box(bm, Vector((0, FRONT * (self.d / 2 - 0.15), 1.7)), (self.w * 0.8, 0.16, 3.0), "glass")
        box(bm, Vector((0, FRONT * (self.d / 2 - 0.1), 0.35)), (self.w * 0.86, 0.2, 0.7), "trim")
        # awning (angled panel)
        rot = Matrix.Rotation(math.radians(18), 3, 'X')
        aw = Vector((0, FRONT * (self.d / 2 + 0.5), 3.5))
        panel(bm, [Vector((-self.w * 0.44, aw.y, aw.z)), Vector((self.w * 0.44, aw.y, aw.z)),
                   Vector((self.w * 0.5, aw.y + FRONT * 1.1, aw.z - 0.35)), Vector((-self.w * 0.5, aw.y + FRONT * 1.1, aw.z - 0.35))], "trim")
        # emissive sign band
        box(bm, Vector((0, FRONT * (self.d / 2 + 0.06), 4.4)), (self.w * 0.7, 0.3, 0.9), "light")
        # upper floor windows
        if self.floors > 1:
            self.windows(rows=self.floors - 1)
            for fi in range(1, self.floors):
                pass
        self.door()

    def house(self):
        bm = self.bm
        self.walls()
        self.windows(cols=max(2, int(self.w / 3.2)))
        self.door(double=False)
        # pitched roof (loft along X)
        eave = self.H
        rise = 2.2
        overh = 0.5
        pts = [Vector((-self.w / 2 - overh, 0, eave)), Vector((0, 0, eave + rise)), Vector((self.w / 2 + overh, 0, eave))]
        # build roof as two sloped panels + gable ends
        for sy in (-1, 1):
            yd = sy * (self.d / 2 + overh)
            panel(bm, [Vector((-self.w / 2 - overh, yd, eave)), Vector((-self.w / 2 - overh, sy * self.d / 2, eave)),
                       Vector((0, sy * self.d / 2, eave + rise)), Vector((-self.w / 2 - overh, yd, eave))], "roof")
        for sx in (-1, 1):
            gable = [Vector((sx * self.w / 2, -self.d / 2, eave)), Vector((sx * self.w / 2, self.d / 2, eave)),
                     Vector((0, self.d / 2, eave + rise)), Vector((0, -self.d / 2, eave + rise))]
            panel(bm, gable, "wall")
        # roof slabs
        for sy in (-1, 1):
            panel(bm, [Vector((-self.w / 2 - overh, sy * (self.d / 2 + overh), eave)), Vector((-self.w / 2 - overh, 0, eave + rise)),
                       Vector((self.w / 2 + overh, 0, eave + rise)), Vector((self.w / 2 + overh, sy * (self.d / 2 + overh), eave))], "roof")
        # chimney
        box(bm, Vector((self.w * 0.25, 0, eave + rise + 0.8)), (0.9, 0.9, 1.8), "wall")
        # porch
        box(bm, Vector((0, FRONT * (self.d / 2 + 0.9), 0.15)), (3.2, 1.8, 0.3), "trim")

    def roof_junk(self):
        bm = self.bm
        s = self.s
        top = self.H + (0.8 if self.style != "house" else 2.4)
        # AC units + vents
        n = 1 + (self.floors % 3)
        for i in range(n):
            box(bm, Vector((-self.w / 3 + i * self.w / 2.2, 0, top + 0.35)), (1.6, 1.2, 0.9), "metal")
        if s.get("antenna"):
            tube(bm, [Vector((self.w * 0.3, self.d * 0.2, top)), Vector((self.w * 0.3, self.d * 0.2, top + 4.0))],
                 [(0.06, 0.06)] * 2, "metal", segs=6, cap_e=True)
        if s.get("neon") and self.style == "shop":
            pass

def make_mats(spec):
    wall_tex = {"brick": "brick_red", "warehouse": "concrete_panel", "tower": "concrete", "shop": "brick_tan", "house": "brick_tan"}
    wall_c = tuple(spec.get("wall", (0.55, 0.55, 0.55)))
    return [
        mat_textured("M_Wall", wall_tex.get(spec.get("style", "brick"), "concrete"), wall_c),
        mat_plain("M_Trim", (0.4, 0.39, 0.37), 0.8),
        mat_plain("M_Glass", (0.07, 0.1, 0.13), 0.06, metallic=0.2),
        mat_plain("M_Door", (0.25, 0.2, 0.16), 0.6),
        mat_plain("M_Light", (0.9, 0.75, 0.35), 0.5, emission=(0.95, 0.7, 0.3), energy=2.2),
        mat_textured("M_Metal", "metal", (0.55, 0.55, 0.58), metallic=0.6),
        mat_plain("M_Roof", (0.2, 0.19, 0.18), 0.9),
    ]

def _purge_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me, do_unlink=True)

def build_building(spec):
    _purge_scene()
    _img_cache.clear()
    bb = BuildingBuilder(spec)
    bb.build()
    mats = make_mats(spec)
    mesh = bpy.data.meshes.new("Building")
    bb.bm.to_mesh(mesh)
    for m in mats:
        mesh.materials.append(m)
    obj = bpy.data.objects.new("Building", mesh)
    bpy.context.scene.collection.objects.link(obj)
    out = os.path.join(OUT, "%s.glb" % spec["id"])
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=False,
                              export_apply=False, export_materials='EXPORT')
    print("BUILDING BUILT:", spec["id"], "verts:", len(mesh.vertices), "->", out)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    data = json.load(open(argv[0]))
    if isinstance(data, dict):
        for k in list(data.keys()):
            data[k]["id"] = k
        specs = list(data.values())
    else:
        specs = data
    only = set(argv[1:]) if len(argv) > 1 else None
    for spec in specs:
        if only and spec["id"] not in only:
            continue
        build_building(spec)
    print("DONE")
