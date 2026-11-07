extends CanvasLayer
## In-game HUD: crosshair + hit marker, health, weapon and ammo, round and remaining monsters,
## objective, interaction prompt, toasts, round banner, plaque info panel, damage vignette,
## Tourist objective markers, the round-complete summary and the death screen (both count down
## automatically; Enter/E skips).

var _health: ProgressBar
var _health_label: Label
var _weapon: Label
var _ammo: Label
var _reserve: Label
var _round: Label
var _objective: Label
var _prompt: Label
var _toast: Label
var _banner: Label
var _banner_sub: Label
var _info: PanelContainer
var _info_title: Label
var _info_body: Label
var _vignette: ColorRect
var _cross: Control
var _markers: Control
var _screen: PanelContainer
var _screen_title: Label
var _screen_body: Label
var _screen_count: Label
var _screen_buttons: HBoxContainer
var _hit_t := 0.0
var _hit_head := false
var _hit_kill := false
var _toast_t := 0.0
var _banner_tween: Tween
var _info_t := 0.0
var _last_hp := 100.0
var _low_ammo := false
var player: Node3D

func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.6, 0, 0, 0)
	root.add_child(_vignette)
	_markers = Control.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	root.add_child(_markers)
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	root.add_child(_cross)

	# Top left: round, monsters, objective.
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 18)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	_round = UI.label("", 24, UI.GOLD, tl)
	_objective = UI.label("", 16, UI.TEXT, tl)

	# Bottom left: health.
	var hb := VBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hb.offset_left = 24
	hb.offset_top = -80
	hb.offset_right = 344
	hb.offset_bottom = -24
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb)
	_health_label = UI.label("HEALTH  100", 16, UI.TEXT, hb)
	_health = ProgressBar.new()
	_health.custom_minimum_size = Vector2(320, 14)
	_health.show_percentage = false
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.78, 0.14, 0.12)
	fg.set_corner_radius_all(4)
	_health.add_theme_stylebox_override("background", bg)
	_health.add_theme_stylebox_override("fill", fg)
	hb.add_child(_health)

	# Bottom right: weapon and ammo.
	var wb := VBoxContainer.new()
	wb.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	wb.offset_left = -360
	wb.offset_top = -110
	wb.offset_right = -24
	wb.offset_bottom = -20
	wb.alignment = BoxContainer.ALIGNMENT_END
	wb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wb)
	_weapon = UI.label("", 16, UI.DIM, wb)
	_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var ah := HBoxContainer.new()
	ah.alignment = BoxContainer.ALIGNMENT_END
	ah.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wb.add_child(ah)
	_ammo = UI.label("30", 44, UI.TEXT, ah)
	_reserve = UI.label(" / 120", 22, UI.DIM, ah)

	# Centre: prompt, toast, banner.
	_prompt = UI.label("", 20, Color(1, 0.95, 0.8), root)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -500
	_prompt.offset_right = 500
	_prompt.offset_top = 60
	_prompt.offset_bottom = 90
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast = UI.label("", 18, Color(0.85, 0.95, 1.0), root)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -600
	_toast.offset_right = 600
	_toast.offset_top = -170
	_toast.offset_bottom = -140
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner = UI.label("", 64, UI.GOLD, root)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -600
	_banner.offset_right = 600
	_banner.offset_top = 150
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner_sub = UI.label("", 22, UI.TEXT, _banner)
	_banner_sub.position = Vector2(0, 84)
	_banner_sub.size = Vector2(1200, 30)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Plaque / info panel (right side).
	_info = PanelContainer.new()
	_info.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_info.offset_left = -440
	_info.offset_right = -24
	_info.offset_top = -120
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	root.add_child(_info)
	var iv := UI.vbox(_info, 8)
	_info_title = UI.label("", 22, UI.GOLD, iv)
	_info_body = UI.label("", 16, UI.TEXT, iv, false)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.custom_minimum_size = Vector2(380, 0)

	# Round summary / death screen.
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	_screen = PanelContainer.new()
	_screen.custom_minimum_size = Vector2(560, 0)
	_screen.visible = false
	cc.add_child(_screen)
	var sv := UI.vbox(_screen, 12)
	_screen_title = UI.label("", 46, UI.GOLD, sv)
	_screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_body = UI.label("", 19, UI.TEXT, sv, false)
	_screen_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_count = UI.label("", 18, UI.DIM, sv, false)
	_screen_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_buttons = UI.hbox(sv, 10)
	_screen_buttons.alignment = BoxContainer.ALIGNMENT_CENTER

func _director() -> Node:
	return get_parent().get_node_or_null("Director")

func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if _hit_t > 0.0:
		_hit_t -= delta
		_cross.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
	if _info.visible:
		_info_t -= delta
		if _info_t <= 0.0:
			_info.visible = false
	if _vignette.color.a > 0.0 and not _screen.visible:
		var floor_a := 0.0
		if player and player.hp < 30.0 and not player.dead:
			floor_a = 0.18 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
		_vignette.color.a = maxf(_vignette.color.a - delta * 1.2, floor_a)
	elif player and player.hp < 30.0 and not player.dead:
		_vignette.color.a = 0.2
	_cross.visible = player != null and not player.dead and not _screen.visible
	if GameSettings.diff("markers"):
		_markers.queue_redraw()
	if _screen.visible and Input.is_action_just_pressed("interact"):
		var d := _director()
		if d: d.skip_countdown()

func _input(event: InputEvent) -> void:
	if _screen.visible and event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		var d := _director()
		if d: d.skip_countdown()

func _draw_cross() -> void:
	var c := Color(1, 1, 1, 0.9)
	var spread := 9.0
	if player and player.weapons:
		spread = 6.0 if player.aiming else 11.0
		if player.moving: spread += 4.0
		spread += player.weapons.recoil * 80.0
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		_cross.draw_line(d * spread, d * (spread + 7.0), Color(1, 1, 1, 0.75), 2.0)
	_cross.draw_circle(Vector2.ZERO, 1.8, c)
	if _hit_t > 0.0:
		var hc := Color(1, 0.25, 0.2) if _hit_head or _hit_kill else Color(1, 1, 1)
		hc.a = clampf(_hit_t / 0.2, 0, 1)
		var s := 1.4 if _hit_kill else 1.0
		for v in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_cross.draw_line(v * 7 * s, v * 15 * s, hc, 2.5)

## Tourist difficulty: markers over awake enemies, edge arrows for off-screen ones.
func _draw_markers() -> void:
	if player == null or player.dead or _screen.visible:
		return
	var cam: Camera3D = player.camera
	var size := _markers.size
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.state == Enemy.S.DORMANT:
			continue
		var p: Vector3 = e.global_position + Vector3.UP * (e.height + 0.3)
		var col := Color(1, 0.3, 0.2, 0.9)
		if not cam.is_position_behind(p):
			var sp := cam.unproject_position(p)
			if Rect2(Vector2.ZERO, size).grow(-30).has_point(sp):
				_markers.draw_colored_polygon(PackedVector2Array([sp + Vector2(-7, -12), sp + Vector2(7, -12), sp]), col)
				continue
		var to := cam.global_transform.affine_inverse() * p
		var dir := Vector2(to.x, -to.y).normalized()
		if to.z > 0.0:
			dir = Vector2(to.x, 0.3).normalized() if absf(to.x) > 0.01 else Vector2(0, 1)
		var c := size * 0.5
		var edge := c + dir * minf(size.x, size.y) * 0.42
		var perp := Vector2(-dir.y, dir.x)
		_markers.draw_colored_polygon(PackedVector2Array([edge + dir * 14, edge - dir * 6 + perp * 9, edge - dir * 6 - perp * 9]), col)

# ------------------------------------------------------------------ setters

func hit_marker(headshot: bool, killed: bool) -> void:
	_hit_t = 0.2
	_hit_head = headshot
	_hit_kill = killed
	_cross.queue_redraw()

func set_health(hp: float, max_hp: float) -> void:
	_health.max_value = max_hp
	_health.value = hp
	_health_label.text = "HEALTH  %d" % int(ceil(hp))
	_last_hp = hp

func damage_flash(amount: float) -> void:
	_vignette.color = Color(0.6, 0, 0, clampf(0.15 + amount * 0.015, 0.2, 0.55))

func set_ammo(weapon_name: String, mag: int, mag_size: int, reserve: int) -> void:
	_weapon.text = weapon_name.to_upper() + "     [1] Rifle  [2] Handgun"
	_ammo.text = str(mag)
	_reserve.text = " / unlimited" if reserve < 0 else " / %d" % reserve
	var low := mag <= mag_size / 4
	_ammo.add_theme_color_override("font_color", UI.RED if low else UI.TEXT)
	if mag == 0 and reserve == 0:
		toast("Out of ammunition - find an ammo pack (Storage, Security Office, hall desk, Crypt)", 3.0)

func set_round(n: int, remaining: int, total: int) -> void:
	_round.text = "ROUND %d     MONSTERS  %d / %d" % [n, remaining, total] if n > 0 else ""

func set_objective(text: String) -> void:
	_objective.text = text

func set_prompt(text: String) -> void:
	_prompt.text = text

func toast(text: String, seconds := 3.0) -> void:
	_toast.text = text
	_toast_t = seconds
	_toast.modulate.a = 1.0

func banner(title: String, sub: String, seconds: float) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.text = title
	_banner_sub.text = sub
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)

func show_info(title: String, body: String) -> void:
	_info_title.text = title
	_info_body.text = body
	_info.visible = true
	_info_t = 9.0

func hide_screens() -> void:
	_screen.visible = false
	_vignette.color = Color(0.6, 0, 0, 0)

func set_countdown(t: float) -> void:
	if _screen.visible:
		_screen_count.text = "%s in %d   ·   Enter / E to continue now" % [_count_label, int(ceil(maxf(t, 0.0)))]

var _count_label := ""

func _fill_buttons(defs: Array) -> void:
	for c in _screen_buttons.get_children():
		c.queue_free()
	for d in defs:
		UI.button(d[0], _screen_buttons, d[1])

func show_summary(s: Dictionary, _seconds: float) -> void:
	_screen.visible = true
	_screen_title.text = "MUSEUM CLEARED"
	_screen_title.add_theme_color_override("font_color", UI.GOLD)
	_screen_body.text = "Round %d complete\n\nMonsters destroyed: %d\nTime: %s\nAccuracy: %d%%\nDamage taken: %d\n\nBest completed round: %d" % [
		s.round, s.kills, _fmt(s.time), int(s.accuracy), int(s.damage), s.best]
	_count_label = "Next round"
	_fill_buttons([])
	_vignette.color = Color(0, 0, 0, 0.35)

func show_death(s: Dictionary, _seconds: float) -> void:
	_screen.visible = true
	_screen_title.text = "YOU DIED"
	_screen_title.add_theme_color_override("font_color", UI.RED)
	_screen_body.text = "The museum claimed another guard.\n\nRound %d   ·   %d of %d monsters destroyed\nSurvived: %s\nAccuracy: %d%%\n\nBest completed round: %d" % [
		s.round, s.kills, s.total, _fmt(s.time), int(s.accuracy), s.best]
	_count_label = "Restarting the round"
	_fill_buttons([])
	var t := create_tween()
	t.tween_property(_vignette, "color", Color(0.25, 0, 0, 0.7), 0.8)

static func _fmt(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
