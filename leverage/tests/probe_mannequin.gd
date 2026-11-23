extends SceneTree
## Probe UAL mannequin import: node tree, animation names, materials.
## Run: godot --headless -s tests/probe_mannequin.gd

func _init() -> void:
        var path := "res://assets/characters/ual_mannequin.glb"
        var packed: PackedScene = load(path)
        if packed == null:
                print("PROBE FAIL: cannot load scene")
                quit(1)
                return
        var inst := packed.instantiate()
        var ap: AnimationPlayer = _find(inst, "AnimationPlayer") as AnimationPlayer
        var sk: Skeleton3D = _find_type(inst, "Skeleton3D") as Skeleton3D
        var mesh: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
        print("ROOT: ", inst.name)
        if ap:
                var anims: Array = ap.get_animation_list()
                print("ANIM_LIBS: ", ap.get_animation_library_list())
                print("ANIM_COUNT: ", anims.size())
                print("ANIMS: ", ", ".join(anims.map(func(a): return str(a))))
        else:
                print("NO ANIMATION PLAYER")
        if sk:
                print("BONES: ", sk.get_bone_count())
        if mesh:
                print("MESH surfaces: ", mesh.mesh.get_surface_count())
                for i in mesh.mesh.get_surface_count():
                        var mat = mesh.get_active_material(i)
                        if mat:
                                var std := mat as StandardMaterial3D
                                var albedo := "-"
                                if std:
                                        albedo = str(std.albedo_color)
                                print("MAT ", i, ": ", mat.resource_name, " ", mat.get_class(), " albedo=", albedo)
        print("PROBE OK")
        quit(0)


func _find(node: Node, name: String) -> Node:
        if node.name == name:
                return node
        for c in node.get_children():
                var r := _find(c, name)
                if r:
                        return r
        return null


func _find_type(node: Node, type: String) -> Node:
        if node.get_class() == type:
                return node
        for c in node.get_children():
                var r := _find_type(c, type)
                if r:
                        return r
        return null
