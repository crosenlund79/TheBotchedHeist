extends Node
## Round manager. Bakes the navigation mesh, composes each round (possessed exhibits, haunted
## staff, supernatural entities, beasts) from the difficulty and round number, introduces the
## rest of the round's finite roster during play, tracks statistics, runs the alarm, and handles
## round completion (summary + automatic countdown) and player death (death screen + restart).

const HAUNTING := preload("res://Scripts/haunting.gd")
const C := "res://Assets/Synty/PolygonHeist/Prefab/Characters/"
const STAFF_MODELS := ["SM_Chr_Male_Overall_01", "SM_Chr_Female_Overall_01", "SM_Chr_Male_SuitVest_01",
	"SM_Chr_Female_SuitVest_01", "SM_Chr_Male_Shirt_01", "SM_Chr_Female_Shirt_01", "SM_Chr_Male_SWAT_01"]
const ENTITY_MODELS := ["SM_Chr_Yokai_01", "SM_Chr_Witch_01", "SM_Chr_Count_01", "SM_Chr_Ghoul_01"]
const BEAST_MODELS := ["SM_Chr_Werewolf_01", "SM_Chr_Demon_01", "SM_Chr_Butcher_01", "SM_Chr_Gimp_01"]
const SUMMARY_SECONDS := 10.0
const DEATH_SECONDS := 7.0
const SAFE_ZONE := "Security Office"

var museum: Node3D
var player: Node3D
var hud: Node
var cctv: Node
var haunting: Node
var region: NavigationRegion3D
var nav_ready := false
var _nav_wait := false
var started := false

var round_num := 0
var round_active := false
var round_time := 0.0
var round_total := 0
var round_kills := 0
var pending: Array = []
var bonus_spawned := 0
var _pace_t := 0.0
var _idle_t := 0.0
var _countdown := -1.0
var _countdown_action := ""
var _status_t := 0.0

var stats := {"shots": 0, "hits": 0, "kills": 0, "damage": 0.0, "time": 0.0}
var round_stats := {}
var alarm_on := false
var _alarm_sound: Node
var _alarm_light: SpotLight3D
var _alarm_t := 0.0

func start(m: Node3D) -> void:
	museum = m
	player = get_tree().get_first_node_in_group("player")
	hud = get_parent().get_node("HUD")
	cctv = get_parent().get_node("CCTV")
	cctv.director = self
	haunting = HAUNTING.new()
	haunting.name = "Haunting"
	add_child(haunting)
	haunting.setup(museum, self)
	player.health_changed.connect(hud.set_health)
	player.damaged.connect(func(a):
		stats.damage += a
		round_stats.damage = round_stats.get("damage", 0.0) + a
		hud.damage_flash(a))
	player.died.connect(_on_player_died)
	player.prompt_changed.connect(hud.set_prompt)
	var w: Node = player.weapons
	w.ammo_changed.connect(hud.set_ammo)
	w.fired.connect(func(_h):
		stats.shots += 1
		round_stats.shots = round_stats.get("shots", 0) + 1)
	w.hit_enemy.connect(func(head, killed):
		stats.hits += 1
		round_stats.hits = round_stats.get("hits", 0) + 1
		hud.hit_marker(head, killed))
	w._emit_ammo()
	hud.set_health(player.hp, player.MAX_HP)
	_build_alarm()
	_bake_navigation()

func _bake_navigation() -> void:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 8     # world + navigation-only blockers
	# Floor-level geometry only: walls and exhibits block, ceilings are ignored.
	nm.filter_baking_aabb = AABB(Vector3(-22, -0.5, -30), Vector3(44, 2.6, 50))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, museum)
	# The bake callback runs on a worker thread: hand the result to the main thread.
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func(): _on_baked.call_deferred(nm))

func _on_baked(nm: NavigationMesh) -> void:
	# A fresh region with its own copy: assigning the mesh object the baker produced to a region
	# that already existed left the server-side region empty in Godot 4.6.
	region = NavigationRegion3D.new()
	region.navigation_mesh = nm.duplicate()
	museum.add_child(region)
	_nav_wait = true
	if not NavigationServer3D.map_changed.is_connected(_on_map_changed):
		NavigationServer3D.map_changed.connect(_on_map_changed)

func _on_map_changed(_map: RID) -> void:
	if _nav_wait:
		_check_nav_sync()

## The map syncs regions a few physics frames later; only then are spawn points snapped.
func _check_nav_sync() -> void:
	var p := NavigationServer3D.map_get_closest_point(_nav_map(), Vector3(0, 0, 4))
	if p != Vector3.ZERO:
		_nav_wait = false
		nav_ready = true

## Called by the main menu's Play button.
func start_game() -> void:
	if started:
		return
	started = true
	stats = {"shots": 0, "hits": 0, "kills": 0, "damage": 0.0, "time": 0.0}
	var waited := 0
	while not nav_ready and waited < 600:     # Play pressed before the navmesh finished baking
		if _nav_wait:
			_check_nav_sync()
		await get_tree().physics_frame
		waited += 1
	_begin_round(1)

func _nav_map() -> RID:
	return museum.get_world_3d().navigation_map

func _snap(p: Vector3) -> Vector3:
	var map := _nav_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return p
	var q := NavigationServer3D.map_get_closest_point(map, p)
	if q == Vector3.ZERO:
		return p          # map not synced yet
	return Vector3(q.x, 0.0, q.z)     # navmesh surface sits slightly above the floor

# ------------------------------------------------------------------ rounds

func _compose(r: int) -> Dictionary:
	var d: Dictionary = GameSettings.DIFFICULTY[GameSettings.difficulty]
	var rs := mini(r, int(d.max_round_scale))
	var total := clampi(int(round((3.0 + rs) * float(d.count))), 3, 14)
	var exhibits := mini(1 + rs / 2, 4)
	var entities := 0 if r < int(d.entity_round) else 1 + (rs - int(d.entity_round)) / 3
	var beasts := 0 if r < int(d.beast_round) else 1 + (rs - int(d.beast_round)) / 3
	var staff := maxi(total - exhibits - entities - beasts, 1)
	return {"exhibits": exhibits, "staff": staff, "entities": entities, "beasts": beasts, "scale": rs}

func _begin_round(n: int) -> void:
	_clear_enemies()
	set_alarm(false)
	round_num = n
	round_time = 0.0
	round_kills = 0
	bonus_spawned = 0
	round_stats = {"shots": 0, "hits": 0, "damage": 0.0}
	pending.clear()
	museum.reset_round()
	haunting.reset()
	haunting.enabled = true
	var comp := _compose(n)
	var scale := 1.0 + 0.12 * (int(comp.scale) - 1)
	# Possessed exhibits: a random selection of figures and statues, dormant where they stand.
	var spots: Array = museum.possessable.duplicate()
	spots.shuffle()
	var figures := spots.filter(func(s): return not s.statue)
	var statues := spots.filter(func(s): return s.statue)
	var chosen := []
	for i in comp.exhibits:
		var pool: Array = statues if (i % 2 == 1 and statues.size() > 0) else figures
		if pool.is_empty():
			pool = figures if statues.is_empty() else statues
		if pool.is_empty():
			break
		chosen.append(pool.pop_back())
	for s in chosen:
		_spawn_exhibit(s, scale, true)
	# Staff and beasts: some now, the rest arrive during the round; entities manifest later.
	var roster := []
	for i in comp.staff: roster.append(Enemy.Kind.STAFF)
	for i in comp.beasts: roster.append(Enemy.Kind.BEAST)
	roster.shuffle()
	var now_count := maxi(1, int(ceil(roster.size() * 0.6)))
	for i in roster.size():
		if i < now_count:
			_spawn_kind(roster[i], scale)
		else:
			pending.append(roster[i])
	for i in comp.entities:
		pending.append(Enemy.Kind.ENTITY)
	pending.shuffle()
	round_total = chosen.size() + roster.size() + comp.entities
	_pace_t = _pace_interval()
	round_active = true
	hud.banner("ROUND %d" % n, "%s  ·  %d monsters" % [GameSettings.difficulty, round_total], 2.6)
	hud.hide_screens()
	_update_hud()

func _pace_interval() -> float:
	return {"Tourist": 32.0, "Security Guard": 24.0, "Nightmare": 15.0}.get(GameSettings.difficulty, 24.0)

func remaining() -> int:
	return maxi(round_total - round_kills, 0)

func active_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")

func _physics_process(_delta: float) -> void:
	if _nav_wait:
		_check_nav_sync()

func _process(delta: float) -> void:
	_update_alarm(delta)
	_status_t -= delta
	if _status_t <= 0.0:
		_status_t = 1.0
		museum.update_status(_board_text())
	if _countdown >= 0.0:
		_countdown -= delta
		hud.set_countdown(_countdown)
		if _countdown < 0.0:
			_run_countdown_action()
	if not round_active:
		return
	round_time += delta
	stats.time += delta
	var enemies := active_enemies()
	var awake := enemies.filter(func(e): return e.state != Enemy.S.DORMANT)
	var dormant := enemies.size() - awake.size()
	_pace_t -= delta
	if pending.size() > 0 and (_pace_t <= 0.0 or awake.is_empty()):
		if awake.is_empty() and _pace_t > 3.0:
			_pace_t = 3.0
		elif _pace_t <= 0.0:
			_introduce_next()
			_pace_t = _pace_interval()
	elif pending.is_empty() and awake.is_empty() and dormant > 0:
		_idle_t += delta
		if _idle_t > 8.0:
			_idle_t = 0.0
			if awaken_exhibit(""):
				hud.toast("You hear stone grinding... an exhibit has woken up.", 3.0)
	else:
		_idle_t = 0.0
	_update_hud()

func _update_hud() -> void:
	hud.set_round(round_num, remaining(), round_total)
	var obj := ""
	if not round_active:
		obj = ""
	elif remaining() == 0:
		obj = "Museum cleared"
	else:
		var dormant: int = active_enemies().filter(func(e): return e.state == Enemy.S.DORMANT).size()
		obj = "Destroy the haunted: %d remaining" % remaining()
		if pending.size() > 0:
			obj += "  (%d yet to appear)" % pending.size()
		if dormant > 0 and GameSettings.diff("markers"):
			obj += "\nSome exhibits are only sleeping - approach or shoot them"
	hud.set_objective(obj)

func _introduce_next() -> void:
	if pending.is_empty():
		return
	var k: int = pending.pop_front()
	var comp := _compose(round_num)
	var scale := 1.0 + 0.12 * (int(comp.scale) - 1)
	var e := _spawn_kind(k, scale)
	if e == null:
		return
	match k:
		Enemy.Kind.ENTITY:
			Fx.ghost_burst(museum, e.global_position + Vector3.UP, e.eye_color)
			Sfx.play(museum, "ghost_wail", e.global_position + Vector3.UP, 0.0)
			hud.toast("A presence manifests in the %s..." % museum.zone_name(e.global_position), 3.0)
			get_tree().call_group("cctv", "record_event", "phase", e.global_position, "Entity manifested in %s" % museum.zone_name(e.global_position))
		Enemy.Kind.BEAST:
			Sfx.play(museum, "growl", e.global_position + Vector3.UP, 4.0, 0.6)
			hud.toast("Something big is loose in the %s." % museum.zone_name(e.global_position), 3.0)
		_:
			hud.toast("Footsteps... more of the night staff are wandering the halls.", 3.0)

func _on_killed(e: Node) -> void:
	if not round_active:
		return
	round_kills += 1
	stats.kills += 1
	_update_hud()
	if round_kills >= round_total and pending.is_empty():
		_round_complete()

func _round_complete() -> void:
	if not round_active:
		return
	round_active = false
	haunting.enabled = false
	set_alarm(false)
	GameSettings.record_round(round_num)
	Sfx.play(museum, "round_chime", null, 0.0)
	hud.show_summary(_summary_data(true), SUMMARY_SECONDS)
	_start_countdown(SUMMARY_SECONDS, "next")

func _summary_data(won: bool) -> Dictionary:
	var shots: int = round_stats.get("shots", 0)
	return {"won": won, "round": round_num, "kills": round_kills, "total": round_total, "time": round_time,
		"accuracy": (100.0 * round_stats.get("hits", 0) / shots) if shots > 0 else 0.0,
		"damage": round_stats.get("damage", 0.0), "best": GameSettings.best_round,
		"total_kills": stats.kills, "total_time": stats.time}

func _on_player_died() -> void:
	if not round_active:
		return
	round_active = false
	haunting.enabled = false
	hud.show_death(_summary_data(false), DEATH_SECONDS)
	_start_countdown(DEATH_SECONDS, "restart")

func _start_countdown(seconds: float, action: String) -> void:
	_countdown = seconds
	_countdown_action = action

func _run_countdown_action() -> void:
	_countdown = -1.0
	match _countdown_action:
		"next":
			_begin_round(round_num + 1)
		"restart":
			restart_round()
	_countdown_action = ""

## Skip the countdown (Enter / E on the summary or death screen).
func skip_countdown() -> void:
	if _countdown >= 0.0:
		_run_countdown_action()

func restart_round() -> void:
	_countdown = -1.0
	_countdown_action = ""
	if player.dead or player.hp < player.MAX_HP:
		player.respawn()
	_begin_round(maxi(round_num, 1))

# ------------------------------------------------------------------ spawning

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.despawn()
	for e in get_parent().get_children():
		if e is Enemy and not e.is_queued_for_deletion():
			e.queue_free()

func _spawn_point(min_dist := 11.0) -> Vector3:
	var cands := []
	for z in museum.zones:
		if z.name == SAFE_ZONE:
			continue
		for p in z.points:
			cands.append(_snap(p))
	cands.shuffle()
	var cam: Camera3D = player.camera
	var here: String = museum.zone_name(player.global_position)
	for relax in 3:
		for p in cands:
			var d: float = p.distance_to(player.global_position)
			if d < min_dist * (1.0 - relax * 0.3):
				continue
			if relax == 0 and (cam.is_position_in_frustum(p + Vector3.UP) or museum.zone_name(p) == here):
				continue
			return p
	return cands[0]

func _patrol_route(from: Vector3) -> Array:
	var pts := []
	for z in museum.zones:
		for p in z.points:
			if p.distance_to(from) < 22.0:
				pts.append(_snap(p))
	pts.shuffle()
	return pts.slice(0, 4)

func _configure(e: Enemy, kind: int, scale: float) -> void:
	e.kind = kind
	match kind:
		Enemy.Kind.EXHIBIT:
			e.max_hp = (170.0 if e.statue else 130.0) * scale
			e.walk_speed = 0.9
			e.chase_speed = 2.6 if e.statue else 1.45
			e.damage = 22.0 if e.statue else 18.0
			e.attack_range = 1.5 if e.statue else 1.7
			e.attack_cooldown = 1.8
			e.eye_color = Color(1.0, 0.25, 0.1) if e.statue else Color(1.0, 0.55, 0.1)
			e.detect_range = 18.0
		Enemy.Kind.STAFF:
			e.max_hp = 90.0 * scale
			e.walk_speed = 1.3
			e.chase_speed = 3.2
			e.damage = 9.0
			e.attack_range = 1.6
			e.attack_cooldown = 1.3
			e.height = randf_range(1.75, 1.88)
			e.eye_color = Color(0.4, 0.9, 1.0)
			e.detect_range = 14.0
		Enemy.Kind.ENTITY:
			e.max_hp = 75.0 * scale
			e.walk_speed = 1.2
			e.chase_speed = 2.6
			e.damage = 14.0
			e.attack_range = 2.2
			e.attack_cooldown = 2.2
			e.height = 1.9
			e.eye_color = Color(0.5, 1.0, 0.8)
			e.detect_range = 20.0
		Enemy.Kind.BEAST:
			e.max_hp = 220.0 * scale
			e.walk_speed = 1.2
			e.chase_speed = 3.7
			e.damage = 20.0
			e.attack_range = 1.9
			e.attack_cooldown = 1.6
			e.height = 2.1
			e.eye_color = Color(1.0, 0.45, 0.05)
			e.detect_range = 16.0

func _add_enemy(e: Enemy, pos: Vector3) -> Enemy:
	e.position = pos + Vector3(0, 0.05, 0)
	e.killed.connect(_on_killed)
	get_parent().add_child(e)
	return e

func _spawn_kind(kind: int, scale: float, pos = null, prefab := "") -> Enemy:
	var e := Enemy.new()
	match kind:
		Enemy.Kind.STAFF:
			e.prefab = prefab if prefab != "" else C + STAFF_MODELS[randi() % STAFF_MODELS.size()] + ".tscn"
			e.label_name = "Haunted staff"
		Enemy.Kind.ENTITY:
			e.prefab = prefab if prefab != "" else ENTITY_MODELS[randi() % ENTITY_MODELS.size()]
			e.label_name = "Entity"
		Enemy.Kind.BEAST:
			e.prefab = prefab if prefab != "" else BEAST_MODELS[randi() % BEAST_MODELS.size()]
			e.label_name = "Beast"
		Enemy.Kind.EXHIBIT:
			e.prefab = prefab if prefab != "" else "SM_Gen_Chr_Skeleton_01"
			e.label_name = "Exhibit"
	_configure(e, kind, scale)
	var p: Vector3 = _snap(pos) if pos is Vector3 else _spawn_point()
	if kind == Enemy.Kind.STAFF:
		e.patrol = _patrol_route(p)
	e.model_yaw = randf() * TAU
	return _add_enemy(e, p)

func _spawn_exhibit(spot: Dictionary, scale: float, dormant: bool) -> Enemy:
	var e := Enemy.new()
	e.prefab = spot.prefab
	e.statue = spot.statue
	e.dormant = dormant
	e.label_name = spot.title
	e.source_exhibit = spot.node
	_configure(e, Enemy.Kind.EXHIBIT, scale)
	e.height = 1.9 if spot.statue else float(spot.size)
	e.model_yaw = deg_to_rad(spot.yaw)
	if is_instance_valid(spot.node):
		spot.node.visible = false
	var p: Vector3 = spot.pos + (Vector3(0, 0.12, 0) if not spot.statue else Vector3.ZERO)
	return _add_enemy(e, p)

## Wakes a dormant exhibit whose name contains `filter` (any when empty). If none is dormant but a
## matching exhibit is still on display, it becomes a bonus enemy (relics, events).
func awaken_exhibit(filter: String) -> bool:
	var dormant: Array = active_enemies().filter(func(e): return e.state == Enemy.S.DORMANT and (filter == "" or e.label_name.contains(filter) or e.prefab.contains(filter)))
	if dormant.size() > 0:
		dormant.shuffle()
		var nearest: Enemy = dormant[0]
		nearest.awaken()
		return true
	if filter == "" or not round_active:
		return false
	for s in museum.possessable:
		if (s.title.contains(filter) or s.prefab.contains(filter)) and is_instance_valid(s.node) and s.node.visible:
			if bonus_spawned >= 4:
				return false
			bonus_spawned += 1
			round_total += 1
			var e := _spawn_exhibit(s, 1.0 + 0.12 * (int(_compose(round_num).scale) - 1), true)
			e.awaken.call_deferred(0.8)
			_update_hud()
			return true
	return false

## Extra enemy from a relic or event; counted in the round total (capped per round).
func spawn_bonus(kind: int, pos: Vector3, prefab := "") -> void:
	if not round_active or bonus_spawned >= 4:
		return
	bonus_spawned += 1
	round_total += 1
	var e := _spawn_kind(kind, 1.0 + 0.12 * (int(_compose(round_num).scale) - 1), pos, prefab)
	if e:
		Fx.ghost_burst(museum, e.global_position + Vector3.UP, e.eye_color)
		e._last_seen = player.global_position
		e.call_deferred("_enter", Enemy.S.ALERT)
	_update_hud()

## Cursed relic interactions (one each per round).
func on_relic(relic: String, _pos: Vector3) -> void:
	match relic:
		"longship":
			haunting.longship_fog(true)
			hud.toast("The war horn's call echoes... the longship's crew answers.", 3.5)
		"totem":
			haunting.totem_pulse(true)
			hud.toast("The totem's runes burn green. Something steps out of the stone.", 3.5)
		"crystal":
			haunting.occult_encounter()
			hud.toast("The crystal shows a face behind you. The seance has begun!", 3.5)
		"tomb":
			haunting.tomb_encounter()
			hud.toast("The seal cracks. The Nameless King's servants awaken.", 3.5)

func open_terminal() -> void:
	cctv.open_terminal()

# ------------------------------------------------------------------ alarm

func _build_alarm() -> void:
	_alarm_light = SpotLight3D.new()
	_alarm_light.light_color = Color(1, 0.1, 0.05)
	_alarm_light.spot_range = 22.0
	_alarm_light.spot_angle = 35.0
	_alarm_light.light_energy = 0.0
	_alarm_light.visible = false
	museum.add_child(_alarm_light)
	_alarm_light.position = Vector3(0, 5.6, 0)

func toggle_alarm() -> void:
	set_alarm(not alarm_on)

func set_alarm(on: bool) -> void:
	if on == alarm_on:
		return
	alarm_on = on
	if on:
		_alarm_sound = Sfx.loop(museum, "alarm", Vector3(0, 4, 0), 0.0, "SFX")
		_alarm_light.visible = true
		_alarm_light.light_energy = 8.0
		_alarm_t = 0.0
		hud.toast("ALARM ACTIVE - every monster in the museum is heading for the main hall.", 3.0)
		get_tree().call_group("cctv", "record_event", "alarm", Vector3.ZERO, "Museum alarm activated")
	else:
		if is_instance_valid(_alarm_sound):
			_alarm_sound.queue_free()
		_alarm_light.visible = false

func _update_alarm(delta: float) -> void:
	if not alarm_on:
		return
	_alarm_light.rotation = Vector3(-1.0, Time.get_ticks_msec() * 0.006, 0)
	_alarm_t -= delta
	if _alarm_t <= 0.0:
		_alarm_t = 3.0
		get_tree().call_group("enemies", "hear_noise", Vector3(0, 0, -1), 80.0, false)

# ------------------------------------------------------------------ status / developer helpers

func _board_text() -> String:
	var cams := get_tree().get_nodes_in_group("security_cameras")
	var down: int = cams.filter(func(c): return not c.is_working()).size()
	return "MUSEUM STATUS\nRound %d  ·  %s\nMonsters left: %d\nAlarm: %s\nCameras: %d online, %d down\nBest round: %d" % [
		round_num, GameSettings.difficulty, remaining(), "ON" if alarm_on else "off", cams.size() - down, down, GameSettings.best_round]

func status_text() -> String:
	var enemies := active_enemies()
	var dormant: int = enemies.filter(func(e): return e.state == Enemy.S.DORMANT).size()
	var cams := get_tree().get_nodes_in_group("security_cameras")
	var rec: int = cams.filter(func(c): return c.recording).size()
	var down: int = cams.filter(func(c): return not c.is_working()).size()
	var acc: float = 100.0 * stats.hits / stats.shots if stats.shots > 0 else 0.0
	return "Round %d   (%s)\nMonsters remaining: %d of %d\nAwake: %d   Dormant: %d   Yet to appear: %d\nHaunting intensity: %d%%\nAlarm: %s\nCameras: %d recording, %d live-only, %d without signal\n\nKills: %d   Accuracy: %d%%\nDamage taken: %d\nTime this round: %s\nBest completed round: %d" % [
		round_num, GameSettings.difficulty, remaining(), round_total, enemies.size() - dormant, dormant, pending.size(),
		int(haunting.intensity * 100.0), "ON" if alarm_on else "off", rec, cams.size() - rec, down,
		stats.kills, int(acc), int(stats.damage), _fmt_time(round_time), GameSettings.best_round]

static func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

func dev_spawn(kind: int) -> void:
	if kind == Enemy.Kind.EXHIBIT:
		var spots: Array = museum.possessable.filter(func(s): return is_instance_valid(s.node) and s.node.visible)
		if spots.is_empty():
			return
		var s: Dictionary = spots[randi() % spots.size()]
		round_total += 1
		var e := _spawn_exhibit(s, 1.0, true)
		e.awaken.call_deferred(0.5)
	else:
		round_total += 1
		var fwd: Vector3 = -player.camera.global_basis.z
		fwd.y = 0.0
		_spawn_kind(kind, 1.0, player.global_position + fwd.normalized() * 6.0)
	_update_hud()

func dev_remove_all() -> void:
	_clear_enemies()
	pending.clear()
	round_total = round_kills
	if round_active and remaining() == 0:
		_round_complete()

func dev_complete_round() -> void:
	_clear_enemies()
	pending.clear()
	round_kills = round_total
	_round_complete()

func dev_teleport(zone_index: int) -> void:
	var z: Dictionary = museum.zones[zone_index]
	player.global_position = _snap(z.points[0]) + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
