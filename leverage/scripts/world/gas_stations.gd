class_name GasStations
extends Node3D
## GasStations - two Cinder City filling stations (Docklands depot + East
## Strip). Concrete apron, steel canopy on columns with an illuminated fascia,
## pump islands whose pumps are EXPLOSIVE (shoot them - chain reaction), a
## price totem and a glass kiosk. The pumps listen for damage from the weapon
## raycast via EventBus.explosive_damaged.

const STATIONS := [
        {"pos": Vector2(-180, 150), "rot": 0.0, "name": "DEZ DEPOT"},            # Docklands
        {"pos": Vector2(350, 60), "rot": PI / 2.0, "name": "EAST STRIP FUEL"},   # Kestrel edge
]

var _pumps: Array = []
var _fascia_mats: Array = []


func _ready() -> void:
        for st in STATIONS:
                _build_station(st)
        EventBus.explosive_damaged.connect(_on_explosive_damaged)


func _on_explosive_damaged(node: Node, damage: float, source: Node3D) -> void:
        if not (node is Node3D) or not is_instance_valid(node):
                return
        var hp := float(node.get_meta("explosive_hp", 40.0)) - damage
        EventBus.sfx_requested.emit("sfx_bullet_impact", (node as Node3D).global_position)
        CombatFeel.spawn_impact((node as Node3D).global_position + Vector3(0, 0.8, 0), 1.1, Vector3.UP)
        if hp <= 0.0 and not node.has_meta("exploded"):
                node.set_meta("exploded", true)
                var pos: Vector3 = (node as Node3D).global_position
                # pump body: hide, scorch mark stays
                for c in (node as Node3D).get_children():
                        if c is MeshInstance3D or c is CollisionShape3D:
                                (c as Node).queue_free()
                Explosions.boom(pos + Vector3(0, 0.6, 0), 8.0, 70.0, source)
                EventBus.notification_posted.emit("Gas pump detonated", "crime")
        else:
                node.set_meta("explosive_hp", hp)


# ---------------------------------------------------------------- build
func _build_station(def: Dictionary) -> void:
        var root := Node3D.new()
        root.name = "GasStation_" + String(def["name"]).replace(" ", "_")
        var c: Vector2 = def["pos"]
        var rot: float = def["rot"]
        var fwd := Vector2(cos(rot), sin(rot))
        var right := Vector2(-fwd.y, fwd.x)

        # --- concrete apron ---
        var apron := MeshInstance3D.new()
        var am := BoxMesh.new()
        am.size = Vector3(30, 0.14, 22)
        apron.mesh = am
        var ap_mat := StandardMaterial3D.new()
        ap_mat.albedo_color = Color(0.52, 0.52, 0.50)
        ap_mat.roughness = 0.95
        apron.set_surface_override_material(0, ap_mat)
        apron.position = Vector3(c.x, 0.07, c.y)
        apron.rotation.y = -rot
        root.add_child(apron)

        # --- canopy: 4 columns + roof + illuminated fascia ---
        var steel := StandardMaterial3D.new()
        steel.albedo_color = Color(0.82, 0.84, 0.86)
        steel.metallic = 0.6
        steel.roughness = 0.35
        for sx in [-1.0, 1.0]:
                for sz in [-1.0, 1.0]:
                        var col := MeshInstance3D.new()
                        var cm := CylinderMesh.new()
                        cm.top_radius = 0.22
                        cm.bottom_radius = 0.26
                        cm.height = 5.2
                        col.mesh = cm
                        col.set_surface_override_material(0, steel)
                        col.position = Vector3(c.x + right.x * sx * 7.4 + fwd.x * sz * 4.6, 2.6,
                                c.y + right.y * sx * 7.4 + fwd.y * sz * 4.6)
                        root.add_child(col)
        var roof := MeshInstance3D.new()
        var rm := BoxMesh.new()
        rm.size = Vector3(19, 0.55, 12)
        roof.mesh = rm
        roof.set_surface_override_material(0, steel)
        roof.position = Vector3(c.x, 5.45, c.y)
        roof.rotation.y = -rot
        root.add_child(roof)
        # fascia band with emission (glows at night)
        for side in [-1.0, 1.0]:
                var band := MeshInstance3D.new()
                var bm := BoxMesh.new()
                bm.size = Vector3(19, 1.15, 0.3)
                band.mesh = bm
                var band_mat := StandardMaterial3D.new()
                band_mat.albedo_color = Color(0.9, 0.35, 0.1)
                band_mat.emission_enabled = true
                band_mat.emission = Color(1.0, 0.45, 0.12)
                band_mat.emission_energy_multiplier = 0.4
                band.set_surface_override_material(0, band_mat)
                band.position = Vector3(c.x + right.x * side * 5.9, 5.15, c.y + right.y * side * 5.9)
                band.rotation.y = -rot
                root.add_child(band)
                _fascia_mats.append(band_mat)

        # --- pump islands (2 islands, 2 pumps each) ---
        var body := StaticBody3D.new()
        body.name = "PumpBodies"
        for ix in [-1.0, 1.0]:
                # island plinth
                var plinth := MeshInstance3D.new()
                var pm := BoxMesh.new()
                pm.size = Vector3(1.9, 0.28, 7.0)
                plinth.mesh = pm
                plinth.set_surface_override_material(0, ap_mat)
                plinth.position = Vector3(c.x + right.x * ix * 3.2, 0.28, c.y + right.y * ix * 3.2)
                plinth.rotation.y = -rot
                root.add_child(plinth)
                for pz in [-1.7, 1.7]:
                        var pump := _make_pump(String(def["name"]))
                        var off: Vector2 = fwd * float(pz) + right * float(ix) * 3.2
                        pump.position = Vector3(c.x + off.x, 0.4, c.y + off.y)
                        pump.rotation.y = -rot
                        root.add_child(pump)
                        _pumps.append(pump)
                        # collision so bullets/melee can hit it
                        var cs := CollisionShape3D.new()
                        var box := BoxShape3D.new()
                        box.size = Vector3(0.9, 1.6, 0.7)
                        cs.shape = box
                        cs.position = pump.position + Vector3(0, 0.8, 0)
                        cs.rotation = pump.rotation
                        body.add_child(cs)
        root.add_child(body)

        # --- price totem ---
        var totem := MeshInstance3D.new()
        var tm := BoxMesh.new()
        tm.size = Vector3(1.5, 4.2, 0.4)
        totem.mesh = tm
        var t_mat := StandardMaterial3D.new()
        t_mat.albedo_color = Color(0.15, 0.15, 0.16)
        totem.set_surface_override_material(0, t_mat)
        totem.position = Vector3(c.x + right.x * 12.0, 2.1, c.y + right.y * 12.0)
        totem.rotation.y = -rot
        root.add_child(totem)
        var panel := MeshInstance3D.new()
        var pmm := BoxMesh.new()
        pmm.size = Vector3(1.35, 2.6, 0.1)
        panel.mesh = pmm
        var p_mat := StandardMaterial3D.new()
        p_mat.albedo_color = Color(0.95, 0.55, 0.12)
        p_mat.emission_enabled = true
        p_mat.emission = Color(1.0, 0.6, 0.15)
        p_mat.emission_energy_multiplier = 0.5
        panel.set_surface_override_material(0, p_mat)
        panel.position = totem.position + Vector3(right.x * 0.26, 0.1, right.y * 0.26)
        panel.rotation.y = -rot
        root.add_child(panel)
        _fascia_mats.append(p_mat)

        # --- glass kiosk ---
        var kiosk := MeshInstance3D.new()
        var km := BoxMesh.new()
        km.size = Vector3(7.5, 3.4, 5.0)
        kiosk.mesh = km
        var k_mat := StandardMaterial3D.new()
        k_mat.albedo_color = Color(0.32, 0.34, 0.38)
        kiosk.set_surface_override_material(0, k_mat)
        kiosk.position = Vector3(c.x - fwd.x * 7.0, 1.7, c.y - fwd.y * 7.0)
        kiosk.rotation.y = -rot
        root.add_child(kiosk)
        var glass := MeshInstance3D.new()
        var gm := BoxMesh.new()
        gm.size = Vector3(6.4, 1.9, 0.12)
        glass.mesh = gm
        var g_mat := StandardMaterial3D.new()
        g_mat.albedo_color = Color(0.9, 0.85, 0.6)
        g_mat.emission_enabled = true
        g_mat.emission = Color(1.0, 0.9, 0.62)
        g_mat.emission_energy_multiplier = 0.35
        glass.set_surface_override_material(0, g_mat)
        glass.position = kiosk.position + Vector3(fwd.x * 2.6, 0.15, fwd.y * 2.6)
        glass.rotation.y = -rot
        root.add_child(glass)
        _fascia_mats.append(g_mat)

        add_child(root)


func _make_pump(station_name: String) -> Node3D:
        var pump := Node3D.new()
        pump.add_to_group("explosive")
        pump.set_meta("explosive_hp", 40.0)
        pump.set_meta("station", station_name)
        var shell := MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(0.8, 1.5, 0.6)
        shell.mesh = sm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.88, 0.16, 0.12)
        mat.roughness = 0.5
        shell.set_surface_override_material(0, mat)
        shell.position.y = 0.75
        pump.add_child(shell)
        var screen := MeshInstance3D.new()
        var scm := BoxMesh.new()
        scm.size = Vector3(0.5, 0.35, 0.05)
        screen.mesh = scm
        var s_mat := StandardMaterial3D.new()
        s_mat.albedo_color = Color(0.35, 0.95, 0.75)
        s_mat.emission_enabled = true
        s_mat.emission = Color(0.4, 1.0, 0.8)
        s_mat.emission_energy_multiplier = 1.4
        screen.set_surface_override_material(0, s_mat)
        screen.position = Vector3(0, 1.15, 0.32)
        pump.add_child(screen)
        var _fascia := screen   # kept for future night ramp
        return pump


# ---------------------------------------------------------------- night ramp
func set_night_glow(night_f: float) -> void:
        # called by world day-night update: fascia/totem/glass glow at night
        for m in _fascia_mats:
                if m is StandardMaterial3D:
                        (m as StandardMaterial3D).emission_energy_multiplier = lerp(0.35, 1.5, night_f)


# ---------------------------------------------------------------- test API
func pump_count() -> int:
        return _pumps.size()


func station_count() -> int:
        return STATIONS.size()


func intact_pumps() -> int:
        var n := 0
        for p in _pumps:
                if is_instance_valid(p) and not p.has_meta("exploded"):
                        n += 1
        return n


func damage_pump(node: Node, damage: float, source: Node3D = null) -> void:
        _on_explosive_damaged(node, damage, source)
