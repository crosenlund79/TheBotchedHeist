extends Node3D
## A ceiling-mounted security camera (Synty Heist SM_Prop_Camera_01) with a status light:
## blinking red = recording, steady green = live view only. It covers `area_rect`.
## The CCTV system keeps one rolling world-state buffer; this camera tells it when the player
## enters and leaves its coverage so a recording clip becomes available shortly after leaving.

const PROP := "res://Assets/Synty/PolygonHeist/Prefab/Props/SM_Prop_Camera_01.tscn"
const RELEASE_DELAY := 1.0

var camera_name := "CAM"
var area_rect := Rect2()
var area_height := 3.6
var recording := true
var player: Node3D
var cctv: Node

var camera: Camera3D            # viewpoint only (never made current); playback cameras copy it
var glitch_t := 0.0
var _light_mesh: MeshInstance3D
var _light: OmniLight3D
var _inside := false
var _enter_t := 0.0
var _exit_timer := -1.0
var _exit_t := 0.0
var _blink := 0.0

func _ready() -> void:
	add_to_group("security_cameras")
	var prop: Node3D = load(PROP).instantiate()
	add_child(prop)
	for body in prop.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0
	var target := Vector3(area_rect.get_center().x, 0.8, area_rect.get_center().y)
	var head: Node3D = prop.get_node_or_null("SM_Prop_Camera_Head_01")
	prop.look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP, true)   # lens faces +Z
	var col := Color(1, 0.05, 0.05) if recording else Color(0.1, 1, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	_light_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.material = m
	_light_mesh.mesh = sm
	(head if head else prop).add_child(_light_mesh)
	_light_mesh.position = Vector3(0.06, 0.02, 0.12)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 0.6
	_light.omni_range = 0.9
	_light_mesh.add_child(_light)
	camera = Camera3D.new()
	camera.fov = 74.0
	camera.current = false
	add_child(camera)
	camera.global_position = global_position + Vector3(0, -0.35, 0) + (target - global_position).normalized() * 0.3
	camera.look_at(target, Vector3.UP)
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

func covers(pos: Vector3) -> bool:
	return area_rect.has_point(Vector2(pos.x, pos.z)) and pos.y < area_height + 0.5

func is_working() -> bool:
	return glitch_t <= 0.0

## Haunting event: the camera loses signal for a few seconds.
func glitch(seconds: float) -> void:
	glitch_t = seconds

func _on_enter() -> void:
	if not _inside and _exit_timer < 0.0:
		_enter_t = cctv.now()
	_inside = true
	_exit_timer = -1.0

func _on_exit() -> void:
	_inside = false
	_exit_t = cctv.now()
	_exit_timer = RELEASE_DELAY

func _process(delta: float) -> void:
	glitch_t = maxf(glitch_t - delta, 0.0)
	_blink += delta
	if glitch_t > 0.0:
		_light_mesh.visible = randf() < 0.15
	elif recording:
		_light_mesh.visible = fmod(_blink, 1.0) < 0.5
	else:
		_light_mesh.visible = true
	if _exit_timer >= 0.0:
		_exit_timer -= delta
		if _exit_timer < 0.0 and recording and cctv:
			cctv.on_camera_clip(self, _enter_t, _exit_t)
