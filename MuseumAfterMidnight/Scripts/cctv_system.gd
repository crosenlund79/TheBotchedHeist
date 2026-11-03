extends Node
## Plays security-camera replays: the recorded player transforms and animation are re-enacted
## by a ghost copy of the character, seen through the camera's fixed Camera3D, with a CCTV
## overlay (REC indicator, timestamp, scanlines). Gameplay resumes automatically afterwards.

const MIN_REPLAY := 3.0
const MAX_REPLAY := 5.0
const CLOCK_START := 47 * 60 + 12.0   # the night shift clock starts at 00:47:12

var player: Node3D
var _ghost: Node3D
var _ghost_anim: AnimationPlayer
var _samples: Array = []
var _cam_node: Node
var _t0 := 0.0
var _t := 0.0
var _length := 0.0
var _active := false
var _clock := 0.0

var _layer: CanvasLayer
var _rec: Label
var _stamp: Label
var _name: Label
var _info: Label

func clock() -> float:
	return _clock

func is_replaying() -> bool:
	return _active

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_build_overlay()

func _process(delta: float) -> void:
	_clock += delta
	if not _active:
		return
	_t += delta
	var t: float = min(_t0 + _t, _samples[-1].clock)
	var i := 0
	while i < _samples.size() - 2 and _samples[i + 1].clock < t:
		i += 1
	var a: Dictionary = _samples[i]
	var b: Dictionary = _samples[min(i + 1, _samples.size() - 1)]
	var w := 0.0 if b.clock <= a.clock else clampf((t - a.clock) / (b.clock - a.clock), 0.0, 1.0)
	_ghost.global_position = a.pos.lerp(b.pos, w)
	_ghost.rotation.y = lerp_angle(a.yaw, b.yaw, w)
	var clip := "m/" + str(a.clip)
	if _ghost_anim.current_animation != clip:
		_ghost_anim.play(clip, 0.15)
	var pos: float = a.t + (t - a.clock) * float(a.get("speed", 1.0))
	_ghost_anim.seek(fmod(pos, maxf(_ghost_anim.current_animation_length, 0.01)), true)
	_rec.visible = fmod(_t, 1.0) < 0.6
	_stamp.text = _format_clock(t)
	_info.text = "PLAYBACK  ◀◀  %ds" % int(ceil(_length - _t))
	if _t >= _length:
		_finish()

func play_replay(cam: Node, samples: Array) -> void:
	if _active or samples.size() < 2:
		return
	var end_t: float = samples[-1].clock
	_t0 = maxf(samples[0].clock, end_t - MAX_REPLAY)
	_length = clampf(end_t - _t0, MIN_REPLAY, MAX_REPLAY)   # short clips hold their last frame
	_samples = samples
	_t = 0.0
	_cam_node = cam
	_active = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.visible = false
	_ghost = load(player.MODEL).instantiate()
	add_child(_ghost)
	if _ghost is CollisionObject3D:
		(_ghost as CollisionObject3D).collision_layer = 0
		(_ghost as CollisionObject3D).collision_mask = 0
	_ghost_anim = _ghost.get_node("AnimationPlayer")
	_ghost_anim.add_animation_library("m", load(player.ANIMS))
	cam.camera.make_current()
	_name.text = cam.camera_name
	_layer.visible = true

func _finish() -> void:
	_active = false
	_layer.visible = false
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	player.visible = true
	player.set_physics_process(true)
	player.controls_enabled = true
	player.camera.make_current()

func _format_clock(t: float) -> String:
	var d := Time.get_date_dict_from_system()
	var s := int(CLOCK_START + t)
	return "%04d-%02d-%02d  %02d:%02d:%02d" % [d.year, d.month, d.day, (s / 3600) % 24, (s / 60) % 60, s % 60]

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g) * vec3(0.82, 1.0, 0.9), 0.7);
	c = 1.0 - exp(-c * 2.2);  // lift the dark gallery like a CCTV sensor
	c *= 0.9 + 0.1 * sin(uv.y * 720.0);
	float n = fract(sin(dot(uv * vec2(12.9898, 78.233) + vec2(TIME * 3.1, TIME * 1.7), vec2(1.0))) * 43758.5453);
	c += (n - 0.5) * 0.07;
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * 1.3;
	COLOR = vec4(c, 1.0);
}
"""
	var mat := ShaderMaterial.new(); mat.shader = sh
	fx.material = mat
	_layer.add_child(fx)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(margin)
	var grid := VBoxContainer.new()
	margin.add_child(grid)
	var top := HBoxContainer.new(); grid.add_child(top)
	var bottom := HBoxContainer.new()
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_child(spacer); grid.add_child(bottom)
	_rec = _mk_label("●  REC", 34, Color(1, 0.15, 0.15), top)
	var s1 := Control.new(); s1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(s1)
	_stamp = _mk_label("", 28, Color(0.92, 0.95, 0.9), top)
	_name = _mk_label("", 26, Color(0.92, 0.95, 0.9), bottom)
	var s2 := Control.new(); s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bottom.add_child(s2)
	_info = _mk_label("", 26, Color(0.92, 0.95, 0.9), bottom)

func _mk_label(t: String, size: int, col: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l
