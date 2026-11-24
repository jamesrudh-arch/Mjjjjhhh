extends Node
func _ready() -> void:
        await get_tree().process_frame
        print("[EX] b_brick2.gltf exists: ", ResourceLoader.exists("res://assets/buildings/b_brick2.gltf"))
        print("[EX] tree_a.glb exists: ", ResourceLoader.exists("res://assets/props/tree_a.glb"))
        print("[EX] load b_brick2: ", load("res://assets/buildings/b_brick2.gltf") != null)
        get_tree().quit()
