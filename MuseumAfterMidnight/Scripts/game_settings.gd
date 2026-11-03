extends Node
## Input actions and the three graphics presets. The preset is applied immediately,
## remembered in user://settings.cfg, and defaults to Low.

signal preset_changed(preset: String)

const PRESETS := ["Low", "Medium", "High"]
const CONFIG_PATH := "user://settings.cfg"

var preset := "Low"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_key("move_forward", [KEY_W, KEY_UP])
	_add_key("move_back", [KEY_S, KEY_DOWN])
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("run", [KEY_SHIFT])
	_add_key("menu", [KEY_ESCAPE])
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mb)
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		preset = str(cfg.get_value("graphics", "preset", "Low"))
	if not PRESETS.has(preset):
		preset = "Low"
	# Lights and environment in the scene are configured once the scene is ready.
	get_tree().node_added.connect(_on_node_added)
	apply.call_deferred()

func _add_key(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func set_preset(p: String) -> void:
	if not PRESETS.has(p):
		return
	preset = p
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("graphics", "preset", p)
	cfg.save(CONFIG_PATH)
	apply()

func _on_node_added(n: Node) -> void:
	if n is Light3D:
		_apply_light.call_deferred(n)

## Applies the current preset to the viewport, the WorldEnvironment and every light.
func apply() -> void:
	var vp := get_viewport()
	var env: Environment = null
	for we in get_tree().get_nodes_in_group("world_environment"):
		env = (we as WorldEnvironment).environment
	match preset:
		"Low":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.67
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 1024
			RenderingServer.directional_shadow_atlas_set_size(1024, false)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			vp.mesh_lod_threshold = 4.0
		"Medium":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 2048
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			vp.mesh_lod_threshold = 2.0
		"High":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.positional_shadow_atlas_size = 4096
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			vp.mesh_lod_threshold = 1.0
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
	preset_changed.emit(preset)

## Lights opt in with groups:
##   "shadow_med"  casts shadows on Medium and High (key lights)
##   "shadow_high" casts shadows on High only (exhibit spots)
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
