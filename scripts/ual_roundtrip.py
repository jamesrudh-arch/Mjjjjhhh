#!/usr/bin/env python3
"""Roundtrip UAL glTF through Blender -> GLB to normalize it for Godot."""
import bpy

SRC = "/home/z/my-project/tools/assets_raw/gltf-universal-animation-library-main/glTF/AnimationLibrary_Godot_Standard.gltf"
DST = "/home/z/my-project/leverage/assets/characters/ual_mannequin.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
print("UALEDIT imported objects:", len(bpy.data.objects))
print("UALEDIT actions:", len(bpy.data.actions))
print("UALEDIT meshes:", [m.name for m in bpy.data.meshes])
print("UALEDIT materials:", [m.name for m in bpy.data.materials])
armatures = [o for o in bpy.data.objects if o.type == 'ARMATURE']
print("UALEDIT armatures:", [(a.name, len(a.data.bones)) for a in armatures])
# animations imported as actions assigned to armature objects via animation data
for a in armatures:
    ad = a.animation_data
    if ad:
        print("UALEDIT anim_data on", a.name, "action:", ad.action.name if ad.action else None)
        print("UALEDIT nla tracks:", len(ad.nla_tracks))
        for t in ad.nla_tracks:
            print("UALEDIT track:", t.name, "strips:", len(t.strips), [s.name for s in t.strips])

bpy.ops.export_scene.gltf(
    filepath=DST,
    export_format='GLB',
    export_yup=True,
    export_apply=False,
    export_materials='EXPORT',
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_extras=False,
    export_cameras=False,
    export_lights=False,
    export_force_sampling=True,
    export_optimize_animation_size=False,
)
print("UALEDIT exported ->", DST)
