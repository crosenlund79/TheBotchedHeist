extends CanvasLayer
## Crosshair, hit marker, health bar, monster counter, round messages and damage/death overlay.

var _health: ProgressBar
var _health_label: Label
var _counter: Label
var _message: Label
var _vignette: ColorRect
var _cross: Control
var _hit_t := 0.0
var _hit_head := false
var _msg_tween: Tween
var _total := 0
var _last_hp := 100.0

func _ready() -> void:
	layer = 4
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.6, 0, 0, 0)
	add_child(_vignette)

	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	add_child(_cross)

	var box := VBoxContainer.new()
	box.offset_left = 24; box.offset_top = 20
	add_child(box)
	_counter = _label(22, Color(0.92, 0.82, 0.6), box)

	var hb := VBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hb.offset_left = 24; hb.offset_top = -78; hb.offset_right = 324; hb.offset_bottom = -24
	add_child(hb)
	_health_label = _label(16, Color(0.9, 0.9, 0.92), hb)
	_health = ProgressBar.new()
	_health.custom_minimum_size = Vector2(300, 14)
	_health.show_percentage = false
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.55); bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new(); fg.bg_color = Color(0.75, 0.12, 0.12); fg.set_corner_radius_all(4)
	_health.add_theme_stylebox_override("background", bg)
	_health.add_theme_stylebox_override("fill", fg)
	hb.add_child(_health)

	_message = _label(64, Color(0.95, 0.85, 0.55), self)
	_message.set_anchors_preset(Control.PRESET_CENTER)
	_message.offset_left = -500; _message.offset_right = 500; _message.offset_top = -170; _message.offset_bottom = -90
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0

func _label(size: int, col: Color, parent: Node) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _process(delta: float) -> void:
	if _hit_t > 0.0:
		_hit_t -= delta
		_cross.queue_redraw()
	if _vignette.color.a > 0.0 and _message.text != "YOU DIED":
		_vignette.color.a = maxf(_vignette.color.a - delta * 1.2, 0.0)

func _draw_cross() -> void:
	var c := Color(1, 1, 1, 0.9)
	_cross.draw_arc(Vector2.ZERO, 9, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.5)
	_cross.draw_circle(Vector2.ZERO, 2.0, c)
	if _hit_t > 0.0:
		var hc := Color(1, 0.25, 0.2) if _hit_head else Color(1, 1, 1)
		hc.a = clampf(_hit_t / 0.18, 0, 1)
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_cross.draw_line(s * 7, s * 15, hc, 2.5)

func hit_marker(headshot: bool, _killed: bool) -> void:
	_hit_t = 0.18
	_hit_head = headshot
	_cross.queue_redraw()

func set_health(hp: float, max_hp: float) -> void:
	_health.max_value = max_hp
	_health.value = hp
	_health_label.text = "HEALTH  %d" % int(ceil(hp))
	if hp < _last_hp:
		_vignette.color.a = 0.35
	_last_hp = hp
	if hp >= max_hp and _message.text == "YOU DIED":
		_vignette.color = Color(0.6, 0, 0, 0)
		_message.modulate.a = 0.0
		_message.text = ""

func set_monsters(alive: int, total: int, round_num: int) -> void:
	if total > 0:
		_total = total
	_counter.text = "ROUND %d     MONSTERS  %d / %d" % [round_num, alive, _total]

func show_message(text: String, seconds: float) -> void:
	if _msg_tween:
		_msg_tween.kill()
	_message.text = text
	_message.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(seconds)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.6)

func show_death() -> void:
	if _msg_tween:
		_msg_tween.kill()
	_message.text = "YOU DIED"
	_message.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_vignette, "color", Color(0.25, 0, 0, 0.75), 0.8)
