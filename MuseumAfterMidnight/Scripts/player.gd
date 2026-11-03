extends CharacterBody3D
## Third-person player. A Synty Heist character driven by the baked Mixamo clips
## (Assets/Animations/heist_female_inplace.res, from the Heist showcase pipeline).
## WASD to move, Shift to run, mouse to look.

const MODEL := "res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Female_Overall_01.tscn"
const ANIMS := "res://Assets/Animations/heist_female_inplace.res"
# Clip root speeds measured by the bake (m/s); playback speed follows movement speed.
const WALK_CLIP_SPEED := 1.41
const RUN_CLIP_SPEED := 3.17
const WALK_SPEED := 1.7
const RUN_SPEED := 4.2
const MOUSE_SENS := 0.0022
const GRAVITY := 9.8

@onready var pivot: Node3D = $CameraPivot
@onready var spring: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var model: Node3D
var anim: AnimationPlayer
var controls_enabled := true
var current_clip := ""
var yaw := 0.0
var pitch := -0.18

func _ready() -> void:
	model = load(MODEL).instantiate()
	add_child(model)
	# The prefab root is itself a CharacterBody3D; keep it out of physics.
	if model is CollisionObject3D:
		(model as CollisionObject3D).collision_layer = 0
		(model as CollisionObject3D).collision_mask = 0
	anim = model.get_node("AnimationPlayer")
	anim.add_animation_library("m", load(ANIMS))
	_play("idle")
	yaw = rotation.y
	rotation.y = 0.0
	model.rotation.y = yaw + PI
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.1, 0.5)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0)
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var running := controls_enabled and Input.is_action_pressed("run")
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y))
	var speed := RUN_SPEED if running else WALK_SPEED
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 14.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	var flat := Vector2(velocity.x, velocity.z).length()
	if dir.length() > 0.1:
		var face := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, face, 1.0 - exp(-12.0 * delta))
	if flat < 0.15:
		_play("idle")
		anim.speed_scale = 1.0
	elif running and flat > WALK_SPEED + 0.3:
		_play("running")
		anim.speed_scale = flat / RUN_CLIP_SPEED
	else:
		_play("walking")
		anim.speed_scale = maxf(flat, 0.6) / WALK_CLIP_SPEED

func _play(clip: String) -> void:
	if current_clip == clip:
		return
	current_clip = clip
	anim.play("m/" + clip, 0.2)

## For the security-camera recorder: what the player looks like right now.
func snapshot() -> Dictionary:
	return {"pos": global_position, "yaw": model.rotation.y, "clip": current_clip,
		"t": anim.current_animation_position, "speed": anim.speed_scale}
