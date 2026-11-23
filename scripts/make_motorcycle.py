"""make_motorcycle.py - author the LEVERAGE motorcycle GLB via Blender headless.

Original in-project asset (no third-party licence needed). Low-poly,
mobile-friendly: cubes/cylinders, 4 materials (matte black, amber paint,
chrome, emissives). Forward axis = -Z (matches other vehicle GLBs).
Run: tools/blender-4.5.9-linux-x64/blender -b --python make_motorcycle.py
"""
import bpy
import math

OUT = "/home/z/my-project/leverage/assets/vehicles/motorcycle.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.6, metal=0.0, emit=None, emit_energy=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit_energy
    return m


MATTE = mat("MatteBlack", (0.05, 0.05, 0.06), rough=0.85)
AMBER = mat("AmberPaint", (0.94, 0.64, 0.24), rough=0.35, metal=0.35)
CHROME = mat("Chrome", (0.75, 0.77, 0.8), rough=0.22, metal=1.0)
TIRE = mat("Tire", (0.02, 0.02, 0.025), rough=0.95)
LAMP = mat("HeadLamp", (1.0, 1.0, 0.9), emit=(1.0, 0.95, 0.8), emit_energy=4.0)
TAIL = mat("TailLamp", (0.4, 0.02, 0.02), emit=(1.0, 0.1, 0.1), emit_energy=2.5)


def cube(name, size, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(material)
    return o


def cylinder(name, r, depth, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth,
                                        location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


# --- chassis (forward = -Z) ---
cube("FrameMain", (0.13, 0.16, 1.30), (0, 0.58, 0.05), MATTE)
cube("Engine", (0.30, 0.30, 0.48), (0, 0.40, -0.05), MATTE)
cube("Tank", (0.24, 0.16, 0.46), (0, 0.84, -0.38), AMBER)
cube("Seat", (0.26, 0.07, 0.52), (0, 0.80, 0.28), MATTE)
cube("RearFender", (0.20, 0.05, 0.30), (0, 0.66, 0.72), AMBER)
cube("HeadlightCowl", (0.18, 0.10, 0.22), (0, 0.76, -0.86), AMBER)

# fork + handlebar
fork_tilt = (math.radians(26.0), 0, 0)
for x in (-0.09, 0.09):
    cylinder("ForkL" if x < 0 else "ForkR", 0.028, 0.72,
             (x, 0.62, -0.62), CHROME, rot=fork_tilt)
cylinder("Handlebar", 0.024, 0.56, (0, 1.00, -0.66), MATTE,
         rot=(0, 0, math.radians(90)))
cube("MirrorL", (0.07, 0.04, 0.02), (-0.28, 1.06, -0.66), AMBER)
cube("MirrorR", (0.07, 0.04, 0.02), (0.28, 1.06, -0.66), AMBER)

# lights
cylinder("Headlamp", 0.075, 0.09, (0, 0.70, -0.97), LAMP)
cube("Taillamp", (0.12, 0.05, 0.04), (0, 0.74, 0.86), TAIL)

# exhaust
cylinder("Exhaust", 0.045, 0.62, (0.17, 0.34, 0.30), CHROME,
         rot=(math.radians(90), 0, 0))

# wheels (axis along X)
wheel_rot = (0, 0, math.radians(90))
cylinder("WheelFront", 0.34, 0.11, (0, 0.34, -0.78), TIRE, rot=wheel_rot)
cylinder("WheelRear", 0.34, 0.13, (0, 0.34, 0.78), TIRE, rot=wheel_rot)
cylinder("HubFront", 0.09, 0.14, (0, 0.34, -0.78), CHROME, rot=wheel_rot)
cylinder("HubRear", 0.09, 0.16, (0, 0.34, 0.78), CHROME, rot=wheel_rot)

bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB",
                         export_yup=True, export_materials="EXPORT",
                         export_animations=False)
print("WROTE", OUT)
