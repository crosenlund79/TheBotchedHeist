extends Node
## Security-camera system.
##  * Recorder: 10 times a second it snapshots every node in group "recordable" (player, enemies,
##    camera-only phantoms) into one rolling 90-second world-state buffer, plus timestamped events
##    (awakenings, shattered cases, phantoms, glitches...). Recording pauses with the game.
##  * Clips: when the player leaves a recording camera's area, a clip [enter, exit] becomes
##    available and a picture-in-picture replay of its last seconds plays in the corner.
##  * Terminal (security office): every camera, live view or playback of the whole buffer from
##    that camera's viewpoint, with play/pause, rewind, speed and a scrub timeline, alarm controls,
##    museum status, round statistics and the event log. The game is paused while it is open.
##  * Monitor wall in the office: live feeds on Medium/High, animated static on Low.
## Playback rebuilds puppets on render layer 8 and never alters gameplay.

const PLAYBACK := preload("res://Scripts/cctv_playback.gd")
const RATE := 10.0
const BUFFER := 90.0
const PIP_SECONDS := 7.0
const CLOCK_START := 47 * 60 + 12.0   # the night shift clock starts at 00:47:12
const SPEEDS := [0.5, 1.0, 2.0, 4.0]

var frames: Array = []        # {t, ents: {id: snapshot}}
var events: Array = []        # {t, type, pos, text, cam?, dur?}
var clips: Array = []         # {cam, t0, t1}
var _t := 0.0
var _accum := 0.0
var director: Node

var pip: Node
var term: Node
var _pip_layer: CanvasLayer
var _pip_rect: TextureRect
var _pip_label: Label
var _pip_stamp: Label
var _pip_t := 0.0

var _term_layer: CanvasLayer
var _term_view: TextureRect
var _term_cam_list: VBoxContainer
var _term_title: Label
var _term_stamp: Label
var _term_mode: Label
var _term_caption: Label
var _term_slider: HSlider
var _term_play: Button
var _term_speed: Button
var _term_status: Label
var _term_log: Label
var _term_clips: HBoxContainer
var _term_cam: Node3D
var _term_open := false
var _slider_lock := false
var _speed_i := 1

var _monitors: Array = []     # {screen, viewport, cam, source}
var _monitor_i := 0
var _monitor_t := 0.0
var _noise_mat: ShaderMaterial

func _ready() -> void:
	add_to_group("cctv")
	process_mode = Node.PROCESS_MODE_ALWAYS
	pip = PLAYBACK.new()
	add_child(pip)
	pip.setup(self, Vector2i(480, 270), false)
	term = PLAYBACK.new()
	add_child(term)
	term.setup(self, Vector2i(1024, 576), true)
	_build_pip()
	_build_terminal()
	GameSettings.preset_changed.connect(func(_p): _setup_monitors.call_deferred())
	_setup_monitors.call_deferred()

func now() -> float:
	return _t

func cameras() -> Array:
	return get_tree().get_nodes_in_group("security_cameras")

# ------------------------------------------------------------------ recorder

func _process(delta: float) -> void:
	if not get_tree().paused:
		_t += delta
		_accum += delta
		if _accum >= 1.0 / RATE:
			_accum = 0.0
			_sample()
		_update_pip(delta)
		_update_monitors(delta)
	if _term_open:
		_update_terminal()

func _sample() -> void:
	var ents := {}
	for n in get_tree().get_nodes_in_group("recordable"):
		if n.has_method("snapshot") and n.is_inside_tree():
			var s: Dictionary = n.snapshot()
			ents[s.get("id", "player")] = s
	frames.append({"t": _t, "ents": ents})
	while frames.size() > 2 and _t - float(frames[0].t) > BUFFER:
		frames.pop_front()
	while events.size() > 0 and _t - float(events[0].t) > BUFFER:
		events.pop_front()
	while clips.size() > 0 and float(clips[0].t1) < buffer_start():
		clips.pop_front()

func buffer_start() -> float:
	return float(frames[0].t) if frames.size() > 0 else 0.0

## Bracketing frames for time t: [a, b, weight] (empty when nothing is recorded).
func frames_at(time: float) -> Array:
	if frames.is_empty():
		return []
	if time <= float(frames[0].t):
		return [frames[0], frames[0], 0.0]
	if time >= float(frames[-1].t):
		return [frames[-1], frames[-1], 0.0]
	var lo := 0
	var hi := frames.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if float(frames[mid].t) <= time:
			lo = mid
		else:
			hi = mid
	var a: Dictionary = frames[lo]
	var b: Dictionary = frames[hi]
	return [a, b, clampf((time - float(a.t)) / maxf(float(b.t) - float(a.t), 0.001), 0.0, 1.0)]

func record_event(type: String, pos: Vector3, text: String, extra := {}) -> void:
	var e := {"t": _t, "type": type, "pos": pos, "text": text}
	e.merge(extra)
	events.append(e)

## True if `cam` was glitched (signal lost) at time t.
func glitched_at(cam: Node, time: float) -> bool:
	for e in events:
		if e.type == "glitch" and e.get("cam") == cam and time >= e.t and time <= e.t + float(e.get("dur", 0.0)):
			return true
	return false

func format_clock(time: float) -> String:
	var d := Time.get_date_dict_from_system()
	var s := int(CLOCK_START + time)
	return "%04d-%02d-%02d  %02d:%02d:%02d" % [d.year, d.month, d.day, (s / 3600) % 24, (s / 60) % 60, s % 60]

# ------------------------------------------------------------------ clips & picture-in-picture

func on_camera_clip(cam: Node3D, t0: float, t1: float) -> void:
	if t1 - t0 < 1.5:
		return
	t0 = maxf(t0, buffer_start())
	clips.append({"cam": cam, "t0": t0, "t1": t1})
	if clips.size() > 24:
		clips.pop_front()
	var hud := get_parent().get_node_or_null("HUD")
	if hud:
		hud.toast("New recording: %s  -  view it at the Security Office terminal" % cam.camera_name, 4.0)
	if not _term_open:
		pip.start(cam, maxf(t0, t1 - PIP_SECONDS), t1)
		_pip_label.text = "%s   ·   PLAYBACK" % cam.camera_name
		_pip_t = 0.0
		_pip_layer.visible = true

func _build_pip() -> void:
	_pip_layer = CanvasLayer.new()
	_pip_layer.layer = 3
	_pip_layer.visible = false
	add_child(_pip_layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.75), 6, 6))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -500
	panel.offset_right = -16
	panel.offset_top = 70
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_layer.add_child(panel)
	var v := UI.vbox(panel, 4)
	_pip_rect = TextureRect.new()
	_pip_rect.texture = pip.texture()
	_pip_rect.custom_minimum_size = Vector2(480, 270)
	_pip_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_pip_rect.material = UI.cctv_material()
	_pip_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_pip_rect)
	var h := UI.hbox(v)
	_pip_label = UI.label("", 14, Color(1, 0.35, 0.3), h)
	UI.spacer(h)
	_pip_stamp = UI.label("", 14, UI.TEXT, h)

func _update_pip(delta: float) -> void:
	if not _pip_layer.visible:
		return
	_pip_t += delta
	_pip_stamp.text = format_clock(pip.t)
	_pip_rect.material.set_shader_parameter("static_amt", 1.0 if pip.signal_lost() else 0.0)
	if (not pip.playing and _pip_t > 1.0) or _pip_t > PIP_SECONDS + 2.0:
		_pip_layer.visible = false
		pip.stop()

# ------------------------------------------------------------------ terminal

func is_terminal_open() -> bool:
	return _term_open

func open_terminal() -> void:
	if _term_open:
		return
	_term_open = true
	pip.stop()
	_pip_layer.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_term_layer.visible = true
	_rebuild_cam_list()
	var cams := cameras()
	var pick: Node3D = clips[-1].cam if clips.size() > 0 else (cams[0] if cams.size() > 0 else null)
	if pick:
		_select_cam(pick, clips.size() > 0)
	Sfx.play(self, "power_up", null, -10.0, 1.3)

func close_terminal() -> void:
	if not _term_open:
		return
	_term_open = false
	term.stop()
	_term_layer.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if _term_open and (event.is_action_pressed("menu") or event.is_action_pressed("interact")):
		close_terminal()
		get_viewport().set_input_as_handled()

func _select_cam(cam: Node3D, latest_clip := false) -> void:
	_term_cam = cam
	_term_title.text = cam.camera_name + ("" if cam.recording else "   (live only - not recording)")
	_rebuild_clips()
	if cam.recording and frames.size() > 1:
		var t0 := buffer_start()
		var t1 := _t
		var from := maxf(t0, t1 - 10.0)
		var own: Array = clips.filter(func(c): return c.cam == cam)
		if latest_clip and own.size() > 0:
			from = own[-1].t0
		term.start(cam, t0, t1, from)
		term.speed = SPEEDS[_speed_i]
	else:
		term.start_live(cam)

func _go_live() -> void:
	if _term_cam:
		term.start_live(_term_cam)

func _build_terminal() -> void:
	_term_layer = CanvasLayer.new()
	_term_layer.layer = 12
	_term_layer.visible = false
	add_child(_term_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.02, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_term_layer.add_child(bg)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 22)
	_term_layer.add_child(root)
	var cols := UI.hbox(root, 16)
	# Left column: cameras.
	var left := UI.vbox(cols, 8)
	left.custom_minimum_size = Vector2(230, 0)
	UI.label("SECURITY TERMINAL", 22, UI.GOLD, left)
	UI.header("CAMERAS", left)
	_term_cam_list = UI.vbox(left, 6)
	UI.spacer(left, false)
	UI.label("Esc / E  -  close terminal", 14, UI.DIM, left)
	UI.button("Close terminal", left, close_terminal)
	# Centre: footage and transport controls.
	var mid := UI.vbox(cols, 8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(mid)
	_term_title = UI.label("", 20, UI.TEXT, top)
	UI.spacer(top)
	_term_mode = UI.label("", 20, Color(1, 0.3, 0.25), top)
	var frame := Control.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(480, 270)
	mid.add_child(frame)
	_term_view = TextureRect.new()
	_term_view.texture = term.texture()
	_term_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_term_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_term_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_term_view.material = UI.cctv_material()
	frame.add_child(_term_view)
	_term_stamp = UI.label("", 18, UI.TEXT, frame)
	_term_stamp.position = Vector2(20, 14)
	_term_caption = UI.label("", 20, Color(0.6, 1.0, 0.8), frame)
	_term_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_term_caption.position = Vector2(20, 0)
	_term_caption.offset_top = -44
	_term_slider = HSlider.new()
	_term_slider.step = 0.05
	_term_slider.custom_minimum_size = Vector2(0, 26)
	_term_slider.value_changed.connect(func(v):
		if not _slider_lock and not term.live:
			term.seek(v))
	mid.add_child(_term_slider)
	_term_clips = UI.hbox(mid, 6)
	_term_clips.custom_minimum_size = Vector2(0, 34)
	var ctr := UI.hbox(mid, 6)
	ctr.add_theme_font_size_override("font_size", 15)
	UI.button("|< Clip", ctr, func():
		var own: Array = clips.filter(func(c): return c.cam == _term_cam)
		if own.size() > 0 and not term.live: term.seek(own[-1].t0))
	UI.button("-5s", ctr, func(): if not term.live: term.seek(term.t - 5.0))
	_term_play = UI.button("Pause", ctr, func():
		if term.live: return
		if not term.playing and term.t >= term.t_end - 0.05: term.seek(term.t_start)
		term.playing = not term.playing)
	UI.button("+5s", ctr, func(): if not term.live: term.seek(term.t + 5.0))
	_term_speed = UI.button("Speed 1x", ctr, func():
		_speed_i = (_speed_i + 1) % SPEEDS.size()
		term.speed = SPEEDS[_speed_i])
	UI.button("<< Rewind", ctr, func():
		if not term.live:
			term.speed = -2.0
			term.playing = true)
	UI.spacer(ctr)
	UI.button("LIVE", ctr, _go_live)
	# Right column: museum status, alarm, statistics, event log.
	var right := UI.vbox(cols, 8)
	right.custom_minimum_size = Vector2(270, 0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	UI.header("MUSEUM STATUS", right)
	_term_status = UI.label("", 15, UI.TEXT, right)
	_term_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_term_status.custom_minimum_size = Vector2(270, 0)
	UI.header("ALARM", right)
	var ah := UI.hbox(right)
	UI.button("Trigger alarm", ah, func(): if director: director.set_alarm(true))
	UI.button("Silence", ah, func(): if director: director.set_alarm(false))
	UI.header("EVENT LOG", right)
	_term_log = UI.label("", 14, UI.DIM, right)
	_term_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_term_log.custom_minimum_size = Vector2(270, 0)

func _rebuild_cam_list() -> void:
	for c in _term_cam_list.get_children():
		c.queue_free()
	for cam in cameras():
		var n: int = clips.filter(func(c): return c.cam == cam).size()
		var tag := ("REC" if cam.recording else "LIVE") + ("  ·  %d clip%s" % [n, "" if n == 1 else "s"] if cam.recording else "")
		var b := UI.button("%s\n%s" % [cam.camera_name, tag], _term_cam_list, _select_cam.bind(cam))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _rebuild_clips() -> void:
	for c in _term_clips.get_children():
		c.queue_free()
	var own: Array = clips.filter(func(c): return c.cam == _term_cam)
	if own.is_empty():
		UI.label("No player clips on this camera yet - full buffer available on the timeline." if _term_cam and _term_cam.recording else "This camera does not record.", 14, UI.DIM, _term_clips)
		return
	UI.label("Clips:", 14, UI.DIM, _term_clips)
	for c in own.slice(maxi(own.size() - 6, 0)):
		var cc: Dictionary = c
		var cb := UI.button("%s (%ds)" % [format_clock(cc.t0).get_slice("  ", 1), int(cc.t1 - cc.t0)], _term_clips, func():
			if term.live: term.start(_term_cam, buffer_start(), _t, cc.t0)
			else: term.seek(cc.t0)
			term.playing = true)
		cb.add_theme_font_size_override("font_size", 14)

func _update_terminal() -> void:
	var lost: bool = term.signal_lost()
	_term_view.material.set_shader_parameter("static_amt", 1.0 if lost else 0.0)
	if term.live:
		_term_mode.text = "LIVE"
		_term_stamp.text = format_clock(_t) + ("    NO SIGNAL" if lost else "")
		_term_caption.text = ""
		_slider_lock = true
		_term_slider.min_value = 0
		_term_slider.max_value = 1
		_term_slider.value = 1
		_slider_lock = false
	else:
		_term_mode.text = ("PLAYBACK" if term.playing else "PAUSED") + "  %sx" % str(term.speed)
		_term_stamp.text = format_clock(term.t) + ("    NO SIGNAL" if lost else "")
		_slider_lock = true
		_term_slider.min_value = term.t_start
		_term_slider.max_value = term.t_end
		_term_slider.value = term.t
		_slider_lock = false
		var cap := ""
		for e in events:
			if e.t <= term.t and e.t > term.t - 3.0 and _term_cam and (_term_cam.covers(e.pos) or e.type in ["blackout", "alarm"]):
				cap = "! " + e.text
		_term_caption.text = cap
	_term_play.text = "Pause" if term.playing else "Play"
	_term_speed.text = "Speed %sx" % str(SPEEDS[_speed_i])
	if director:
		_term_status.text = director.status_text()
	var lines := []
	for e in events.slice(maxi(events.size() - 9, 0)):
		lines.append("%s  %s" % [format_clock(e.t).get_slice("  ", 1), e.text])
	lines.reverse()
	_term_log.text = "\n".join(lines) if lines.size() > 0 else "No incidents recorded."

# ------------------------------------------------------------------ office monitor wall

func _setup_monitors() -> void:
	for m in _monitors:
		if is_instance_valid(m.viewport):
			m.viewport.queue_free()
	_monitors.clear()
	var museum := get_parent()
	if not ("monitor_screens" in museum):
		return
	if _noise_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded;
void fragment() {
	float n = fract(sin(dot(floor(UV * vec2(160.0, 90.0)) + vec2(TIME * 37.0, TIME * 11.0), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = vec3(n * 0.55 + 0.05) * vec3(0.8, 1.0, 0.9);
}
"""
		_noise_mat = ShaderMaterial.new()
		_noise_mat.shader = sh
	var cams := cameras()
	var live_feeds := GameSettings.preset != "Low"
	for i in museum.monitor_screens.size():
		var screen: MeshInstance3D = museum.monitor_screens[i]
		var src: Node3D = cams[i % cams.size()] if cams.size() > 0 else null
		if not live_feeds or src == null:
			screen.material_override = _noise_mat
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i(256, 144)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.positional_shadow_atlas_size = 0
		add_child(vp)
		var c := Camera3D.new()
		c.cull_mask = 1 | 2 | 4
		vp.add_child(c)
		c.global_transform = src.camera.global_transform
		c.fov = src.camera.fov
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = vp.get_texture()
		screen.material_override = mat
		_monitors.append({"screen": screen, "viewport": vp, "mat": mat, "source": src})

func _update_monitors(delta: float) -> void:
	if _monitors.is_empty():
		return
	_monitor_t -= delta
	if _monitor_t > 0.0:
		return
	_monitor_t = 0.12
	# Only refresh feeds while the player is near the office.
	var player := get_tree().get_first_node_in_group("player")
	if player and player.global_position.distance_to(Vector3(15, 0, -12.5)) > 14.0:
		return
	var m: Dictionary = _monitors[_monitor_i % _monitors.size()]
	_monitor_i += 1
	if m.source.is_working():
		m.screen.material_override = m.mat
		m.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		m.screen.material_override = _noise_mat
