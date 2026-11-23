import bpy, json, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="/home/z/my-project/leverage/assets/characters/ual_mannequin.glb")
arm = None
for o in bpy.data.objects:
    if o.type == 'ARMATURE':
        arm = o; break
print("ARMATURE:", arm.name, "scale:", tuple(arm.scale))
bones = {}
for pb in arm.pose.bones:
    world = arm.matrix_world @ pb.head
    wt = arm.matrix_world @ pb.tail
    bones[pb.name] = {"head": [round(v,4) for v in world], "tail": [round(v,4) for v in wt], "parent": pb.parent.name if pb.parent else None}
out = json.dumps(bones, indent=0)
open("/tmp/rig_dump.json", "w").write(out)
print("BONES:", len(bones))
# also mesh + material info
for o in bpy.data.objects:
    if o.type == 'MESH':
        print("MESH:", o.name, "verts:", len(o.data.vertices), "materials:", [m.name for m in o.data.materials])
# animation actions
for a in bpy.data.actions:
    pass
print("ACTIONS:", len(bpy.data.actions))
