class_name UI
extends RefCounted
## Shared look for every screen: dark translucent panels, brass accents, outlined labels.

const GOLD := Color(0.92, 0.76, 0.45)
const TEXT := Color(0.9, 0.91, 0.94)
const DIM := Color(0.66, 0.68, 0.74)
const RED := Color(0.95, 0.25, 0.22)

static var _theme: Theme

static func box(c: Color, r := 10, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 18
	_theme.set_stylebox("normal", "Button", box(Color(1, 1, 1, 0.07), 6, 12))
	_theme.set_stylebox("focus", "Button", box(Color(1, 1, 1, 0.12), 6, 12))
	_theme.set_stylebox("hover", "Button", box(Color(1, 1, 1, 0.17), 6, 12))
	_theme.set_stylebox("pressed", "Button", box(Color(0.86, 0.68, 0.32, 0.95), 6, 12))
	_theme.set_stylebox("hover_pressed", "Button", box(Color(0.9, 0.72, 0.36, 0.95), 6, 12))
	_theme.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), 6, 12))
	_theme.set_color("font_pressed_color", "Button", Color(0.08, 0.08, 0.1))
	_theme.set_color("font_hover_pressed_color", "Button", Color(0.08, 0.08, 0.1))
	_theme.set_stylebox("panel", "PanelContainer", box(Color(0.045, 0.05, 0.065, 0.93), 14, 20))
	_theme.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), 3, 2))
	_theme.set_stylebox("grabber_area", "HSlider", box(Color(0.86, 0.68, 0.32, 0.9), 3, 2))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", box(Color(0.95, 0.78, 0.4, 1.0), 3, 2))
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0.0), 0, 6))
	_theme.set_stylebox("tab_selected", "TabContainer", box(Color(0.86, 0.68, 0.32, 0.95), 6, 10))
	_theme.set_stylebox("tab_unselected", "TabContainer", box(Color(1, 1, 1, 0.07), 6, 10))
	_theme.set_stylebox("tab_hovered", "TabContainer", box(Color(1, 1, 1, 0.16), 6, 10))
	_theme.set_color("font_selected_color", "TabContainer", Color(0.08, 0.08, 0.1))
	return _theme

static func label(text: String, size := 18, col := TEXT, parent: Node = null, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", maxi(4, size / 4))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent:
		parent.add_child(l)
	return l

static func button(text: String, parent: Node, cb: Callable, toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.pressed.connect(func():
		Sfx.play(b, "ui_click", null, -12.0)
		cb.call())
	parent.add_child(b)
	return b

static func header(text: String, parent: Node) -> Label:
	return label(text, 13, GOLD, parent, false)

static func vbox(parent: Node, sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v

static func hbox(parent: Node, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h

static func spacer(parent: Node, horizontal := true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

## CRT/CCTV look for footage: desaturated green tint, scanlines, noise, vignette; `static_amt`
## blends to pure static (signal lost).
static func cctv_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float static_amt = 0.0;
uniform float tint = 0.7;
void fragment() {
	vec2 uv = UV;
	vec3 c = texture(TEXTURE, uv).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g) * vec3(0.82, 1.0, 0.9), tint);
	c = 1.0 - exp(-c * 2.4);
	c *= 0.9 + 0.1 * sin(uv.y * 600.0);
	float n = fract(sin(dot(uv * vec2(12.9898, 78.233) + vec2(TIME * 3.1, TIME * 1.7), vec2(1.0))) * 43758.5453);
	c += (n - 0.5) * 0.08;
	c = mix(c, vec3(n), static_amt);
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * 1.2;
	COLOR = vec4(c, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
