extends Node3D
## Third-person orbit camera for the animation showcase.
## Drag with the left or right mouse button (outside the panel) to orbit, use the wheel to zoom.
## Follows a target point smoothly so the character stays framed during root motion.

@export var camera: Camera3D
@export var distance := 4.2
@export var min_distance := 1.4
@export var max_distance := 10.0
@export var yaw_deg := 28.0
@export var pitch_deg := 14.0
@export var min_pitch_deg := -8.0
@export var max_pitch_deg := 75.0
@export var mouse_sensitivity := 0.3
@export var follow_speed := 6.0

var target_point := Vector3(0, 1, 0)
var _dragging := false
var _goal_distance := 4.2

func _ready() -> void:
	_goal_distance = distance
	global_position = target_point
	_apply()

func snap() -> void:
	global_position = target_point

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_goal_distance = clampf(_goal_distance * 0.9, min_distance, max_distance)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_goal_distance = clampf(_goal_distance * 1.1, min_distance, max_distance)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		yaw_deg -= mm.relative.x * mouse_sensitivity
		pitch_deg = clampf(pitch_deg + mm.relative.y * mouse_sensitivity, min_pitch_deg, max_pitch_deg)
	elif event is InputEventPanGesture:
		_goal_distance = clampf(_goal_distance * (1.0 + (event as InputEventPanGesture).delta.y * 0.05), min_distance, max_distance)
	elif event is InputEventMagnifyGesture:
		_goal_distance = clampf(_goal_distance / (event as InputEventMagnifyGesture).factor, min_distance, max_distance)

func _process(delta: float) -> void:
	var w := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target_point, w)
	distance = lerpf(distance, _goal_distance, 1.0 - exp(-10.0 * delta))
	_apply()

func _apply() -> void:
	if camera == null:
		return
	var rot := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch_deg))
	camera.position = rot * Vector3(0, 0, distance)
	camera.look_at(global_position, Vector3.UP)
