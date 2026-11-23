class_name MapScreen
extends Control
## MapScreen - full-screen live city map: roads, districts, locations, mission
## markers, player tracker. Tap a location (or TRACK a mission) to set a GPS
## destination; an A* route through the road network is drawn and an HUD
## waypoint arrow guides the player. Zoom + pan + fog-of-war (visited areas).

const MAP_SIZE := 1600.0
const WORLD_SPAN := 1500.0
const ORIGIN := Vector2(-750.0, -750.0)

var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var _drag_last := Vector2.ZERO
var _selected := {}                      # {id, name, pos, kind}
var _route: Array = []                   # world-space route polyline
var _waypoint := Vector2.ZERO            # active GPS destination (world space)
var _has_waypoint := false
var _route_t := 0.0
var _map: Control
var _detail: VBoxContainer

static var _node_graph: Dictionary = {}     # built once: {pos: [neighbor pos...]}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	set_process(true)

func _build() -> void:
	add_child(LvgTheme.color_rect(Color(0, 0, 0, 0.55)))
	var sheet := LvgTheme.make_panel(LvgTheme.CHARCOAL, LvgTheme.LINE)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.custom_minimum_size = Vector2(MAP_SIZE + 160, MAP_SIZE + 260)
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	sheet.add_child(v)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	v.add_child(header)
	header.add_child(LvgTheme.make_display_label("CINDER CITY", 54, LvgTheme.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for z in [["+", 1.25], ["-", 0.8]]:
		var zb := LvgTheme.make_button(z[0])
		zb.pressed.connect(func(): _zoom = clampf(_zoom * z[1], 0.7, 3.0); _map.queue_redraw())
		header.add_child(zb)
	var clear := LvgTheme.make_button("CLEAR GPS")
	clear.pressed.connect(func(): _clear_route())
	header.add_child(clear)
	var close := LvgTheme.make_button("CLOSE")
	close.pressed.connect(func(): _close())
	header.add_child(close)
	var mid := HBoxContainer.new()
	v.add_child(mid)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_map.clip_contents = true
	_map.draw.connect(func(): _draw_map(_map))
	_map.gui_input.connect(func(ev): _on_map_input(ev))
	mid.add_child(_map)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(140, 0)
	_detail.add_theme_constant_override("separation", 10)
	mid.add_child(_detail)
	v.add_child(LvgTheme.make_label(
		"Tap a location to inspect it, SET ROUTE for GPS guidance. Amber = you; amber line = GPS route. Unvisited districts stay dim.", 22, LvgTheme.TEXT_DIM))

func _process(_delta: float) -> void:
	_route_t += _delta
	if _map != null:
		_map.queue_redraw()

# ---------------------------------------------------------------- transform
func _scale() -> float:
	return MAP_SIZE / WORLD_SPAN * _zoom

func _to_map(p: Vector2) -> Vector2:
	var s := _scale()
	return (p - ORIGIN - _pan / _zoom) * s + Vector2(MAP_SIZE, MAP_SIZE) / 2.0

func _to_world(p: Vector2) -> Vector2:
	var s := _scale()
	return (p - Vector2(MAP_SIZE, MAP_SIZE) / 2.0) / s + ORIGIN + _pan / _zoom

# ---------------------------------------------------------------- input
func _on_map_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_last = mb.position
				var picked := _pick_location(mb.position)
				if not picked.is_empty():
					_select(picked)
			else:
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = clampf(_zoom * 1.1, 0.7, 3.0)
			_map.queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = clampf(_zoom * 0.9, 0.7, 3.0)
			_map.queue_redraw()
	elif ev is InputEventMouseMotion and _dragging:
		var mm := ev as InputEventMouseMotion
		_pan += (mm.position - _drag_last) / _zoom
		_drag_last = mm.position
		_map.queue_redraw()

# ---------------------------------------------------------------- locations
func _locations() -> Array:
	var out: Array = []
	for k in ["pawn", "threads", "quickmart"]:
		out.append({"id": k, "name": _shop_name(k), "pos": _shop_pos(k), "kind": "shop"})
	for k in ["dez_apartment", "marisol_bar", "iron_gym", "lennox_clinic", "kestrel_lobby"]:
		out.append({"id": k, "name": _interior_name(k), "pos": _interior_pos(k), "kind": "interior"})
	out.append({"id": "bank", "name": "Kestrel Bank", "pos": Vector2(240, -60), "kind": "landmark"})
	out.append({"id": "hospital", "name": "Saint Verity Hospital", "pos": Vector2(-160, 20), "kind": "landmark"})
	out.append({"id": "villa", "name": "The Villa (Heights)", "pos": Vector2(150, -640), "kind": "landmark"})
	return out

func _shop_name(k: String) -> String:
	match k:
		"pawn": return "Pawn & Barrel"
		"threads": return "Threads & Sins"
		"quickmart": return "QuickMart"
	return k

func _interior_name(k: String) -> String:
	match k:
		"dez_apartment": return "Dez's Apartment (Safehouse)"
		"marisol_bar": return "Marisol's Bar"
		"iron_gym": return "Iron Gym (Train)"
		"lennox_clinic": return "Lennox Clinic (Heal)"
		"kestrel_lobby": return "Kestrel Tower Lobby"
	return k

func _shop_pos(k: String) -> Vector2:
	match k:
		"pawn": return Vector2(-260, -80)
		"threads": return Vector2(320, 200)
		"quickmart": return Vector2(-140, -60)
	return Vector2.ZERO

func _interior_pos(k: String) -> Vector2:
	match k:
		"dez_apartment": return Vector2(-280, -160)
		"marisol_bar": return Vector2(-240, -180)
		"iron_gym": return Vector2(-200, 560)
		"lennox_clinic": return Vector2(-120, 20)
		"kestrel_lobby": return Vector2(240, -200)
	return Vector2.ZERO

func _mission_target() -> Vector2:
	var obj := MissionSystem.current_objective()
	if not obj.is_empty() and obj.has("pos"):
		var p: Vector3 = obj["pos"]
		return Vector2(p.x, p.z)
	return Vector2.INF

func _pick_location(screen_p: Vector2) -> Dictionary:
	var wp := _to_world(screen_p)
	var best := {}
	var best_d := 42.0 / _zoom
	for loc in _locations():
		var d: float = (wp - (loc["pos"] as Vector2)).length()
		if d < best_d:
			best_d = d
			best = loc
	# mission marker is pickable too
	var mt := _mission_target()
	if mt != Vector2.INF and (wp - mt).length() < best_d:
		best = {"id": "mission", "name": String(MissionSystem.mission_def(MissionSystem.active_id).get("title", "Mission")), "pos": mt, "kind": "mission"}
	return best

func _select(loc: Dictionary) -> void:
	_selected = loc
	EventBus.sfx_requested.emit("sfx_ui_click", Vector3.ZERO)
	_refresh_detail()

func _refresh_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _selected.is_empty():
		_detail.add_child(LvgTheme.make_label("Nothing selected.", 24, LvgTheme.TEXT_DIM))
		return
	var loc := _selected
	_detail.add_child(LvgTheme.make_kicker(String(loc["kind"]).to_upper(), LvgTheme.ACCENT))
	_detail.add_child(LvgTheme.make_label(String(loc["name"]), 28, LvgTheme.TEXT, true))
	var area := CityDirector.area_at(loc["pos"] as Vector2)
	if area != "":
		_detail.add_child(LvgTheme.make_label("District: " + CityDirector.AREAS[area]["display"], 22, LvgTheme.TEXT_DIM))
	var route := LvgTheme.make_button("SET ROUTE (GPS)")
	route.pressed.connect(func(): _set_route_to(loc["pos"]))
	_detail.add_child(route)
	var clear_b := LvgTheme.make_button("CLEAR")
	clear_b.pressed.connect(func(): _selected = {}; _refresh_detail())
	_detail.add_child(clear_b)

# ---------------------------------------------------------------- routing
func _set_route_to(dest: Vector2) -> void:
	_waypoint = dest
	_has_waypoint = true
	GameState.gps_waypoint = dest
	GameState.has_gps = true
	var player := _player_pos()
	_route = _compute_route(player, dest)
	EventBus.notification_posted.emit("GPS route set - follow the amber line.", "gps")
	EventBus.sfx_requested.emit("sfx_ui_click", Vector3.ZERO)
	GameState.discovered_locations[_selected.get("id", "custom")] = true
	_map.queue_redraw()

func _clear_route() -> void:
	_route = []
	_has_waypoint = false
	GameState.has_gps = false
	_map.queue_redraw()

static func _ensure_graph() -> void:
	if not _node_graph.is_empty():
		return
	var roads: Array = CityDirector.ROADS
	# nodes: endpoints + intersections between roads
	var nodes: Array = []
	for r in roads:
		nodes.append(r["a"])
		nodes.append(r["b"])
	for i in roads.size():
		for j in range(i + 1, roads.size()):
			var p: Variant = _seg_cross(roads[i]["a"], roads[i]["b"], roads[j]["a"], roads[j]["b"])
			if p != Vector2.INF:
				nodes.append(p)
	# dedupe
	var uniq := {}
	for n in nodes:
		uniq[n] = true
	var node_list: Array = uniq.keys()
	# adjacency: same-road ordering
	var graph := {}
	for n in node_list:
		graph[n] = []
	for r in roads:
		var on_road: Array = []
		for n in node_list:
			if _on_segment(n, r["a"], r["b"]):
				on_road.append(n)
		on_road.sort_custom(func(a, b):
			return (a as Vector2).distance_to(r["a"]) < (b as Vector2).distance_to(r["a"]))
		for k in on_road.size() - 1:
			graph[on_road[k]].append(on_road[k + 1])
			graph[on_road[k + 1]].append(on_road[k])
	_node_graph = graph

static func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.001:
		return false
	var t: float = clamp((p - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).distance_to(p) < 0.5

static func _seg_cross(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> Variant:
	var d = Geometry2D.segment_intersects_segment(a1, a2, b1, b2)
	if d == null:
		return Vector2.INF
	return d

static func _nearest_node(p: Vector2) -> Vector2:
	_ensure_graph()
	var best := p
	var best_d := INF
	for n in _node_graph.keys():
		var d: float = (n as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = n
	return best

## A* over the road graph; returns world-space polyline start->dest.
static func _compute_route(from: Vector2, dest: Vector2) -> Array:
	_ensure_graph()
	if _node_graph.is_empty():
		return [from, dest]
	var start := _nearest_node(from)
	var goal := _nearest_node(dest)
	if start == goal:
		return [from, dest]
	var open: Array = [start]
	var g_score := {start: 0.0}
	var f_score := {start: (start as Vector2).distance_to(goal)}
	var came_from := {}
	while not open.is_empty():
		# lowest f
		var current: Vector2 = open[0]
		var best_f: float = f_score[current]
		for o in open:
			if float(f_score[o]) < best_f:
				best_f = f_score[o]
				current = o
		if current == goal:
			var path: Array = [current]
			var cur = current
			while came_from.has(cur):
				cur = came_from[cur]
				path.push_front(cur)
			path.push_front(from)
			path.append(dest)
			return path
		open.erase(current)
		for nb in _node_graph[current]:
			var tentative: float = g_score[current] + (current as Vector2).distance_to(nb)
			if not g_score.has(nb) or tentative < float(g_score[nb]):
				came_from[nb] = current
				g_score[nb] = tentative
				f_score[nb] = tentative + (nb as Vector2).distance_to(goal)
				if not open.has(nb):
					open.append(nb)
	return [from, dest]

func _player_pos() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		return Vector2(player.global_position.x, player.global_position.z)
	return Vector2.ZERO

# ---------------------------------------------------------------- draw
func _draw_map(map: Control) -> void:
	map.draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), LvgTheme.PANEL)
	map.draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), LvgTheme.LINE, false, 3.0)
	# districts (fog of war: unvisited dimmed)
	for area_id in CityDirector.AREAS.keys():
		var r: Rect2 = CityDirector.AREAS[area_id]["bounds"]
		var tl := _to_map(r.position)
		var sz := r.size * _scale()
		var col: Color = CityDirector.AREAS[area_id]["color"]
		var visited: bool = GameState.visited_areas.has(area_id)
		var a := 0.22 if visited else 0.09
		map.draw_rect(Rect2(tl, sz), Color(col.r, col.g, col.b, a))
		map.draw_rect(Rect2(tl, sz), Color(col.r, col.g, col.b, 0.7 if visited else 0.3), false, 2.0)
		var disp: String = CityDirector.AREAS[area_id]["display"]
		var short := disp.split(" ")[0].to_upper()
		var vis_a: float = 0.9 if visited else 0.4
		map.draw_string(LvgTheme.font_body, tl + sz / 2.0 - Vector2(60, 0), short,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(col.r, col.g, col.b, vis_a))
	# roads
	for road in CityDirector.ROADS:
		var a: Vector2 = _to_map(road["a"])
		var b: Vector2 = _to_map(road["b"])
		map.draw_line(a, b, Color(0.33, 0.34, 0.4), 8.0 * _zoom)
	# GPS route (animated dashes)
	if not _route.is_empty():
		var col := LvgTheme.ACCENT
		for i in _route.size() - 1:
			var a: Vector2 = _to_map(_route[i])
			var b: Vector2 = _to_map(_route[i + 1])
			map.draw_line(a, b, Color(col.r, col.g, col.b, 0.85), 6.0 * _zoom)
	# locations
	for loc in _locations():
		var p: Vector2 = _to_map(loc["pos"])
		var icon_col := LvgTheme.SUCCESS if String(loc["kind"]) == "shop" else Color(0.45, 0.62, 0.85) if String(loc["kind"]) == "interior" else Color(0.8, 0.75, 0.6)
		if GameState.discovered_locations.has(String(loc["id"])):
			icon_col = icon_col.lightened(0.2)
		map.draw_circle(p, 8.0 * _zoom, icon_col)
		map.draw_circle(p, 3.0 * _zoom, Color(0.1, 0.1, 0.12))
	# mission marker (pulsing)
	var mt := _mission_target()
	if mt != Vector2.INF:
		var p: Vector2 = _to_map(mt)
		var pulse: float = 0.6 + 0.4 * sin(_route_t * 4.0)
		map.draw_circle(p, (12.0 + 4.0 * pulse) * _zoom, Color(LvgTheme.DANGER.r, LvgTheme.DANGER.g, LvgTheme.DANGER.b, 0.35))
		map.draw_circle(p, 6.0 * _zoom, LvgTheme.DANGER)
	# police
	for u in get_tree().get_nodes_in_group("police_unit"):
		if u is PoliceUnit and is_instance_valid(u):
			var up: Vector2 = _to_map(Vector2(u.global_position.x, u.global_position.z))
			map.draw_circle(up, 5.0 * _zoom, LvgTheme.POLICE)
	# waypoint flag
	if _has_waypoint:
		var wp: Vector2 = _to_map(_waypoint)
		map.draw_line(wp - Vector2(0, 18), wp + Vector2(0, 18), LvgTheme.ACCENT, 3.0)
		map.draw_circle(wp, 10.0 * _zoom, Color(LvgTheme.ACCENT.r, LvgTheme.ACCENT.g, LvgTheme.ACCENT.b, 0.4))
	# player
	var pp: Vector2 = _to_map(_player_pos())
	map.draw_circle(pp, 12.0 * _zoom, LvgTheme.ACCENT)
	map.draw_circle(pp, 6.0 * _zoom, Color(1, 1, 1))

func waypoint_world() -> Vector2:
	return _waypoint

func has_waypoint() -> bool:
	return _has_waypoint

func set_waypoint(pos: Vector2) -> void:
	_waypoint = pos
	_has_waypoint = true

func _close() -> void:
	var hud_layer := get_parent()
	if hud_layer and hud_layer.has_method("_close_panels"):
		hud_layer._close_panels()
	else:
		queue_free()
