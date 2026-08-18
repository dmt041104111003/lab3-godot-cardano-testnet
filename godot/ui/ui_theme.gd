extends Node
## Global UI theme (autoload): Press Start 2P font + styled buttons/panels.

var theme: Theme
var font: FontFile

func _ready() -> void:
	font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	theme = Theme.new()
	if font != null:
		theme.default_font = font
	theme.default_font_size = 12

	var b_n := StyleBoxFlat.new()
	b_n.bg_color = Color("#126e73")
	b_n.set_corner_radius_all(10)
	b_n.border_color = Color("#4de6cb")
	b_n.set_border_width_all(1)
	b_n.content_margin_left = 18
	b_n.content_margin_right = 18
	b_n.content_margin_top = 11
	b_n.content_margin_bottom = 11
	theme.set_stylebox("normal", "Button", b_n)
	var b_h := b_n.duplicate()
	b_h.bg_color = Color("#1b9c8f")
	b_h.border_color = Color("#d4fff6")
	theme.set_stylebox("hover", "Button", b_h)
	var b_p := b_n.duplicate()
	b_p.bg_color = Color(0.08, 0.35, 0.32)
	theme.set_stylebox("pressed", "Button", b_p)
	var b_d := b_n.duplicate()
	b_d.bg_color = Color(0.15, 0.18, 0.2)
	b_d.border_color = Color(0.3, 0.35, 0.4)
	theme.set_stylebox("disabled", "Button", b_d)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	theme.set_color("font_pressed_color", "Button", Color(0.8, 1, 1))
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.65, 0.7))
	theme.set_font_size("font_size", "Button", 12)

	var pn := StyleBoxFlat.new()
	pn.bg_color = Color(0.025, 0.055, 0.10, 0.94)
	pn.set_corner_radius_all(18)
	pn.border_color = Color(0.20, 0.76, 0.70, 0.7)
	pn.set_border_width_all(1)
	pn.shadow_color = Color(0, 0, 0, 0.55)
	pn.shadow_size = 18
	pn.content_margin_left = 34
	pn.content_margin_right = 34
	pn.content_margin_top = 28
	pn.content_margin_bottom = 28
	theme.set_stylebox("panel", "Panel", pn)
	theme.set_stylebox("panel", "PanelContainer", pn)

	theme.set_color("font_color", "Label", Color(0.92, 0.95, 1.0))
	theme.set_color("font_color", "LineEdit", Color(0.95, 0.98, 1.0))
	theme.set_color("caret_color", "LineEdit", Color(0.9, 1.0, 1.0))
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.06, 0.09, 0.13)
	le.set_corner_radius_all(6)
	le.border_color = Color(0.3, 0.6, 0.6)
	le.set_border_width_all(1)
	theme.set_stylebox("normal", "LineEdit", le)
	theme.set_color("font_placeholder_color", "LineEdit", Color("#71859d"))
	theme.set_constant("minimum_character_width", "LineEdit", 12)
