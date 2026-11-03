extends Node3D
## A ceiling-mounted security camera (Synty Heist SM_Prop_Camera_01) with a blinking red light.
## While the player is inside its detection area it records their transform and animation
## state; shortly after they leave, it asks the CCTV system to replay the last few seconds
## from this camera's fixed viewpoint.

const PROP := "res://Assets/Synty/PolygonHeist/Prefab/Props/SM_Prop_Camera_01.tscn"
const SAMPLE_RATE := 30.0
const BUFFER_SECONDS := 8.0
const REPLAY_DELAY := 0.8

var camera_name := "CAM"
var area_rect := Rect2()      # detection area on the XZ plane (world space)
var area_height := 3.6
var player: Node3D
var cctv: Node

var camera: Camera3D
var _light_mesh: MeshInstance3D
var _light: OmniLight3D
var _inside := false
var _samples: Array = []
var _accum := 0.0
var _exit_timer := -1.0

func _ready() -> void:
	var prop: Node3D = load(PROP).instantiate()
	add_child(prop)
	var target := Vector3(area_rect.get_center().x, 0.8, area_rect.get_center().y)
	var head: Node3D = prop.get_node_or_null("SM_Prop_Camera_Head_01")
	var flat := Vector3(target.x, global_position.y, target.z)
	prop.look_at(flat, Vector3.UP, true)   # Synty camera lens faces +Z

	# Blinking red recording light on the camera head.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.05, 0.05); m.emission_enabled = true
	m.emission = Color(1, 0.05, 0.05); m.emission_energy_multiplier = 6.0
	_light_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.025; sm.height = 0.05; sm.material = m
	_light_mesh.mesh = sm
	(head if head else prop).add_child(_light_mesh)
	_light_mesh.position = Vector3(0.06, 0.02, 0.12)
	_light = OmniLight3D.new()
	_light.light_color = Color(1, 0.1, 0.1); _light.light_energy = 0.6; _light.omni_range = 0.9
	_light_mesh.add_child(_light)
	var blink := Timer.new(); blink.wait_time = 0.5; blink.autostart = true
	blink.timeout.connect(func(): _light_mesh.visible = not _light_mesh.visible)
	add_child(blink)

	# Fixed viewpoint for the replay.
	camera = Camera3D.new()
	camera.fov = 72.0
	add_child(camera)
	camera.global_position = global_position + Vector3(0, -0.35, 0) + (target - global_position).normalized() * 0.3
	camera.look_at(target, Vector3.UP)

	# Detection area covering the gallery.
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(area_rect.size.x - 0.4, area_height, area_rect.size.y - 0.4)
	cs.shape = box
	area.add_child(cs)
	add_child(area)
	area.global_position = Vector3(area_rect.get_center().x, area_height * 0.5, area_rect.get_center().y)
	area.body_entered.connect(func(b): if b == player: _on_enter())
	area.body_exited.connect(func(b): if b == player: _on_exit())

func _on_enter() -> void:
	if not _inside and _exit_timer < 0.0:
		_samples.clear()
	_inside = true
	_exit_timer = -1.0

func _on_exit() -> void:
	_inside = false
	_exit_timer = REPLAY_DELAY

func _physics_process(delta: float) -> void:
	if _inside and player and player.has_method("snapshot"):
		_accum += delta
		if _accum >= 1.0 / SAMPLE_RATE:
			_accum = 0.0
			var s: Dictionary = player.snapshot()
			s["clock"] = cctv.clock()
			_samples.append(s)
			while _samples.size() > 1 and _samples[-1].clock - _samples[0].clock > BUFFER_SECONDS:
				_samples.pop_front()
	if _exit_timer >= 0.0:
		_exit_timer -= delta
		if _exit_timer < 0.0:
			if _samples.size() > 3:
				cctv.play_replay(self, _samples.duplicate())
			_samples.clear()
