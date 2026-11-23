#!/usr/bin/env python3
"""LEVERAGE street props generator (Blender 4.5, background).
Trees (trunk+canopy), streetlights, traffic lights, hydrant, bin, bench,
bus stop, billboard, dumpster, barrier. Output: assets/props/*.glb."""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix

TEX = "/home/z/my-project/leverage/assets/textures"
OUT = "/home/z/my-project/leverage/assets/props"
ZONES = ["bark", "leaf", "metal", "light", "red", "plastic", "glass", "green"]
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

def mat_textured(name, base, color, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    ns = mat.node_tree
    nodes, links = ns.nodes, ns.links
    bsdf = nodes["Principled BSDF"]
    alb = _tex(os.path.join(TEX, base + "_albedo.png"), srgb=True)
    if alb:
        n = nodes.new('ShaderNodeTexImage'); n.image = alb
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
        n = nodes.new('ShaderNodeTexImage'); n.image = rgh
        links.new(n.outputs['Color'], bsdf.inputs['Roughness'])
    nrm = _tex(os.path.join(TEX, base + "_normal.png"))
    if nrm:
        n = nodes.new('ShaderNodeTexImage'); n.image = nrm
        nm = nodes.new('ShaderNodeNormalMap')
        links.new(n.outputs['Color'], nm.inputs['Color'])
        links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    if metallic:
        bsdf.inputs['Metallic'].default_value = metallic
    return mat

def mat_plain(name, color, rough=0.7, metallic=0.0, emission=None, energy=3.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = rough
    if metallic:
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

def tube(bm, path, radii, zone, segs=10, cap_s=False, cap_e=False):
    uvl = bm.loops.layers.uv.verify()
    rings = []
    n = len(path)
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
        for s in range(segs):
            t = 2 * math.pi * s / segs
            ring.append(bm.verts.new(path[i] + x * math.cos(t) * rx + y * math.sin(t) * ry))
        rings.append(ring)
    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segs):
            s2 = (s + 1) % segs
            try:
                f = bm.faces.new((r0[s], r0[s2], r1[s2], r1[s]))
                f.smooth = True
                f.material_index = ZI[zone]
                for loop in f.loops:
                    loop[uvl].uv = (s / segs * 2.0, i / max(1, n - 1) * 3.0)
            except ValueError:
                pass
    for cap, rr in [(cap_s, rings[0]), (cap_e, rings[-1])]:
        if cap:
            c = bm.verts.new((sum((v.co for v in rr), Vector())) / len(rr))
            for s in range(len(rr)):
                s2 = (s + 1) % len(rr)
                try:
                    f = bm.faces.new((c, rr[s], rr[s2]) if cap == cap_s else (c, rr[s2], rr[s]))
                    f.smooth = False
                    f.material_index = ZI[zone]
                    for loop in f.loops:
                        loop[uvl].uv = (0.5, 0.5)
                except ValueError:
                    pass
    return rings

def ellipsoid(bm, center, r, zone, scale=(1, 1, 1), segs_u=12, segs_v=8):
    uvl = bm.loops.layers.uv.verify()
    verts = {}
    for iu in range(segs_u):
        for iv in range(segs_v):
            u = 2 * math.pi * iu / segs_u
            v = math.pi * iv / (segs_v - 1)
            p = Vector((math.sin(v) * math.cos(u), math.sin(v) * math.sin(u), math.cos(v)))
            p = Vector((p.x * r * scale[0], p.y * r * scale[1], p.z * r * scale[2]))
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
                    loop[uvl].uv = (iu / segs_u * 3.0, iv / (segs_v - 1) * 3.0)
            except ValueError:
                pass

def box(bm, center, size, zone):
    x, y, z = size
    uvl = bm.loops.layers.uv.verify()
    idx = [(-1, -1, -1), (-1, -1, 1), (-1, 1, -1), (-1, 1, 1), (1, -1, -1), (1, -1, 1), (1, 1, -1), (1, 1, 1)]
    vs = []
    for (sx, sy, sz) in idx:
        vs.append(bm.verts.new(center + Vector((sx * x / 2, sy * y / 2, sz * z / 2))))
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

def _mats():
    return [
        mat_textured("M_Bark", "bark", (1.0, 1.0, 1.0)),
        mat_textured("M_Leaf", "leaf", (1.0, 1.0, 1.0)),
        mat_textured("M_Metal", "metal", (0.55, 0.55, 0.58), metallic=0.6),
        mat_plain("M_Light", (1.0, 0.92, 0.75), 0.4, emission=(1.0, 0.9, 0.7), energy=6.0),
        mat_plain("M_Red", (0.65, 0.1, 0.08), 0.5, emission=(0.9, 0.12, 0.1), energy=3.0),
        mat_plain("M_Plastic", (0.16, 0.16, 0.17), 0.85),
        mat_plain("M_Glass", (0.1, 0.13, 0.16), 0.08, metallic=0.1),
        mat_plain("M_Green", (0.1, 0.7, 0.12), 0.5, emission=(0.15, 0.9, 0.2), energy=2.5),
    ]

def _purge_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me, do_unlink=True)

def _export(name, bm):
    mats = _mats()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    for m in mats:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    out = os.path.join(OUT, "%s.glb" % name)
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=False,
                              export_apply=False, export_materials='EXPORT')
    print("PROP BUILT:", name, "->", out)

def build_tree(name, seed, height=7.0, canopy_r=2.6):
    _purge_scene()
    _img_cache.clear()
    import random
    rng = random.Random(seed)
    bm = bmesh.new()
    # trunk with slight lean + branches
    base = Vector((0, 0, 0))
    top = Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), height))
    mid = (base + top) / 2 + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0))
    tube(bm, [base, mid, top], [(0.16, 0.2), (0.11, 0.14), (0.07, 0.09)], "bark", segs=8, cap_e=True)
    for k in range(4):
        ang = rng.uniform(0, 2 * math.pi)
        h = rng.uniform(0.45, 0.7) * height
        start = Vector((0, 0, h))
        dir = Vector((math.cos(ang), math.sin(ang), rng.uniform(0.3, 0.7))).normalized()
        tube(bm, [start, start + dir * rng.uniform(1.2, 2.0)], [(0.05, 0.05), (0.025, 0.025)], "bark", segs=6, cap_e=True)
    # canopy clusters
    for k in range(5):
        c = top + Vector((rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2), rng.uniform(-0.8, 1.6)))
        r = canopy_r * rng.uniform(0.55, 0.9)
        ellipsoid(bm, c, r, "leaf", scale=(1.0, 1.0, rng.uniform(0.7, 0.95)), segs_u=12, segs_v=8)
    _export(name, bm)

def build_streetlight(name, double=False):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    tube(bm, [Vector((0, 0, 0)), Vector((0, 0, 4.6))], [(0.06, 0.08), (0.045, 0.05)], "metal", segs=8, cap_s=True)
    if double:
        for sx in (-1, 1):
            tube(bm, [Vector((0, 0, 4.6)), Vector((sx * 0.8, 0, 4.9)), Vector((sx * 1.5, 0, 4.75))],
                 [(0.04, 0.04)] * 3, "metal", segs=6)
            box(bm, Vector((sx * 1.5, 0, 4.6)), (0.5, 0.16, 0.12), "light")
    else:
        tube(bm, [Vector((0, 0, 4.6)), Vector((0.8, 0, 4.9)), Vector((1.5, 0, 4.75))],
             [(0.04, 0.04)] * 3, "metal", segs=6)
        box(bm, Vector((1.5, 0, 4.6)), (0.5, 0.16, 0.12), "light")
    _export(name, bm)

def build_trafficlight(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    tube(bm, [Vector((0, 0, 0)), Vector((0, 0, 4.2))], [(0.06, 0.08), (0.05, 0.05)], "metal", segs=8, cap_s=True)
    box(bm, Vector((0, 0, 4.6)), (0.26, 0.26, 0.8), "plastic")
    box(bm, Vector((0, -0.14, 4.85)), (0.14, 0.02, 0.14), "red")
    box(bm, Vector((0, -0.14, 4.6)), (0.14, 0.02, 0.14), "light")
    box(bm, Vector((0, -0.14, 4.35)), (0.14, 0.02, 0.14), "green")
    _export(name, bm)

def build_hydrant(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    tube(bm, [Vector((0, 0, 0)), Vector((0, 0, 0.65))], [(0.09, 0.09), (0.09, 0.09)], "red", segs=8, cap_s=True)
    ellipsoid(bm, Vector((0, 0, 0.72)), 0.1, "red", segs_u=8, segs_v=6)
    box(bm, Vector((0, 0, 0.4)), (0.34, 0.12, 0.1), "red")
    _export(name, bm)

def build_bin(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    tube(bm, [Vector((0, 0, 0)), Vector((0, 0, 0.9))], [(0.28, 0.28), (0.26, 0.26)], "plastic", segs=10, cap_s=True)
    tube(bm, [Vector((0, 0, 0.93)), Vector((0, 0, 0.97))], [(0.3, 0.3), (0.3, 0.3)], "plastic", segs=10, cap_e=True)
    _export(name, bm)

def build_bench(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    for k in range(3):
        box(bm, Vector((0, -0.25 + k * 0.16, 0.45)), (1.8, 0.13, 0.05), "bark")
    for k in range(2):
        box(bm, Vector((0, -0.28 + k * 0.2, 0.75)), (1.8, 0.12, 0.04), "bark")
    for sx in (-1, 1):
        box(bm, Vector((sx * 0.8, 0, 0.22)), (0.08, 0.4, 0.05), "metal")
        box(bm, Vector((sx * 0.8, 0.2, 0.55)), (0.06, 0.06, 0.5), "metal")
    _export(name, bm)

def build_busstop(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    for sx in (-1, 1):
        tube(bm, [Vector((sx * 1.4, 0, 0)), Vector((sx * 1.4, 0, 2.6))], [(0.06, 0.06)] * 2, "metal", segs=8, cap_s=True)
    box(bm, Vector((0, 0, 2.75)), (3.2, 1.2, 0.1), "plastic")
    box(bm, Vector((0, -0.55, 1.3)), (2.8, 0.05, 2.6), "glass")
    box(bm, Vector((0, 0, 0.45)), (2.6, 0.6, 0.1), "bark")
    _export(name, bm)

def build_billboard(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    for sx in (-1, 1):
        tube(bm, [Vector((sx * 2.0, 0, 0)), Vector((sx * 2.0, 0, 3.4))], [(0.09, 0.09)] * 2, "metal", segs=8, cap_s=True)
    box(bm, Vector((0, 0, 5.2)), (4.4, 0.3, 3.4), "plastic")
    box(bm, Vector((0, -0.18, 5.2)), (4.2, 0.04, 3.2), "light")
    _export(name, bm)

def build_dumpster(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    box(bm, Vector((0, 0, 0.65)), (2.0, 1.1, 1.3), "metal")
    box(bm, Vector((0, 0, 1.36)), (2.05, 1.15, 0.1), "plastic")
    box(bm, Vector((0, 0, 0.1)), (2.1, 1.2, 0.2), "plastic")
    _export(name, bm)

def build_barrier(name):
    _purge_scene()
    _img_cache.clear()
    bm = bmesh.new()
    box(bm, Vector((0, 0, 0.75)), (2.0, 0.08, 0.4), "red")
    for sx in (-1, 1):
        box(bm, Vector((sx * 0.85, 0, 0.38)), (0.08, 0.5, 0.08), "plastic")
        box(bm, Vector((sx * 0.85, 0, 0.02)), (0.5, 0.5, 0.04), "plastic")
    _export(name, bm)

if __name__ == "__main__":
    build_tree("tree_a", seed=11, height=7.5, canopy_r=2.8)
    build_tree("tree_b", seed=29, height=6.2, canopy_r=2.2)
    build_tree("tree_c", seed=47, height=8.6, canopy_r=3.1)
    build_streetlight("streetlight_v2")
    build_streetlight("streetlight_d2", double=True)
    build_trafficlight("trafficlight_v2")
    build_hydrant("hydrant")
    build_bin("bin")
    build_bench("bench")
    build_busstop("busstop")
    build_billboard("billboard")
    build_dumpster("dumpster")
    build_barrier("barrier")
    print("DONE")
