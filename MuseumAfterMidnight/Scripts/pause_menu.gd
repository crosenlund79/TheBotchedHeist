extends CanvasLayer
## Esc menu: resume, graphics preset (applies immediately), quit. Also shows a short controls hint.

var _panel: PanelContainer
var _preset_buttons := {}
var _hint: Label
var _status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	_panel.visible = false
	GameSettings.preset_changed.connect(_on_preset_changed)
	_on_preset_changed(GameSettings.preset)
	var t := create_tween()
	t.tween_interval(9.0)
	t.tween_property(_hint, "modulate:a", 0.0, 2.0)

func _process(_delta: float) -> void:
	var cctv := get_parent().get_node_or_null("CCTV")
	var replaying: bool = cctv != null and cctv.is_replaying()
	_status.visible = not replaying
	_hint.visible = not replaying

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	var open := not _panel.visible
	_panel.visible = open
	get_tree().paused = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func _on_preset_changed(p: String) -> void:
	for k in _preset_buttons:
		(_preset_buttons[k] as Button).button_pressed = k == p
	_status.text = "Graphics: %s   ·   Esc for menu" % p

func _style(c: Color, r := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c; s.set_corner_radius_all(r)
	s.content_margin_left = 16; s.content_margin_right = 16; s.content_margin_top = 10; s.content_margin_bottom = 10
	return s

func _build() -> void:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("normal", "Button", _style(Color(1, 1, 1, 0.07), 6))
	theme.set_stylebox("focus", "Button", _style(Color(1, 1, 1, 0.07), 6))
	theme.set_stylebox("hover", "Button", _style(Color(1, 1, 1, 0.16), 6))
	theme.set_stylebox("pressed", "Button", _style(Color(0.86, 0.68, 0.32, 0.95), 6))
	theme.set_stylebox("hover_pressed", "Button", _style(Color(0.86, 0.68, 0.32, 0.95), 6))
	theme.set_color("font_pressed_color", "Button", Color(0.08, 0.08, 0.1))
	theme.set_color("font_hover_pressed_color", "Button", Color(0.08, 0.08, 0.1))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme = theme
	_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.055, 0.07, 0.92), 14))
	_panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var title := Label.new(); title.text = "Museum After Midnight"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.92, 0.78, 0.48))
	v.add_child(title)
	var resume := Button.new(); resume.text = "Resume"; resume.pressed.connect(toggle); v.add_child(resume)
	var gl := Label.new(); gl.text = "GRAPHICS"
	gl.add_theme_font_size_override("font_size", 13); gl.add_theme_color_override("font_color", Color(0.86, 0.68, 0.32))
	v.add_child(gl)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	for p in GameSettings.PRESETS:
		var b := Button.new(); b.text = p; b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): GameSettings.set_preset(p))
		row.add_child(b)
		_preset_buttons[p] = b
	var info := Label.new()
	info.text = "Low: laptop-friendly, 67% resolution, no shadows or post effects.\nMedium: 85% resolution, key-light shadows, SSAO, glow.\nHigh: full resolution, MSAA 4×, all shadows, SSIL, SSR, volumetric fog."
	info.add_theme_font_size_override("font_size", 13); info.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	v.add_child(info)
	var controls := Label.new()
	controls.text = "WASD move  ·  Shift run  ·  Mouse look  ·  Esc menu"
	controls.add_theme_font_size_override("font_size", 14); controls.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	v.add_child(controls)
	var quit := Button.new(); quit.text = "Quit"; quit.pressed.connect(func(): get_tree().quit()); v.add_child(quit)

	_hint = Label.new()
	_hint.text = "WASD move   ·   Shift run   ·   Mouse look   ·   Esc menu"
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -400; _hint.offset_right = 400; _hint.offset_top = -72; _hint.offset_bottom = -40
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86, 0.75))
	_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status.offset_left = -420; _status.offset_right = -16; _status.offset_top = 12; _status.offset_bottom = 36
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status)
