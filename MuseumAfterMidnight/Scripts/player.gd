extends CharacterBody3D
## Third-person player. A Synty Heist character driven by the baked Mixamo clips
## (Assets/Animations/heist_female_inplace.res, from the Heist showcase pipeline).
## WASD to move, Shift to run, mouse to look, left mouse button to shoot.

signal health_changed(hp: float, max_hp: float)
signal shot_hit(headshot: bool, killed: bool)
signal died
signal respawned

const MODEL := "res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Female_Overall_01.tscn"
const ANIMS := "res://Assets/Animations/heist_female_inplace.res"
const GUN := "res://Assets/Synty/PolygonHeist/Prefab/Weapons/SM_Wep_RifleBandit_01.tscn"
# Clip root speeds measured by the bake (m/s); playback speed follows movement speed.
const WALK_CLIP_SPEED := 1.41
const RUN_CLIP_SPEED := 3.17
const WALK_SPEED := 1.7
const RUN_SPEED := 4.2
const MOUSE_SENS := 0.0022
const GRAVITY := 9.8
const MAX_HP := 100.0
const FIRE_INTERVAL := 0.17
const DAMAGE := 34.0
const RANGE := 60.0
const SHOT_MASK := 1 | 4     # world + monsters

@onready var pivot: Node3D = $CameraPivot
@onready var spring: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var aim: AimModifier
var gun: Node3D
var muzzle: Node3D
var controls_enabled := true
var current_clip := ""
var yaw := 0.0
var pitch := -0.18
var hp := MAX_HP
var dead := false
var invulnerable := 0.0
var spawn_xf := Transform3D()
var _fire_cd := 0.0
var _aim_timer := 0.0
var _gun_fwd := Vector3.FORWARD   # current barrel direction (world, from the hands)
var _hand_r := -1
var _hand_l := -1
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D

func _ready() -> void:
	spawn_xf = global_transform
	model = load(MODEL).instantiate()
	add_child(model)
	# The prefab root is itself a CharacterBody3D; keep it out of physics.
	if model is CollisionObject3D:
		(model as CollisionObject3D).collision_layer = 0
		(model as CollisionObject3D).collision_mask = 0
	anim = model.get_node("AnimationPlayer")
	anim.add_animation_library("m", load(ANIMS))
	skeleton = model.get_node("Skeleton3D")
	aim = AimModifier.new()
	skeleton.add_child(aim)
	aim.setup(anim.get_animation("m/firing_rifle"))
	aim.influence = 1.0
	_attach_gun()
	_play("idle")
	yaw = rotation.y
	rotation.y = 0.0
	model.rotation.y = yaw + PI
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _attach_gun() -> void:
	# The crew rifle is carried in the "Firing Rifle" stance (AimModifier keeps it on the upper
	# body at all times). Each frame it is placed in the right hand, barrel through the left.
	_hand_r = skeleton.find_bone("Hand_R")
	_hand_l = skeleton.find_bone("Hand_L")
	gun = load(GUN).instantiate()
	add_child(gun)
	gun.top_level = true
	for body in gun.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0; body.collision_mask = 0
	var ab := AABB()
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		ab = ab.merge(mi.transform * mi.mesh.get_aabb()) if ab.size != Vector3.ZERO else mi.transform * mi.mesh.get_aabb()
	aim.hand_r = _hand_r
	aim.hand_l = _hand_l
	aim.hands_posed.connect(_place_gun)
	muzzle = Node3D.new()
	gun.add_child(muzzle)
	muzzle.position = Vector3(0, ab.position.y + ab.size.y * 0.66, ab.end.z + 0.02)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1, 0.75, 0.35); _flash.light_energy = 0.0; _flash.omni_range = 4.0
	muzzle.add_child(_flash)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.8, 0.4); m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.28, 0.28); q.material = m
	_flash_mesh.mesh = q
	_flash_mesh.visible = false
	muzzle.add_child(_flash_mesh)

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
	invulnerable = maxf(invulnerable - delta, 0.0)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	var input := Vector2.ZERO
	var active := controls_enabled and not dead
	if active:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var running := active and Input.is_action_pressed("run")
	var dir := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y))
	var speed := RUN_SPEED if running else WALK_SPEED
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 14.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	if active and Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _fire_cd <= 0.0:
		_shoot()
	_aim_timer = maxf(_aim_timer - delta, 0.0)
	aim.influence = move_toward(aim.influence, 0.0 if dead else 1.0, delta * 6.0)

	if dead:
		return
	var flat := Vector2(velocity.x, velocity.z).length()
	# Turn the body so the barrel (not the hips) points where we aim or move.
	var desired := Vector3.ZERO
	var rate := 12.0
	if _aim_timer > 0.0:
		desired = -camera.global_basis.z
		rate = 22.0
	elif dir.length() > 0.1:
		desired = dir
	desired.y = 0.0
	var cur := Vector3(_gun_fwd.x, 0, _gun_fwd.z)
	if desired.length() > 0.01 and cur.length() > 0.01:
		var err := wrapf(atan2(desired.x, desired.z) - atan2(cur.x, cur.z), -PI, PI)
		model.rotation.y += err * (1.0 - exp(-rate * delta))
	if flat < 0.15:
		_play("idle")
		anim.speed_scale = 1.0
	elif running and flat > WALK_SPEED + 0.3:
		_play("running")
		anim.speed_scale = flat / RUN_CLIP_SPEED
	else:
		_play("walking")
		anim.speed_scale = maxf(flat, 0.6) / WALK_CLIP_SPEED

func _process(_delta: float) -> void:
	gun.visible = aim.influence > 0.9 and not dead

## Grip in the right hand, barrel through the left hand, upright to the body.
func _place_gun(right: Transform3D, left: Transform3D) -> void:
	var xf := skeleton.global_transform
	var rh := xf * right.origin
	var lh := xf * left.origin
	var fwd := (lh - rh).normalized()
	if fwd.length() < 0.5:
		return
	_gun_fwd = fwd
	var up := model.global_basis.y
	var b := Basis.looking_at(fwd, up, true)
	gun.global_transform = Transform3D(b, rh + b * Vector3(0.0, -0.035, 0.03))

func _shoot() -> void:
	_fire_cd = FIRE_INTERVAL
	_aim_timer = 0.9
	# Aim through the crosshair (screen centre).
	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE, SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit.position if hit else from + dir * RANGE
	var origin := muzzle.global_position
	Sfx.play(self, "shot", null, -4.0)
	get_tree().call_group("monsters", "hear_shot", global_position)
	_muzzle_flash()
	_tracer(origin, end)
	if hit:
		var col: Object = hit.collider
		if col and col.has_method("take_damage"):
			var head: bool = hit.position.y > col.global_position.y + col.head_height
			var killed: bool = col.take_damage(DAMAGE * (2.0 if head else 1.0), dir)
			shot_hit.emit(head, killed)
			_impact(end, hit.normal, Color(0.55, 0.05, 0.08))
		else:
			_impact(end, hit.normal, Color(1.0, 0.8, 0.4))

func _world() -> Node:
	return get_tree().current_scene if get_tree().current_scene else get_parent()

func _muzzle_flash() -> void:
	_flash.light_energy = 6.0
	_flash_mesh.visible = true
	_flash_mesh.rotation.z = randf() * TAU
	var t := create_tween()
	t.tween_property(_flash, "light_energy", 0.0, 0.07)
	t.tween_callback(func(): _flash_mesh.visible = false)

func _tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.3:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008; cm.bottom_radius = 0.008; cm.height = len; cm.radial_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.85, 0.5, 0.8); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.material = m
	mi.mesh = cm
	_world().add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	mi.global_basis = Basis(side, up, side.cross(up))
	var t := mi.create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, 0.08)
	t.tween_callback(mi.queue_free)

func _impact(pos: Vector3, normal: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true; p.emitting = false; p.amount = 14; p.lifetime = 0.35; p.explosiveness = 1.0
	p.direction = normal; p.spread = 50.0; p.initial_velocity_min = 1.5; p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9, 0); p.scale_amount_min = 0.02; p.scale_amount_max = 0.05
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = color
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 6; sm.rings = 3; sm.material = m
	p.mesh = sm
	_world().add_child(p)
	p.global_position = pos + normal * 0.02
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

# ------------------------------------------------------------------ health

func take_hit(amount: float) -> void:
	if dead or invulnerable > 0.0 or not controls_enabled:
		return
	hp = maxf(hp - amount, 0.0)
	health_changed.emit(hp, MAX_HP)
	Sfx.play(self, "hurt", null, -2.0)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	died.emit()
	velocity = Vector3.ZERO
	_aim_timer = 0.0
	anim.speed_scale = 1.4
	anim.play("m/crouching", 0.15)
	anim.seek(1.2, true)
	current_clip = "crouching"
	await get_tree().create_timer(2.6).timeout
	global_transform = spawn_xf
	yaw = spawn_xf.basis.get_euler().y
	rotation.y = 0.0
	model.rotation.y = yaw + PI
	hp = MAX_HP
	dead = false
	invulnerable = 2.5
	current_clip = ""
	_play("idle")
	health_changed.emit(hp, MAX_HP)
	respawned.emit()

func _play(clip: String) -> void:
	if current_clip == clip:
		return
	current_clip = clip
	anim.play("m/" + clip, 0.2)

## For the security-camera recorder: what the player looks like right now.
func snapshot() -> Dictionary:
	return {"pos": global_position, "yaw": model.rotation.y, "clip": current_clip,
		"t": anim.current_animation_position, "speed": anim.speed_scale}
