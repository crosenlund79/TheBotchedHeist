class_name Enemy
extends CharacterBody3D
## One haunted-museum enemy. Archetypes:
##  EXHIBIT  possessed figure or statue: dormant until awakened; figures walk slowly, stone statues
##           only move while the player is not looking at them.
##  STAFF    haunted night staff: patrols, investigates noise, chases, loses sight, searches.
##  ENTITY   supernatural ghost: hovers, phases (short teleport), telegraphs a lunge attack.
##  BEAST    Horror Mansion monster: fast, tough, heavy hits (later rounds).
## States: Dormant, Idle, Patrol, Investigate, Alert, Chase, Attack, Recover, Search, Return, Phase, Dead.

signal killed(enemy: Node)
signal awakened(enemy: Node)

enum Kind { EXHIBIT, STAFF, ENTITY, BEAST }
enum S { DORMANT, IDLE, PATROL, INVESTIGATE, ALERT, CHASE, ATTACK, RECOVER, SEARCH, RETURN, PHASE, DEAD }
const STATE_NAMES := ["Dormant", "Idle", "Patrol", "Investigate", "Alert", "Chase", "Attack", "Recover", "Search", "Return", "Phase", "Dead"]
const KIND_NAMES := ["Possessed Exhibit", "Haunted Staff", "Supernatural Entity", "Nightmare Beast"]
const WALK_CLIP := 1.41
const RUN_CLIP := 3.17
const SNEAK_CLIP := 2.2
const LIVE_LAYER := 2

static var _next_id := 1
static var _ghost_shader: Shader
static var _stone_mat: StandardMaterial3D

# Configuration (set by the spawner before add_child).
var kind := Kind.STAFF
var prefab := "res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Male_Overall_01.tscn"
var statue := false
var max_hp := 100.0
var walk_speed := 1.2
var chase_speed := 3.0
var damage := 10.0
var attack_range := 1.6
var attack_cooldown := 1.6
var detect_range := 14.0
var height := 1.85
var eye_color := Color(1, 0.2, 0.1)
var patrol: Array = []
var dormant := false
var model_yaw := 0.0
var source_exhibit: Node3D = null   # the museum exhibit this enemy replaced (shown again on reset)
var label_name := ""

# Runtime.
var id := 0
var hp := 100.0
var state := S.IDLE
var head_height := 1.5
var surface := "flesh"
var player: Node3D
var model: Node3D
var anim: AnimationPlayer
var agent: NavigationAgent3D
var observed := false
var _clip := ""
var _state_t := 0.0
var _attack_cd := 0.0
var _struck := false
var _los := false
var _los_t := 0.0
var _obs_t := 0.0
var _last_seen := Vector3.ZERO
var _lost_t := 0.0
var _target := Vector3.ZERO
var _patrol_i := 0
var _repath := 0.0
var _stuck_t := 0.0
var _stuck_check := 1.0
var _last_pos := Vector3.ZERO
var _side_step := Vector3.ZERO
var _side_t := 0.0
var _flash := 0.0
var _overlay: ShaderMaterial
var _ghost_mat: ShaderMaterial
var _alpha := 1.0
var _phase_cd := 4.0
var _phase_dest := Vector3.ZERO
var _phase_in := false
var _windup := 0.0
var _lunge := Vector3.ZERO
var _glow: OmniLight3D
var _wisps: CPUParticles3D
var _label: Label3D
var _label_t := 0.0
var _home := Vector3.ZERO
var _voice_t := 3.0
var _step_t := 0.0
var _grind_t := 0.0
var _lean := 0.0

# ------------------------------------------------------------------ shared visuals

## Builds an enemy (or CCTV puppet) model: a Heist scene path or a converted Unity prefab.
static func build_visual(p: String) -> Node3D:
	var m: Node3D
	if p.begins_with("res://"):
		m = load(p).instantiate()
		if m is CollisionObject3D:
			(m as CollisionObject3D).collision_layer = 0
			(m as CollisionObject3D).collision_mask = 0
		var ap: AnimationPlayer = m.get_node_or_null("AnimationPlayer")
		if ap and not ap.has_animation_library("m"):
			ap.add_animation_library("m", load(ExhibitFactory.ANIMS))
	else:
		m = ExhibitFactory.build(p, false)
	return m

static func find_anim(m: Node) -> AnimationPlayer:
	for ap in m.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation_library("m"):
			return ap
	return null

static func ghost_material(color: Color, alpha := 1.0) -> ShaderMaterial:
	if _ghost_shader == null:
		_ghost_shader = Shader.new()
		_ghost_shader.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.4, 1.0, 0.8, 1.0);
uniform float alpha = 1.0;
uniform float rim = 1.6;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float n = 0.75 + 0.25 * sin(TIME * 6.0 + VERTEX.y * 9.0);
	ALBEDO = tint.rgb * (0.12 + f * rim) * n * alpha;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _ghost_shader
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("alpha", alpha)
	return m

static func apply_stone(m: Node) -> void:
	if _stone_mat == null:
		_stone_mat = StandardMaterial3D.new()
		_stone_mat.albedo_color = Color(0.56, 0.55, 0.52)
		_stone_mat.roughness = 0.95
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _stone_mat

static func apply_ghost(m: Node, mat: Material) -> void:
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Scales a freshly built model to `h` metres tall with its feet on the parent origin.
static func fit_height(m: Node3D, h: float) -> void:
	var ab := ExhibitFactory.bounds(m)
	m.scale *= h / maxf(ab.size.y, 0.3)
	ExhibitFactory.fit(m, Vector3.ZERO, 0.0)

# ------------------------------------------------------------------ setup

func _ready() -> void:
	id = _next_id
	_next_id += 1
	add_to_group("enemies")
	add_to_group("recordable")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 if kind != Kind.ENTITY else 1 | 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34 if kind != Kind.BEAST else 0.42
	cap.height = height
	cs.shape = cap
	cs.position.y = height * 0.5
	add_child(cs)
	model = build_visual(prefab)
	add_child(model)
	fit_height(model, height)
	model.rotation.y = model_yaw
	anim = find_anim(model)
	head_height = height * 0.8
	player = get_tree().get_first_node_in_group("player")
	if statue:
		surface = "statue"
		apply_stone(model)
	if kind == Kind.ENTITY:
		surface = "spirit"
		_ghost_mat = ghost_material(eye_color, 1.0)
		apply_ghost(model, _ghost_mat)
		_wisps = Fx.particles(self, global_position + Vector3.UP * height * 0.5, Vector3.UP, Color(eye_color, 0.5), 18, 0.3, 1.6, 0.22, 0.25, Fx.WISP, true, 70.0, true)
		_wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_wisps.emission_sphere_radius = 0.45
		_wisps.position = Vector3(0, height * 0.5, 0)
		_wisps.emitting = true
	else:
		_overlay = ghost_material(eye_color, 0.0)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			mi.material_overlay = _overlay
	_add_eyes()
	_glow = OmniLight3D.new()
	_glow.light_color = eye_color
	_glow.light_energy = 0.0 if dormant else (1.3 if kind == Kind.ENTITY else 0.6)
	_glow.omni_range = 3.0 if kind == Kind.ENTITY else 1.6
	_glow.add_to_group("preset_light")
	_glow.add_to_group("detail_light")
	add_child(_glow)
	_glow.position = Vector3(0, height * 0.88, 0.25)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 0.6
	agent.path_height_offset = 0.5      # the baked navmesh surface sits ~0.5 m above the floor
	agent.radius = 0.4
	add_child(agent)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 28
	_label.pixel_size = 0.004
	_label.outline_size = 6
	_label.position.y = height + 0.35
	_label.visible = false
	add_child(_label)
	Fx.set_layers(self, LIVE_LAYER)
	hp = max_hp
	_home = global_position
	_last_pos = global_position
	if dormant:
		state = S.DORMANT
		_play("idle", 0.0, 0.0)
		if anim:
			anim.seek(randf() * 3.0, true)
	else:
		_enter(S.PATROL if patrol.size() > 0 else S.IDLE)

func _add_eyes() -> void:
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	var head := sk.find_bone("Head")
	if head < 0:
		return
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = eye_color
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	sk.add_child(att)
	var rest := sk.get_bone_global_rest(head)
	for x in [-0.045, 0.045]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.018
		sm.height = 0.036
		sm.material = em
		eye.mesh = sm
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(eye)
		eye.transform = rest.affine_inverse() * Transform3D(Basis(), rest.origin + Vector3(x, 0.085, 0.115))
		eye.visible = not dormant
		eye.add_to_group("enemy_eye_%d" % get_instance_id())

# ------------------------------------------------------------------ state machine

func _enter(s: int) -> void:
	state = s
	match s:
		S.IDLE:
			_state_t = randf_range(1.5, 3.5)
			_play("idle", 1.0)
		S.PATROL:
			if patrol.is_empty():
				_set_target(_home + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)))
			else:
				_set_target(patrol[_patrol_i % patrol.size()])
			_state_t = 14.0
		S.INVESTIGATE:
			_set_target(_target)
			_state_t = 12.0
		S.ALERT:
			_state_t = 0.5 * float(GameSettings.diff("reaction"))
			_play("idle", 1.4)
			_voice(true)
		S.CHASE:
			_repath = 0.0
			_lost_t = 0.0
		S.ATTACK:
			_struck = false
			_attack_cd = attack_cooldown
			_windup = (0.85 if kind == Kind.ENTITY else (0.55 if kind == Kind.EXHIBIT else 0.32)) * float(GameSettings.diff("reaction"))
			_state_t = _windup + 0.55
			if kind == Kind.ENTITY:
				Sfx.play(self, "shriek", global_position + Vector3.UP * 1.4, -2.0, randf_range(0.9, 1.15))
			elif not statue:
				_play("button_pushing", 1.0 / maxf(_windup + 0.3, 0.2) * 1.2, 0.12)
				if anim:
					anim.seek(0.6, true)
				Sfx.play(self, "growl", global_position + Vector3.UP * 1.5, -5.0, randf_range(0.8, 1.15))
		S.RECOVER:
			_state_t = 0.4 if kind == Kind.STAFF else 0.2
		S.SEARCH:
			_state_t = 7.0
			_set_target(_last_seen)
		S.RETURN:
			_set_target(patrol[_patrol_i % patrol.size()] if patrol.size() > 0 else _home)
			_state_t = 25.0
		S.PHASE:
			_phase_in = false
			_state_t = 0.35
			Sfx.play(self, "phase", global_position + Vector3.UP, -3.0)

func _set_target(p: Vector3) -> void:
	var map := get_world_3d().navigation_map if is_inside_tree() else RID()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		p = NavigationServer3D.map_get_closest_point(map, p)
	_target = p
	agent.target_position = p

## Reached the current navigation target (own distance check; the agent's flag can be stale
## right after a new target is set).
func _arrived() -> bool:
	var dist := Vector2(_target.x - global_position.x, _target.z - global_position.z).length()
	return dist < 0.9 or (agent.is_navigation_finished() and dist < 2.0)

func _player_ok() -> bool:
	return player != null and player.visible and not player.dead and player.controls_enabled

## Wakes a dormant exhibit (awaken event, proximity, relic or being shot).
func awaken(delay := 0.9) -> void:
	if state != S.DORMANT:
		return
	Sfx.play(self, "awaken", global_position + Vector3.UP * 1.2, 0.0, randf_range(0.85, 1.1))
	if statue:
		Sfx.play(self, "stone_grind", global_position + Vector3.UP, -2.0)
	Fx.particles(get_parent(), global_position + Vector3.UP * 1.0, Vector3.UP, Color(0.75, 0.72, 0.65, 0.5), 22, 1.0, 1.2, 0.35, 0.3, Fx.DUST, false, 80.0)
	Fx.flash(get_parent(), global_position + Vector3.UP * 1.6, eye_color, 5.0, 5.0, 0.8)
	var t := create_tween()
	t.tween_property(_glow, "light_energy", 0.7, 0.4)
	for e in get_tree().get_nodes_in_group("enemy_eye_%d" % get_instance_id()):
		e.visible = true
	if _overlay:
		_overlay.set_shader_parameter("alpha", 0.9)
	_last_seen = player.global_position if player else global_position
	state = S.ALERT
	_state_t = delay
	_play("idle", 1.0)
	awakened.emit(self)
	get_tree().call_group("cctv", "record_event", "awaken", global_position, "%s awakened" % (label_name if label_name != "" else "An exhibit"))

func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_state_t -= delta
	_phase_cd -= delta
	_voice_t -= delta
	_update_flash(delta)
	_update_label(delta)
	if player == null:
		return
	var to_p := player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	var p_ok := _player_ok()
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.2
		_los = p_ok and state != S.DORMANT and _can_see(dist, to_p)
	if _los:
		_last_seen = player.global_position
	if statue:
		_obs_t -= delta
		if _obs_t <= 0.0:
			_obs_t = 0.1
			observed = p_ok and _is_observed()
	var move := Vector3.ZERO
	var spd := walk_speed
	match state:
		S.DORMANT:
			if p_ok and dist < 2.4 and not statue:
				awaken(0.6)
			velocity = Vector3.ZERO
			return
		S.IDLE:
			if _los: _spot()
			elif _state_t <= 0.0: _enter(S.PATROL)
		S.PATROL:
			if _los:
				_spot()
			elif _arrived() or _state_t <= 0.0:
				if patrol.size() > 0:
					_patrol_i += 1
				_enter(S.IDLE)
				_state_t = randf_range(0.8, 2.2)
			else:
				move = _steer()
		S.INVESTIGATE:
			spd = walk_speed * 1.35
			if _los:
				_spot()
			elif _arrived() or _state_t <= 0.0:
				_last_seen = _target
				_enter(S.SEARCH)
			else:
				move = _steer()
		S.ALERT:
			_face(to_p if _los or dist < 30.0 else _target - global_position, delta, 10.0)
			if _state_t <= 0.0:
				_enter(S.CHASE)
		S.CHASE:
			spd = chase_speed
			if not p_ok:
				_enter(S.RETURN)
			elif dist < attack_range and _attack_cd <= 0.0 and (_los or dist < 1.2) and absf(player.global_position.y - global_position.y) < 1.2:
				_enter(S.ATTACK)
			else:
				if not _los:
					_lost_t += delta
				else:
					_lost_t = 0.0
				if _lost_t > 5.0 or (not _los and global_position.distance_to(_last_seen) < 1.0):
					_enter(S.SEARCH)
				else:
					_repath -= delta
					if _repath <= 0.0:
						_repath = 0.3
						_set_target(_last_seen)
					move = _steer() if (dist > 2.0 or not _los) else to_p.normalized()
					if dist < attack_range * 0.75 and _los:
						move = Vector3.ZERO
					if kind == Kind.ENTITY and dist > 7.0 and _phase_cd <= 0.0 and _los:
						_enter(S.PHASE)
		S.ATTACK:
			_attack(delta, to_p, dist, p_ok)
		S.RECOVER:
			if _state_t <= 0.0:
				_last_seen = player.global_position
				_enter(S.CHASE)
		S.SEARCH:
			if _los:
				_enter(S.CHASE)
			elif _state_t <= 0.0:
				_enter(S.RETURN)
			elif _arrived():
				_set_target(_last_seen + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
				_play("idle", 1.0)
			else:
				move = _steer()
		S.RETURN:
			if _los:
				_spot()
			elif _arrived() or _state_t <= 0.0:
				_enter(S.PATROL if patrol.size() > 0 else S.IDLE)
			else:
				move = _steer()
		S.PHASE:
			_phase(delta)
			return
	# Stone statues freeze while watched.
	if statue and observed and state != S.DORMANT:
		move = Vector3.ZERO
		if anim: anim.speed_scale = 0.0
		velocity = Vector3(0, velocity.y, 0)
		_gravity(delta)
		move_and_slide()
		return
	move = _unstick(move, delta)
	var speed := spd * float(GameSettings.diff("speed"))
	if statue and state in [S.CHASE, S.SEARCH]:
		speed = chase_speed * 1.25
	velocity.x = move.x * speed
	velocity.z = move.z * speed
	_gravity(delta)
	move_and_slide()
	if kind == Kind.ENTITY:
		model.position.y = 0.3 + sin(Time.get_ticks_msec() * 0.003 + id) * 0.08
	var flat := Vector2(velocity.x, velocity.z).length()
	if state != S.ATTACK:
		if flat > 0.15:
			_face(Vector3(velocity.x, 0, velocity.z), delta, 8.0)
			_locomotion(flat)
		elif state in [S.CHASE, S.ALERT] and _los:
			_face(to_p, delta, 8.0)
			_play("idle", 1.2)
		elif state not in [S.ALERT]:
			_play("idle", 1.0)
	_sounds(flat, delta)

func _gravity(delta: float) -> void:
	if kind == Kind.ENTITY:
		velocity.y = 0.0
	else:
		velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta

func _locomotion(flat: float) -> void:
	if statue:
		return
	if kind == Kind.ENTITY:
		_play("sneak_walk", 0.45)
		return
	if flat > 2.2:
		_play("running", flat / RUN_CLIP)
	elif kind == Kind.EXHIBIT:
		_play("sneak_walk", flat / SNEAK_CLIP * 1.4)
	else:
		_play("walking", flat / WALK_CLIP)

func _spot() -> void:
	_enter(S.ALERT)

func _attack(delta: float, to_p: Vector3, dist: float, p_ok: bool) -> void:
	var t_since := (_windup + 0.55) - _state_t
	if t_since < _windup:
		_face(to_p, delta, 10.0)
		velocity = Vector3(0, velocity.y, 0)
		if kind == Kind.ENTITY:
			# Clear warning: brightening glow, shaking, rising shriek.
			var k := t_since / _windup
			_glow.light_energy = 1.3 + k * 6.0
			_ghost_mat.set_shader_parameter("rim", 1.6 + k * 4.0)
			model.position.x = randf_range(-0.04, 0.04) * k
		elif statue and observed:
			_state_t += delta     # a watched statue cannot finish its strike
	elif not _struck:
		_struck = true
		if kind == Kind.ENTITY:
			_lunge = to_p.normalized() * 7.0
			model.position.x = 0.0
			_ghost_mat.set_shader_parameter("rim", 1.6)
			_glow.light_energy = 1.3
		if p_ok and dist < attack_range + (1.6 if kind == Kind.ENTITY else 0.5):
			player.take_hit(damage, global_position)
			Sfx.play(self, "impact_flesh", player.global_position + Vector3.UP, -4.0)
	if _lunge.length() > 0.1:
		velocity.x = _lunge.x
		velocity.z = _lunge.z
		_lunge = _lunge.move_toward(Vector3.ZERO, delta * 22.0)
		move_and_slide()
	if _state_t <= 0.0:
		_clip = ""
		_enter(S.CHASE)

## Entity phase: fade out, reappear a few metres from the player, fade in.
func _phase(delta: float) -> void:
	velocity = Vector3.ZERO
	if not _phase_in:
		_alpha = maxf(_alpha - delta / 0.35, 0.0)
		if _alpha <= 0.0:
			var ang := randf() * TAU
			var p := player.global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(3.0, 4.5)
			var map := get_world_3d().navigation_map
			if NavigationServer3D.map_get_iteration_id(map) > 0:
				p = NavigationServer3D.map_get_closest_point(map, p)
				p.y = 0.0
			global_position = p
			_phase_in = true
			Fx.ghost_burst(get_parent(), p + Vector3.UP, eye_color)
			Sfx.play(self, "phase", p + Vector3.UP, -3.0, 1.2)
	else:
		_alpha = minf(_alpha + delta / 0.4, 1.0)
		if _alpha >= 1.0:
			_phase_cd = randf_range(5.0, 8.0) * float(GameSettings.diff("reaction"))
			_enter(S.CHASE)
	_ghost_mat.set_shader_parameter("alpha", _alpha)
	_glow.light_energy = 1.3 * _alpha

func _steer() -> Vector3:
	var map := agent.get_navigation_map()
	var d: Vector3
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		d = agent.target_position - global_position
	else:
		d = agent.get_next_path_position() - global_position
		if Vector2(d.x, d.z).length() < 0.05:
			d = agent.target_position - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO

## Detects being stuck against geometry: side-step, repath, and as a last resort snap to the navmesh.
func _unstick(move: Vector3, delta: float) -> Vector3:
	_stuck_check -= delta
	if _side_t > 0.0:
		_side_t -= delta
		return _side_step
	if _stuck_check <= 0.0:
		_stuck_check = 1.0
		var moved := global_position.distance_to(_last_pos)
		_last_pos = global_position
		if move.length() > 0.1 and moved < 0.25:
			_stuck_t += 1.0
			_side_step = move.rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
			_side_t = 0.45
			agent.target_position = _target
			if state == S.PATROL and _stuck_t >= 3.0:
				_patrol_i += 1
				_enter(S.IDLE)
			if _stuck_t >= 5.0 and not _visible_to_player():
				var map := get_world_3d().navigation_map
				if NavigationServer3D.map_get_iteration_id(map) > 0:
					var q := NavigationServer3D.map_get_closest_point(map, global_position + move * 1.2)
					global_position = Vector3(q.x, global_position.y, q.z)
				_stuck_t = 0.0
		else:
			_stuck_t = maxf(_stuck_t - 1.0, 0.0)
	return move

func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))

func _can_see(dist: float, to_p: Vector3) -> bool:
	var rng := detect_range * float(GameSettings.diff("detect"))
	if player.crouching:
		rng *= 0.65
	if dist > rng:
		return false
	var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	var fov := 0.0 if state in [S.CHASE, S.SEARCH, S.ALERT, S.RECOVER] else 0.35   # ~130 deg cone when calm
	if dist > 2.5 and fwd.dot(to_p.normalized()) < fov:
		return false
	var from := global_position + Vector3.UP * height * 0.85
	var to := player.global_position + Vector3.UP * (0.9 if player.crouching else 1.4)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## True when this enemy is on the player's screen and not hidden behind walls.
func _is_observed() -> bool:
	var cam: Camera3D = player.camera
	var c := global_position + Vector3.UP * height * 0.6
	if not cam.is_position_in_frustum(c):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, c, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _visible_to_player() -> bool:
	return player != null and _is_observed()

func _play(clip: String, speed: float, blend := 0.25) -> void:
	if anim == null:
		return
	anim.speed_scale = speed
	if _clip != clip:
		_clip = clip
		anim.play("m/" + clip, blend)

func _voice(alert: bool) -> void:
	if _voice_t > 0.0 and not alert:
		return
	_voice_t = randf_range(4.0, 9.0)
	var k := "moan"
	match kind:
		Kind.ENTITY: k = "whisper" if not alert else "ghost_wail"
		Kind.BEAST: k = "growl"
		Kind.EXHIBIT: k = "stone_grind" if statue else "moan"
		Kind.STAFF: k = "moan" if not alert else "shriek"
	Sfx.play(self, k, global_position + Vector3.UP * 1.5, -6.0 if alert else -10.0, randf_range(0.8, 1.15))

func _sounds(flat: float, delta: float) -> void:
	if state in [S.PATROL, S.IDLE, S.SEARCH, S.CHASE] and _voice_t <= 0.0:
		_voice(false)
	if flat > 0.3 and kind != Kind.ENTITY:
		if statue:
			_grind_t -= delta
			if _grind_t <= 0.0:
				_grind_t = 1.1
				Sfx.play(self, "stone_grind", global_position, -12.0, randf_range(0.9, 1.2))
		else:
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.34 if flat > 2.2 else 0.55
				Sfx.play(self, "step_stone", global_position, -16.0, 0.85)

func _update_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _overlay:
			_overlay.set_shader_parameter("alpha", 0.9 + clampf(_flash / 0.15, 0.0, 1.0) * 3.0)
		elif _ghost_mat:
			_ghost_mat.set_shader_parameter("rim", 1.6 + clampf(_flash / 0.15, 0.0, 1.0) * 5.0)
	if _lean > 0.0:
		_lean = maxf(_lean - delta * 2.5, 0.0)
		model.rotation.x = -_lean

func _update_label(delta: float) -> void:
	_label_t -= delta
	if _label_t > 0.0:
		return
	_label_t = 0.25
	_label.visible = Dev.show_ai
	if _label.visible:
		_label.text = "%s\n%s  %d hp" % [KIND_NAMES[kind], STATE_NAMES[state], int(hp)]
		_label.modulate = Color(1, 0.4, 0.3) if state in [S.CHASE, S.ATTACK] else Color(1, 0.9, 0.5)

# ------------------------------------------------------------------ external events

## Noise from gunfire, sprinting footsteps, breaking glass or alarms.
func hear_noise(pos: Vector3, radius: float, gunshot: bool) -> void:
	if state in [S.DEAD, S.DORMANT, S.ATTACK, S.PHASE]:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	if state in [S.CHASE, S.ALERT, S.RECOVER]:
		if not _los:
			_last_seen = pos
		return
	_target = pos
	_last_seen = pos
	if gunshot and d < radius * 0.5:
		_enter(S.ALERT)
	else:
		_enter(S.INVESTIGATE)

## Returns true when this hit killed the enemy.
func take_damage(amount: float, dir: Vector3, _pos: Vector3 = Vector3.ZERO, head := false) -> bool:
	if state == S.DEAD or (state == S.PHASE and _alpha < 0.4):
		return false
	if state == S.DORMANT:
		awaken(0.25)
	hp -= amount
	_flash = 0.15
	if kind != Kind.ENTITY and not statue:
		_lean = 0.22 if head else 0.12
	if hp <= 0.0:
		_die(dir)
		return true
	if randf() < 0.35:
		Sfx.play(self, "hurt" if kind == Kind.STAFF else ("impact_spirit" if kind == Kind.ENTITY else "growl"),
			global_position + Vector3.UP * 1.4, -6.0, randf_range(0.7, 0.9))
	if player:
		_last_seen = player.global_position
	match state:
		S.IDLE, S.PATROL, S.INVESTIGATE, S.SEARCH, S.RETURN:
			_enter(S.ALERT)
			_state_t = 0.15
		S.CHASE:
			if kind == Kind.STAFF and randf() < 0.45:
				_enter(S.RECOVER)
			elif kind == Kind.ENTITY and randf() < 0.3 and _phase_cd <= 1.0:
				_enter(S.PHASE)
	if kind == Kind.STAFF or kind == Kind.BEAST:
		velocity += dir.normalized() * (1.6 if kind == Kind.STAFF else 0.6)
	return false

func _die(dir: Vector3) -> void:
	state = S.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	killed.emit(self)
	_label.visible = false
	var parent := get_parent()
	if kind == Kind.ENTITY:
		Fx.ghost_burst(parent, global_position + Vector3.UP * 1.0, eye_color)
		Sfx.play(self, "ghost_wail", global_position + Vector3.UP, -2.0, 1.2)
		if _wisps: _wisps.emitting = false
		var t := create_tween()
		t.tween_method(func(a): _ghost_mat.set_shader_parameter("alpha", a), 1.0, 0.0, 0.9)
		t.parallel().tween_property(_glow, "light_energy", 0.0, 0.9)
		t.tween_callback(queue_free)
		return
	if statue:
		Sfx.play(self, "stone_grind", global_position + Vector3.UP, 0.0, 0.7)
		Sfx.play(self, "impact_stone", global_position + Vector3.UP, 0.0, 0.6)
		Fx.particles(parent, global_position + Vector3.UP * 1.0, Vector3.UP, Color(0.6, 0.58, 0.55, 1.0), 40, 3.0, 1.2, 0.07, -9.0, Fx.SPARK, false, 90.0)
		Fx.particles(parent, global_position + Vector3.UP * 0.8, Vector3.UP, Color(0.7, 0.68, 0.62, 0.6), 18, 0.8, 1.6, 0.5, 0.2, Fx.DUST, false, 90.0)
		var t := create_tween()
		t.tween_property(model, "scale", model.scale * Vector3(1.1, 0.05, 1.1), 0.35).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(_glow, "light_energy", 0.0, 0.3)
		t.tween_callback(queue_free)
		return
	Sfx.play(self, "death", global_position + Vector3.UP, -2.0, randf_range(0.75, 1.1))
	_clip = ""
	_play("crouching", 1.8, 0.1)
	if anim:
		anim.seek(1.0, true)
	var away := dir
	away.y = 0.0
	var fall_axis_yaw := atan2(away.x, away.z) if away.length() > 0.01 else model.rotation.y
	Fx.ghost_burst(parent, global_position + Vector3.UP * 1.0, eye_color)
	var t := create_tween()
	t.tween_property(_glow, "light_energy", 0.0, 0.5)
	t.parallel().tween_property(model, "rotation:x", -1.35 if absf(wrapf(fall_axis_yaw - model.rotation.y, -PI, PI)) < PI * 0.5 else 1.35, 0.7).set_delay(0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_interval(1.4)
	t.tween_property(model, "position:y", -1.6, 1.4).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

## Immediate removal (round reset, developer overlay). Does not count as a kill.
func despawn() -> void:
	state = S.DEAD
	remove_from_group("enemies")
	queue_free()

## World state for the security-camera recorder.
func snapshot() -> Dictionary:
	return {"kind": "enemy", "id": "e%d" % id, "model": prefab, "pos": global_position, "yaw": model.rotation.y,
		"pitch": model.rotation.x, "clip": _clip, "t": anim.current_animation_position if anim and anim.is_playing() else 0.0,
		"speed": anim.speed_scale if anim else 0.0, "alive": state != S.DEAD, "ghost": kind == Kind.ENTITY,
		"stone": statue, "alpha": _alpha, "hover": model.position.y, "h": height, "color": eye_color,
		"dormant": state == S.DORMANT, "sink": model.position.y < -0.05}
