class_name LvgTheme
extends RefCounted
## LvgTheme - LEVERAGE UI design language: charcoal + amber "cinder" identity.
## Factory helpers keep every screen visually consistent.
## Fonts: Lilita One (display), Liberation Sans (body/HUD) - both bundled
## with licenses in assets/fonts/.

# --- Palette ---
const CHARCOAL := Color("15161a")
const PANEL := Color("1d1f24")
const PANEL_LIFT := Color("25272e")
const LINE := Color("2a2d34")
const TEXT := Color("e8e6e3")
const TEXT_DIM := Color("9a9a94")
const ACCENT := Color("f0a33c")        # cinder amber
const ACCENT_DEEP := Color("c8761f")
const DANGER := Color("d64541")
const POLICE := Color("3b6fd6")
const SUCCESS := Color("5aa05a")
const BLACK := Color(0, 0, 0)
const WHITE := Color(1, 1, 1)
const TRANSPARENT := Color(0, 0, 0, 0)

# --- Fonts (static, loaded once) ---
static var font_body: FontFile
static var font_body_bold: FontFile
static var font_display: FontFile
static var font_condensed: FontFile
static var font_mono: FontFile

const FONT_BODY_PATH := "res://assets/fonts/LiberationSans-Regular.ttf"
const FONT_BODY_BOLD_PATH := "res://assets/fonts/LiberationSans-Bold.ttf"
const FONT_DISPLAY_PATH := "res://assets/fonts/Anton-Regular.ttf"
const FONT_CONDENSED_PATH := "res://assets/fonts/Oswald.ttf"
const FONT_MONO_PATH := "res://assets/fonts/DejaVuSans.ttf"


static func load_fonts() -> void:
        if font_body != null:
                return
        font_body = load(FONT_BODY_PATH) as FontFile
        font_body_bold = load(FONT_BODY_BOLD_PATH) as FontFile
        # cinematic display: Anton (heavy condensed) with Lilita One fallback
        font_display = load(FONT_DISPLAY_PATH) as FontFile
        if font_display == null:
                font_display = load("res://assets/fonts/lilita_one_regular.ttf") as FontFile
        font_condensed = load(FONT_CONDENSED_PATH) as FontFile
        if font_condensed == null:
                font_condensed = font_body_bold
        font_mono = load(FONT_MONO_PATH) as FontFile


# --- Style factories ---
static func panel_style(bg := PANEL, border := LINE, corner := 6.0) -> StyleBoxFlat:
        var s := StyleBoxFlat.new()
        s.bg_color = bg
        s.border_width_bottom = 2
        s.border_width_top = 2
        s.border_width_left = 2
        s.border_width_right = 2
        s.border_color = border
        s.corner_radius_top_left = corner
        s.corner_radius_top_right = corner
        s.corner_radius_bottom_left = corner
        s.corner_radius_bottom_right = corner
        s.content_margin_left = 24
        s.content_margin_right = 24
        s.content_margin_top = 18
        s.content_margin_bottom = 18
        return s


static func button_style(normal := PANEL, hover := PANEL_LIFT, pressed := ACCENT_DEEP) -> Dictionary:
        var n := StyleBoxFlat.new()
        n.bg_color = normal
        n.border_width_bottom = 2
        n.border_width_top = 2
        n.border_width_left = 2
        n.border_width_right = 2
        n.border_color = LINE
        n.corner_radius_top_left = 4
        n.corner_radius_top_right = 4
        n.corner_radius_bottom_left = 4
        n.corner_radius_bottom_right = 4
        n.content_margin_left = 28
        n.content_margin_right = 28
        n.content_margin_top = 16
        n.content_margin_bottom = 16
        var h := n.duplicate()
        h.bg_color = hover
        h.border_color = ACCENT
        var p := n.duplicate()
        p.bg_color = pressed
        var f := n.duplicate()
        f.bg_color = Color(normal.r, normal.g, normal.b, 0.35)
        f.border_color = Color(LINE.r, LINE.g, LINE.b, 0.35)
        return {"normal": n, "hover": h, "pressed": p, "focus": f, "disabled": f}


static func make_button(text: String, display := false, width := 0.0) -> Button:
        load_fonts()
        var b := Button.new()
        b.text = text
        if display:
                b.add_theme_font_override("font", font_display)
                b.add_theme_font_size_override("font_size", 54)
        else:
                b.add_theme_font_override("font", font_body_bold)
                b.add_theme_font_size_override("font_size", 40)
        b.add_theme_color_override("font_color", TEXT)
        b.add_theme_color_override("font_hover_color", ACCENT)
        b.add_theme_color_override("font_pressed_color", WHITE)
        b.add_theme_color_override("font_focus_color", ACCENT)
        var st := button_style()
        b.add_theme_stylebox_override("normal", st["normal"])
        b.add_theme_stylebox_override("hover", st["hover"])
        b.add_theme_stylebox_override("pressed", st["pressed"])
        b.add_theme_stylebox_override("focus", st["focus"])
        b.add_theme_stylebox_override("disabled", st["disabled"])
        if width > 0:
                b.custom_minimum_size = Vector2(width, 0)
        return b


static func make_label(text: String, size := 40, color := TEXT, bold := false) -> Label:
        load_fonts()
        var l := Label.new()
        l.text = text
        if bold:
                l.add_theme_font_override("font", font_body_bold)
        else:
                l.add_theme_font_override("font", font_body)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", color)
        return l


static func make_display_label(text: String, size := 96, color := ACCENT) -> Label:
        load_fonts()
        var l := Label.new()
        l.text = text
        l.add_theme_font_override("font", font_display)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", color)
        return l


static func make_panel(bg := PANEL, border := LINE) -> PanelContainer:
        var p := PanelContainer.new()
        p.add_theme_stylebox_override("panel", panel_style(bg, border))
        return p


## Letter-spaced small caps label (section headers).
static func make_kicker(text: String, color := TEXT_DIM, size := 26) -> Label:
        load_fonts()
        var l := Label.new()
        l.text = text
        l.add_theme_font_override("font", font_condensed)
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", color)
        l.uppercase = true
        return l


## Full-rect color layer.
static func color_rect(color: Color) -> ColorRect:
        var c := ColorRect.new()
        c.color = color
        c.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return c


## Uppercase letter-spaced string.
static func tracked(phrase: String) -> String:
        var out := ""
        for ch in phrase.to_upper():
                out += ch + " "
        return out.strip_edges()
