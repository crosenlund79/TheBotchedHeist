extends Node
## Global settings (autoload "GameSettings"): controls and remapping, graphics presets,
## difficulty, audio volumes, mouse sensitivity and the best completed round.
## Everything is saved in user://settings.cfg.

signal preset_changed(preset: String)
signal settings_changed

const PRESETS := ["Low", "Medium", "High"]
const DIFFICULTIES := ["Tourist", "Security Guard", "Nightmare"]
const CONFIG_PATH := "user://settings.cfg"

## Difficulty changes composition and behaviour, not only numbers.
const DIFFICULTY := {
	"Tourist": {"count": 0.7, "damage": 0.5, "reaction": 1.7, "detect": 0.8, "speed": 0.9, "ammo": 2.0,
		"events": 0.7, "markers": true, "max_round_scale": 4, "entity_round": 3, "beast_round": 5, "regen": true},
	"Security Guard": {"count": 1.0, "damage": 1.0, "reaction": 1.0, "detect": 1.0, "speed": 1.0, "ammo": 1.3,
		"events": 1.0, "markers": false, "max_round_scale": 6, "entity_round": 2, "beast_round": 3, "regen": false},
	"Nightmare": {"count": 1.35, "damage": 1.45, "reaction": 0.55, "detect": 1.3, "speed": 1.12, "ammo": 0.9,
		"events": 1.6, "markers": false, "max_round_scale": 8, "entity_round": 1, "beast_round": 2, "regen": false},
}

## Actions shown on the controls screen, with their default bindings.
## Keys use physical keycodes; ints in 1000..1099 are mouse buttons (1000 + button index).
## (Special keys such as Shift or Esc have keycodes above 4 million, so they never collide.)
const BINDINGS := [
	["move_forward", "Move forward", [KEY_W, KEY_UP]],
	["move_back", "Move back", [KEY_S, KEY_DOWN]],
	["move_left", "Move left", [KEY_A, KEY_LEFT]],
	["move_right", "Move right", [KEY_D, KEY_RIGHT]],
	["run", "Sprint", [KEY_SHIFT]],
	["crouch", "Crouch", [KEY_C, KEY_CTRL]],
	["shoot", "Fire", [1000 + MOUSE_BUTTON_LEFT]],
	["aim", "Aim", [1000 + MOUSE_BUTTON_RIGHT]],
	["reload", "Reload", [KEY_R]],
	["interact", "Interact", [KEY_E]],
	["weapon_1", "Rifle", [KEY_1]],
	["weapon_2", "Handgun", [KEY_2]],
	["flashlight", "Flashlight", [KEY_F]],
	["shoulder", "Swap shoulder", [KEY_V]],
	["menu", "Pause", [KEY_ESCAPE]],
	["dev_overlay", "Developer overlay", [KEY_F1]],
]

var preset := "Low"
var difficulty := "Tourist"
var volumes := {"Master": 0.85, "SFX": 0.9, "Ambience": 0.7}
var mouse_sensitivity := 1.0
var invert_y := false
var best_round := 0
var particle_density := 0.5
var live_monitors := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	var cfg := ConfigFile.new()
	var has_cfg := cfg.load(CONFIG_PATH) == OK
	for b in BINDINGS:
		var saved = cfg.get_value("input", b[0]) if has_cfg and cfg.has_section_key("input", b[0]) else null
		_bind(b[0], saved if saved is Array else b[2])
	if has_cfg:
		preset = str(cfg.get_value("graphics", "preset", "Low"))
		difficulty = str(cfg.get_value("game", "difficulty", "Tourist"))
		mouse_sensitivity = float(cfg.get_value("game", "sensitivity", 1.0))
		invert_y = bool(cfg.get_value("game", "invert_y", false))
		best_round = int(cfg.get_value("game", "best_round", 0))
		for k in volumes:
			volumes[k] = float(cfg.get_value("audio", k, volumes[k]))
	if not PRESETS.has(preset): preset = "Low"
	if not DIFFICULTIES.has(difficulty): difficulty = "Tourist"
	_apply_volumes()
	get_tree().node_added.connect(_on_node_added)
	apply.call_deferred()

func diff(key: String):
	return DIFFICULTY[difficulty][key]

# ------------------------------------------------------------------ input

func _bind(action: String, codes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	for c in codes:
		InputMap.action_add_event(action, _event_for(int(c)))

func _event_for(code: int) -> InputEvent:
	if is_mouse_code(code):
		var mb := InputEventMouseButton.new()
		mb.button_index = code - 1000
		return mb
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev

static func is_mouse_code(code: int) -> bool:
	return code >= 1000 and code < 1100

static func code_of(ev: InputEvent) -> int:
	if ev is InputEventMouseButton:
		return 1000 + (ev as InputEventMouseButton).button_index
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return k.physical_keycode if k.physical_keycode != 0 else k.keycode
	return -1

static func code_name(code: int) -> String:
	if is_mouse_code(code):
		return {1: "Left mouse", 2: "Right mouse", 3: "Middle mouse", 4: "Wheel up", 5: "Wheel down"}.get(code - 1000, "Mouse %d" % (code - 1000))
	return OS.get_keycode_string(code)

func binding_text(action: String) -> String:
	var names := []
	for ev in InputMap.action_get_events(action):
		names.append(code_name(code_of(ev)))
	return " / ".join(names)

## Rebinds an action to a single new input (keeps it saved).
func rebind(action: String, ev: InputEvent) -> void:
	var code := code_of(ev)
	if code < 0:
		return
	_bind(action, [code])
	save()

func reset_bindings() -> void:
	for b in BINDINGS:
		_bind(b[0], b[2])
	save()

# ------------------------------------------------------------------ persistence

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("graphics", "preset", preset)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "sensitivity", mouse_sensitivity)
	cfg.set_value("game", "invert_y", invert_y)
	cfg.set_value("game", "best_round", best_round)
	for k in volumes:
		cfg.set_value("audio", k, volumes[k])
	for b in BINDINGS:
		var codes := []
		for ev in InputMap.action_get_events(b[0]):
			codes.append(code_of(ev))
		cfg.set_value("input", b[0], codes)
	cfg.save(CONFIG_PATH)
	settings_changed.emit()

func set_preset(p: String) -> void:
	if not PRESETS.has(p):
		return
	preset = p
	save()
	apply()

func set_difficulty(d: String) -> void:
	if DIFFICULTIES.has(d):
		difficulty = d
		save()

func record_round(r: int) -> void:
	if r > best_round:
		best_round = r
		save()

# ------------------------------------------------------------------ audio

func _setup_audio_buses() -> void:
	for n in ["SFX", "Ambience"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
	# A little room reverb on effects sells the empty museum.
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.65; rv.damping = 0.4; rv.wet = 0.18; rv.dry = 1.0
		AudioServer.add_bus_effect(sfx, rv)

func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	_apply_volumes()
	save()

func _apply_volumes() -> void:
	for k in volumes:
		var i := AudioServer.get_bus_index(k)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[k], 0.0001)))
			AudioServer.set_bus_mute(i, volumes[k] <= 0.001)

# ------------------------------------------------------------------ graphics

func _on_node_added(n: Node) -> void:
	if n is Light3D:
		_apply_light.call_deferred(n)
	elif n is CPUParticles3D or n is GPUParticles3D:
		_apply_particles.call_deferred(n)

## Applies the current preset to the viewport, the WorldEnvironment, lights and particles.
func apply() -> void:
	var vp := get_viewport()
	var env: Environment = null
	for we in get_tree().get_nodes_in_group("world_environment"):
		env = (we as WorldEnvironment).environment
	var web := OS.has_feature("web")
	match preset:
		"Low":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if web else Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.67
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 1024
			RenderingServer.directional_shadow_atlas_set_size(1024, false)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			vp.mesh_lod_threshold = 4.0
			particle_density = 0.5
			live_monitors = false
		"Medium":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if web else Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 2048
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			vp.mesh_lod_threshold = 2.0
			particle_density = 0.8
			live_monitors = true
		"High":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.positional_shadow_atlas_size = 4096
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			vp.mesh_lod_threshold = 1.0
			particle_density = 1.0
			live_monitors = true
	if env:
		env.ssao_enabled = preset != "Low"
		env.ssil_enabled = preset == "High"
		env.ssr_enabled = preset == "High"
		env.glow_enabled = preset != "Low"
		env.volumetric_fog_enabled = preset == "High"
		env.fog_enabled = true
		env.sdfgi_enabled = false
		RenderingServer.environment_set_ssao_quality(
			RenderingServer.ENV_SSAO_QUALITY_HIGH if preset == "High" else RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50, 300)
	for l in get_tree().get_nodes_in_group("preset_light"):
		_apply_light(l)
	for n in get_tree().get_nodes_in_group("detail_fx"):
		if n is Node3D:
			(n as Node3D).visible = preset != "Low"
	preset_changed.emit(preset)

## Lights opt in with groups:
##   "shadow_med"   casts shadows on Medium and High (key lights)
##   "shadow_high"  casts shadows on High only (exhibit spots)
##   "detail_light" is switched off on Low (purely decorative fills)
func _apply_light(l: Node) -> void:
	if not is_instance_valid(l) or not (l is Light3D):
		return
	var light := l as Light3D
	if light.is_in_group("shadow_med"):
		light.shadow_enabled = preset != "Low"
	elif light.is_in_group("shadow_high"):
		light.shadow_enabled = preset == "High"
	if light.is_in_group("detail_light"):
		light.visible = preset != "Low"

## One-shot effect particles scale their amount with the preset (gameplay effects keep a minimum).
func _apply_particles(p: Node) -> void:
	if not is_instance_valid(p) or not p.has_meta("base_amount"):
		return
	p.amount = maxi(int(p.get_meta("base_amount") * particle_density), 4)
