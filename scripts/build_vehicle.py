#!/usr/bin/env python3
"""LEVERAGE detailed vehicle generator (Blender 4.5, background).
Parametric cars: lower-body hull + glass cabin w/ pillars, wheel flares,
detailed wheels (tyre+rim+spokes) as separate nodes, lights, grille,
bumpers, mirrors, interior. Motorcycle included.
Output: assets/vehicles/<id>.glb  (Body + WheelFL/FR/RL/RR[+Seat]).
Usage: blender -b -P build_vehicle.py -- <specs.json> [ids...]
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix

TEX = "/home/z/my-project/leverage/assets/textures"
OUT = "/home/z/my-project/leverage/assets/vehicles"
ZONES = ["paint", "paint2", "glass", "chrome", "tyre", "light", "taillight", "plastic", "interior", "plate", "blue"]
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

# ---------------------------------------------------------------- geometry helpers
def _basis(d):
    d = d.normalized()
    up = Vector((0, 0, 1))
    if abs(d.dot(up)) > 0.9:
        up = Vector((0, 1, 0))
    x = d.cross(up).normalized()
    y = x.cross(d).normalized()
    return x, y

def tube(bm, path, radii, zone, segs=16, cap_s=False, cap_e=False, arc=(0.0, 2 * math.pi)):
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
                f.smooth = True
                f.material_index = ZI[zone]
                for loop in f.loops:
                    loop[uvl].uv = (s / len(r0) * 4.0, i / max(1, n - 1) * 4.0)
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

def ellipsoid(bm, center, r, zone, scale=(1, 1, 1), segs_u=16, segs_v=10, rot=None):
    uvl = bm.loops.layers.uv.verify()
    verts = {}
    for iu in range(segs_u):
        for iv in range(segs_v):
            u = 2 * math.pi * iu / segs_u
            v = math.pi * iv / (segs_v - 1)
            p = Vector((math.sin(v) * math.cos(u), math.sin(v) * math.sin(u), math.cos(v)))
            p = Vector((p.x * r * scale[0], p.y * r * scale[1], p.z * r * scale[2]))
            if rot is not None:
                p = rot @ p
            verts[(iu, iv)] = bm.verts.new(center + p)
    for iu in range(segs_u):
        for iv in range(segs_v - 1):
            a = verts[(iu, iv)]; b = verts[((iu + 1) % segs_u, iv)]
            c = verts[((iu + 1) % segs_u, iv + 1)]; d = verts[(iu, iv + 1)]
            try:
                f = bm.faces.new((a, b, c, d))
                f.smooth = True
                f.material_index = ZI[zone]
                for loop in f.loops:
                    loop[uvl].uv = (iu / segs_u * 4.0, iv / (segs_v - 1) * 4.0)
            except ValueError:
                pass

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

def panel(bm, corners, zone, nx=6, ny=3, bulge=0.0):
    uvl = bm.loops.layers.uv.verify()
    grid = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            u = i / nx; v = j / ny
            p = corners[0].lerp(corners[1], u).lerp(corners[3].lerp(corners[2], u), v)
            if bulge:
                nrm = ((corners[1] - corners[0]).cross(corners[3] - corners[0])).normalized()
                p += nrm * bulge * math.sin(u * math.pi) * math.sin(v * math.pi)
            grid[(i, j)] = bm.verts.new(p)
    for j in range(ny):
        for i in range(nx):
            try:
                f = bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
                f.smooth = True
                f.material_index = ZI[zone]
                for loop in f.loops:
                    loop[uvl].uv = (0.5, 0.5)
            except ValueError:
                pass

def smooth_mesh(mesh):
    for p in mesh.polygons:
        p.use_smooth = True

def _axis_flip(bm):
    """Convert authored Godot-convention coords (x, height, length) to Blender
    (x, -length, height) so glTF export yields a correctly-oriented vehicle."""
    for v in bm.verts:
        c = v.co
        v.co = Vector((c.x, -c.z, c.y))

# ---------------------------------------------------------------- car builder
class CarBuilder:
    """Unified single-hull car: one closed volume from nose to tail whose upper
    surfaces are retagged to glass by region (windshield/sides/rear). Pillars are
    the paint bands between glass regions. Arch wells are cut from the hull."""
    def __init__(self, spec):
        self.s = spec
        self.bm = bmesh.new()
        self.L = spec.get("length", 4.4)
        self.W = spec.get("width", 1.86)
        self.nose = -self.L / 2 - 0.05
        self.tail = self.L / 2 + 0.05
        self.belt = spec.get("belt", 0.78)
        self.roof = spec.get("roof", 1.32)
        self.ride = spec.get("ride", 0.55)
        self.wheel_z = (-1.4, 1.5)
        self.wheel_x = 0.85
        self.wr = 0.34
        self.stations = self._stations()

    def _stations(self):
        t = self.s.get("body_type", "sedan")
        L, belt, roof, ride = self.L, self.belt, self.roof, self.ride
        if t == "hatch":
            return [
                (self.nose, 0.74, 0.24, ride - 0.06),
                (-1.55, 0.92, 0.30, ride),
                (-0.95, 0.98, 0.30, ride + 0.12),
                (-0.5, 0.97, 0.38, belt + 0.14),
                (-0.05, 0.94, 0.44, belt + 0.28),
                (0.45, 0.93, 0.42, belt + 0.26),
                (1.05, 0.92, 0.34, belt + 0.06),
                (1.55, 0.93, 0.30, ride + 0.04),
                (self.tail, 0.82, 0.26, ride - 0.02),
            ]
        if t == "suv":
            return [
                (self.nose, 0.76, 0.26, ride - 0.04),
                (-1.6, 0.93, 0.32, ride),
                (-1.0, 0.99, 0.34, ride + 0.12),
                (-0.5, 0.98, 0.46, belt + 0.16),
                (0.0, 0.95, 0.52, belt + 0.30),
                (0.8, 0.94, 0.5, belt + 0.30),
                (1.5, 0.93, 0.46, belt + 0.24),
                (1.85, 0.94, 0.34, ride + 0.08),
                (self.tail, 0.82, 0.28, ride),
            ]
        if t == "sport":
            return [
                (self.nose, 0.72, 0.20, ride - 0.06),
                (-1.55, 0.93, 0.26, ride),
                (-0.85, 0.99, 0.28, ride + 0.08),
                (-0.3, 0.97, 0.36, belt + 0.08),
                (0.25, 0.94, 0.40, belt + 0.18),
                (0.75, 0.92, 0.36, belt + 0.1),
                (1.3, 0.93, 0.30, ride + 0.05),
                (1.8, 0.92, 0.26, ride),
                (self.tail, 0.8, 0.22, ride - 0.02),
            ]
        # sedan
        return [
            (self.nose, 0.74, 0.24, ride - 0.06),
            (-1.55, 0.92, 0.30, ride),
            (-0.95, 0.98, 0.30, ride + 0.14),
            (-0.55, 0.97, 0.38, belt + 0.12),
            (-0.15, 0.94, 0.44, belt + 0.26),
            (0.35, 0.92, 0.42, belt + 0.25),
            (0.85, 0.9, 0.38, belt + 0.12),
            (1.45, 0.93, 0.34, ride + 0.06),
            (1.85, 0.92, 0.30, ride + 0.02),
            (self.tail, 0.8, 0.26, ride - 0.02),
        ]

    def build(self):
        self.hull()
        self.glass_regions()
        self.cut_arches()
        self.trim()

    def hull(self):
        bm = self.bm
        st = self.stations
        tube(bm, [Vector((0, c, z)) for z, w, h, c in st],
             [(w * self.W / 2, h) for z, w, h, c in st], "paint", segs=18, cap_s=True, cap_e=True)
        # side skirts
        for sx in (-1, 1):
            box(bm, Vector((sx * (self.W / 2 - 0.04), 0.24, 0.0)), (0.05, 0.09, self.L * 0.4), "plastic")
        # wheel flares
        for wz in self.wheel_z:
            for sx in (-1, 1):
                self.flare(Vector((sx * self.wheel_x, 0.25, wz)))

    def flare(self, c):
        bm = self.bm
        pts = []
        for i in range(13):
            ang = -math.pi * 0.15 + (math.pi * 1.3) * i / 12
            pts.append(Vector((c.x, 0.25 + math.sin(ang) * (self.wr + 0.07), c.z + math.cos(ang) * (self.wr + 0.07))))
        tube(bm, pts, [(0.045, 0.05)] * len(pts), "paint", segs=8, cap_s=True, cap_e=True)

    def glass_regions(self):
        """Retag hull faces to glass by region: windshield, side windows, rear
        glass. Paint bands between them become the pillars and roof."""
        bm = self.bm
        belt, roof = self.belt, self.roof
        cz0 = self.stations[2][0]      # cowl
        cz1 = self.stations[-3][0]      # rear glass end
        hw = self.W / 2
        for f in list(bm.faces):
            if f.material_index != ZI["paint"]:
                continue
            c = f.calc_center_median()
            n = f.normal
            if c.y < belt + 0.04:
                continue
            # windshield: front-top region
            if cz0 + 0.05 < c.z < cz0 + 0.75 and c.y > belt + 0.10 and n.z < -0.2 and abs(c.x) < hw * 0.88:
                f.material_index = ZI["glass"]
                continue
            # rear glass / hatch back: rear-top
            if c.z > cz1 - 0.55 and c.y > belt + 0.10 and n.z > 0.25 and abs(c.x) < hw * 0.85:
                f.material_index = ZI["glass"]
                continue
            # side windows: cabin sides above belt
            if abs(c.x) > hw * 0.72 and abs(n.x) > 0.55 and c.z > cz0 + 0.15 and c.z < cz1 - 0.12 and c.y > belt + 0.08:
                f.material_index = ZI["glass"]
                continue
        # beltline trim strips
        bm2 = self.bm
        for sx in (-1, 1):
            box(bm2, Vector((sx * (self.W / 2 + 0.002), belt - 0.02, (cz0 + cz1) / 2)), (0.014, 0.03, (cz1 - cz0) * 0.9), "chrome")

    def cut_arches(self):
        bm = self.bm
        for wz in self.wheel_z:
            for f in list(bm.faces):
                c = f.calc_center_median()
                if abs(c.x) < self.W / 2 - 0.3:
                    continue
                if c.y > self.wr * 2 + 0.05:
                    continue
                dy = c.y - 0.25
                dz = c.z - wz
                if math.sqrt(dy * dy + dz * dz) < self.wr + 0.06:
                    bm.faces.remove(f)

    def trim(self):
        bm = self.bm
        s = self.s
        ride, belt = self.ride, self.belt
        # headlights
        for sx in (-1, 1):
            ellipsoid(bm, Vector((sx * (self.W / 2 - 0.24), ride + 0.13, self.nose + 0.05)), 0.12, "light",
                      scale=(1.2, 0.5, 0.85), segs_u=12, segs_v=8)
            box(bm, Vector((sx * (self.W / 2 - 0.28), ride + 0.14, self.tail - 0.015)), (0.3, 0.07, 0.035), "taillight")
        # grille
        box(bm, Vector((0, ride + 0.10, self.nose - 0.005)), (0.55, 0.15, 0.05), "plastic")
        for k in range(3):
            box(bm, Vector((0, ride + 0.05 + k * 0.045, self.nose - 0.02)), (0.5, 0.016, 0.02), "chrome")
        ellipsoid(bm, Vector((0, ride + 0.22, self.nose - 0.005)), 0.035, "chrome", scale=(1, 0.7, 0.6), segs_u=8, segs_v=6)
        # bumpers
        box(bm, Vector((0, ride - 0.1, self.nose + 0.05)), (self.W * 0.92, 0.15, 0.3), "plastic")
        box(bm, Vector((0, ride - 0.1, self.tail - 0.05)), (self.W * 0.92, 0.16, 0.28), "plastic")
        # plates flush with bumpers
        box(bm, Vector((0, ride - 0.11, self.nose - 0.14)), (0.4, 0.11, 0.012), "plate")
        box(bm, Vector((0, ride - 0.11, self.tail + 0.12)), (0.4, 0.11, 0.012), "plate")
        # mirrors on the beltline at the A-pillar
        for sx in (-1, 1):
            m = Vector((sx * (self.W / 2 + 0.03), belt + 0.04, self.stations[2][0] + 0.3))
            tube(bm, [Vector((sx * (self.W / 2 - 0.02), belt + 0.02, self.stations[2][0] + 0.33)), m],
                 [(0.014, 0.014)] * 2, "plastic", segs=6)
            box(bm, m + Vector((sx * 0.045, 0.0, 0)), (0.085, 0.055, 0.12), "paint2")
        # door handles
        for sx in (-1, 1):
            for hz in (self.stations[2][0] + 0.6, self.stations[2][0] + 1.25):
                box(bm, Vector((sx * (self.W / 2 - 0.004), belt - 0.09, hz)), (0.022, 0.028, 0.15), "chrome")
        # exhaust
        tube(bm, [Vector((-0.45, ride - 0.16, self.tail - 0.06)), Vector((-0.45, ride - 0.16, self.tail + 0.01))],
             [(0.042, 0.042)] * 2, "chrome", segs=10, cap_e=True)
        self.interior()
        if s.get("sign"):
            box(bm, Vector((0, self.roof + 0.05, 0.1)), (0.56, 0.035, 0.24), "plastic")
            box(bm, Vector((0, self.roof + 0.115, 0.1)), (0.5, 0.1, 0.19), "light")
        if s.get("lightbar"):
            box(bm, Vector((-0.22, self.roof + 0.09, 0.1)), (0.4, 0.08, 0.15), "taillight")
            box(bm, Vector((0.22, self.roof + 0.09, 0.1)), (0.4, 0.08, 0.15), "blue")
            box(bm, Vector((0, self.roof + 0.045, 0.1)), (0.9, 0.035, 0.2), "plastic")

    def interior(self):
        bm = self.bm
        belt = self.belt
        cz0 = self.stations[2][0]
        cz1 = self.stations[-3][0]
        # dashboard
        box(bm, Vector((0, belt + 0.05, cz0 + 0.3)), (self.W * 0.75, 0.13, 0.3), "interior")
        # steering wheel (visible through windshield)
        tube(bm, [Vector((-0.35, belt + 0.02, cz0 + 0.5)), Vector((-0.35, belt + 0.1, cz0 + 0.42))],
             [(0.025, 0.025)] * 2, "interior", segs=8)
        pts = []
        for i in range(14):
            ang = 2 * math.pi * i / 14
            center = Vector((-0.35, belt + 0.12, cz0 + 0.38))
            pts.append(center + Vector((math.cos(ang) * 0.13, math.sin(ang) * 0.13, 0)))
        tube(bm, pts, [(0.018, 0.018)] * len(pts), "interior", segs=6)
        # seats
        for sx in (-1, 1):
            sc = Vector((sx * 0.4, belt - 0.04, cz0 + 0.85))
            tube(bm, [sc + Vector((0, 0, -0.18)), sc, sc + Vector((0, 0.02, 0.05))],
                 [(0.22, 0.22), (0.22, 0.22), (0.2, 0.2)], "interior", segs=12, cap_s=True, cap_e=True)
            tube(bm, [sc + Vector((0, 0.12, 0.05)), sc + Vector((0, 0.4, 0.08))],
                 [(0.2, 0.2), (0.19, 0.19)], "interior", segs=12, cap_e=True)
        bench = Vector((0, belt - 0.04, cz1 - 0.32))
        tube(bm, [bench + Vector((0, 0, -0.2)), bench, bench + Vector((0, 0, 0.05))],
             [(0.7, 0.22), (0.7, 0.22), (0.68, 0.2)], "interior", segs=14, cap_s=True, cap_e=True)
        tube(bm, [bench + Vector((0, 0.1, 0.05)), bench + Vector((0, 0.38, 0.1))],
             [(0.68, 0.2), (0.66, 0.18)], "interior", segs=14, cap_e=True)

def wheel_mesh(mats):
    bm = bmesh.new()
    pts = []
    R = 0.245
    for i in range(18):
        ang = 2 * math.pi * i / 18
        pts.append(Vector((0, math.sin(ang) * R, math.cos(ang) * R)))
    tube(bm, pts, [(0.088, 0.092)] * len(pts), "tyre", segs=10)
    tube(bm, [Vector((-0.05, 0, 0)), Vector((0.05, 0, 0))], [(0.165, 0.165), (0.165, 0.165)],
         "chrome", segs=14, cap_s=True, cap_e=True)
    for k in range(5):
        ang = 2 * math.pi * k / 5
        sp = Vector((0, math.sin(ang), math.cos(ang)))
        mid = sp * 0.08
        tube(bm, [mid - sp * 0.14, mid + sp * 0.14], [(0.026, 0.026)] * 2, "chrome", segs=6)
    ellipsoid(bm, Vector((0.055, 0, 0)), 0.05, "plastic", scale=(0.45, 1, 1), segs_u=10, segs_v=8)
    return bm

def make_mats(spec):
    paint_c = tuple(spec.get("paint", (0.25, 0.27, 0.3)))
    paint2_c = tuple(spec.get("paint2", paint_c))
    glass_c = tuple(spec.get("glass", (0.05, 0.08, 0.11)))
    return [
        mat_textured("M_Paint", "metal", paint_c, metallic=0.7),
        mat_textured("M_Paint2", "metal", paint2_c, metallic=0.7),
        mat_plain("M_Glass", glass_c, rough=0.05, metallic=0.15),
        mat_textured("M_Chrome", "metal", (0.9, 0.9, 0.95), metallic=0.95),
        mat_textured("M_Tyre", "leather", (0.5, 0.5, 0.53), rough=0.95),
        mat_plain("M_Light", (1.0, 0.96, 0.88), rough=0.4, emission=(1.0, 0.95, 0.85), energy=4.0),
        mat_plain("M_Tail", (0.9, 0.1, 0.06), rough=0.4, emission=(1.0, 0.1, 0.05), energy=2.5),
        mat_textured("M_Plastic", "concrete", (0.42, 0.42, 0.44), rough=0.85),
        mat_textured("M_Interior", "fabric_cotton", (0.5, 0.5, 0.55), rough=0.9),
        mat_plain("M_Plate", (0.92, 0.92, 0.9), rough=0.5),
        mat_plain("M_Blue", (0.25, 0.45, 1.0), rough=0.4, emission=(0.25, 0.45, 1.0), energy=4.0),
    ]

def _purge_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me, do_unlink=True)

def build_car(spec):
    _purge_scene()
    _img_cache.clear()
    cb = CarBuilder(spec)
    cb.build()
    _axis_flip(cb.bm)
    mats = make_mats(spec)
    mesh = bpy.data.meshes.new("Body")
    cb.bm.to_mesh(mesh)
    for m in mats:
        mesh.materials.append(m)
    body = bpy.data.objects.new("Body", mesh)
    bpy.context.scene.collection.objects.link(body)
    smooth_mesh(mesh)
    for wz, fn in [(-1.4, "F"), (1.5, "R")]:
        for sx, sd in [(-1, "L"), (1, "R")]:
            wbm = wheel_mesh(mats)
            wm = bpy.data.meshes.new("W")
            wbm.to_mesh(wm)
            for m in mats:
                wm.materials.append(m)
            wobj = bpy.data.objects.new("Wheel%s%s" % (fn, sd), wm)
            wobj.location = Vector((sx * 0.85, -wz, 0.25))
            smooth_mesh(wm)
            bpy.context.scene.collection.objects.link(wobj)
    # (wheel geometry is symmetric about its axle; no rotation needed)
    out = os.path.join(OUT, "%s.glb" % spec["id"])
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=False,
                              export_apply=False, export_materials='EXPORT')
    print("VEHICLE BUILT:", spec["id"], "verts:", len(mesh.vertices), "->", out)

# ---------------------------------------------------------------- motorcycle
def build_moto(spec):
    _purge_scene()
    _img_cache.clear()
    mats = make_mats(spec)
    bm = bmesh.new()
    ride = 0.6
    # frame tubes
    frame_paths = [
        [Vector((-0.12, 0.55, -0.75)), Vector((-0.1, 0.7, -0.35)), Vector((-0.08, 0.72, 0.1))],
        [Vector((-0.12, 0.55, -0.75)), Vector((0.0, 0.42, -0.55)), Vector((0.05, 0.5, 0.15))],
        [Vector((-0.08, 0.72, 0.1)), Vector((-0.06, 0.62, 0.55)), Vector((-0.06, 0.55, 0.7))],
        [Vector((0.05, 0.5, 0.15)), Vector((-0.02, 0.5, 0.62)), Vector((-0.06, 0.55, 0.7))],
    ]
    for fp in frame_paths:
        tube(bm, fp, [(0.035, 0.035)] * len(fp), "chrome", segs=8)
    # engine block
    box(bm, Vector((0.02, 0.48, -0.15)), (0.3, 0.3, 0.5), "plastic")
    # tank
    tube(bm, [Vector((0, 0.72, -0.35)), Vector((0, 0.78, -0.15)), Vector((0, 0.76, 0.02))],
         [(0.16, 0.1), (0.15, 0.12), (0.13, 0.08)], "paint", segs=14, cap_s=True, cap_e=True)
    # seat
    tube(bm, [Vector((0, 0.62, 0.12)), Vector((0, 0.6, 0.42)), Vector((0, 0.63, 0.68))],
         [(0.13, 0.05), (0.12, 0.04), (0.1, 0.05)], "interior", segs=12, cap_s=True, cap_e=True)
    # tail cowl
    tube(bm, [Vector((0, 0.68, 0.55)), Vector((0, 0.78, 0.78))],
         [(0.1, 0.07), (0.05, 0.04)], "paint", segs=10, cap_e=True)
    # forks
    for sx in (-1, 1):
        tube(bm, [Vector((sx * 0.09, 0.62, -0.72)), Vector((sx * 0.09, 0.42, -0.9)), Vector((sx * 0.09, 0.33, -0.95))],
             [(0.025, 0.025)] * 3, "chrome", segs=8)
    # handlebars
    tube(bm, [Vector((-0.28, 0.86, -0.62)), Vector((-0.12, 0.9, -0.58)), Vector((0.12, 0.9, -0.58)), Vector((0.28, 0.86, -0.62))],
         [(0.02, 0.02)] * 4, "chrome", segs=8, cap_s=True, cap_e=True)
    for sx in (-1, 1):
        tube(bm, [Vector((sx * 0.26, 0.86, -0.62)), Vector((sx * 0.34, 0.85, -0.62))],
             [(0.032, 0.032)] * 2, "plastic", segs=8, cap_e=True)
    # headlight
    ellipsoid(bm, Vector((0, 0.82, -0.72)), 0.07, "light", scale=(1, 1, 0.9), segs_u=12, segs_v=8)
    # taillight
    box(bm, Vector((0, 0.75, 0.8)), (0.07, 0.05, 0.02), "taillight")
    # exhaust
    tube(bm, [Vector((0.18, 0.45, -0.2)), Vector((0.2, 0.42, 0.15)), Vector((0.18, 0.48, 0.55))],
         [(0.045, 0.045)] * 3, "chrome", segs=10, cap_e=True)
    # fenders
    for fz, arc_r in [(-0.95, 0.42), (0.85, 0.4)]:
        pts = []
        for i in range(9):
            ang = math.pi * 0.7 - (math.pi * 1.4) * i / 8
            pts.append(Vector((0, 0.34 + math.sin(ang) * arc_r * 0.9, fz + math.cos(ang) * 0.3 * (1 if fz < 0 else -1) + (fz * 0))))
        tube(bm, pts, [(0.05, 0.06)] * len(pts), "paint", segs=8, cap_s=True, cap_e=True)
    _axis_flip(bm)
    mesh = bpy.data.meshes.new("Body")
    bm.to_mesh(mesh)
    for m in mats:
        mesh.materials.append(m)
    body = bpy.data.objects.new("Body", mesh)
    bpy.context.scene.collection.objects.link(body)
    smooth_mesh(mesh)
    # wheels (thinner)
    for wz, nm in [(-0.95, "WheelF"), (0.85, "WheelR")]:
        wbm = bmesh.new()
        pts = []
        R = 0.3
        for i in range(18):
            ang = 2 * math.pi * i / 18
            pts.append(Vector((0, math.sin(ang) * R, math.cos(ang) * R)))
        tube(wbm, pts, [(0.055, 0.06)] * len(pts), "tyre", segs=8)
        tube(wbm, [Vector((-0.03, 0, 0)), Vector((0.03, 0, 0))], [(0.13, 0.13), (0.13, 0.13)],
             "chrome", segs=12, cap_s=True, cap_e=True)
        wm = bpy.data.meshes.new("W")
        wbm.to_mesh(wm)
        for m in mats:
            wm.materials.append(m)
        wobj = bpy.data.objects.new(nm, wm)
        wobj.location = Vector((0, -wz, 0.31))
        smooth_mesh(wm)
        bpy.context.scene.collection.objects.link(wobj)
    out = os.path.join(OUT, "%s.glb" % spec["id"])
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=False,
                              export_apply=False, export_materials='EXPORT')
    print("MOTO BUILT:", spec["id"], "->", out)

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
        if spec.get("type", "car") == "moto":
            build_moto(spec)
        else:
            build_car(spec)
    print("DONE")
