extends SceneTree
## list_anims.gd — print all animation names on the mannequin.
func _init() -> void:
	var ps: PackedScene = load("res://assets/characters/ual_mannequin.glb")
	if ps == null:
		print("LOAD FAILED")
		quit(1)
		return
	var node: Node = ps.instantiate()
	var anim: AnimationPlayer = _find(node)
	if anim == null:
		print("NO ANIMATIONPLAYER")
	else:
		var list: PackedStringArray = anim.get_animation_list()
		print("ANIMCOUNT=", list.size())
		for n in list:
			print("ANIM=", n)
	quit(0)

func _find(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find(c)
		if r != null:
			return r
	return null
