#!/usr/bin/env python3
"""Probe FBX character files: bones, animations, meshes. Run inside Blender headless."""
import bpy
import sys
import json

path = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=path)

out = {"file": path, "armatures": [], "actions": [], "meshes": []}
for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        bones = [b.name for b in obj.data.bones]
        out["armatures"].append({"name": obj.name, "bone_count": len(bones), "bones": bones[:60]})
    elif obj.type == 'MESH':
        out["meshes"].append(obj.name)

out["actions"] = [a.name for a in bpy.data.actions]
print("PROBE_JSON:" + json.dumps(out, indent=1)[:6000])
