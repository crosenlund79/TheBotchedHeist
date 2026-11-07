extends CanvasLayer
## Menus: main menu (Play, Difficulty, Graphics, Audio, Controls, Quit) over a slow camera flight
## through the museum, the pause menu (Resume, Settings, Restart round, Main menu) and the
## settings screen (graphics presets, audio volumes, control remapping, sensitivity, difficulty).
## Also shows a short controls guide when a game starts.

const DIFF_TEXT := {
	"Tourist": "Fewer, slower monsters that hit softly. Health regenerates, the handgun never runs dry, and markers point to every awake monster.",
	"Security Guard": "The intended experience. Monsters react quickly, entities appear from round 2 and beasts from round 3.",
	"Nightmare": "Large packs, lightning reactions, frequent hauntings. Entities from round 1, beasts from round 2. Scarce ammunition.",
}
const PRESET_TEXT := {
	"Low": "Laptop-friendly: 67% resolution, no shadows or post effects, fewer particles, monitor wall shows static.",
	"Medium": "85% resolution, key-light shadows, SSAO and glow, live CCTV monitors in the office.",
	"High": "Full resolution, MSAA 4x, all shadows, SSIL, SSR, volumetric fog, dense particles.",
}

var _main: Control
var _pause: Control
var _settings: Control
var _guide: Label
var _menu_cam: Camera3D
var _cam_t := 0.0
var _in_main := true
var _settings_from_main := true
var _diff_buttons := {}
var _diff_label: Label
var _preset_buttons := {}
var _preset_label: Label
var _bind_buttons := {}
var _waiting_action := ""
var _status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_main = _build_main(root)
	_pause = _build_pause(root)
	_settings = _build_settings(root)
	_guide = UI.label("", 18, UI.TEXT, root)
	_guide.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_guide.offset_left = -700
	_guide.offset_right = 700
	_guide.offset_top = -250
	_guide.offset_bottom = -190
	_guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guide.modulate.a = 0.0
	_status = UI.label("", 13, Color(0.8, 0.82, 0.86, 0.7), root)
	_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status.offset_left = -420
	_status.offset_right = -16
	_status.offset_top = 10
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameSettings.preset_changed.connect(func(_p): _refresh())
	_refresh()
	_show_main.call_deferred()

func _show_main() -> void:
	_in_main = true
	_main.visible = true
	_pause.visible = false
	_settings.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_cam = Camera3D.new()
	_menu_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_cam.fov = 60.0
	_menu_cam.cull_mask = 0xFFFFF & ~(4 | 8)
	get_parent().add_child(_menu_cam)
	_menu_cam.make_current()
	var hud := get_parent().get_node_or_null("HUD")
	if hud: hud.visible = false

func _process(delta: float) -> void:
	if _in_main and is_instance_valid(_menu_cam):
		_cam_t += delta * 0.05
		var p := Vector3(sin(_cam_t) * 6.5, 2.6 + sin(_cam_t * 2.3) * 0.4, 4.8 + cos(_cam_t) * 1.2)
		_menu_cam.global_position = p
		_menu_cam.look_at(Vector3(0, 1.2, -1.5))
	var cctv := get_parent().get_node_or_null("CCTV")
	_status.text = "Graphics: %s  ·  %s  ·  Esc menu  ·  F1 developer" % [GameSettings.preset, GameSettings.difficulty]
	_status.visible = not _in_main and not (cctv and cctv.is_terminal_open())

func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action != "":
		return
	if event.is_action_pressed("menu"):
		var cctv := get_parent().get_node_or_null("CCTV")
		if cctv and cctv.is_terminal_open():
			return
		if _settings.visible:
			_close_settings()
		elif not _in_main:
			toggle()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	var ok: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not ok:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and _waiting_action != "menu":
		_waiting_action = ""
		_refresh()
		return
	GameSettings.rebind(_waiting_action, event)
	_waiting_action = ""
	_refresh()

func toggle() -> void:
	var open := not _pause.visible
	_pause.visible = open
	_settings.visible = false
	get_tree().paused = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func _play() -> void:
	_in_main = false
	_main.visible = false
	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.camera.make_current()
	if is_instance_valid(_menu_cam):
		_menu_cam.queue_free()
	var hud := get_parent().get_node_or_null("HUD")
	if hud: hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var d := get_parent().get_node_or_null("Director")
	if d: d.start_game()
	_guide.text = "WASD move · Shift sprint · %s crouch · RMB aim · LMB fire · R reload · 1/2 weapons · E interact · F flashlight · V shoulder\nClear every haunted exhibit and spirit. The Security Office (east) has CCTV recordings, an alarm and supplies." % GameSettings.binding_text("crouch").get_slice(" / ", 0)
	_guide.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(12.0)
	t.tween_property(_guide, "modulate:a", 0.0, 2.0)

func _open_settings(tab: int, from_main: bool) -> void:
	_settings_from_main = from_main
	_main.visible = false
	_pause.visible = false
	_settings.visible = true
	(_settings.find_child("Tabs", true, false) as TabContainer).current_tab = tab

func _close_settings() -> void:
	_settings.visible = false
	GameSettings.save()
	if _settings_from_main and _in_main:
		_main.visible = true
	else:
		_pause.visible = true

# ------------------------------------------------------------------ builders

func _panel(root: Control, width := 460) -> PanelContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	cc.add_child(p)
	return p

func _build_main(root: Control) -> Control:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	holder.add_child(shade)
	var p := _panel(holder, 520)
	var v := UI.vbox(p, 12)
	var t := UI.label("MUSEUM AFTER MIDNIGHT", 40, UI.GOLD, v)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := UI.label("THE MUSEUM AWAKENS", 18, UI.TEXT, v)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var story := UI.label("You are the night guard. The doors locked at midnight - and the exhibits woke up.", 15, UI.DIM, v, false)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var play := UI.button("▶  PLAY", v, _play)
	play.add_theme_font_size_override("font_size", 24)
	UI.header("DIFFICULTY", v)
	var row := UI.hbox(v)
	for d in GameSettings.DIFFICULTIES:
		var b := UI.button(d, row, func(): GameSettings.set_difficulty(d); _refresh(), true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_diff_buttons[d] = b
	_diff_label = UI.label("", 14, UI.DIM, v, false)
	_diff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_label.custom_minimum_size = Vector2(480, 44)
	var r2 := UI.hbox(v)
	for pair in [["Graphics", 0], ["Audio", 1], ["Controls", 2]]:
		var b := UI.button(pair[0], r2, _open_settings.bind(pair[1], true))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.button("Quit", v, func(): get_tree().quit())
	var best := UI.label("", 14, UI.DIM, v, false)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.text = "Best completed round: %d" % GameSettings.best_round
	return holder

func _build_pause(root: Control) -> Control:
	var p := _panel(root, 420)
	p.get_parent().visible = false
	var v := UI.vbox(p, 12)
	UI.label("PAUSED", 30, UI.GOLD, v)
	UI.button("Resume", v, toggle)
	UI.button("Settings", v, _open_settings.bind(0, false))
	UI.button("Restart round", v, func():
		toggle()
		var d := get_parent().get_node_or_null("Director")
		if d: d.restart_round())
	UI.button("Main menu", v, func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	UI.button("Quit to desktop", v, func(): get_tree().quit())
	return p.get_parent()

func _build_settings(root: Control) -> Control:
	var p := _panel(root, 700)
	p.get_parent().visible = false
	var v := UI.vbox(p, 12)
	var top := UI.hbox(v)
	UI.label("SETTINGS", 28, UI.GOLD, top)
	UI.spacer(top)
	UI.button("Back", top, _close_settings)
	var tabs := TabContainer.new()
	tabs.name = "Tabs"
	tabs.custom_minimum_size = Vector2(660, 430)
	v.add_child(tabs)
	# Graphics
	var g := UI.vbox(tabs, 12)
	g.name = "Graphics"
	UI.header("PRESET", g)
	var gr := UI.hbox(g)
	for pr in GameSettings.PRESETS:
		var b := UI.button(pr, gr, func(): GameSettings.set_preset(pr); _refresh(), true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_preset_buttons[pr] = b
	_preset_label = UI.label("", 15, UI.DIM, g, false)
	_preset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preset_label.custom_minimum_size = Vector2(620, 0)
	# Audio
	var a := UI.vbox(tabs, 12)
	a.name = "Audio"
	for bus in ["Master", "SFX", "Ambience"]:
		UI.header(bus.to_upper(), a)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.value = GameSettings.volumes[bus]
		sl.custom_minimum_size = Vector2(600, 24)
		sl.value_changed.connect(func(val): GameSettings.set_volume(bus, val))
		a.add_child(sl)
	# Controls
	var c := UI.vbox(tabs, 6)
	c.name = "Controls"
	var sh := UI.hbox(c)
	UI.label("Mouse sensitivity", 15, UI.TEXT, sh)
	var sens := HSlider.new()
	sens.min_value = 0.3
	sens.max_value = 2.5
	sens.step = 0.05
	sens.value = GameSettings.mouse_sensitivity
	sens.custom_minimum_size = Vector2(260, 24)
	sens.value_changed.connect(func(val): GameSettings.mouse_sensitivity = val)
	sh.add_child(sens)
	var inv := CheckButton.new()
	inv.text = "Invert Y"
	inv.button_pressed = GameSettings.invert_y
	inv.toggled.connect(func(on): GameSettings.invert_y = on)
	sh.add_child(inv)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for b in GameSettings.BINDINGS:
		var l := UI.label(b[1], 15, UI.TEXT, grid, false)
		l.custom_minimum_size = Vector2(240, 0)
		var btn := UI.button("", grid, func():
			_waiting_action = b[0]
			_refresh())
		btn.custom_minimum_size = Vector2(330, 0)
		_bind_buttons[b[0]] = btn
	UI.button("Reset controls to defaults", c, func(): GameSettings.reset_bindings(); _refresh())
	return p.get_parent()

func _refresh() -> void:
	for d in _diff_buttons:
		_diff_buttons[d].button_pressed = d == GameSettings.difficulty
	if _diff_label:
		_diff_label.text = DIFF_TEXT.get(GameSettings.difficulty, "")
	for pr in _preset_buttons:
		_preset_buttons[pr].button_pressed = pr == GameSettings.preset
	if _preset_label:
		_preset_label.text = PRESET_TEXT.get(GameSettings.preset, "")
	for a in _bind_buttons:
		_bind_buttons[a].text = "Press a key or mouse button..." if a == _waiting_action else GameSettings.binding_text(a)
