#!/usr/bin/env python3
"""LEVERAGE realistic human character generator (Blender 4.5, background).
Authors detailed human bodies skinned to the imported UAL rig (DEF-* bones).
Output: char_<id>.glb (armature + skinned mesh, NO animations - shared via ual_mannequin.glb at runtime).
Usage: blender -b -P build_character.py -- <specs.json> [ids...]
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector

TEX = "/home/z/my-project/leverage/assets/textures"
OUT = "/home/z/my-project/leverage/assets/characters"
MANNEQUIN = "/home/z/my-project/leverage/assets/characters/ual_mannequin.glb"
RIG_DUMP = "/tmp/rig_dump.json"

ZONES = ["skin", "hair", "eyew", "iris", "lips", "top", "shirt", "pants", "shoes", "metal", "beard"]
ZI = {z: i for i, z in enumerate(ZONES)}

_bones = None
def bone(name, mode="head"):
    global _bones
    if _bones is None:
        _bones = json.load(open(RIG_DUMP))
    b = _bones.get(name)
    if b is None:
        return Vector((0, 0, 0))
    return Vector(b[mode])

def side(sx):
    return 'L' if sx > 0 else 'R'

# ---------------------------------------------------------------- materials
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

def mat_textured(name, base, color, metallic=0.0):
    """Principled with albedo*color + roughness map + normal map from texture set."""
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
    return mat

def mat_plain(name, color, roughness=0.7, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat

# ---------------------------------------------------------------- geometry
def _basis_from_dir(d):
    d = d.normalized()
    up = Vector((0, 0, 1))
    if abs(d.dot(up)) > 0.9:
        up = Vector((0, 1, 0))
    x = d.cross(up).normalized()
    y = x.cross(d).normalized()
    return x, y

def tube(bm, path, radii, zone, segs=20, u_rep=1.0, v_rep=1.0, cap_s=False, cap_e=False,
         arc=(0.0, 2 * math.pi), taper_uv=True):
    """Tube along polyline; per-ring (rx,ry). Tags faces with zone material index."""
    uvl = bm.loops.layers.uv.verify()
    rings = []
    vmap = {}
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
        x, y = _basis_from_dir(d)
        rx, ry = radii[i]
        ring = []
        s_count = segs if closed else max(2, int(segs * (arc[1] - arc[0]) / (2 * math.pi)))
        for s in range(s_count):
            t = (arc[1] - arc[0]) * s / s_count + arc[0]
            v = bm.verts.new(path[i] + x * math.cos(t) * rx + y * math.sin(t) * ry)
            ring.append(v)
            vmap[v.index] = (i, s, s_count)
        rings.append(ring)
    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(len(r0)):
            if not closed and s == len(r0) - 1:
                continue
            s2 = (s + 1) % len(r0)
            try:
                f = bm.faces.new((r0[s], r0[s2], r1[s2], r1[s]))
            except ValueError:
                continue
            f.smooth = True
            f.material_index = ZI[zone]
            _uv_tube(f, uvl, vmap, i, s, n, u_rep, v_rep)
    if cap_s:
        _cap(bm, rings[0], zone, True)
    if cap_e:
        _cap(bm, rings[-1], zone, False)
    return rings

def _uv_tube(f, uvl, vmap, i, s, n, u_rep, v_rep):
    for loop in f.loops:
        info = vmap.get(loop.vert.index)
        if info:
            ri, si, sn = info
            u = si / sn * u_rep * 4.0
            v = ri / max(1, n - 1) * v_rep * 4.0
            loop[uvl].uv = (u, v)

def _cap(bm, ring, zone, invert):
    c = bm.verts.new((sum((v.co for v in ring), Vector())) / len(ring))
    for s in range(len(ring)):
        s2 = (s + 1) % len(ring)
        try:
            tri = (c, ring[s], ring[s2]) if not invert else (c, ring[s2], ring[s])
            f = bm.faces.new(tri)
            f.smooth = True
            f.material_index = ZI[zone]
            for loop in f.loops:
                loop[bm.loops.layers.uv.verify()].uv = (0.5, 0.5)
        except ValueError:
            pass

def ellipsoid(bm, center, r, zone, scale=(1, 1, 1), segs_u=24, segs_v=16, clip=None):
    uvl = bm.loops.layers.uv.verify()
    verts = {}
    for iu in range(segs_u):
        for iv in range(segs_v):
            u = 2 * math.pi * iu / segs_u
            v = math.pi * iv / (segs_v - 1)
            p = Vector((math.sin(v) * math.cos(u), math.sin(v) * math.sin(u), math.cos(v)))
            p = Vector((p.x * r * scale[0], p.y * r * scale[1], p.z * r * scale[2])) + center
            verts[(iu, iv)] = bm.verts.new(p)
    for iu in range(segs_u):
        for iv in range(segs_v - 1):
            a = verts[(iu, iv)]; b = verts[((iu + 1) % segs_u, iv)]
            c = verts[((iu + 1) % segs_u, iv + 1)]; d = verts[(iu, iv + 1)]
            try:
                f = bm.faces.new((a, b, c, d))
                f.smooth = True
                f.material_index = ZI[zone]
                uu = iu / segs_u * 4.0; vv = iv / (segs_v - 1) * 4.0
                for loop in f.loops:
                    loop[uvl].uv = (uu, vv)
            except ValueError:
                pass
    if clip:
        for f in list(bm.faces):
            if f.material_index == ZI[zone]:
                c = f.calc_center_median()
                if clip(c):
                    bm.faces.remove(f)

def box(bm, center, size, zone, rot=None):
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
            f.smooth = True
            f.material_index = ZI[zone]
            for loop in f.loops:
                loop[uvl].uv = (0.5, 0.5)
        except ValueError:
            pass

# ---------------------------------------------------------------- body builder
class HumanBuilder:
    def __init__(self, spec):
        self.s = spec
        self.build = spec.get("build", 1.0)
        self.female = spec.get("female", False)
        self.bm = bmesh.new()

    def B(self):
        return self.build

    def build_body(self):
        bm = self.bm
        b = self.build
        shoulder_w = 0.88 if self.female else 1.0
        hip_w = 1.1 if self.female else 1.0
        pelvis_c = Vector((0, 0, 0.94)); waist_c = Vector((0, 0.004, 1.07))
        chest_c = Vector((0, 0.006, 1.27)); sh_c = Vector((0, 0, 1.425)); neck_c = Vector((0, 0.01, 1.487))
        tube(bm, [pelvis_c, waist_c, chest_c, sh_c, neck_c],
             [(0.155 * b * hip_w, 0.118), (0.138 * b, 0.108), (0.172 * b * shoulder_w, 0.122),
              (0.185 * b * shoulder_w, 0.112), (0.058, 0.058)], "skin", segs=22, v_rep=3, cap_e=True)
        ellipsoid(bm, Vector((0, 0.002, 0.965)), 0.13, "skin", scale=(1.18 * b * hip_w, 0.92, 0.62), segs_u=20, segs_v=10)
        ellipsoid(bm, Vector((0, 0.075, 0.96)), 0.085, "skin", scale=(1.25 * b * hip_w, 0.7, 0.8), segs_u=16, segs_v=8)
        for sx in (-1, 1):
            ellipsoid(bm, Vector((sx * 0.06 * b, -0.075, 1.31)), 0.055, "skin", scale=(1.0, 0.55, 0.9), segs_u=14, segs_v=8)
        if self.female:
            for sx in (-1, 1):
                ellipsoid(bm, Vector((sx * 0.065 * b, -0.095, 1.24)), 0.062, "skin", scale=(1.05, 0.75, 0.95), segs_u=16, segs_v=10)
        tube(bm, [neck_c, Vector((0, -0.005, 1.568))], [(0.055, 0.055), (0.048, 0.048)], "skin", segs=14)
        self.build_head()
        for sx in (-1, 1):
            self.build_arm(sx)
        for sx in (-1, 1):
            self.build_leg(sx)

    def build_head(self):
        bm = self.bm
        rings = [
            (Vector((0, 0.0, 1.545)), (0.030, 0.028)),
            (Vector((0, -0.004, 1.555)), (0.062, 0.050)),
            (Vector((0, -0.012, 1.575)), (0.082, 0.068)),
            (Vector((0, -0.014, 1.588)), (0.090, 0.076)),
            (Vector((0, -0.012, 1.615)), (0.097, 0.085)),
            (Vector((0, -0.010, 1.637)), (0.100, 0.092)),
            (Vector((0, -0.006, 1.660)), (0.098, 0.095)),
            (Vector((0, 0.0, 1.683)), (0.088, 0.090)),
            (Vector((0, 0.0, 1.700)), (0.055, 0.055)),
        ]
        tube(bm, [r[0] for r in rings], [r[1] for r in rings], "skin", segs=22, cap_e=True, cap_s=True, v_rep=2)
        ellipsoid(bm, Vector((0, 0.045, 1.635)), 0.083, "skin", scale=(1.05, 0.95, 1.0), segs_u=18, segs_v=12)
        # nose: sunk ellipsoid protruding 6-8mm
        ellipsoid(bm, Vector((0, -0.093, 1.628)), 0.021, "skin", scale=(0.62, 0.85, 1.15), segs_u=12, segs_v=8)
        for sx in (-1, 1):
            ellipsoid(bm, Vector((sx * 0.033, -0.085, 1.649)), 0.019, "skin", scale=(1.25, 0.6, 0.8), segs_u=10, segs_v=6)
        for sx in (-1, 1):
            ellipsoid(bm, Vector((sx * 0.036, -0.0875, 1.630)), 0.0125, "eyew", scale=(1.0, 0.95, 1.0), segs_u=12, segs_v=8)
            # eyelids: full sunk ellipsoids - only rim protrudes over the eyeball
            ellipsoid(bm, Vector((sx * 0.036, -0.0855, 1.6375)), 0.0148, "skin", scale=(1.05, 1.05, 0.62), segs_u=12, segs_v=8)
            ellipsoid(bm, Vector((sx * 0.036, -0.0855, 1.6245)), 0.0142, "skin", scale=(1.05, 1.0, 0.55), segs_u=12, segs_v=8)
        # lips: sunk ellipsoids, slight protrusion
        ellipsoid(bm, Vector((0, -0.088, 1.579)), 0.0135, "lips", scale=(1.8, 0.65, 0.75), segs_u=12, segs_v=8)
        ellipsoid(bm, Vector((0, -0.086, 1.5725)), 0.0115, "lips", scale=(1.55, 0.6, 0.7), segs_u=12, segs_v=8)
        ellipsoid(bm, Vector((0, -0.078, 1.555)), 0.022, "skin", scale=(1.15, 0.9, 0.85), segs_u=10, segs_v=6)
        for sx in (-1, 1):
            ellipsoid(bm, Vector((sx * 0.1, 0.006, 1.622)), 0.03, "skin", scale=(0.55, 1.0, 1.1), segs_u=10, segs_v=8)

    def build_face_details(self):
        bm = self.bm
        for sx in (-1, 1):
            ellipsoid(bm, Vector((sx * 0.0375, -0.0965, 1.630)), 0.0065, "iris", scale=(1, 0.5, 1), segs_u=8, segs_v=6)
            # brows: sunk ellipsoids protruding 3mm from the brow ridge
            ellipsoid(bm, Vector((sx * 0.034, -0.094, 1.654)), 0.0145, "hair", scale=(1.4, 0.4, 0.5), segs_u=10, segs_v=6)

    def build_arm(self, sx):
        bm = self.bm
        sd = side(sx)
        sh = bone('DEF-upper_arm.%s' % sd, 'head')
        el = bone('DEF-forearm.%s' % sd, 'head')
        wr = bone('DEF-hand.%s' % sd, 'head')
        ellipsoid(bm, sh - Vector((sx * 0.02, 0, 0.01)), 0.055 * self.B(), "skin", scale=(1.05, 0.95, 1.0), segs_u=14, segs_v=10)
        mid = (sh + el) / 2
        tube(bm, [sh + Vector((sx * 0.01, 0, 0)), mid + Vector((0, 0.01, 0.005)), el],
             [(0.045 * self.B(), 0.048 * self.B()), (0.041 * self.B(), 0.044 * self.B()), (0.043 * self.B(), 0.046 * self.B())], "skin", segs=16, v_rep=2)
        fmid = el + (wr - el) * 0.35
        tube(bm, [el, fmid, wr], [(0.042 * self.B(), 0.045 * self.B()), (0.045 * self.B(), 0.048 * self.B()), (0.034, 0.036)], "skin", segs=16, v_rep=2)
        hd = bone('DEF-hand.%s' % sd, 'tail')
        pdir = (hd - wr).normalized() if (hd - wr).length > 0.001 else Vector((sx, 0, 0))
        palm_c = wr + pdir * 0.045
        z = Vector((0, 0, 1))
        if abs(pdir.dot(z)) > 0.9: z = Vector((0, 1, 0))
        tube(bm, [palm_c - pdir * 0.045, palm_c + pdir * 0.055],
             [(0.042, 0.021), (0.040, 0.017)], "skin", segs=14, cap_s=True, cap_e=True)
        for fing in ['thumb', 'f_index', 'f_middle', 'f_ring', 'f_pinky']:
            for seg_i in [1, 2, 3]:
                nm = 'DEF-%s.%02d.%s' % (fing, seg_i, sd)
                h = bone(nm, 'head'); t = bone(nm, 'tail')
                if h.length == 0 and t.length == 0:
                    continue
                r = 0.0115 if 'thumb' not in fing else 0.013
                tube(bm, [h, t], [(r, r), (r * 0.8, r * 0.8)], "skin", segs=8, cap_s=True, cap_e=True)

    def build_leg(self, sx):
        bm = self.bm
        sd = side(sx)
        hip = bone('DEF-thigh.%s' % sd, 'head')
        knee = bone('DEF-shin.%s' % sd, 'head')
        ankle = bone('DEF-foot.%s' % sd, 'head')
        tm = (hip + knee) / 2 + Vector((0, 0.01, 0.02))
        tube(bm, [hip, tm, knee], [(0.086 * self.B(), 0.090 * self.B()), (0.075 * self.B(), 0.078 * self.B()), (0.062 * self.B(), 0.063 * self.B())], "skin", segs=18, v_rep=3)
        sm = ankle + (knee - ankle) * 0.28
        tube(bm, [knee, sm, ankle], [(0.060 * self.B(), 0.062 * self.B()), (0.058 * self.B(), 0.066 * self.B()), (0.038, 0.040)], "skin", segs=18, v_rep=3)
        ellipsoid(bm, (knee + sm) / 2 - Vector((0, 0.025, 0)), 0.05, "skin", scale=(0.95, 0.9, 1.0), segs_u=12, segs_v=8)
        heel = ankle + Vector((0, 0.045, -0.075))
        toe = ankle + Vector((0, -0.155, -0.075))
        tube(bm, [ankle + Vector((0, 0.012, 0.0)), ankle + Vector((0, 0.045, -0.045)), Vector((0, 0.045, -0.055)), toe],
             [(0.042, 0.044), (0.055, 0.045), (0.052, 0.042), (0.035, 0.025)], "skin", segs=14, cap_e=True)

    # ---------------- hair / beard (flat-hugging closed ellipsoids) ----------------
    def build_hair(self, style):
        bm = self.bm
        if style in ("crop", "buzz", "short"):
            if style == "buzz":
                ellipsoid(bm, Vector((0, 0.04, 1.652)), 0.115, "hair", scale=(1.0, 0.095, 0.05), segs_u=20, segs_v=12)
            elif style == "crop":
                ellipsoid(bm, Vector((0, 0.045, 1.655)), 0.118, "hair", scale=(1.02, 0.105, 0.055), segs_u=20, segs_v=12)
            else:
                ellipsoid(bm, Vector((0, 0.045, 1.655)), 0.124, "hair", scale=(1.04, 0.112, 0.06), segs_u=20, segs_v=12)
        elif style == "long":
            ellipsoid(bm, Vector((0, 0.045, 1.655)), 0.124, "hair", scale=(1.04, 0.112, 0.06), segs_u=20, segs_v=12)
            for sx in (-1, 1):
                tube(bm, [Vector((sx * 0.09, 0.062, 1.64)), Vector((sx * 0.1, 0.075, 1.52)), Vector((sx * 0.09, 0.072, 1.38))],
                     [(0.03, 0.03), (0.027, 0.027), (0.02, 0.02)], "hair", segs=10, cap_e=True)
        elif style == "ponytail":
            ellipsoid(bm, Vector((0, 0.045, 1.655)), 0.118, "hair", scale=(1.02, 0.105, 0.055), segs_u=20, segs_v=12)
            tube(bm, [Vector((0, 0.115, 1.66)), Vector((0, 0.142, 1.585)), Vector((0, 0.152, 1.47)), Vector((0, 0.148, 1.41))],
                 [(0.017, 0.017), (0.015, 0.015), (0.011, 0.011), (0.009, 0.009)], "hair", segs=10, cap_e=True)
        elif style == "bun":
            ellipsoid(bm, Vector((0, 0.045, 1.655)), 0.118, "hair", scale=(1.02, 0.105, 0.055), segs_u=20, segs_v=12)
            ellipsoid(bm, Vector((0, 0.118, 1.662)), 0.045, "hair", scale=(1.0, 0.9, 1.0), segs_u=12, segs_v=10)
        elif style == "afro":
            ellipsoid(bm, Vector((0, 0.03, 1.652)), 0.145, "hair", scale=(1.0, 1.0, 0.085), segs_u=22, segs_v=14)
        elif style == "bald":
            return

    def build_beard(self, style):
        bm = self.bm
        if style == "stubble":
            ellipsoid(bm, Vector((0, -0.008, 1.583)), 0.102, "beard", scale=(1.0, 0.36, 0.5), segs_u=16, segs_v=12)
        elif style == "goatee":
            ellipsoid(bm, Vector((0, -0.012, 1.582)), 0.052, "beard", scale=(1.0, 0.9, 0.85), segs_u=12, segs_v=10)
        elif style == "full":
            ellipsoid(bm, Vector((0, -0.006, 1.583)), 0.104, "beard", scale=(1.0, 0.6, 0.5), segs_u=16, segs_v=12)
        if style in ("full", "mustache"):
            tube(bm, [Vector((-0.017, -0.091, 1.585)), Vector((0.017, -0.091, 1.585))], [(0.007, 0.004), (0.007, 0.004)], "beard", segs=8, cap_s=True, cap_e=True)

    # ---------------- outfit ----------------
    def build_outfit(self):
        bm = self.bm
        s = self.s
        b = self.build
        top = s.get("top", "jacket")
        o = 0.014 * b
        pelvis_c = Vector((0, 0, 0.94)); waist_c = Vector((0, 0.004, 1.07))
        chest_c = Vector((0, 0.006, 1.27)); sh_c = Vector((0, 0, 1.425)); neck_c = Vector((0, 0.01, 1.487))
        if top in ("tee", "tank", "dress_shirt", "blouse", "tshirt_long"):
            r_add = o if top != "tank" else o * 0.7
            tube(bm, [Vector((0, 0, 1.032)), waist_c, chest_c, sh_c, neck_c],
                 [(0.155 + r_add, 0.12 + r_add), (0.14 + r_add, 0.11 + r_add), (0.174 + r_add, 0.126 + r_add),
                  (0.186 + r_add, 0.116 + r_add), (0.06, 0.06)], "top", segs=22, v_rep=3)
        if top in ("jacket", "suit", "vest", "leather_jacket", "coat", "hoodie", "police"):
            # under-shirt so the jacket hem gap shows fabric, never skin
            r_u = o
            tube(bm, [pelvis_c + Vector((0, 0, 0.02)), waist_c, chest_c, sh_c, neck_c],
                 [(0.152 + r_u, 0.118 + r_u), (0.139 + r_u, 0.108 + r_u), (0.173 + r_u, 0.124 + r_u),
                  (0.185 + r_u, 0.114 + r_u), (0.059, 0.059)], "shirt", segs=22, v_rep=3)
            r_add = o * 1.7
            tube(bm, [pelvis_c - Vector((0, 0, 0.01)), waist_c, chest_c, sh_c, neck_c + Vector((0, 0, 0.01))],
                 [(0.158 + r_add, 0.124 + r_add), (0.142 + r_add, 0.114 + r_add), (0.178 + r_add, 0.132 + r_add),
                  (0.19 + r_add, 0.122 + r_add), (0.066, 0.066)], "top", segs=22, v_rep=3)
            tube(bm, [Vector((0, 0.01, 1.472)), Vector((0, -0.012, 1.543))], [(0.077, 0.082), (0.085, 0.088)], "top", segs=16)
            tube(bm, [waist_c - Vector((0, 0, 0.015)), waist_c + Vector((0, 0, 0.015))],
                 [(0.15 + r_add, 0.118 + r_add)] * 2, "top", segs=22)
            # front zip strip + hip pockets so jackets read as jackets
            box(bm, Vector((0, -0.128 - r_add, 1.18)), (0.014, 0.008, 0.62), "shirt")
            for sx in (-1, 1):
                box(bm, Vector((sx * 0.095, -0.138 - r_add, 1.045)), (0.06, 0.006, 0.08), "shirt")
        if s.get("skirt"):
            tube(bm, [Vector((0, 0, 1.0)), Vector((0, 0, 0.86)), Vector((0, 0, 0.58)), Vector((0, 0, 0.47))],
                 [(0.165, 0.13), (0.185, 0.16), (0.24, 0.22), (0.26, 0.24)], "pants", segs=24, cap_e=True)
        if top not in ("tank", "vest"):
            for sx in (-1, 1):
                sd = side(sx)
                sh = bone('DEF-upper_arm.%s' % sd, 'head')
                el = bone('DEF-forearm.%s' % sd, 'head')
                wr = bone('DEF-hand.%s' % sd, 'head')
                if top in ("tee", "tshirt_long", "dress_shirt", "blouse"):
                    end = sh + (el - sh) * 0.45 if top == "tee" else el + (wr - el) * 0.4
                    tube(bm, [sh - Vector((sx * 0.02, 0, 0)), sh + (el - sh) * 0.5, end],
                         [(0.052 * b, 0.055 * b), (0.048 * b, 0.051 * b), (0.044 * b, 0.047 * b)], "top", segs=14)
                else:
                    r_add = o * 1.6
                    tube(bm, [sh - Vector((sx * 0.06, 0, 0)), (sh + el) / 2, el, el + (wr - el) * 0.55],
                         [(0.052 * b + r_add, 0.055 * b + r_add), (0.048 * b + r_add, 0.051 * b + r_add),
                          (0.046 * b + r_add, 0.049 * b + r_add), (0.038 + r_add, 0.040 + r_add)], "top", segs=14, cap_e=True)
                    tube(bm, [el + (wr - el) * 0.5, el + (wr - el) * 0.62], [(0.041 + r_add, 0.044 + r_add)] * 2, "top", segs=14)
        pants = s.get("pants", "pants")
        if pants != "none":
            for sx in (-1, 1):
                sd = side(sx)
                hip = bone('DEF-thigh.%s' % sd, 'head')
                knee = bone('DEF-shin.%s' % sd, 'head')
                ankle = bone('DEF-foot.%s' % sd, 'head')
                r_add = o
                if pants == "shorts":
                    tube(bm, [hip - Vector((0, 0, 0.04)), (hip + knee) / 2, knee - Vector((0, 0, 0.06))],
                         [(0.092 * b + r_add, 0.096 * b + r_add), (0.08 * b + r_add, 0.083 * b + r_add), (0.075 * b + r_add, 0.077 * b + r_add)], "pants", segs=18, cap_e=True, v_rep=2)
                else:
                    hem_z = 0.118 if s.get("shoes", "boots") == "boots" else 0.132
                    tube(bm, [hip - Vector((0, 0, 0.04)), (hip + knee) / 2 + Vector((0, 0.01, 0.02)), knee, Vector((sx * 0.089, 0.01, hem_z))],
                         [(0.092 * b + r_add, 0.096 * b + r_add), (0.079 * b + r_add, 0.082 * b + r_add),
                          (0.065 * b + r_add, 0.066 * b + r_add), (0.048, 0.05)], "pants", segs=18, v_rep=3)
            tube(bm, [Vector((0, 0, 1.02)), Vector((0, 0, 1.055))], [(0.145 * b, 0.112), (0.142 * b, 0.11)], "pants", segs=22)
        shoe = s.get("shoes", "boots")
        for sx in (-1, 1):
            sd = side(sx)
            ankle = bone('DEF-foot.%s' % sd, 'head')
            toe = ankle + Vector((0, -0.16, -0.077))
            if shoe == "boots":
                tube(bm, [ankle + Vector((0, 0.01, 0.02)), ankle + Vector((0, 0.05, -0.05)), ankle + Vector((0, 0.055, -0.062)), toe + Vector((0, 0, 0.02))],
                     [(0.055, 0.058), (0.062, 0.052), (0.058, 0.048), (0.04, 0.03)], "shoes", segs=14, cap_e=True)
                tube(bm, [Vector((sx * 0.089, 0.05, 0.015)), Vector((sx * 0.089, -0.19, 0.008))],
                     [(0.062, 0.026), (0.062, 0.026)], "shoes", segs=12, cap_s=True, cap_e=True)
            elif shoe == "sneakers":
                tube(bm, [ankle + Vector((0, 0.03, 0.0)), ankle + Vector((0, 0.045, -0.05)), ankle + Vector((0, 0.05, -0.06)), toe],
                     [(0.05, 0.052), (0.058, 0.048), (0.054, 0.044), (0.036, 0.026)], "shoes", segs=14, cap_e=True)
        if s.get("belt", pants == "pants"):
            tube(bm, [Vector((0, 0, 1.03)), Vector((0, 0, 1.065))], [(0.166, 0.128), (0.164, 0.126)], "shoes", segs=20)
            box(bm, Vector((0, -0.152, 1.047)), (0.036, 0.014, 0.05), "metal")
        for ex in s.get("extras", []):
            if ex == "watch":
                wr = bone('DEF-hand.L', 'head')
                box(bm, wr + Vector((0.02, 0, 0)), (0.045, 0.05, 0.02), "metal")
            elif ex == "holster":
                box(bm, Vector((0.115, 0.02, 1.0)), (0.07, 0.2, 0.09), "shoes")
            elif ex == "chain":
                tube(bm, [Vector((0.0, -0.11, 1.07)), Vector((0.02, -0.105, 1.05))], [(0.01, 0.01), (0.01, 0.01)], "metal", segs=8)
            elif ex == "cap":
                ellipsoid(bm, Vector((0, 0.008, 1.684)), 0.105, "top", scale=(1.0, 1.0, 0.72), segs_u=18, segs_v=10,
                          clip=lambda c: c.z < 1.672)
                box(bm, Vector((0, -0.1, 1.684)), (0.17, 0.075, 0.012), "top")
            elif ex == "fedora":
                ellipsoid(bm, Vector((0, 0.012, 1.688)), 0.085, "top", scale=(1.0, 1.0, 0.8), segs_u=16, segs_v=10)
                tube(bm, [Vector((0, -0.06, 1.675)), Vector((0, 0.06, 1.675))], [(0.14, 0.15), (0.14, 0.15)], "top", segs=16, cap_s=True, cap_e=True)
            elif ex == "flatcap":
                ellipsoid(bm, Vector((0, 0.008, 1.683)), 0.108, "top", scale=(1.0, 1.05, 0.7), segs_u=16, segs_v=10,
                          clip=lambda c: c.z < 1.676)
            elif ex == "hoodie":
                ellipsoid(bm, Vector((0, -0.01, 1.68)), 0.115, "top", scale=(1.0, 1.05, 0.85), segs_u=16, segs_v=10)

# ---------------------------------------------------------------- proximity skinning
def _proximity_skin(obj, arm):
    """Deterministic skinning: each vertex bound to its 3 nearest bones
    (distance to bone segment) with cubic-inverse weights. No auto-weight
    envelopes, no neutral bone, predictable joints."""
    import mathutils
    bones = []
    for pb in arm.pose.bones:
        if pb.name.startswith("DEF-"):
            bones.append((pb.name, arm.matrix_world @ pb.head, arm.matrix_world @ pb.tail))
    # wipe existing groups
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    mw = obj.matrix_world
    infl = 3
    for v in obj.data.vertices:
        wpos = mw @ v.co
        dists = []
        for (nm, h, t) in bones:
            ab = t - h
            l2 = ab.length_squared
            if l2 < 1e-9:
                d = (wpos - h).length
            else:
                tt = max(0.0, min(1.0, (wpos - h).dot(ab) / l2))
                d = (wpos - (h + ab * tt)).length
            dists.append((d + 0.003, nm))  # softening epsilon: ~3mm
        dists.sort(key=lambda x: x[0])
        top = dists[:infl]
        wts = [1.0 / (d * d * d) for d, _ in top]
        tot = sum(wts)
        for (d, nm), w in zip(top, wts):
            vg = obj.vertex_groups.get(nm)
            if vg is None:
                vg = obj.vertex_groups.new(name=nm)
            vg.add([v.index], w / tot, 'ADD')

# ---------------------------------------------------------------- assemble
def build_char(spec, arm):
    # clean previous body + materials from this session
    for o in list(bpy.data.objects):
        if o.type == 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m, do_unlink=True)
    hb = HumanBuilder(spec)
    hb.build_body()
    hb.build_face_details()
    hb.build_hair(spec.get("hair", "crop"))
    if spec.get("beard"):
        hb.build_beard(spec["beard"])
    hb.build_outfit()
    skin_c = tuple(spec.get("skin", (1.0, 1.0, 1.0)))
    top = spec.get("top", "jacket")
    top_c = tuple(spec.get("top_color", (0.2, 0.22, 0.25)))
    pants_tex = "denim" if spec.get("pants_tex") == "denim" else "fabric_cotton"
    top_tex = "leather" if top == "leather_jacket" else ("fabric_gray" if top in ("suit", "police", "coat") else "fabric_cotton")
    hair_c = tuple(spec.get("hair_color", (0.07, 0.05, 0.04)))
    beard_c = tuple(min(1.0, c * 1.5) for c in hair_c)
    mats = [
        mat_textured("M_Skin", "skin", skin_c),
        mat_plain("M_Hair", hair_c, 0.55),
        mat_plain("M_EyeWhite", (0.88, 0.87, 0.85), 0.25),
        mat_plain("M_Iris", tuple(spec.get("iris", (0.14, 0.10, 0.07))), 0.15),
        mat_plain("M_Lips", tuple(spec.get("lip_color", (0.35, 0.18, 0.14))), 0.5),
        mat_textured("M_Top", top_tex, top_c),
        mat_textured("M_Shirt", "fabric_cotton", tuple(spec.get("shirt_color", (0.24, 0.25, 0.28)))),
        mat_textured("M_Pants", pants_tex, tuple(spec.get("pants_color", (0.16, 0.19, 0.30)))),
        mat_textured("M_Shoe", "leather", tuple(spec.get("shoe_color", (0.10, 0.09, 0.08)))),
        mat_plain("M_Metal", (0.75, 0.73, 0.70), 0.35, metallic=0.9),
        mat_plain("M_Beard", beard_c, 0.75),
    ]
    mesh = bpy.data.meshes.new("Body")
    hb.bm.to_mesh(mesh)
    for m in mats:
        mesh.materials.append(m)
    obj = bpy.data.objects.new("Body", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE')
    # deterministic proximity skinning: 3 nearest bones per vertex, cubic falloff
    _proximity_skin(obj, arm)
    out_path = os.path.join(OUT, "char_%s.glb" % spec["id"])
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB',
                              export_animations=False, export_apply=False,
                              export_texcoords=True, export_normals=True,
                              export_materials='EXPORT',
                              export_cameras=False, export_lights=False,
                              use_selection=True)
    print("CHAR BUILT: %s verts=%d faces=%d -> %s" % (spec["id"], len(mesh.vertices), len(mesh.polygons), out_path))
    return out_path

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    spec_file = argv[0]
    data = json.load(open(spec_file))
    if isinstance(data, dict):
        for k in list(data.keys()):
            data[k]["id"] = k
        specs = list(data.values())
    else:
        specs = data
    only = set(argv[1:]) if len(argv) > 1 else None
    # import the mannequin rig ONCE per session (factory resets break the gltf addon)
    bpy.ops.import_scene.gltf(filepath=MANNEQUIN)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for o in list(bpy.data.objects):
        if o.type == 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    for spec in specs:
        if only and spec["id"] not in only:
            continue
        build_char(spec, arm)
    print("DONE")
