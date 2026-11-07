extends Node3D
## Rifle and handgun: ammo, firing through the crosshair, recoil, reload, switching, effects and
## the weapon-mounted flashlight. The player's rig calls place() from inside the skeleton update.

signal ammo_changed(weapon_name: String, mag: int, mag_size: int, reserve: int)
signal fired(hit_enemy: bool)
signal hit_enemy(headshot: bool, killed: bool)
signal weapon_switched(weapon_name: String)

const W := "res://Assets/Synty/PolygonHeist/Prefab/Weapons/"
const MUZZLE := "res://Assets/Generated/template_muzzle_flash.png"
const SHOT_MASK := 1 | 4    # world + enemies
const SPECS := [
	{"name": "Crew Rifle", "scene": "SM_Wep_RifleBandit_01", "damage": 28.0, "head": 2.0, "interval": 0.105, "auto": true,
		"mag": 30, "reserve": 120, "spread_hip": 2.4, "spread_aim": 0.5, "kick": 0.035, "cam_kick": 0.9,
		"sound": "rifle", "reload": 2.2, "forend": 0.55, "barrel": 0.66, "flash": 0.42, "range": 70.0},
	{"name": "Handgun", "scene": "SM_Wep_PistolBandit_01", "damage": 40.0, "head": 2.2, "interval": 0.2, "auto": false,
		"mag": 12, "reserve": 48, "spread_hip": 1.6, "spread_aim": 0.35, "kick": 0.055, "cam_kick": 1.4,
		"sound": "pistol", "reload": 1.45, "forend": -0.1, "barrel": 0.78, "flash": 0.3, "range": 55.0},
]

var player: Node3D
var current := 0
var weapons: Array = []        # [{node, muzzle, forend_local, mag_node, spec, mag, reserve}]
var ik_target: Node3D
var recoil := 0.0              # rig kick (rad), decays
var recoil_back := 0.0         # weapon slide-back (m), decays
var reloading := false
var reload_t := 0.0
var switching := 0.0
var flashlight: SpotLight3D
var _cd := 0.0
var _trigger_was_down := false
var _flash_light: OmniLight3D
var _flash_quads: Array = []
var _reload_sounds := {}

func setup(p: Node3D) -> void:
	player = p
	ik_target = Node3D.new()
	ik_target.top_level = true
	add_child(ik_target)
	var ammo_mult: float = GameSettings.diff("ammo")
	for spec in SPECS:
		var n: Node3D = load(W + spec.scene + ".tscn").instantiate()
		add_child(n)
		n.top_level = true
		for body in n.find_children("*", "CollisionObject3D", true, false):
			body.collision_layer = 0; body.collision_mask = 0
		var ab := AABB(); var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.transform * mi.mesh.get_aabb()
			ab = b if first else ab.merge(b); first = false
		var muzzle := Node3D.new()
		n.add_child(muzzle)
		var barrel_y: float = ab.position.y + ab.size.y * spec.barrel
		muzzle.position = Vector3(0, barrel_y, ab.end.z + 0.02)
		var forend: Vector3
		if spec.forend > 0.0:
			forend = Vector3(0.0, barrel_y - 0.05, ab.end.z * spec.forend)
		else:
			forend = Vector3(-0.045, ab.position.y + ab.size.y * 0.35, 0.02)   # handgun: cup the grip
		var mags: Array = n.find_children("*Mag*", "MeshInstance3D", true, false)
		weapons.append({"node": n, "muzzle": muzzle, "forend": forend, "mag_node": mags[0] if mags.size() > 0 else null,
			"spec": spec, "mag": spec.mag, "reserve": int(spec.reserve * ammo_mult), "length": ab.end.z})
	# Muzzle flash: two crossed additive quads and a light, on the active muzzle.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(MUZZLE)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new(); qm.size = Vector2(0.4, 0.4); qm.material = m
		q.mesh = qm
		q.visible = false
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flash_quads.append(q)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1, 0.72, 0.35); _flash_light.light_energy = 0.0; _flash_light.omni_range = 4.5
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.light_energy = 4.0
	flashlight.spot_range = 22.0
	flashlight.spot_angle = 22.0
	flashlight.spot_angle_attenuation = 1.6
	flashlight.shadow_enabled = false
	flashlight.add_to_group("preset_light")
	flashlight.add_to_group("shadow_high")
	_equip(0, true)

func _equip(i: int, instant := false) -> void:
	current = i
	for k in weapons.size():
		weapons[k].node.visible = k == i
	var w: Dictionary = weapons[i]
	for q in _flash_quads:
		if q.get_parent(): q.get_parent().remove_child(q)
		w.muzzle.add_child(q)
	_flash_quads[1].rotation.y = PI * 0.5
	_flash_quads[2].rotation.x = PI * 0.5
	for q in _flash_quads: q.scale = Vector3.ONE * w.spec.flash / 0.4
	if _flash_light.get_parent(): _flash_light.get_parent().remove_child(_flash_light)
	w.muzzle.add_child(_flash_light)
	if flashlight.get_parent(): flashlight.get_parent().remove_child(flashlight)
	w.muzzle.add_child(flashlight)
	flashlight.position = Vector3(0, 0.03, -0.05)
	flashlight.rotation = Vector3(0, PI, 0)
	reloading = false
	if w.mag_node: w.mag_node.visible = true
	if not instant:
		switching = 0.35
		Sfx.play(self, "switch", w.node.global_position, -6.0)
	weapon_switched.emit(w.spec.name)
	_emit_ammo()

func spec() -> Dictionary:
	return weapons[current].spec

func muzzle_position() -> Vector3:
	return weapons[current].muzzle.global_position

func _emit_ammo() -> void:
	var w: Dictionary = weapons[current]
	var reserve: int = -1 if (Dev.infinite_ammo or _infinite_reserve()) else w.reserve
	ammo_changed.emit(w.spec.name, w.mag, w.spec.mag, reserve)

func _infinite_reserve() -> bool:
	return current == 1 and GameSettings.difficulty == "Tourist"

func add_ammo(rounds_rifle: int, rounds_pistol: int) -> void:
	weapons[0].reserve += rounds_rifle
	weapons[1].reserve += rounds_pistol
	_emit_ammo()

func refill() -> void:
	var ammo_mult: float = GameSettings.diff("ammo")
	for w in weapons:
		w.mag = w.spec.mag
		w.reserve = maxi(w.reserve, int(w.spec.reserve * ammo_mult))
	_emit_ammo()

func switch_to(i: int) -> void:
	if i != current and i >= 0 and i < weapons.size() and switching <= 0.0:
		_equip(i)

func toggle_flashlight() -> void:
	flashlight.visible = not flashlight.visible
	Sfx.play(self, "ui_click", flashlight.global_position, -8.0)

func start_reload() -> void:
	var w: Dictionary = weapons[current]
	if reloading or switching > 0.0 or w.mag >= w.spec.mag:
		return
	if w.reserve <= 0 and not (Dev.infinite_ammo or _infinite_reserve()):
		return
	reloading = true
	reload_t = 0.0
	_reload_sounds = {}

func _finish_reload() -> void:
	var w: Dictionary = weapons[current]
	var need: int = w.spec.mag - w.mag
	if Dev.infinite_ammo or _infinite_reserve():
		w.mag = w.spec.mag
	else:
		var take := mini(need, w.reserve)
		w.mag += take
		w.reserve -= take
	reloading = false
	_emit_ammo()

## Per physics frame. trigger: fire button state; aim_point: crosshair target in world space.
func tick(delta: float, trigger: bool, aiming: bool, moving: bool, crouching: bool, camera: Camera3D, can_fire: bool) -> void:
	_cd = maxf(_cd - delta, 0.0)
	switching = maxf(switching - delta, 0.0)
	recoil = move_toward(recoil, 0.0, delta * (0.5 + recoil * 8.0))
	recoil_back = move_toward(recoil_back, 0.0, delta * 0.6)
	var w: Dictionary = weapons[current]
	if reloading:
		reload_t += delta / w.spec.reload
		_reload_cues(w)
		if reload_t >= 1.0:
			_finish_reload()
	var pressed: bool = trigger and (w.spec.auto or not _trigger_was_down)
	_trigger_was_down = trigger
	if pressed and can_fire and not reloading and switching <= 0.0 and _cd <= 0.0:
		if w.mag <= 0:
			Sfx.play(self, "dry", w.muzzle.global_position, -6.0)
			_cd = 0.3
			start_reload()
		else:
			_fire(w, aiming, moving, crouching, camera)

func _reload_cues(w: Dictionary) -> void:
	var cues := [[0.18, "mag_out"], [0.62, "mag_in"], [0.82, "bolt"]]
	for c in cues:
		if reload_t >= c[0] and not _reload_sounds.has(c[1]):
			_reload_sounds[c[1]] = true
			Sfx.play(self, c[1], w.node.global_position, -4.0)
	if w.mag_node:
		w.mag_node.visible = reload_t < 0.22 or reload_t > 0.6

func _fire(w: Dictionary, aiming: bool, moving: bool, crouching: bool, camera: Camera3D) -> void:
	_cd = w.spec.interval
	if not Dev.infinite_ammo:
		w.mag -= 1
	var spread_deg: float = w.spec.spread_aim if aiming else w.spec.spread_hip
	if moving: spread_deg *= 1.6
	if crouching: spread_deg *= 0.7
	spread_deg += recoil * 12.0
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var a := randf() * TAU
	var r := tan(deg_to_rad(spread_deg)) * sqrt(randf())
	var dir := (fwd + right * cos(a) * r + up * sin(a) * r).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * w.spec.range, SHOT_MASK, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit.position if hit else from + dir * w.spec.range
	var origin: Vector3 = w.muzzle.global_position
	recoil += w.spec.kick
	recoil_back = 0.035
	player.camera_kick(w.spec.cam_kick)
	Sfx.play(self, w.spec.sound, origin, -1.0)
	_muzzle_flash()
	_tracer(origin, end)
	get_tree().call_group("enemies", "hear_noise", origin, 24.0 * float(GameSettings.diff("detect")), true)
	var struck := false
	if hit:
		var col: Object = hit.collider
		if col and col.has_method("take_damage"):
			var head: bool = hit.position.y > col.global_position.y + col.head_height
			var dmg: float = w.spec.damage * (w.spec.head if head else 1.0)
			var killed: bool = col.take_damage(dmg, dir, hit.position, head)
			struck = true
			hit_enemy.emit(head, killed)
			Fx.impact(_world(), end, hit.normal, col.surface if "surface" in col else "flesh", false)
		else:
			Fx.impact(_world(), end, hit.normal, Fx.surface_of(col), col is StaticBody3D)
	fired.emit(struck)
	_emit_ammo()
	if w.mag == 0:
		start_reload()

func _world() -> Node:
	return get_tree().current_scene if get_tree().current_scene else player.get_parent()

func _muzzle_flash() -> void:
	_flash_light.light_energy = 2.6
	for q in _flash_quads:
		q.visible = true
	_flash_quads[0].rotation.z = randf() * TAU
	var t := create_tween()
	t.tween_property(_flash_light, "light_energy", 0.0, 0.06)
	t.parallel().tween_interval(0.045)
	t.tween_callback(func():
		for q in _flash_quads: q.visible = false)
	Fx.particles(_world(), muzzle_position(), -player.camera.global_basis.z, Color(0.5, 0.5, 0.5, 0.18), 3, 0.4, 0.5, 0.12, 0.4, Fx.DUST, false, 20.0)

func _tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006; cm.bottom_radius = 0.006; cm.height = minf(len, 6.0); cm.radial_segments = 4; cm.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.85, 0.5, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.material = m
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world().add_child(mi)
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	mi.global_basis = Basis(side, dir, side.cross(dir))
	mi.global_position = a + dir * cm.height * 0.5
	# The streak travels from the barrel toward the target.
	var t := mi.create_tween()
	t.tween_property(mi, "global_position", b - dir * cm.height * 0.5, clampf(len / 260.0, 0.02, 0.12))
	t.parallel().tween_property(m, "albedo_color:a", 0.0, clampf(len / 260.0, 0.02, 0.12))
	t.tween_callback(mi.queue_free)

## Called by the rig with the posed hands (skeleton space). Places the weapon in the strong
## hand along the aim direction and moves the support-hand IK target.
func place(skeleton: Skeleton3D, right: Transform3D, aim_dir: Vector3, grip_up: Vector3) -> void:
	var w: Dictionary = weapons[current]
	var rh := skeleton.global_transform * right.origin
	var fwd := aim_dir.normalized()
	var b := Basis.looking_at(fwd, grip_up, true)
	# Reload: roll the weapon and dip the muzzle while the support hand works.
	var rt := 0.0
	if reloading:
		rt = sin(clampf(reload_t, 0.0, 1.0) * PI)
		b = b.rotated(b.z, deg_to_rad(-38.0) * rt).rotated(b.x, deg_to_rad(22.0) * rt)
	var origin := rh + b * Vector3(0.0, -0.035, 0.03 - recoil_back)
	w.node.global_transform = Transform3D(b, origin)
	var fore: Vector3 = w.node.global_transform * w.forend
	var target := fore
	if reloading:
		var mag_well: Vector3 = w.node.global_transform * Vector3(0, -0.16, w.length * 0.25)
		var hips := skeleton.find_bone("Hips")
		var pouch: Vector3 = skeleton.global_transform * (skeleton.get_bone_global_pose(hips).origin + Vector3(0.17, -0.02, 0.1))
		var handle: Vector3 = w.node.global_transform * Vector3(0.05, 0.02, w.length * 0.15)
		var t := reload_t
		if t < 0.18: target = fore.lerp(mag_well, t / 0.18)
		elif t < 0.38: target = mag_well.lerp(pouch, (t - 0.18) / 0.2)
		elif t < 0.6: target = pouch.lerp(mag_well, (t - 0.38) / 0.22)
		elif t < 0.75: target = mag_well.lerp(handle, (t - 0.6) / 0.15)
		elif t < 0.85: target = handle
		else: target = handle.lerp(fore, (t - 0.85) / 0.15)
	ik_target.global_transform = Transform3D(b, target)
