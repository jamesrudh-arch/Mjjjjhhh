extends Control
## LEVERAGE Hello Diag — zero-dependency diagnostic.
## Renders from pure engine primitives (ColorRect + default font + Labels).
## No textures, no meshes, no audio, no autoloads, no external assets.
## If this shows colored bands + readable text on a device, the whole
## "open project folder in Xogot and press Play" path works there, and any
## problem with the main game is inside the game, not the delivery chain.

var _bg: ColorRect
var _band: ColorRect
var _fps_label: Label
var _info_label: Label
var _title: Label
var _sub: Label
var _t := 0.0
var _hue := 0.0

func _ready() -> void:
	print("[HELLO DIAG] boot OK | Godot %s | renderer=%s | OS=%s | mem=%d MB" % [
		Engine.get_version_info().string,
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		OS.get_name(),
		OS.get_memory_info().get("physical", 0) / 1048576,
	])

	_bg = ColorRect.new()
	_bg.color = Color.from_hsv(0.58, 0.35, 0.12)  # dark slate backdrop
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_title = Label.new()
	_title.text = "LEVERAGE HELLO DIAG"
	_title.add_theme_font_size_override("font_size", 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_left = 0.0; _title.anchor_right = 1.0
	_title.anchor_top = 0.16; _title.anchor_bottom = 0.30
	add_child(_title)

	_sub = Label.new()
	_sub.text = "If you can read this, the project-folder path works on this device.\nInstall the main LEVERAGE zip the exact same way."
	_sub.add_theme_font_size_override("font_size", 28)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.anchor_left = 0.0; _sub.anchor_right = 1.0
	_sub.anchor_top = 0.32; _sub.anchor_bottom = 0.48
	add_child(_sub)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 22)
	_info_label.anchor_left = 0.0; _info_label.anchor_right = 1.0
	_info_label.anchor_top = 0.52; _info_label.anchor_bottom = 0.62
	add_child(_info_label)

	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 22)
	_fps_label.anchor_left = 0.0; _fps_label.anchor_right = 1.0
	_fps_label.anchor_top = 0.64; _fps_label.anchor_bottom = 0.70
	add_child(_fps_label)

	_band = ColorRect.new()  # moving color band = the render loop is alive
	_band.color = Color.from_hsv(0.0, 0.85, 0.95)
	_band.anchor_left = 0.0; _band.anchor_right = 1.0
	_band.anchor_top = 0.74; _band.anchor_bottom = 0.80
	add_child(_band)

func _process(delta: float) -> void:
	_t += delta
	_hue = fmod(_hue + delta * 0.25, 1.0)
	if _band:
		_band.color = Color.from_hsv(_hue, 0.85, 0.95)
	if _fps_label:
		_fps_label.text = "fps %.0f   t %.1fs   band hue %.2f (moving = loop alive)" % [
			Engine.get_frames_per_second(), _t, _hue]
	if _info_label and Engine.get_frames_drawn() % 30 == 0:
		_info_label.text = "Godot %s | %s | %s" % [
			Engine.get_version_info().string,
			ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
			OS.get_name()]
