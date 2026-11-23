class_name CharacterFactory
extends RefCounted
## CharacterFactory - builds humanoid actors from the UAL mannequin GLB.
## Single shared rig + animation set (TDL #3/#12); visual identity comes from
## material tinting + procedural accessories. All CC0 (see asset_register.md).

const MANNEQUIN := "res://assets/characters/ual_mannequin.glb"

## Palette for tinting (top = body material, bottom = joints material)
const SKIN_TONES := [
        Color("e8c39e"), Color("c99169"), Color("9c6b4a"), Color("6e4a33"), Color("f0d8c0"),
]
const TOP_COLORS := [
        Color("8a4a3a"), Color("3a5a7a"), Color("5a7a4a"), Color("7a6a3a"), Color("6a4a6a"),
        Color("4a4a52"), Color("2a2d34"), Color("b8b8a0"), Color("d84fa0"), Color("f0a33c"),
]
const BOT_COLORS := [
        Color("2a2d34"), Color("3a3a40"), Color("5a5248"), Color("26282e"), Color("44464e"),
]


static func make_actor(top_color: Color, bot_color: Color, skin: Color, scale_factor := 1.0) -> Node3D:
        var packed: PackedScene = load(MANNEQUIN)
        if packed == null:
                push_error("CharacterFactory: mannequin missing")
                return Node3D.new()
        var inst: Node3D = packed.instantiate()
        inst.scale = Vector3.ONE * scale_factor
        _tint(inst, top_color, bot_color, skin)
        return inst


static func _tint(inst: Node3D, top_color: Color, bot_color: Color, skin: Color) -> void:
        var mi: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
        if mi == null or mi.mesh == null:
                return
        # surface 0: M_Main body, surface 1: M_Joints
        var body := StandardMaterial3D.new()
        body.albedo_color = top_color
        body.roughness = 0.85
        var joints := StandardMaterial3D.new()
        joints.albedo_color = bot_color
        joints.roughness = 0.9
        mi.set_surface_override_material(0, body)
        mi.set_surface_override_material(1, joints)
        inst.set_meta("skin_tone", skin)


## Accessories attach to bones on the skeleton via BoneAttachment3D.
static func attach_accessory(actor: Node3D, kind: String, color: Color) -> Node3D:
        var sk: Skeleton3D = _find_type(actor, "Skeleton3D") as Skeleton3D
        if sk == null:
                return null
        var bone_name := "DEF-head"
        var mesh: Mesh = null
        var offset := Vector3.ZERO
        match kind:
                "cap":
                        mesh = _box(0.26, 0.10, 0.30)
                        offset = Vector3(0, 0.09, 0.04)
                "fedora":
                        var brim := _box(0.34, 0.02, 0.34)
                        var crown := _box(0.22, 0.14, 0.22)
                        mesh = _combine(brim, crown, Vector3(0, 0.08, 0))
                        offset = Vector3(0, 0.10, 0)
                "flatcap":
                        mesh = _box(0.28, 0.08, 0.28)
                        offset = Vector3(0, 0.08, 0)
                "hoodie":
                        mesh = _box(0.30, 0.24, 0.26)
                        offset = Vector3(0, 0.06, -0.02)
                "ponytail":
                        mesh = _box(0.08, 0.30, 0.08)
                        offset = Vector3(0, 0.05, -0.12)
                "bun":
                        mesh = _box(0.12, 0.10, 0.12)
                        offset = Vector3(0, 0.11, -0.06)
                "holster":
                        bone_name = "DEF-thigh.R"
                        mesh = _box(0.10, 0.16, 0.06)
                        offset = Vector3(0.09, -0.05, 0)
                _:
                        return null
        if mesh == null:
                return null
        var att := BoneAttachment3D.new()
        att.bone_name = bone_name
        att.name = "BoneAtt_" + kind
        sk.add_child(att)
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.roughness = 0.8
        mi.set_material_override(mat)
        mi.position = offset
        att.add_child(mi)
        return mi


## Attach a held item (weapon) to the right hand.
static func attach_to_hand(actor: Node3D, mesh: Mesh, offset := Vector3(0.04, 0.02, 0.05)) -> Node3D:
        var sk: Skeleton3D = _find_type(actor, "Skeleton3D") as Skeleton3D
        if sk == null:
                return null
        var att := BoneAttachment3D.new()
        att.bone_name = "DEF-hand.R"
        sk.add_child(att)
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        mi.position = offset
        att.add_child(mi)
        return mi


static func hand_mesh_from_glb(glb_path: String, scale_factor: float, rot := Vector3.ZERO) -> MeshInstance3D:
        var packed: PackedScene = load(glb_path)
        var mi := MeshInstance3D.new()
        if packed != null:
                var inst: Node3D = packed.instantiate()
                var src: MeshInstance3D = _find_type(inst, "MeshInstance3D") as MeshInstance3D
                if src and src.mesh:
                        mi.mesh = src.mesh
        mi.scale = Vector3.ONE * scale_factor
        mi.rotation_degrees = rot
        return mi


static func _box(w: float, h: float, d: float) -> BoxMesh:
        var m := BoxMesh.new()
        m.size = Vector3(w, h, d)
        return m


static func _combine(a: Mesh, b: Mesh, offset: Vector3) -> ArrayMesh:
        var out := ArrayMesh.new()
        for m in [a, b]:
                var arrays: Array = m.surface_get_arrays(0)
                if m == b:
                        var verts: PackedVector3Array = arrays[ArrayMesh.ARRAY_VERTEX]
                        var moved: PackedVector3Array = PackedVector3Array()
                        moved.resize(verts.size())
                        for i in verts.size():
                                moved[i] = offset + verts[i]
                        arrays[ArrayMesh.ARRAY_VERTEX] = moved
                out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        return out


static func _find_type(node: Node, type: String) -> Node:
        if node.get_class() == type:
                return node
        for c in node.get_children():
                var r := _find_type(c, type)
                if r:
                        return r
        return null


## Random tinted actor for pedestrians.
static func make_random_ped(rng: RandomNumberGenerator) -> Node3D:
        var top: Color = TOP_COLORS[rng.randi_range(0, TOP_COLORS.size() - 1)]
        var bot: Color = BOT_COLORS[rng.randi_range(0, BOT_COLORS.size() - 1)]
        var skin: Color = SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)]
        var s := rng.randf_range(0.95, 1.05)
        return make_actor(top, bot, skin, s)


## Named-cast actor: tint/accessories by NPCDirector.CAST entry.
static func make_named(npc_id: String) -> Node3D:
        var tint: Color = NPCDirector.cast_meta(npc_id, "tint", Color("6a6a6a"))
        var bot := Color("2a2d34")
        var skin := Color("e8c39e")
        var actor := make_actor(tint, bot, skin)
        var hair: String = String(NPCDirector.cast_meta(npc_id, "hair", ""))
        var hat: String = String(NPCDirector.cast_meta(npc_id, "hat", ""))
        if hair != "":
                attach_accessory(actor, hair, Color("3a2a1a"))
        if hat != "":
                attach_accessory(actor, hat, Color("2a2d34"))
        var body := String(NPCDirector.cast_meta(npc_id, "body", ""))
        if body == "suit":
                attach_accessory(actor, "flatcap", tint.darkened(0.3))
        if body == "police":
                attach_accessory(actor, "cap", Color("3b6fd6"))
        return actor


## Player actor (Dez): amber-jacket signature look.
static func make_player() -> Node3D:
        var actor := make_actor(Color("c8761f"), Color("23252c"), Color("e8c39e"))
        attach_accessory(actor, "holster", Color("1d1f24"))
        return actor
