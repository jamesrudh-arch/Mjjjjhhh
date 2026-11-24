extends Node
func _ready() -> void:
        await get_tree().process_frame
        var b: Variant = load("res://assets/buildings/b_brick2.gltf")
        var inst: Node3D = (b as PackedScene).instantiate()
        get_tree().root.add_child(inst)
        var mmi := _find(inst)
        for si in mmi.mesh.get_surface_count():
                var mat: StandardMaterial3D = mmi.mesh.surface_get_material(si) as StandardMaterial3D
                if mat:
                        var tex = mat.albedo_texture
                        print("[TEX] surf %d mat=%s albedo_tex=%s emiss=%s" % [si, mat.resource_name.left(20), tex.resource_path if tex else "NONE", mat.emission_enabled])
        get_tree().quit()

func _find(node: Node) -> MeshInstance3D:
        if node is MeshInstance3D: return node
        for c in node.get_children():
                var r = _find(c)
                if r: return r
        return null
