class_name UiTheme
extends RefCounted
## Единый визуальный стиль интерфейса: тёмные панели, тонкие светлые рамки, красный акцент.

## Логический размер экрана (stretch = canvas_items, keep) — верстка в абсолютных пикселях.
const VW := 1280
const VH := 720

const BG := Color(0.055, 0.050, 0.065, 0.95)
const BG_SOFT := Color(0.085, 0.078, 0.095, 0.88)
const BORDER := Color(0.72, 0.70, 0.64, 0.45)
const BORDER_HOT := Color(0.85, 0.82, 0.74, 0.85)
const TEXT := Color(0.90, 0.88, 0.83)
const DIM := Color(0.60, 0.58, 0.55)
const ACCENT := Color(0.64, 0.15, 0.17)
const GOLD := Color(0.82, 0.74, 0.50)
const BLOOD := Color(0.45, 0.07, 0.09)


static func panel_box(bg: Color = BG, border: Color = BORDER, bw: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func make_label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func make_rich(text: String, size: int = 18, color: Color = TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", color)
	return r


static func make_button(text: String, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.34, 0.33))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55)
	hover.border_color = Color(1, 1, 1, 0.25)
	hover.set_border_width_all(1)
	hover.content_margin_left = 18
	hover.content_margin_right = 18
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6

	var focus := hover.duplicate() as StyleBoxFlat
	focus.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75)
	focus.border_color = Color(1, 0.9, 0.85, 0.6)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("pressed", focus)
	b.add_theme_stylebox_override("disabled", normal)
	return b


static func make_panel(bg: Color = BG, border: Color = BORDER, bw: int = 2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(bg, border, bw))
	return p


## Растянуть элемент на весь логический экран.
## Контролы прямо под CanvasLayer не получают размер вида автоматически,
## поэтому задаём его явно (логический экран всегда 1280x720).
static func fullscreen(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.position = Vector2.ZERO
	c.size = Vector2(VW, VH)


static func add_shadow(c: Control) -> void:
	c.modulate = c.modulate
