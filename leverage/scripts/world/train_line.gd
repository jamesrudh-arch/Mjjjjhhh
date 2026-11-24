class_name TrainLine
extends Node3D
## TrainLine - the Cinder Line: an elevated rail viaduct across the north of
## Cinder City (z = -340) with two passenger platforms, arches over the river
## and roads, and a scheduled train (loco + 4 cars, lit windows, horn, rumble)
## that runs east/west and dwells at both stations.

const Z := -340.0
const X_MIN := -470.0
const X_MAX := 470.0
const DECK_TOP := 7.0
const COLUMN_SKIP_X := [-390.0, -260.0, -140.0, 10.0, 140.0, 260.0, 380.0]   # road crossings
const STATION_X := [-300.0, 300.0]
const SPEED := 15.0
const DWELL := 7.0
const HEADWAY := 95.0          # seconds between departures

var _train: Node3D
var _cars: Array = []
var _dir := 1.0
var _x := X_MIN
var _state := "idle"           # idle | run | dwell
var _t := 3.0                  # time to next departure
var _dwell_t := 0.0
var _next_stop := 0            # index into STATION_X
var _horned := {}
var _rumble: AudioStreamPlayer3D
var _window_mats: Array = []
var _sign_mats: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
        _rng.seed = 34034
        _build_viaduct()
        _build_stations()
        _build_train()


# ---------------------------------------------------------------- viaduct
func _build_viaduct() -> void:
        var g := Node3D.new()
        g.name = "Viaduct"
        var concrete := StandardMaterial3D.new()
        concrete.albedo_color = Color(0.58, 0.56, 0.52)
        concrete.roughness = 0.95
        # deck beam
        var deck := MeshInstance3D.new()
        var dm := BoxMesh.new()
        dm.size = Vector3(X_MAX - X_MIN, 1.3, 6.2)
        deck.mesh = dm
        deck.set_surface_override_material(0, concrete)
        deck.position = Vector3((X_MIN + X_MAX) / 2.0, DECK_TOP - 0.65, Z)
        g.add_child(deck)
        # rails
        var rail_mat := StandardMaterial3D.new()
        rail_mat.albedo_color = Color(0.35, 0.36, 0.38)
        rail_mat.metallic = 0.7
        rail_mat.roughness = 0.4
        for side in [-1.55, 1.55]:
                var rail := MeshInstance3D.new()
                var rm := BoxMesh.new()
                rm.size = Vector3(X_MAX - X_MIN, 0.16, 0.14)
                rail.mesh = rm
                rail.set_surface_override_material(0, rail_mat)
                rail.position = Vector3((X_MIN + X_MAX) / 2.0, DECK_TOP + 0.08, Z + side)
                g.add_child(rail)
        # ties (multimesh)
        _spawn_ties(g)
        # columns
        var body := StaticBody3D.new()
        body.name = "ViaductColumns"
        var x := X_MIN + 12.0
        while x < X_MAX - 12.0:
                if not _near_crossing(x) and not _over_river(x):
                        var col := MeshInstance3D.new()
                        var cm := BoxMesh.new()
                        cm.size = Vector3(2.0, DECK_TOP - 1.3, 2.6)
                        col.mesh = cm
                        col.set_surface_override_material(0, concrete)
                        col.position = Vector3(x, (DECK_TOP - 1.3) / 2.0, Z)
                        g.add_child(col)
                        var cs := CollisionShape3D.new()
                        var box := BoxShape3D.new()
                        box.size = Vector3(2.2, DECK_TOP, 2.8)
                        cs.shape = box
                        cs.position = Vector3(x, DECK_TOP / 2.0 - 0.65, Z)
                        body.add_child(cs)
                x += 24.0
        g.add_child(body)
        # river arch: deeper beam + two struts over the water
        var arch := MeshInstance3D.new()
        var am := BoxMesh.new()
        am.size = Vector3(52.0, 2.8, 7.0)
        arch.mesh = am
        arch.set_surface_override_material(0, concrete)
        arch.position = Vector3(CinderRiver.CENTER_X, DECK_TOP - 1.4, Z)
        g.add_child(arch)
        for side in [-1.0, 1.0]:
                var strut := MeshInstance3D.new()
                var sm := BoxMesh.new()
                sm.size = Vector3(1.8, DECK_TOP - 1.3, 2.4)
                strut.mesh = sm
                strut.set_surface_override_material(0, concrete)
                strut.position = Vector3(CinderRiver.CENTER_X + side * 22.0, (DECK_TOP - 1.3) / 2.0, Z)
                g.add_child(strut)
        add_child(g)


func _near_crossing(x: float) -> bool:
        for cx in COLUMN_SKIP_X:
                if absf(x - cx) < 13.0:
                        return true
        return false


func _over_river(x: float) -> bool:
        return absf(x - CinderRiver.CENTER_X) < 24.0


func _spawn_ties(parent: Node3D) -> void:
        var tie := MeshInstance3D.new()
        var tm := BoxMesh.new()
        tm.size = Vector3(0.18, 0.1, 3.6)
        tie.mesh = tm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.30, 0.24, 0.18)
        tie.set_surface_override_material(0, mat)
        var count := int((X_MAX - X_MIN) / 2.4)
        var mm := MultiMeshInstance3D.new()
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = tm
        multimesh.instance_count = count
        for i in count:
                multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(X_MIN + i * 2.4, DECK_TOP + 0.02, Z)))
        mm.multimesh = multimesh
        mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(mm)
        tie.queue_free()


# ---------------------------------------------------------------- stations
func _build_stations() -> void:
        for sx in STATION_X:
                var st := Node3D.new()
                st.name = "Station_%d" % int(sx)
                var concrete := StandardMaterial3D.new()
                concrete.albedo_color = Color(0.62, 0.60, 0.56)
                concrete.roughness = 0.95
                # platform slab (north side of track)
                var slab := MeshInstance3D.new()
                var sm := BoxMesh.new()
                sm.size = Vector3(26.0, 0.5, 5.0)
                slab.mesh = sm
                slab.set_surface_override_material(0, concrete)
                slab.position = Vector3(sx, DECK_TOP + 0.25, Z + 4.4)
                st.add_child(slab)
                # canopy on two columns
                var roof := MeshInstance3D.new()
                var rm := BoxMesh.new()
                rm.size = Vector3(24.0, 0.4, 4.6)
                roof.mesh = rm
                roof.set_surface_override_material(0, concrete)
                roof.position = Vector3(sx, DECK_TOP + 3.3, Z + 4.4)
                st.add_child(roof)
                for cx in [-9.0, 9.0]:
                        var col := MeshInstance3D.new()
                        var cm := CylinderMesh.new()
                        cm.top_radius = 0.14
                        cm.bottom_radius = 0.16
                        cm.height = 2.6
                        col.mesh = cm
                        col.set_surface_override_material(0, concrete)
                        col.position = Vector3(sx + cx, DECK_TOP + 1.75, Z + 4.4)
                        st.add_child(col)
                # stairs down to street level (decorative ramp + steps)
                var stair := MeshInstance3D.new()
                var qm := BoxMesh.new()
                qm.size = Vector3(3.2, 0.5, 9.5)
                stair.mesh = qm
                stair.set_surface_override_material(0, concrete)
                stair.rotation.x = -atan((DECK_TOP - 0.5) / 9.0)
                stair.position = Vector3(sx + 14.0, DECK_TOP / 2.0 + 0.2, Z + 11.0)
                st.add_child(stair)
                # lit sign
                var sign := MeshInstance3D.new()
                var gm := BoxMesh.new()
                gm.size = Vector3(5.0, 0.8, 0.15)
                sign.mesh = gm
                var s_mat := StandardMaterial3D.new()
                s_mat.albedo_color = Color(0.95, 0.75, 0.25)
                s_mat.emission_enabled = true
                s_mat.emission = Color(1.0, 0.78, 0.3)
                s_mat.emission_energy_multiplier = 0.5
                sign.set_surface_override_material(0, s_mat)
                sign.position = Vector3(sx, DECK_TOP + 2.6, Z + 6.6)
                st.add_child(sign)
                _sign_mats.append(s_mat)
                # platform lamps
                for lx in [-8.0, 8.0]:
                        var lamp := _make_deck_lamp()
                        lamp.position = Vector3(sx + lx, DECK_TOP + 0.5, Z + 6.0)
                        st.add_child(lamp)
                add_child(st)


func _make_deck_lamp() -> Node3D:
        var lamp := Node3D.new()
        var pole := MeshInstance3D.new()
        var pm := CylinderMesh.new()
        pm.top_radius = 0.05
        pm.bottom_radius = 0.07
        pm.height = 2.6
        pole.mesh = pm
        var metal := StandardMaterial3D.new()
        metal.albedo_color = Color(0.2, 0.2, 0.22)
        pole.set_surface_override_material(0, metal)
        pole.position.y = 1.3
        lamp.add_child(pole)
        var head := MeshInstance3D.new()
        var hm := BoxMesh.new()
        hm.size = Vector3(0.5, 0.14, 0.3)
        head.mesh = hm
        var h_mat := StandardMaterial3D.new()
        h_mat.albedo_color = Color(1, 0.9, 0.7)
        h_mat.emission_enabled = true
        h_mat.emission = Color(1.0, 0.88, 0.6)
        h_mat.emission_energy_multiplier = 0.8
        head.set_surface_override_material(0, h_mat)
        head.position.y = 2.6
        lamp.add_child(head)
        _sign_mats.append(h_mat)
        return lamp


# ---------------------------------------------------------------- train
func _build_train() -> void:
        _train = Node3D.new()
        _train.name = "Train"
        var car_len := 9.2
        var gap := 0.8
        for i in 5:
                var car := _make_car(i == 0)
                car.position.x = -i * (car_len + gap)
                _train.add_child(car)
                _cars.append(car)
        _train.position = Vector3(_x, DECK_TOP + 0.15, Z)
        add_child(_train)
        _attach_rumble()


func _make_car(is_loco: bool) -> Node3D:
        var car := Node3D.new()
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(9.2, 2.6, 3.0)
        body.mesh = bm
        var mat := StandardMaterial3D.new()
        if is_loco:
                mat.albedo_color = Color(0.72, 0.20, 0.14)
        else:
                mat.albedo_color = Color(0.78, 0.79, 0.80) if (randi() % 2 == 0) else Color(0.30, 0.34, 0.42)
        mat.metallic = 0.35
        mat.roughness = 0.45
        body.set_surface_override_material(0, mat)
        body.position.y = 1.5
        car.add_child(body)
        # window strip (both sides) - emission for night glow
        for side in [-1.0, 1.0]:
                var strip := MeshInstance3D.new()
                var sm := BoxMesh.new()
                sm.size = Vector3(7.6, 0.8, 0.06)
                strip.mesh = sm
                var w_mat := StandardMaterial3D.new()
                w_mat.albedo_color = Color(0.9, 0.85, 0.65)
                w_mat.emission_enabled = true
                w_mat.emission = Color(1.0, 0.9, 0.62)
                w_mat.emission_energy_multiplier = 0.35
                strip.set_surface_override_material(0, w_mat)
                strip.position = Vector3(0, 1.85, side * 1.53)
                car.add_child(strip)
                _window_mats.append(w_mat)
        if is_loco:
                # nose + headlight
                var nose := MeshInstance3D.new()
                var nm := BoxMesh.new()
                nm.size = Vector3(0.9, 1.9, 2.6)
                nose.mesh = nm
                nose.set_surface_override_material(0, mat)
                nose.position = Vector3(4.9, 1.15, 0)
                car.add_child(nose)
                var head := OmniLight3D.new()
                head.light_color = Color(1.0, 0.95, 0.8)
                head.light_energy = 2.2
                head.omni_range = 26.0
                head.position = Vector3(5.4, 1.6, 0)
                car.add_child(head)
        return car


func _attach_rumble() -> void:
        var path := "res://assets/audio/sfx/sfx_train_rumble.ogg"
        if not ResourceLoader.exists(path):
                return
        var stream: AudioStream = load(path)
        if stream is AudioStreamOggVorbis:
                (stream as AudioStreamOggVorbis).loop = true
        _rumble = AudioStreamPlayer3D.new()
        _rumble.stream = stream
        _rumble.bus = "SFX"
        _rumble.max_distance = 150.0
        _rumble.unit_size = 10.0
        _rumble.volume_db = -6.0
        _train.add_child(_rumble)
        _rumble.play()


# ---------------------------------------------------------------- schedule
func _process(delta: float) -> void:
        match _state:
                "idle":
                        _t -= delta
                        if _t <= 0.0:
                                _depart()
                "run":
                        var step := SPEED * _dir * delta
                        _x += step
                        _train.position.x = _x
                        # face travel direction
                        _train.rotation.y = PI if _dir < 0 else 0.0
                        if _rumble:
                                _rumble.playing = true
                        # horn near stations and the river arch (once per pass)
                        for sx in STATION_X:
                                var key := "st_%d_%d" % [int(sx), int(_dir)]
                                if not _horned.has(key) and absf(_x - sx) < 46.0:
                                        _horned[key] = true
                                        EventBus.sfx_requested.emit("sfx_train_horn", _train.global_position + Vector3(0, 1, 0))
                        var rk := "river_%d" % int(_dir)
                        if not _horned.has(rk) and absf(_x - CinderRiver.CENTER_X) < 50.0:
                                _horned[rk] = true
                                EventBus.sfx_requested.emit("sfx_train_horn", _train.global_position + Vector3(0, 1, 0))
                        # station dwell
                        var target: float = STATION_X[_next_stop]
                        if (_dir > 0.0 and _x >= target) or (_dir < 0.0 and _x <= target):
                                _x = target
                                _train.position.x = _x
                                _state = "dwell"
                                _dwell_t = DWELL
                                EventBus.sfx_requested.emit("sfx_station_bell", _train.global_position)
                                if _rumble:
                                        _rumble.playing = false
                        # end of line
                        elif (_dir > 0.0 and _x >= X_MAX) or (_dir < 0.0 and _x <= X_MIN):
                                _arrive_end()
                "dwell":
                        _dwell_t -= delta
                        if _dwell_t <= 0.0:
                                _next_stop += 1
                                if _next_stop >= STATION_X.size():
                                        _arrive_end()
                                else:
                                        _state = "run"


func _depart() -> void:
        _state = "run"
        _horned.clear()
        EventBus.sfx_requested.emit("sfx_train_horn", _train.global_position + Vector3(0, 1, 0))


func _arrive_end() -> void:
        _state = "idle"
        _t = HEADWAY
        if _rumble:
                _rumble.playing = false
        # flip direction, reset stop plan, teleport to the new origin
        _dir *= -1.0
        _next_stop = 0 if _dir > 0.0 else STATION_X.size() - 1
        if _dir > 0.0:
                _x = X_MIN
                _next_stop = 0
        else:
                _x = X_MAX
                _next_stop = STATION_X.size() - 1
        _train.position.x = _x
        _train.rotation.y = PI if _dir < 0 else 0.0


# ---------------------------------------------------------------- night ramp
func set_night_glow(night_f: float) -> void:
        for m in _window_mats:
                (m as StandardMaterial3D).emission_energy_multiplier = lerp(0.35, 1.6, night_f)
        for m in _sign_mats:
                (m as StandardMaterial3D).emission_energy_multiplier = lerp(0.5, 1.6, night_f)


# ---------------------------------------------------------------- test API
func car_count() -> int:
        return _cars.size()


func station_count() -> int:
        return STATION_X.size()


func is_running() -> bool:
        return _state == "run"


func train_x() -> float:
        return _x


func force_depart() -> void:
        ## Test/hook API: guarantee the train leaves now (breaks idle or dwell).
        match _state:
                "idle":
                        _t = 0.01
                "dwell":
                        _dwell_t = 0.01
                "run":
                        pass
