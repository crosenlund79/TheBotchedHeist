extends Node
## Haunted-museum rounds: bakes a navigation mesh, spawns monsters, counts kills, shows
## "MUSEUM CLEARED!" and starts a slightly harder round. Freezes monsters during CCTV replays.

const MONSTER := preload("res://Scripts/monster.gd")

# Horror Mansion monsters (+ the two figures from the gallery) and their traits.
const ROSTER := [
	{"prefab": "SM_Chr_Werewolf_01", "hp": 120, "chase": 3.4, "dmg": 12, "wander": "sneak_walk", "h": 2.05, "eye": Color(1, 0.6, 0.1)},
	{"prefab": "SM_Chr_Demon_01", "hp": 160, "chase": 2.7, "dmg": 16, "wander": "walking", "h": 2.1, "eye": Color(1, 0.35, 0.0)},
	{"prefab": "SM_Chr_Ghoul_01", "hp": 80, "chase": 3.6, "dmg": 8, "wander": "sneak_walk", "h": 1.8, "eye": Color(0.4, 1, 0.3)},
	{"prefab": "SM_Chr_Witch_01", "hp": 90, "chase": 3.0, "dmg": 10, "wander": "walking", "h": 1.85, "eye": Color(0.5, 1, 0.4)},
	{"prefab": "SM_Chr_Butcher_01", "hp": 170, "chase": 2.6, "dmg": 18, "wander": "walking", "h": 1.95, "eye": Color(1, 0.1, 0.1)},
	{"prefab": "SM_Chr_Yokai_01", "hp": 100, "chase": 3.3, "dmg": 11, "wander": "sneak_walk", "h": 1.85, "eye": Color(0.3, 0.9, 1)},
	{"prefab": "SM_Chr_Gimp_01", "hp": 110, "chase": 3.1, "dmg": 12, "wander": "crouched_walking", "h": 1.85, "eye": Color(1, 0.1, 0.3)},
	{"prefab": "SM_Chr_Count_01", "hp": 130, "chase": 3.0, "dmg": 13, "wander": "walking", "h": 1.95, "eye": Color(0.8, 0.2, 1)},
]
const SPAWNS := [
	Vector3(-6, 0, -22), Vector3(1.8, 0, -26.0), Vector3(6, 0, -22), Vector3(7.5, 0, -9.2), Vector3(-2.0, 0, -9.6),
	Vector3(-12.0, 0, 4.0), Vector3(12.0, 0, 2.0), Vector3(-6.0, 0, 5.6), Vector3(7.5, 0, -5.5), Vector3(-14.5, 0, -4.0),
]
const BASE_COUNT := 5
const MAX_COUNT := 10
const MAX_SCALING_ROUND := 6

var frozen := false
var round_num := 0
var alive := 0
var player: Node3D
var hud: Node
var cctv: Node
var region: NavigationRegion3D

func start(museum: Node3D) -> void:
	player = get_tree().get_first_node_in_group("player")
	hud = get_parent().get_node("HUD")
	cctv = get_parent().get_node("CCTV")
	player.health_changed.connect(hud.set_health)
	player.shot_hit.connect(hud.hit_marker)
	player.died.connect(hud.show_death)
	hud.set_health(player.hp, player.MAX_HP)
	_bake_navigation(museum)

func _bake_navigation(museum: Node3D) -> void:
	region = NavigationRegion3D.new()
	museum.add_child(region)
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	# Only floor-level geometry: walls and exhibits block, ceilings are ignored.
	nm.filter_baking_aabb = AABB(Vector3(-22, -0.5, -30), Vector3(44, 2.6, 50))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, museum)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func():
		region.navigation_mesh = nm
		_next_round.call_deferred())

func _process(_delta: float) -> void:
	frozen = cctv != null and cctv.is_replaying()
	if hud:
		hud.visible = not frozen

func _next_round() -> void:
	round_num += 1
	var r: int = min(round_num, MAX_SCALING_ROUND) - 1
	var count: int = min(BASE_COUNT + round_num, MAX_COUNT)
	var mult := 1.0 + 0.1 * r
	hud.show_message("ROUND %d" % round_num, 2.0)
	var points := SPAWNS.duplicate()
	points.shuffle()
	# Never spawn right next to the player: keep points at least 9 m away when there are enough.
	var far: Array = points.filter(func(q): return q.distance_to(player.global_position) > 9.0)
	if far.size() >= 3:
		points = far
	alive = 0
	for i in count:
		var data: Dictionary = ROSTER[(i + round_num) % ROSTER.size()]
		var m := MONSTER.new()
		m.prefab = data.prefab
		m.max_hp = data.hp * mult
		m.chase_speed = data.chase * (1.0 + 0.04 * r)
		m.damage = data.dmg * mult
		m.wander_clip = data.wander
		m.height = data.h
		m.head_height = data.h * 0.78
		m.eye_color = data.eye
		m.detect_range = 12.0 + r * 0.8
		m.player = player
		m.director = self
		m.position = points[i % points.size()] + Vector3(randf_range(-0.6, 0.6), 0.05, randf_range(-0.6, 0.6))
		m.add_to_group("monsters")
		m.killed.connect(_on_killed)
		get_parent().add_child(m)
		alive += 1
	hud.set_monsters(alive, count, round_num)

func _on_killed(_m: Node) -> void:
	alive -= 1
	hud.set_monsters(alive, -1, round_num)
	if alive <= 0:
		hud.show_message("MUSEUM CLEARED!", 3.0)
		await get_tree().create_timer(5.0).timeout
		_next_round()
