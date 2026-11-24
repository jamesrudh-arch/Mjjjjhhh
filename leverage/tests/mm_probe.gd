extends Node
## Debug probe: city multimesh census after the v2.5 building swap.

func _ready() -> void:
        await get_tree().process_frame
        await get_tree().process_frame
        var world: Variant = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
        get_tree().root.add_child(world)
        await get_tree().create_timer(3.0).timeout
        var city: Node = world.city
        var counts := {}
        var total := 0
        for c in city.get_children():
                if c is MultiMeshInstance3D:
                        total += 1
                        var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
                        var n := mm.instance_count if mm else -1
                        var surf := mm.mesh.get_surface_count() if mm and mm.mesh else 0
                        var key := "mm_%d_inst_%d_surf_%d" % [total, n, surf]
                        counts[key] = true
                        print("[MM] #%d instances=%d surfaces=%d tris=%s" % [
                                total, n, surf,
                                str(mm.mesh.surface_get_arrays(0).size() if mm and mm.mesh and surf > 0 else "n/a")])
        print("[MM] TOTAL multimeshes: ", total)
        print("[MM] buildings placed: ", city._buildings.size())
        print("[MM] night materials: ", world._night_materials.size())
        # load one building directly
        var b: Variant = load("res://assets/buildings/b_brick2.gltf")
        print("[MM] b_brick2 loads: ", b != null)
        if b != null:
                var inst: Node3D = (b as PackedScene).instantiate()
                get_tree().root.add_child(inst)
                var mmi := _find(inst)
                if mmi != null:
                        print("[MM] b_brick2 mesh surfaces: ", mmi.mesh.get_surface_count())
                        for si in mmi.mesh.get_surface_count():
                                var mat := mmi.mesh.surface_get_material(si)
                                print("[MM]   surface %d mat=%s emission=%s" % [si, mat.get_class(), str(mat.emission_enabled if mat is StandardMaterial3D else "?")])
                inst.queue_free()
        get_tree().quit(0)


func _find(node: Node) -> MeshInstance3D:
        if node is MeshInstance3D:
                return node
        for c in node.get_children():
                var r := _find(c)
                if r != null:
                        return r
        return null
