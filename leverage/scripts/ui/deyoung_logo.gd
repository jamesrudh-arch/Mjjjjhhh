class_name DeYoungLogo
extends Control
## DeYoungLogo - the animated DE YOUNG GAMES studio ident. Cinematic timeline:
## badge keyline sweeps on, the DY monogram strokes reveal, the wordmark
## illuminates letter-by-letter in an amber sweep, the rule expands, then
## "PRESENTS" settles. Runs on its own clock from tree entry; the boot card
## fades the whole control. Pure canvas drawing - no texture assets.

const T_KEYLINE := 0.55          # badge keyline draw-on
const T_MONO_START := 0.25
const T_MONO_END := 1.05         # monogram reveal window
const T_WORD_START := 0.95       # letter illuminate sweep
const T_WORD_DUR := 0.85
const T_GLOW_PULSE := 1.15       # glow bloom moment (sting impact)
const AMBER := Color(1.0, 0.64, 0.24)
const AMBER_DEEP := Color(0.72, 0.40, 0.12)
const INK := Color(0.92, 0.91, 0.88)

var t := 0.0
var _letters: Array = []          # per-letter Labels for the sweep
var _word_text := "DE YOUNG GAMES"


func _ready() -> void:
        set_anchors_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        custom_minimum_size = Vector2(2688, 1248)
        _build_wordmark()
        queue_redraw()
        set_process(true)


func _process(delta: float) -> void:
        t += delta
        queue_redraw()


func _build_wordmark() -> void:
        var box := HBoxContainer.new()
        box.add_theme_constant_override("separation", 10)
        box.set_anchors_preset(Control.PRESET_CENTER)
        # position under the badge (badge drawn at canvas center - 190)
        box.position = Vector2(2688 / 2.0 - 620, 1248 / 2.0 + 140)
        box.custom_minimum_size = Vector2(1240, 0)
        add_child(box)
        for i in _word_text.length():
                var ch := _word_text[i]
                var l := Label.new()
                if LvgTheme.font_display != null:
                        l.add_theme_font_override("font", LvgTheme.font_display)
                l.add_theme_font_size_override("font_size", 74)
                l.text = ch
                l.custom_minimum_size = Vector2(38 if ch != " " else 30, 90)
                l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                l.modulate = Color(1, 1, 1, 0)
                box.add_child(l)
                _letters.append(l)


func _draw() -> void:
        var cx := 2688 / 2.0
        var cy := 1248 / 2.0 - 60
        # --- ambient glow pulse behind the badge (sting impact) ---
        var glow_k: float = clampf((t - T_GLOW_PULSE) / 0.8, 0.0, 1.0)
        if t >= T_GLOW_PULSE and glow_k < 1.0:
                var g := (1.0 - glow_k) * 0.34
                draw_circle(Vector2(cx, cy), 300.0, Color(AMBER.r, AMBER.g, AMBER.b, g * 0.35))
                draw_circle(Vector2(cx, cy), 190.0, Color(AMBER.r, AMBER.g, AMBER.b, g * 0.5))
        # --- badge keyline: rounded square drawn on progressively ---
        var pts := _badge_points(190.0, 140.0, 16.0, Vector2(cx, cy))
        var prog: float = clampf(t / T_KEYLINE, 0.0, 1.0)
        var n := int(pts.size() * prog)
        if n >= 2:
                var shown := PackedVector2Array()
                for i in n:
                        shown.append(pts[i])
                draw_polyline(shown, AMBER, 3.5, true)
        # --- DY monogram reveal ---
        var mono: float = clampf((t - T_MONO_START) / (T_MONO_END - T_MONO_START), 0.0, 1.0)
        if mono > 0.0:
                _draw_monogram(Vector2(cx, cy), mono)
        # --- wordmark letter sweep ---
        for i in _letters.size():
                var l: Label = _letters[i]
                var k: float = clampf((t - T_WORD_START - i * (T_WORD_DUR / _letters.size())) / 0.35, 0.0, 1.0)
                if k <= 0.0:
                        l.modulate.a = 0.0
                elif k < 1.0:
                        l.modulate.a = k
                        l.modulate = Color(AMBER.r, AMBER.g, AMBER.b, k)
                else:
                        # after the sweep passes, settle to ink white
                        l.modulate = INK
        # --- rule + PRESENTS ---
        var rule_k: float = clampf((t - 1.35) / 0.5, 0.0, 1.0)
        if rule_k > 0.0:
                var w := 520.0 * rule_k
                draw_rect(Rect2(cx - w / 2.0, cy + 262.0, w, 3.0), AMBER_DEEP)
                draw_rect(Rect2(cx - 70.0, cy + 262.0, 140.0 * rule_k, 3.0), AMBER)
        var pres_k: float = clampf((t - 1.6) / 0.6, 0.0, 1.0)
        if pres_k > 0.0:
                draw_string(_display_font(), Vector2(cx - 160.0, cy + 322.0), "P R E S E N T S",
                        HORIZONTAL_ALIGNMENT_CENTER, 320.0, 30, Color(INK.r, INK.g, INK.b, 0.75 * pres_k))


func _display_font() -> Font:
        return LvgTheme.font_display if LvgTheme.font_display != null else ThemeDB.fallback_font


func _badge_points(w: float, h: float, r: float, center: Vector2) -> PackedVector2Array:
        ## Rounded-rect perimeter points starting top-left after the corner.
        var pts := PackedVector2Array()
        var x0 := center.x - w / 2.0
        var x1 := center.x + w / 2.0
        var y0 := center.y - h / 2.0
        var y1 := center.y + h / 2.0
        var steps := 8
        # top edge
        for i in range(steps + 1):
                pts.append(Vector2(x0 + r + (x1 - x0 - 2 * r) * i / steps, y0))
        # top-right corner
        for i in range(1, steps + 1):
                var a := (PI / 2.0) * i / steps
                pts.append(Vector2(x1 - r + sin(a) * r, y0 + r - cos(a) * r))
        # right edge
        for i in range(1, steps + 1):
                pts.append(Vector2(x1, y0 + r + (y1 - y0 - 2 * r) * i / steps))
        # bottom-right corner
        for i in range(1, steps + 1):
                var a := (PI / 2.0) * i / steps
                pts.append(Vector2(x1 - r + cos(a) * r, y1 - r + sin(a) * r))
        # bottom edge
        for i in range(1, steps + 1):
                pts.append(Vector2(x1 - r - (x1 - x0 - 2 * r) * i / steps, y1))
        # bottom-left corner
        for i in range(1, steps + 1):
                var a := (PI / 2.0) * i / steps
                pts.append(Vector2(x0 + r - cos(a) * r, y1 - r + sin(a) * r))
        # left edge
        for i in range(1, steps + 1):
                pts.append(Vector2(x0, y1 - r - (y1 - y0 - 2 * r) * i / steps))
        # top-left corner
        for i in range(1, steps + 1):
                var a := (PI / 2.0) * i / steps
                pts.append(Vector2(x0 + r - sin(a) * r, y0 + r - cos(a) * r))
        return pts


func _draw_monogram(center: Vector2, progress: float) -> void:
        ## Bold interlocked D + Y drawn as stroked polylines, revealed along
        ## their path length by `progress`.
        var s := 1.0
        var ox := center.x
        var oy := center.y
        # D: stem + bow
        var d := PackedVector2Array([
                Vector2(-52, -44), Vector2(28, -44), Vector2(62, -22), Vector2(62, 22),
                Vector2(28, 44), Vector2(-52, 44), Vector2(-52, -44)])
        # Y: two arms + stem rooted in the D's baseline
        var y_pts := PackedVector2Array([
                Vector2(-16, -26), Vector2(16, 4), Vector2(48, -26)])
        var y_stem := PackedVector2Array([Vector2(16, 4), Vector2(16, 40)])
        _draw_partial_polyline(d, progress, AMBER, 11.0, Vector2(ox, oy), s)
        var p2: float = clampf((progress - 0.35) / 0.65, 0.0, 1.0)
        _draw_partial_polyline(y_pts, p2, INK, 8.0, Vector2(ox, oy), s)
        _draw_partial_polyline(y_stem, p2, INK, 8.0, Vector2(ox, oy), s)
        # keystone diamond accent under the D once revealed
        if progress > 0.92:
                var k: float = clampf((progress - 0.92) / 0.08, 0.0, 1.0)
                var dia := PackedVector2Array([
                        Vector2(16, 50), Vector2(24, 56), Vector2(16, 62), Vector2(8, 56)])
                draw_colored_polygon(_scale_pts(dia, Vector2(ox, oy), s),
                        Color(AMBER.r, AMBER.g, AMBER.b, k))


func _draw_partial_polyline(pts: PackedVector2Array, progress: float, color: Color,
                width: float, offset: Vector2, s: float) -> void:
        if progress <= 0.0 or pts.size() < 2:
                return
        var total := 0.0
        for i in range(pts.size() - 1):
                total += (pts[i + 1] - pts[i]).length()
        var target := total * clampf(progress, 0.0, 1.0)
        var shown := PackedVector2Array()
        shown.append(offset + pts[0] * s)
        var acc := 0.0
        for i in range(pts.size() - 1):
                var seg_len: float = (pts[i + 1] - pts[i]).length()
                if acc + seg_len <= target:
                        shown.append(offset + pts[i + 1] * s)
                        acc += seg_len
                else:
                        var k := (target - acc) / seg_len
                        shown.append(offset + (pts[i] + (pts[i + 1] - pts[i]) * k) * s)
                        break
        draw_polyline(shown, color, width, true)


func _scale_pts(pts: PackedVector2Array, offset: Vector2, s: float) -> PackedVector2Array:
        var out := PackedVector2Array()
        for p in pts:
                out.append(offset + p * s)
        return out


# ---------------------------------------------------------------- test API
func logo_progress() -> float:
        return t


func letter_count() -> int:
        return _letters.size()


func wordmark_fully_lit() -> bool:
        for l in _letters:
                if l == null or not is_instance_valid(l) or l.modulate.a < 0.99:
                        return false
        return true
