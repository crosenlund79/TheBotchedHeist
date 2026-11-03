extends CharacterBody3D
## A Horror Mansion monster: wanders near its spawn, notices the player (sight or gunfire),
## chases along the navigation mesh, attacks in melee, and dies when shot.
## Animated with the baked Mixamo clips from the Heist pipeline.

signal killed(monster: Node)

enum State { WANDER, IDLE, CHASE, ATTACK, DEAD }

const WALK_CLIP_SPEED := 1.41
const RUN_CLIP_SPEED := 3.17
const SNEAK_CLIP_SPEED := 2.2

var prefab := "SM_Chr_Werewolf_01"
var max_hp := 100.0
var walk_speed := 1.1
var chase_speed := 3.0
var damage := 10.0
var detect_range := 13.0
var attack_range := 1.6
var attack_cooldown := 1.5
var wander_clip := "walking"
var eye_color := Color(1, 0.15, 0.1)
var height := 1.9
var head_height := 1.45
var player: Node3D
var director: Node

var hp := 100.0
var state := State.IDLE
var home := Vector3.ZERO
var model: Node3D
var anim: AnimationPlayer
var agent: NavigationAgent3D
var _state_t := 0.0
var _attack_cd := 0.0
var _struck := false
var _flash_t := 0.0
var _overlay: StandardMaterial3D
var _clip := ""
var _repath := 0.0
var _stagger := 0.0
var _los_t := 0.0
var _has_los := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.36; cap.height = height
	cs.shape = cap; cs.position.y = height * 0.5
	add_child(cs)
	model = ExhibitFactory.build(prefab, false)
	add_child(model)
	var ab := ExhibitFactory.bounds(model)
	model.scale *= height / maxf(ab.size.y, 0.5)
	ExhibitFactory.fit(model, Vector3.ZERO, 0.0)   # feet on the body's origin
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation_library("m"):
			anim = ap
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.albedo_color = Color(1, 0.1, 0.1, 0.0)
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _overlay
	# Glowing eyes: two tiny emissive dots and a faint light.
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; em.albedo_color = eye_color
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var head := sk.find_bone("Head")
	if head >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = "Head"
		sk.add_child(att)
		var rest := sk.get_bone_global_rest(head)
		for x in [-0.045, 0.045]:
			var eye := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.016; sm.height = 0.032; sm.material = em
			eye.mesh = sm
			att.add_child(eye)
			eye.transform = rest.affine_inverse() * Transform3D(Basis(), rest.origin + Vector3(x, 0.085, 0.115))
	var glow := OmniLight3D.new()
	glow.light_color = eye_color; glow.light_energy = 0.7; glow.omni_range = 1.6
	glow.add_to_group("preset_light"); glow.add_to_group("detail_light")
	add_child(glow)
	glow.position = Vector3(0, height * 0.9, 0.3)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.5
	agent.radius = 0.4
	add_child(agent)
	home = global_position
	hp = max_hp
	_set_state(State.IDLE)
	_state_t = randf_range(0.5, 2.0)

func _set_state(s: int) -> void:
	state = s
	match s:
		State.IDLE:
			_state_t = randf_range(1.5, 3.5)
			_play("idle", 1.0)
		State.WANDER:
			var p := home + Vector3(randf_range(-4.5, 4.5), 0, randf_range(-4.5, 4.5))
			agent.target_position = p
			_state_t = 7.0
		State.CHASE:
			_repath = 0.0
		State.ATTACK:
			_state_t = 0.95
			_struck = false
			_attack_cd = attack_cooldown
			# A lunging strike: the reach of the "button pushing" clip, played fast.
			_play("button_pushing", 1.7, 0.15)
			anim.seek(0.85, true)
			Sfx.play(self, "growl", global_position + Vector3.UP * 1.5, -4.0, randf_range(0.75, 1.1))

func _play(clip: String, speed: float, blend := 0.25) -> void:
	if anim == null:
		return
	anim.speed_scale = speed
	if _clip != clip:
		_clip = clip
		anim.play("m/" + clip, blend)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if director and director.frozen:
		velocity = Vector3.ZERO
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_state_t -= delta
	_stagger = maxf(_stagger - delta, 0.0)
	if _flash_t > 0.0:
		_flash_t -= delta
		_overlay.albedo_color.a = clampf(_flash_t / 0.15, 0.0, 1.0) * 0.6
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var player_ok: bool = player.visible and not player.dead and player.controls_enabled
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.25
		_has_los = player_ok and dist < detect_range and _line_of_sight()
	var move := Vector3.ZERO
	match state:
		State.IDLE:
			if _has_los: _set_state(State.CHASE)
			elif _state_t <= 0.0: _set_state(State.WANDER)
		State.WANDER:
			if _has_los:
				_set_state(State.CHASE)
			elif agent.is_navigation_finished() or _state_t <= 0.0:
				_set_state(State.IDLE)
			else:
				move = _steer() * walk_speed
				_play(wander_clip, walk_speed / (SNEAK_CLIP_SPEED if wander_clip == "sneak_walk" else WALK_CLIP_SPEED))
		State.CHASE:
			if not player_ok or dist > detect_range * 1.8:
				_set_state(State.WANDER)
			elif dist < attack_range and _attack_cd <= 0.0:
				_set_state(State.ATTACK)
			else:
				_repath -= delta
				if _repath <= 0.0:
					_repath = 0.3
					agent.target_position = player.global_position
				move = (_steer() if dist > 2.2 else to_player.normalized()) * chase_speed
				if dist < attack_range * 0.8:
					move = Vector3.ZERO
					_play("idle", 1.4)
				else:
					_play("running", chase_speed / RUN_CLIP_SPEED)
		State.ATTACK:
			_face(to_player, delta, 10.0)
			if not _struck and _state_t < 0.6:
				_struck = true
				if player_ok and dist < attack_range + 0.5:
					player.take_hit(damage)
			if _state_t <= 0.0:
				_clip = ""
				_set_state(State.CHASE)
	if _stagger > 0.0:
		move *= 0.2
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if move.length() > 0.1:
		_face(move, delta, 8.0)
	elif state == State.CHASE:
		_face(to_player, delta, 8.0)

func _steer() -> Vector3:
	var next := agent.get_next_path_position()
	var d := next - global_position
	d.y = 0.0
	if d.length() < 0.05 or NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		d = agent.target_position - global_position
		d.y = 0.0
	return d.normalized()

func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))

func _line_of_sight() -> bool:
	var from := global_position + Vector3.UP * 1.5
	var to := player.global_position + Vector3.UP * 1.3
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Gunfire nearby alerts the monster even without line of sight.
func hear_shot(pos: Vector3) -> void:
	if state in [State.IDLE, State.WANDER] and global_position.distance_to(pos) < detect_range * 1.2:
		_set_state(State.CHASE)

## Returns true when this hit killed the monster.
func take_damage(amount: float, dir: Vector3) -> bool:
	if state == State.DEAD:
		return false
	hp -= amount
	_flash_t = 0.15
	_stagger = 0.25
	velocity += dir.normalized() * 2.0
	Sfx.play(self, "hit", global_position + Vector3.UP * 1.2, -3.0)
	if hp <= 0.0:
		_die()
		return true
	if state != State.ATTACK:
		_set_state(State.CHASE)
	return false

func _die() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	Sfx.play(self, "death", global_position + Vector3.UP, -2.0, randf_range(0.8, 1.1))
	_clip = ""
	_play("crouching", 1.6, 0.1)
	anim.seek(1.1, true)
	killed.emit(self)
	# Ghostly burst, then sink into the floor.
	var p := CPUParticles3D.new()
	p.one_shot = true; p.amount = 40; p.lifetime = 1.4; p.explosiveness = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP; p.spread = 35.0; p.initial_velocity_min = 0.6; p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.6, 0); p.scale_amount_min = 0.05; p.scale_amount_max = 0.14
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(0.5, 1.0, 0.75, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 6; sm.rings = 3; sm.material = m
	p.mesh = sm
	add_child(p)
	p.position.y = 1.0
	p.emitting = true
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_property(model, "position:y", -2.2, 1.6).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
