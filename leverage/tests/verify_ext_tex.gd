extends SceneTree
## verify_ext_tex.gd — confirm GLB-with-external-image-URI imports keep textures.
func _init() -> void:
	var ps: PackedScene = load("res://assets/characters/char_ava.glb")
	if ps == null:
		print("VERIFY FAIL: load failed")
		quit(1)
		return
	var node: Node = ps.instantiate()
	var mesh: MeshInstance3D = _find_mesh(node)
	if mesh == null:
		print("VERIFY FAIL: no mesh")
		quit(1)
		return
	var m: Mesh = mesh.mesh
	var textured := 0
	var plain := 0
	var names: Array = []
	for i in range(m.get_surface_count()):
		var mat: Material = m.surface_get_material(i)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			if sm.albedo_texture != null:
				textured += 1
				names.append("tex:%s" % sm.albedo_texture.resource_path)
			else:
				plain += 1
				names.append("color:%s" % str(sm.albedo_color))
		else:
			names.append("other:%s" % str(mat))
	print("VERIFY surfaces=%d textured=%d plain=%d" % [m.get_surface_count(), textured, plain])
	for n in names:
		print("SURF=", n)
	quit(0)

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null
