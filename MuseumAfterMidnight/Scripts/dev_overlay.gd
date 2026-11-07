extends CanvasLayer
## Developer overlay (F1, hidden by default): cheats, spawning, round control, haunting events,
## lights, zone teleports, AI state readout, camera status, FPS and entity counts.

var _panel: PanelContainer
var _info: Label
var _t := 0.0
var _lights_on := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	_panel = PanelContainer.new()
	_panel.theme = UI.theme()
	_panel.position = Vector2(16, 90)
	_panel.visible = false
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var v := UI.vbox(scroll, 6)
	UI.label("DEVELOPER  (F1)", 20, UI.GOLD, v)
	for f in [["Invulnerable", "invulnerable"], ["Unlimited ammo", "infinite_ammo"], ["Show AI states", "show_ai"]]:
		var cb := CheckButton.new()
		cb.text = f[0]
		cb.toggled.connect(func(on):
			match f[1]:
				"invulnerable": Dev.invulnerable = on
				"infinite_ammo": Dev.infinite_ammo = on
				"show_ai": Dev.show_ai = on
			var p := get_tree().get_first_node_in_group("player")
			if p and f[1] == "infinite_ammo": p.weapons._emit_ammo())
		v.add_child(cb)
	UI.header("SPAWN ENEMY", v)
	var sr := UI.hbox(v, 4)
	for pair in [["Exhibit", Enemy.Kind.EXHIBIT], ["Staff", Enemy.Kind.STAFF], ["Entity", Enemy.Kind.ENTITY], ["Beast", Enemy.Kind.BEAST]]:
		UI.button(pair[0], sr, func(): _dir("dev_spawn", [pair[1]]))
	UI.header("ROUND", v)
	var rr := UI.hbox(v, 4)
	UI.button("Remove all enemies", rr, func(): _dir("dev_remove_all", []))
	UI.button("Complete round", rr, func(): _dir("dev_complete_round", []))
	UI.header("HAUNTING EVENTS", v)
	var grid := GridContainer.new()
	grid.columns = 2
	v.add_child(grid)
	for ev in preload("res://Scripts/haunting.gd").EVENTS:
		var b := UI.button(ev.replace("_", " "), grid, func():
			var d := _director()
			if d and d.haunting: d.haunting.trigger(ev))
		b.custom_minimum_size = Vector2(200, 0)
	UI.button("Toggle museum lights", v, _toggle_lights)
	UI.header("TELEPORT", v)
	var tg := GridContainer.new()
	tg.columns = 2
	v.add_child(tg)
	var museum := get_parent()
	for i in museum.zones.size():
		var b := UI.button(museum.zones[i].name, tg, func(): _dir("dev_teleport", [i]))
		b.custom_minimum_size = Vector2(200, 0)
		b.clip_text = true
	UI.header("STATUS", v)
	_info = UI.label("", 13, UI.TEXT, v, false)

func _director() -> Node:
	return get_parent().get_node_or_null("Director")

func _dir(method: String, args: Array) -> void:
	var d := _director()
	if d:
		d.callv(method, args)

func _toggle_lights() -> void:
	_lights_on = not _lights_on
	var museum := get_parent()
	for l in museum.lights_in(Rect2(-25, -30, 50, 45)):
		l.visible = _lights_on

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_overlay"):
		var d := _director()
		if d == null or not d.started:
			return
		_panel.visible = not _panel.visible
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _panel.visible else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var d := _director()
	var lines := ["FPS %d   ·   draw calls %d" % [Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]]
	var enemies := get_tree().get_nodes_in_group("enemies")
	lines.append("Enemies: %d   Recordables: %d   Nodes: %d" % [enemies.size(), get_tree().get_nodes_in_group("recordable").size(), get_tree().get_node_count()])
	if d:
		lines.append("Round %d  remaining %d/%d  pending %d  bonus %d" % [d.round_num, d.remaining(), d.round_total, d.pending.size(), d.bonus_spawned])
		lines.append("Haunting intensity %d%%  last: %s" % [int(d.haunting.intensity * 100), d.haunting.last_event])
	var cctv := get_parent().get_node_or_null("CCTV")
	if cctv:
		lines.append("CCTV buffer %.0fs  frames %d  events %d  clips %d" % [cctv.now() - cctv.buffer_start(), cctv.frames.size(), cctv.events.size(), cctv.clips.size()])
		for cam in cctv.cameras():
			lines.append("  %s  %s%s" % [cam.camera_name, "REC" if cam.recording else "LIVE", "" if cam.is_working() else "  NO SIGNAL"])
	lines.append("AI:")
	for e in enemies:
		lines.append("  %s · %s · %d hp · %s" % [Enemy.KIND_NAMES[e.kind], Enemy.STATE_NAMES[e.state], int(e.hp), get_parent().zone_name(e.global_position)])
	_info.text = "\n".join(lines)
