extends CharacterBody3D
## Third-person security guard. Synty Heist character + baked Mixamo clips (heist pipeline).
## Lower body: idle / walk / reverse walk / run / crouch clips, hips turned toward movement.
## Upper body: AimModifier (weapon stance + spine twist toward the aim) and TwoBoneIK3D for the
## support hand on the weapon's fore-end. Weapons live in WeaponController.

signal health_changed(hp: float, max_hp: float)
signal damaged(amount: float)
signal died
signal respawned
signal prompt_changed(text: String)

const MODEL := "res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Female_FBI_01.tscn"
const ANIMS := "res://Assets/Animations/heist_female_inplace.res"
const WEAPONS := preload("res://Scripts/weapon_controller.gd")
# Clip root speeds measured by the bake (m/s); playback speed follows movement speed.
const WALK_CLIP := 1.41
const RUN_CLIP := 3.17
const CROUCH_CLIP := 1.2
const WALK_SPEED := 1.8
const AIM_SPEED := 1.45
const RUN_SPEED := 4.4
const CROUCH_SPEED := 1.15
const MOUSE_SENS := 0.0022
const GRAVITY := 9.8
const MAX_HP := 100.0
const LIVE_LAYER := 2          # render layer of live characters (see CCTV system)

@onready var pivot: Node3D = $CameraPivot
@onready var spring: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var shape: CollisionShape3D = $CollisionShape3D

var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var rig: AimModifier
var ik: TwoBoneIK3D
var weapons: Node3D
var controls_enabled := true
var current_clip := ""
var yaw := 0.0
var pitch := -0.15
var hips_yaw := PI
var hp := MAX_HP
var dead := false
var invulnerable := 0.0
var crouching := false
var aiming := false
var sprinting := false
var moving := false
var spawn_xf := Transform3D()
var aim_point := Vector3.ZERO
var aim_dir := Vector3.FORWARD
var shoulder := 1.0
var _view_kick := 0.0
var _shake := 0.0
var _hit := Vector3.ZERO
var _fired_recently := 0.0
var _since_damage := 99.0
var _step_t := 0.0
var _prompt_target: Node = null
var _prompt_t := 0.0
var _museum: Node

func _ready() -> void:
	spawn_xf = global_transform
	model = load(MODEL).instantiate()
	add_child(model)
	if model is CollisionObject3D:
		(model as CollisionObject3D).collision_layer = 0
		(model as CollisionObject3D).collision_mask = 0
	anim = model.get_node("AnimationPlayer")
	anim.add_animation_library("m", load(ANIMS))
	skeleton = model.get_node("Skeleton3D")
	rig = AimModifier.new()
	skeleton.add_child(rig)
	rig.setup(anim.get_animation("m/firing_rifle"))
	weapons = WEAPONS.new()
	add_child(weapons)
	weapons.setup(self)
	# Support hand: two-bone IK onto the weapon's fore-end marker (runs after the rig).
	ik = TwoBoneIK3D.new()
	skeleton.add_child(ik)
	ik.setting_count = 1
	ik.set_root_bone_name(0, "Shoulder_L")
	ik.set_middle_bone_name(0, "Elbow_L")
	ik.set_end_bone_name(0, "Hand_L")
	ik.set_target_node(0, ik.get_path_to(weapons.ik_target))
	var pole := Node3D.new()
	model.add_child(pole)
	pole.position = Vector3(0.9, 0.6, -0.4)    # elbow points down and out to the left
	ik.set_pole_node(0, ik.get_path_to(pole))
	rig.hands_posed.connect(_on_hands_posed)
	Fx.set_layers(self, LIVE_LAYER)
	camera.cull_mask = 0xFFFFF & ~(4 | 8)     # hide camera-only phantoms and CCTV playback puppets
	hips_yaw = spawn_xf.basis.get_euler().y + PI
	yaw = spawn_xf.basis.get_euler().y
	rotation.y = 0.0
	model.rotation.y = hips_yaw
	_play("idle")
	add_to_group("recordable")
	_museum = get_tree().get_first_node_in_group("museum")

func _on_hands_posed(right: Transform3D, _left: Transform3D) -> void:
	weapons.place(skeleton, right, aim_dir, model.global_basis.y)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * GameSettings.mouse_sensitivity * (0.6 if aiming else 1.0)
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * (-1.0 if GameSettings.invert_y else 1.0), -1.15, 0.75)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("crouch"):
		crouching = not crouching
	elif event.is_action_pressed("reload"):
		weapons.start_reload()
	elif event.is_action_pressed("weapon_1"):
		weapons.switch_to(0)
	elif event.is_action_pressed("weapon_2"):
		weapons.switch_to(1)
	elif event.is_action_pressed("flashlight"):
		weapons.toggle_flashlight()
	elif event.is_action_pressed("shoulder"):
		shoulder = -shoulder
	elif event.is_action_pressed("interact") and _prompt_target and is_instance_valid(_prompt_target):
		_prompt_target.interact(self)

func camera_kick(deg: float) -> void:
	_view_kick += deg_to_rad(deg)

func _physics_process(delta: float) -> void:
	invulnerable = maxf(invulnerable - delta, 0.0)
	_since_damage += delta
	_fired_recently = maxf(_fired_recently - delta, 0.0)
	var active := controls_enabled and not dead
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if active else Vector2.ZERO
	aiming = active and Input.is_action_pressed("aim")
	var trigger := active and Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if trigger:
		_fired_recently = 0.6
	sprinting = active and Input.is_action_pressed("run") and input.y < -0.3 and not aiming and not trigger
	if sprinting and crouching:
		crouching = false
	var combat := aiming or _fired_recently > 0.0
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var speed := RUN_SPEED if sprinting else (CROUCH_SPEED if crouching else (AIM_SPEED if combat else WALK_SPEED))
	velocity.x = move_toward(velocity.x, dir.x * speed, 16.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 16.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	# Camera: over-the-shoulder, tighter while aiming, lower while crouched.
	_view_kick = move_toward(_view_kick, 0.0, delta * (0.8 + _view_kick * 10.0))
	_shake = maxf(_shake - delta * 2.5, 0.0)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.03
	pivot.rotation = Vector3(pitch + _view_kick + shake.y, yaw + shake.x, 0)
	pivot.position.y = lerpf(pivot.position.y, 1.2 if crouching else 1.65, 1.0 - exp(-10.0 * delta))
	spring.spring_length = lerpf(spring.spring_length, 1.45 if aiming else (2.6 if crouching else 3.0), 1.0 - exp(-12.0 * delta))
	spring.position.x = lerpf(spring.position.x, shoulder * (0.5 if aiming else 0.6), 1.0 - exp(-10.0 * delta))
	camera.fov = lerpf(camera.fov, 46.0 if aiming else (70.0 if sprinting else 64.0), 1.0 - exp(-10.0 * delta))
	shape.shape.height = lerpf(shape.shape.height, 1.25 if crouching else 1.75, 1.0 - exp(-12.0 * delta))
	shape.position.y = shape.shape.height * 0.5

	# Crosshair target: what the screen centre points at.
	var cf := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + cf * 80.0, 1 | 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	aim_point = hit.position if hit else camera.global_position + cf * 80.0
	if dead:
		return

	var flat := Vector2(velocity.x, velocity.z).length()
	moving = flat > 0.2
	var aim_yaw := atan2(cf.x, cf.z)
	var move_yaw := atan2(dir.x, dir.z)
	var backwards := false
	if combat:
		if moving:
			var rel := wrapf(move_yaw - aim_yaw, -PI, PI)
			if absf(rel) <= deg_to_rad(105):
				_turn_hips(aim_yaw + clampf(rel, -deg_to_rad(70), deg_to_rad(70)), 14.0, delta)
			else:
				backwards = true
				_turn_hips(aim_yaw + clampf(wrapf(rel - PI, -PI, PI), -deg_to_rad(50), deg_to_rad(50)), 14.0, delta)
		elif absf(wrapf(aim_yaw - hips_yaw, -PI, PI)) > deg_to_rad(55):
			_turn_hips(aim_yaw, 8.0, delta)
		aim_dir = (aim_point - weapons.muzzle_position()).normalized()
		if (aim_point - weapons.muzzle_position()).length() < 1.2:
			aim_dir = cf
	else:
		if moving:
			_turn_hips(move_yaw, 12.0, delta)
		var hf := Vector3(sin(hips_yaw), 0, cos(hips_yaw))
		aim_dir = (hf + Vector3(0, -0.65 if sprinting else -0.2, 0)).normalized()
	model.rotation.y = hips_yaw

	# Lower-body clip selection; playback speed matches ground speed.
	if crouching:
		if moving:
			_play("crouched_walking", flat / CROUCH_CLIP * (-1.0 if backwards else 1.0))
		else:
			_play("crouch_idle")
	elif not moving:
		_play("idle")
	elif sprinting and flat > WALK_SPEED + 0.4:
		_play("running", flat / RUN_CLIP)
	else:
		_play("walking", maxf(flat, 0.7) / WALK_CLIP * (-1.0 if backwards else 1.0))

	# Rig inputs.
	_hit = _hit.move_toward(Vector3.ZERO, delta * 1.5)
	rig.hit = _hit
	rig.recoil = weapons.recoil
	rig.influence = move_toward(rig.influence, 1.0, delta * 4.0)
	ik.influence = rig.influence
	weapons.tick(delta, trigger, aiming, moving, crouching, camera, not sprinting)

	# Footsteps by surface; sprinting is loud enough for enemies to hear.
	if moving and is_on_floor():
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.36 if sprinting else (0.62 if crouching else 0.5)
			var surface: String = _museum.surface_at(global_position) if _museum else "stone"
			Sfx.play(self, "step_" + surface, global_position, -18.0 if crouching else (-8.0 if sprinting else -13.0))
			if sprinting:
				get_tree().call_group("enemies", "hear_noise", global_position, 8.0, false)
	# Regeneration on easy difficulty.
	if GameSettings.diff("regen") and _since_damage > 5.0 and hp < MAX_HP:
		hp = minf(hp + 7.0 * delta, MAX_HP)
		health_changed.emit(hp, MAX_HP)
	_update_prompt(delta)

func _turn_hips(target: float, rate: float, delta: float) -> void:
	hips_yaw = lerp_angle(hips_yaw, target, 1.0 - exp(-rate * delta))

func _play(clip: String, speed := 1.0) -> void:
	if current_clip == "rising":
		return
	if clip == "crouch_idle":
		if current_clip != clip:
			current_clip = clip
			anim.play("m/crouching", 0.3)
			anim.seek(2.6, true)
		anim.speed_scale = 1.0
		return
	var reverse := speed < 0.0
	var key := clip + ("_rev" if reverse else "")
	if current_clip != key:
		current_clip = key
		anim.play("m/" + clip, 0.22, -1.0 if reverse else 1.0, reverse)
	anim.speed_scale = absf(speed)

func _update_prompt(delta: float) -> void:
	_prompt_t -= delta
	if _prompt_t > 0.0:
		return
	_prompt_t = 0.12
	var best: Node = null
	var best_score := 0.0
	var fwd := -camera.global_basis.z
	if controls_enabled and not dead:
		for n in get_tree().get_nodes_in_group("interactable"):
			if not n.can_interact():
				continue
			var to: Vector3 = n.global_position - global_position
			to.y = 0.0
			var d := to.length()
			if d > n.radius:
				continue
			var facing := fwd.normalized().dot(to.normalized()) if d > 0.3 else 1.0
			if facing < 0.2:
				continue
			var score := facing / maxf(d, 0.3)
			if score > best_score:
				best_score = score; best = n
	if best != _prompt_target:
		_prompt_target = best
		prompt_changed.emit(best.get_prompt() if best else "")

# ------------------------------------------------------------------ health

func take_hit(amount: float, from: Vector3 = Vector3.ZERO) -> void:
	if dead or invulnerable > 0.0 or not controls_enabled or Dev.invulnerable:
		return
	amount *= float(GameSettings.diff("damage"))
	hp = maxf(hp - amount, 0.0)
	_since_damage = 0.0
	_shake = 1.0
	var away := (global_position - from).normalized() if from != Vector3.ZERO else Vector3.BACK
	away.y = 0.0
	_hit = Vector3(away.z, 0, -away.x).normalized() * 0.35
	velocity += away * 2.0
	health_changed.emit(hp, MAX_HP)
	damaged.emit(amount)
	Sfx.play(self, "hurt", null, -2.0)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	velocity = Vector3.ZERO
	died.emit()
	Sfx.play(self, "death_sting", null, -2.0)
	current_clip = "dying"
	anim.speed_scale = 1.5
	anim.play("m/crouching", 0.15)
	anim.seek(1.0, true)
	var t := create_tween()
	t.tween_property(rig, "influence", 0.0, 0.3)
	t.parallel().tween_property(ik, "influence", 0.0, 0.3)
	t.tween_interval(0.5)
	t.tween_property(model, "rotation:x", -1.35, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(spring, "spring_length", 4.5, 1.5)
	for w in weapons.weapons: w.node.visible = false

## Called by the round manager after the death screen.
func respawn() -> void:
	global_transform = spawn_xf
	rotation.y = 0.0
	velocity = Vector3.ZERO
	model.rotation = Vector3(0, spawn_xf.basis.get_euler().y + PI, 0)
	hips_yaw = model.rotation.y
	yaw = spawn_xf.basis.get_euler().y
	pitch = -0.15
	hp = MAX_HP
	dead = false
	crouching = false
	invulnerable = 3.0
	weapons.weapons[weapons.current].node.visible = true
	weapons.refill()
	anim.speed_scale = 1.6
	anim.play("m/crouching", 0.0, -1.0, true)   # rise from a kneel
	current_clip = "rising"
	get_tree().create_timer(1.0).timeout.connect(func(): if not dead: current_clip = "")
	health_changed.emit(hp, MAX_HP)
	respawned.emit()

func heal(amount: float) -> void:
	hp = minf(hp + amount, MAX_HP)
	health_changed.emit(hp, MAX_HP)

## For the security-camera recorder.
func snapshot() -> Dictionary:
	return {"kind": "player", "model": MODEL, "pos": global_position, "yaw": hips_yaw, "clip": current_clip,
		"t": anim.current_animation_position, "speed": anim.speed_scale, "aim": aim_dir, "weapon": weapons.current,
		"alive": not dead, "pitch": model.rotation.x}
