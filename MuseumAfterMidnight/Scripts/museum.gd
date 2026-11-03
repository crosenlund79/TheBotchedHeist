extends Node3D
## Builds the museum at startup: architecture from the Synty Heist building kit,
## five themed galleries of converted Synty Unity assets, lighting and two security cameras.

const H := "res://Assets/Synty/PolygonHeist/Prefab/"
const FX := "res://Assets/ParticleFX/Prefabs/FX/"
const SECURITY_CAMERA := preload("res://Scripts/security_camera.gd")
const HALL_H := 6.0
const ROOM_H := 3.6
const WALL_T := 0.16

var arch: Node3D
var exhibits: Node3D
var lights: Node3D
var _tinted := {}
var _plinth_mat: StandardMaterial3D
var _brass_mat: StandardMaterial3D
var _flicker: Array = []   # [light, base_energy, phase]

func _ready() -> void:
	arch = _group("Architecture"); exhibits = _group("Exhibits"); lights = _group("Lights")
	_plinth_mat = StandardMaterial3D.new()
	_plinth_mat.albedo_color = Color(0.11, 0.11, 0.13); _plinth_mat.roughness = 0.35
	_brass_mat = StandardMaterial3D.new()
	_brass_mat.albedo_color = Color(0.78, 0.6, 0.3); _brass_mat.metallic = 0.85; _brass_mat.roughness = 0.3
	_build_hall()
	_build_room("Samurai", Rect2(-10, -17.5, 10, 10), Color(0.30, 0.36, 0.30), Color(0.55, 0.42, 0.32), {"S": [1], "N": [1]})
	_build_room("Horror", Rect2(0, -17.5, 10, 10), Color(0.34, 0.18, 0.20), Color(0.35, 0.22, 0.24), {"S": [0], "N": [0]})
	_build_room("Crypt", Rect2(-10, -27.5, 20, 10), Color(0.20, 0.23, 0.22), Color(0.30, 0.32, 0.30), {"S": [1, 2]})
	_build_room("Western", Rect2(-20, -7.5, 10, 15), Color(0.62, 0.50, 0.36), Color(0.62, 0.42, 0.28), {"E": [1]})
	_build_room("SciFi", Rect2(10, -7.5, 10, 15), Color(0.20, 0.24, 0.34), Color(0.30, 0.34, 0.42), {"W": [1]})
	_hall_exhibits()
	_samurai_exhibits()
	_horror_exhibits()
	_western_exhibits()
	_scifi_exhibits()
	_outside()
	_crypt()
	_haunt_existing_rooms()
	_security_cameras()
	GameSettings.apply()
	$Director.start(self)

## Flickering lamps: irregular brightness with occasional drop-outs.
func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in _flicker:
		var l: Light3D = f[0]
		var n := sin(t * 7.3 + f[2]) * 0.5 + sin(t * 13.1 + f[2] * 2.0) * 0.3 + sin(t * 2.1 + f[2]) * 0.2
		var dropout := 0.15 if fmod(t + f[2], 6.7) < 0.12 else 1.0
		l.light_energy = f[1] * clampf(0.72 + 0.28 * n, 0.3, 1.1) * dropout

func _flick(l: Light3D) -> Light3D:
	_flicker.append([l, l.light_energy, randf() * 20.0])
	return l

func _group(n: String) -> Node3D:
	var g := Node3D.new(); g.name = n; add_child(g); return g

# ------------------------------------------------------------------ helpers

func _inst(path: String, parent: Node, pos: Vector3, yaw_deg := 0.0, scl := Vector3.ONE) -> Node3D:
	var n: Node3D = load(path).instantiate()
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.scale = scl
	return n

## Heist kit pieces share one atlas material; tinted copies give each room its own colour.
func _tint(node: Node, tint: Color) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		for s in mi.mesh.get_surface_count():
			var base: Material = mi.get_active_material(s)
			if base == null or not (base is StandardMaterial3D):
				continue
			if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var key := [base.get_instance_id(), tint]
			if not _tinted.has(key):
				var m: StandardMaterial3D = base.duplicate()
				m.albedo_color = tint
				_tinted[key] = m
			mi.set_surface_override_material(s, _tinted[key])

## One wall side of a rectangle, built from 5 m Heist interior panels facing into the room.
## side: N/S/W/E; doors: indices of 5 m segments that get a double-door panel.
func _wall_side(r: Rect2, side: String, height: float, tint: Color, doors: Array, pieces := {}) -> void:
	var length := r.size.x if side in ["N", "S"] else r.size.y
	var count := int(round(length / 5.0))
	for i in count:
		var piece: String = pieces.get(i, H + "Environment/SM_Env_Wall_Interior_DoubleDoor_01.tscn" if doors.has(i) else H + "Environment/SM_Env_Wall_Interior_01.tscn")
		var pos: Vector3; var yaw := 0.0
		match side:
			"N": pos = Vector3(r.position.x + i * 5.0, 0, r.position.y); yaw = 0.0
			"S": pos = Vector3(r.position.x + (i + 1) * 5.0, 0, r.end.y); yaw = 180.0
			"W": pos = Vector3(r.position.x, 0, r.position.y + (i + 1) * 5.0); yaw = 90.0
			"E": pos = Vector3(r.end.x, 0, r.position.y + i * 5.0); yaw = -90.0
		var w := _inst(piece, arch, pos, yaw, Vector3(1, height / 3.0, 1))
		if not pieces.has(i):
			_tint(w, tint)

func _floor_and_ceiling(r: Rect2, height: float, floor_piece: String, floor_tint: Color, ceiling_skip := []) -> void:
	for x in range(int(r.size.x / 5.0)):
		for z in range(int(r.size.y / 5.0)):
			var p := Vector3(r.position.x + x * 5.0, 0, r.position.y + z * 5.0)
			var f := _inst(floor_piece, arch, p)
			if floor_tint != Color.WHITE:
				_tint(f, floor_tint)
			if not ceiling_skip.has(Vector2i(x, z)):
				var c := _inst(H + "Environment/SM_Env_Ceiling_06.tscn", arch, p + Vector3(0, height, 0))
				_tint(c, Color(0.22, 0.22, 0.25))

func _spot(pos: Vector3, target: Vector3, color: Color, energy: float, angle: float, group := "shadow_high", rng := 0.0) -> SpotLight3D:
	var s := SpotLight3D.new()
	lights.add_child(s)
	s.position = pos
	if not pos.is_equal_approx(target):
		var up := Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD
		s.look_at_from_position(pos, target, up)
	s.light_color = color; s.light_energy = energy
	s.spot_angle = angle; s.spot_angle_attenuation = 0.8
	s.spot_range = rng if rng > 0.0 else pos.distance_to(target) + 2.0
	s.shadow_bias = 0.04
	s.add_to_group("preset_light"); s.add_to_group(group)
	return s

func _omni(pos: Vector3, color: Color, energy: float, rng: float, group := "") -> OmniLight3D:
	var o := OmniLight3D.new()
	lights.add_child(o)
	o.position = pos; o.light_color = color; o.light_energy = energy; o.omni_range = rng
	o.add_to_group("preset_light")
	if group != "":
		o.add_to_group(group)
	return o

func _label(text: String, pos: Vector3, yaw: float, size := 48, color := Color(0.93, 0.88, 0.76), parent: Node = null) -> Label3D:
	var l := Label3D.new()
	(parent if parent else exhibits).add_child(l)
	l.text = text; l.font_size = size; l.pixel_size = 0.004
	l.modulate = color; l.outline_size = 0
	l.position = pos; l.rotation_degrees.y = yaw
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.double_sided = false
	return l

func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size; bm.material = mat
	mi.mesh = bm; mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new(); mi.add_child(sb)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
		cs.shape = sh; sb.add_child(cs)
	return mi

## A converted Unity prefab on a stone plinth, with optional glass case, a spotlight and a placard.
## height: plinth height (0 = floor dais), size: largest dimension of the exhibit.
func exhibit(prefab: String, pos: Vector3, yaw: float, size: float, plinth_h := 0.9, glass := false,
		ceiling := ROOM_H, light_color := Color(1.0, 0.86, 0.68), title := "") -> Node3D:
	var node := ExhibitFactory.build(prefab)
	exhibits.add_child(node)
	node.rotation_degrees.y = yaw
	var top := pos + Vector3(0, plinth_h, 0)
	var ab := ExhibitFactory.fit(node, top, size)
	var foot := Vector2(maxf(ab.size.x, 0.5) + 0.35, maxf(ab.size.z, 0.5) + 0.35)
	if plinth_h > 0.05:
		_box(Vector3(foot.x, plinth_h - 0.04, foot.y), pos + Vector3(0, (plinth_h - 0.04) * 0.5, 0), _plinth_mat, exhibits)
		_box(Vector3(foot.x + 0.06, 0.04, foot.y + 0.06), pos + Vector3(0, plinth_h - 0.02, 0), _brass_mat, exhibits, false)
	else:
		_box(Vector3(foot.x + 0.4, 0.12, foot.y + 0.4), pos + Vector3(0, 0.06, 0), _plinth_mat, exhibits)
		node.position.y += 0.12
		ab = ExhibitFactory.bounds(node)
		if not ExhibitFactory.manifest()[prefab].character:
			var sb := StaticBody3D.new(); node.add_child(sb)
			var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
			sh.size = ab.size / node.scale; cs.shape = sh
			cs.position = node.to_local(ab.get_center()); sb.add_child(cs)
	if glass:
		var c := _inst(ExhibitFactory.CASE, exhibits, top)
		c.scale = Vector3((ab.size.x + 0.2) / 0.56, (ab.size.y + 0.15) / 0.51, (ab.size.z + 0.2) / 0.56)
	var reach := maxf(ab.size.x, ab.size.z)
	_spot(Vector3(pos.x, ceiling - 0.15, pos.z) + Vector3(0.4, 0, 0.6), ab.get_center(), light_color,
		2.6 + reach * 0.9, clampf(14.0 + reach * 9.0, 18.0, 55.0))
	var front := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	var pack: String = ExhibitFactory.manifest()[prefab].pack
	var label_h := plinth_h * 0.62 if plinth_h > 0.05 else 0.4
	var lbl := _label("%s\n[ Synty Polygon %s ]" % [title if title != "" else ExhibitFactory.title_of(prefab), pack],
		pos + front * (foot.y * 0.5 + 0.21 * (0.0 if plinth_h > 0.05 else 1.0) + 0.012) + Vector3(0, label_h, 0), yaw, 24)
	if plinth_h <= 0.05:
		lbl.position = pos + front * (foot.y * 0.5 + 0.35) + Vector3(0, 0.13, 0)
		lbl.rotation_degrees.x = -70
	return node

## Hangs a flat exhibit on a wall. normal: direction the wall faces (into the room).
func wall_exhibit(prefab: String, wall_point: Vector3, normal: Vector3, size: float, flip := false,
		ceiling := ROOM_H, light := true) -> Node3D:
	var node := ExhibitFactory.build(prefab)
	exhibits.add_child(node)
	var ab := ExhibitFactory.bounds(node)
	# Rotate so the thinnest horizontal axis points along the wall normal.
	var thin_x := ab.size.x < ab.size.z
	var face_yaw := atan2(normal.x, normal.z)
	node.rotation.y = face_yaw + (PI * 0.5 if thin_x else 0.0) + (PI if flip else 0.0)
	ExhibitFactory.fit(node, wall_point, size)
	ab = ExhibitFactory.bounds(node)
	var depth := ab.size.x if absf(normal.x) > 0.5 else ab.size.z
	node.position += normal * (depth * 0.5 + 0.03)
	node.position.y += wall_point.y - ab.get_center().y + (wall_point.y - wall_point.y)
	ab = ExhibitFactory.bounds(node)
	node.position.y += wall_point.y - ab.get_center().y
	if light:
		_spot(wall_point + normal * 1.6 + Vector3(0, ceiling - wall_point.y - 0.2, 0), wall_point, Color(1.0, 0.88, 0.72), 4.0, 26.0)
	return node

func ropes(points: Array) -> void:
	for i in points.size():
		var p: Vector3 = points[i]
		_inst(H + "Props/SM_Prop_RopeBarrier_Pole_01.tscn", exhibits, p)
		if i + 1 < points.size():
			var q: Vector3 = points[i + 1]
			var r := _inst(H + "Props/SM_Prop_RopeBarrier_01.tscn", exhibits, (p + q) * 0.5)
			r.rotation.y = -atan2(q.z - p.z, q.x - p.x)
			r.scale.x = p.distance_to(q) / 1.96

# ------------------------------------------------------------------ hall

func _build_hall() -> void:
	var r := Rect2(-10, -7.5, 20, 15)
	var cream := Color(0.86, 0.82, 0.74)
	_floor_and_ceiling(r, HALL_H, H + "Environment/SM_Env_Floor_01.tscn", Color.WHITE, [Vector2i(1, 1), Vector2i(2, 1)])
	for x in [-5.0, 0.0]:
		var s := _inst(H + "Environment/SM_Env_Skylight_01.tscn", arch, Vector3(x, HALL_H, -2.5))
		_tint(s, Color(0.3, 0.3, 0.34))
	_wall_side(r, "N", HALL_H, cream, [1, 2])
	_wall_side(r, "W", HALL_H, cream, [1])
	_wall_side(r, "E", HALL_H, cream, [1])
	# Glass entrance facade, two storeys.
	var glass := H + "Environment/SM_Env_Wall_Glass_01.tscn"
	var door := H + "Environment/SM_Env_Wall_Glass_DoorFrame_01.tscn"
	_wall_side(r, "S", 3.0, cream, [], {0: glass, 1: door, 2: door, 3: glass})
	for i in 4:
		_inst(glass, arch, Vector3(r.position.x + (i + 1) * 5.0, 3.0, r.end.y), 180.0)
	# Pillars and pendant lamps.
	for p in [Vector3(-6, 0, -4.2), Vector3(6, 0, -4.2), Vector3(-6, 0, 4.2), Vector3(6, 0, 4.2)]:
		var pl := _inst(H + "Environment/SM_Env_Pillar_01.tscn", arch, p, 0, Vector3(0.8, HALL_H / 3.0, 0.8))
		_tint(pl, Color(0.9, 0.86, 0.8))
	for p in [Vector3(-7.5, HALL_H, 0), Vector3(7.5, HALL_H, 0)]:
		_inst(H + "Environment/SM_Env_Ceiling_Light_03.tscn", arch, p, 0, Vector3(1.2, 1.2, 1.2))
		_flick(_omni(p + Vector3(0, -2.2, 0), Color(1.0, 0.78, 0.5), 1.4, 7.5))
	# Moonlight through the skylights.
	var moon := _spot(Vector3(-1.5, 16, -6), Vector3(0, 0, -1.0), Color(0.62, 0.72, 1.0), 9.0, 22.0, "shadow_med", 26.0)
	moon.spot_attenuation = 0.4
	# Low warm fill so the architecture never drops to black.
	_omni(Vector3(0, 4.5, 2.5), Color(0.9, 0.75, 0.6), 0.6, 13.0)
	_omni(Vector3(0, 3.0, -5.5), Color(0.6, 0.65, 0.9), 0.5, 10.0, "detail_light")
	# Signage.
	_label("MUSEUM  AFTER  MIDNIGHT", Vector3(0, 5.15, -7.5 + WALL_T + 0.02), 0, 150, Color(0.92, 0.78, 0.48))
	_label("SAMURAI  ·  EDO PERIOD", Vector3(-2.5, 4.62, -7.5 + WALL_T + 0.02), 0, 54)
	_label("HOUSE  OF  HORRORS", Vector3(2.5, 4.62, -7.5 + WALL_T + 0.02), 0, 54)
	_label("THE  WILD  WEST", Vector3(-10 + WALL_T + 0.02, 4.62, 0), 90, 60)
	_label("FUTURE  CITY", Vector3(10 - WALL_T - 0.02, 4.62, 0), -90, 60)
	_exit_sign(Vector3(0, 3.35, 7.5 - WALL_T - 0.03), 180)
	for p in [Vector3(-9.2, 0, 6.6), Vector3(9.2, 0, 6.6), Vector3(-9.2, 0, -6.6), Vector3(9.2, 0, -6.6)]:
		_inst(H + "Props/SM_Prop_Plant_01.tscn", arch, p, randf() * 360.0, Vector3(1.3, 1.3, 1.3))
	var fx := _inst(FX + "FX_Dust_01.tscn", lights, Vector3(-2.5, 2.5, -0.5))
	fx.scale = Vector3(4, 2, 3)
	var beam := _inst(FX + "FX_Sun_Beam_01.tscn", lights, Vector3(-1.0, 0, -1.5))
	beam.scale = Vector3(1.6, 1.6, 1.6)
	beam.add_to_group("detail_fx")

func _exit_sign(pos: Vector3, yaw: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.9, 0.35); m.emission_enabled = true
	m.emission = Color(0.1, 1.0, 0.4); m.emission_energy_multiplier = 2.5
	var b := _box(Vector3(0.7, 0.26, 0.06), pos, m, arch, false)
	b.rotation_degrees.y = yaw
	var l := _label("EXIT", pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 0.035), yaw, 40, Color(0.02, 0.15, 0.05))
	l.pixel_size = 0.003
	_omni(pos + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 0.3), Color(0.2, 1.0, 0.45), 0.25, 2.5, "detail_light")

func _hall_exhibits() -> void:
	# Centrepiece: Viking longship on a low dais behind ropes.
	var ship := exhibit("SM_Veh_Boat_01", Vector3(0, 0, -0.8), 90, 8.5, 0.0, false, HALL_H, Color(0.9, 0.9, 1.0), "Viking Longship")
	# Show the sail furled so the hall title stays readable from the entrance.
	for mi in ship.find_children("*Sail_Open*", "MeshInstance3D", true, false):
		mi.visible = false
	_spot(Vector3(4.5, HALL_H - 0.3, 3.0), Vector3(0, 1.0, -0.8), Color(1.0, 0.82, 0.6), 7.0, 30.0, "shadow_med")
	ropes([Vector3(-5, 0, 1.8), Vector3(-1.7, 0, 2.6), Vector3(1.7, 0, 2.6), Vector3(5, 0, 1.8)])
	exhibit("SM_Chr_Chief_01_Brown", Vector3(-7.6, 0, -2.4), 70, 1.85, 0.0, false, HALL_H)
	exhibit("SM_Chr_Shieldmadien_Brown", Vector3(7.6, 0, -2.4), -70, 1.85, 0.0, false, HALL_H)
	exhibit("SM_Env_Stone_Statue_01", Vector3(-3.2, 0, -6.2), 0, 1.9, 0.5, false, HALL_H, Color(0.8, 0.85, 1.0), "Rune Stone")
	exhibit("SM_Prop_Rock_Totem_01", Vector3(3.2, 0, -6.2), 0, 1.7, 0.5, false, HALL_H, Color(0.8, 0.85, 1.0), "Stone Totem")
	exhibit("SM_Wep_LargeAxe_01", Vector3(-6.5, 0, 1.8), 30, 0.9, 1.0, true, HALL_H)
	exhibit("SM_Wep_Horn_01", Vector3(6.5, 0, 1.8), -30, 0.55, 1.0, true, HALL_H, Color(1.0, 0.86, 0.68), "Drinking Horn")
	exhibit("SM_Prop_Chest_01", Vector3(-3.5, 0, 5.0), 180, 1.0, 0.45, false, HALL_H, Color(1.0, 0.86, 0.68), "Iron-bound Chest")
	exhibit("SM_Wep_Sword_01", Vector3(3.5, 0, 5.0), 180, 0.9, 1.0, true, HALL_H, Color(1.0, 0.86, 0.68), "Viking Sword")
	var shields := ["SM_Prop_Shield_Decor_01", "SM_Prop_Shield_Decor_02", "SM_Prop_Shield_Decor_03", "SM_Prop_Shield_Decor_04"]
	for i in 4:
		var x := -9.0 + i * 1.6 if i < 2 else 6.6 + (i - 2) * 1.6
		wall_exhibit(shields[i], Vector3(x + 0.7, 2.6, -7.5 + WALL_T), Vector3(0, 0, 1), 1.0, false, HALL_H, false)
	for g in [["SM_Gen_Prop_Statue_01", Vector3(-9.0, 0, -4.2), 90], ["SM_Gen_Prop_Statue_03", Vector3(9.0, 0, -4.2), -90],
			["SM_Gen_Prop_Statue_02", Vector3(-9.0, 0, 4.2), 90], ["SM_Gen_Prop_Statue_05", Vector3(9.0, 0, 4.2), -90]]:
		exhibit(g[0], g[1], g[2], 1.5, 0.6, false, HALL_H, Color(0.85, 0.9, 1.0), "Classical Statue")

# ------------------------------------------------------------------ rooms

func _build_room(theme: String, r: Rect2, wall_tint: Color, floor_tint: Color, doors: Dictionary) -> void:
	_floor_and_ceiling(r, ROOM_H, H + "Environment/SM_Env_Floor_02.tscn", floor_tint)
	for side in ["N", "S", "W", "E"]:
		_wall_side(r, side, ROOM_H, wall_tint, doors.get(side, []))
	_omni(Vector3(r.get_center().x, ROOM_H - 0.6, r.get_center().y), Color(0.75, 0.75, 0.9), 0.35, maxf(r.size.x, r.size.y) * 0.8)

func _samurai_exhibits() -> void:
	var c := Vector3(-5, 0, -12.5)
	exhibit("SM_Chr_Samurai_Warrior_01_Black", c + Vector3(-3.6, 0, -3.4), 0, 1.85, 0.0)
	exhibit("SM_Chr_Ninja_01_Black", c + Vector3(-2.2, 0, -3.6), 0, 1.8, 0.0)
	exhibit("SM_Chr_Geisha_01_White", c + Vector3(-0.8, 0, -3.4), 0, 1.75, 0.0)
	exhibit("SM_Prop_Bell_01", c + Vector3(0, 0, 0), 0, 1.6, 0.35, false, ROOM_H, Color(1.0, 0.8, 0.55), "Temple Bell")
	exhibit("SM_Prop_Statue_Lion_01", c + Vector3(-1.6, 0, 3.4), 20, 1.0, 0.7)
	exhibit("SM_Prop_Statue_Lion_02", c + Vector3(1.6, 0, 3.4), -20, 1.0, 0.7)
	exhibit("SM_Wep_Odachi_01", c + Vector3(-4.0, 0, -1.2), 90, 1.4, 0.9, true)
	exhibit("SM_Wep_Naginata_01", c + Vector3(-4.0, 0, 1.4), 90, 1.6, 0.9, true)
	exhibit("SM_Wep_Ninjato_01", c + Vector3(4.0, 0, -1.2), -90, 0.9, 0.9, true)
	exhibit("SM_Wep_Sai_01", c + Vector3(4.0, 0, 1.4), -90, 0.5, 1.0, true)
	exhibit("SM_Prop_WarriorShoulderArmor", c + Vector3(-2.6, 0, -0.8), 30, 0.6, 1.0, true, ROOM_H, Color(1.0, 0.86, 0.68), "Shoulder Armour")
	exhibit("SM_Prop_Bonsai_01", c + Vector3(2.6, 0, -0.8), -30, 0.8, 0.8)
	exhibit("SM_Prop_Stone_Lantern_01", c + Vector3(-4.1, 0, 4.0), 45, 1.3, 0.0)
	exhibit("SM_Prop_Zen_Lantern_01", c + Vector3(4.1, 0, 4.0), -45, 1.0, 0.0)
	for p in [c + Vector3(-2.5, ROOM_H - 0.9, 1.5), c + Vector3(2.5, ROOM_H - 0.9, 1.5), c + Vector3(0, ROOM_H - 0.9, -1.8)]:
		var lantern := ExhibitFactory.build("SM_Prop_Paper_Lantern_01")
		exhibits.add_child(lantern)
		ExhibitFactory.fit(lantern, p, 0.55)
		_omni(p + Vector3(0, 0.2, 0), Color(1.0, 0.55, 0.25), 1.1, 4.5, "detail_light")

func _horror_exhibits() -> void:
	var c := Vector3(5, 0, -12.5)
	exhibit("SM_Prop_Coffin_01", c + Vector3(0, 0, 0.3), 0, 2.1, 0.45, false, ROOM_H, Color(0.75, 0.6, 1.0))
	exhibit("SM_Chr_Count_01", c + Vector3(0.6, 0, -3.5), 15, 1.95, 0.0, false, ROOM_H, Color(0.8, 0.5, 0.9), "The Count")
	exhibit("SM_Chr_Witch_01", c + Vector3(2.6, 0, -3.5), -15, 1.9, 0.0, false, ROOM_H, Color(0.6, 1.0, 0.6), "The Witch")
	exhibit("SM_Gen_Chr_Skeleton_01", c + Vector3(3.8, 0, 3.6), -135, 1.8, 0.0, false, ROOM_H, Color(0.85, 0.9, 1.0), "Anatomy Skeleton")
	exhibit("SM_Prop_Gramophone_01", c + Vector3(-3.8, 0, -1.0), 90, 0.75, 0.9)
	exhibit("SM_Prop_Crystal_Ball_01", c + Vector3(-3.8, 0, 1.6), 90, 0.4, 1.0, true, ROOM_H, Color(0.7, 0.6, 1.0))
	exhibit("SM_Prop_Mask_Count_01", c + Vector3(3.8, 0, -1.0), -90, 0.4, 1.1, true)
	exhibit("SM_Prop_Book_Open_01", c + Vector3(3.8, 0, 1.0), -90, 0.5, 1.0, true, ROOM_H, Color(1.0, 0.86, 0.68), "Grimoire")
	exhibit("SM_Prop_Clock_01", c + Vector3(-4.3, 0, 4.2), 45, 2.2, 0.0, false, ROOM_H, Color(1.0, 0.86, 0.68), "Grandfather Clock")
	exhibit("SM_Prop_Chest_01", c + Vector3(-1.6, 0, 3.6), 0, 0.9, 0.4)
	var lamp := exhibit("SM_Prop_Lamp_01", c + Vector3(1.6, 0, 3.6), 0, 0.6, 0.9, false, ROOM_H, Color(1.0, 0.7, 0.4), "Oil Lamp")
	_flick(_omni(ExhibitFactory.bounds(lamp).get_center() + Vector3(0, 0.15, 0), Color(1.0, 0.55, 0.25), 0.9, 3.5))
	var flame := _inst(FX + "FX_Candle_Flame_01.tscn", lights, ExhibitFactory.bounds(lamp).end - Vector3(ExhibitFactory.bounds(lamp).size.x * 0.5, 0.02, ExhibitFactory.bounds(lamp).size.z * 0.5))
	flame.scale = Vector3(0.6, 0.6, 0.6)
	var paints := ["SM_Prop_Painting_01", "SM_Prop_Painting_02", "SM_Prop_Painting_03", "SM_Prop_Painting_04"]
	wall_exhibit(paints[0], c + Vector3(-5 + WALL_T, 1.8, -1.6), Vector3(1, 0, 0), 1.3)
	wall_exhibit(paints[1], c + Vector3(-5 + WALL_T, 1.8, 1.8), Vector3(1, 0, 0), 1.3)
	wall_exhibit(paints[2], c + Vector3(5 - WALL_T, 1.8, -1.6), Vector3(-1, 0, 0), 1.3)
	wall_exhibit(paints[3], c + Vector3(5 - WALL_T, 1.8, 1.8), Vector3(-1, 0, 0), 1.3)
	wall_exhibit("SM_Prop_Mirror_01", c + Vector3(0, 1.8, -5 + WALL_T), Vector3(0, 0, 1), 1.2)
	_omni(c + Vector3(0, 2.4, 0), Color(0.55, 0.3, 0.8), 0.9, 8.0, "detail_light")

func _western_exhibits() -> void:
	var c := Vector3(-15, 0, 0)
	exhibit("SM_Veh_Stagecoach_01", c + Vector3(0.2, 0, -0.6), 90, 5.2, 0.0, false, ROOM_H, Color(1.0, 0.8, 0.55), "Stagecoach")
	ropes([c + Vector3(-2.6, 0, 2.4), c + Vector3(0, 0, 2.9), c + Vector3(2.6, 0, 2.4)])
	exhibit("SM_Chr_Sheriff_01", c + Vector3(-3.4, 0, -5.6), 20, 1.85, 0.0)
	exhibit("SM_Chr_Cowgirl_01", c + Vector3(-1.8, 0, -6.0), 10, 1.75, 0.0)
	exhibit("SM_Prop_Piano_01", c + Vector3(3.2, 0, -5.6), -20, 1.6, 0.0, false, ROOM_H, Color(1.0, 0.8, 0.55), "Saloon Piano")
	exhibit("SM_Wep_Revolver_01", c + Vector3(-3.9, 0, 4.0), 90, 0.32, 1.0, true)
	exhibit("SM_Wep_Rifle_01", c + Vector3(-3.9, 0, 5.8), 90, 1.0, 1.0, true, ROOM_H, Color(1.0, 0.86, 0.68), "Lever-action Rifle")
	exhibit("SM_Wep_Shotgun_01", c + Vector3(3.9, 0, 4.0), -90, 1.0, 1.0, true)
	exhibit("SM_Prop_Saddle_01", c + Vector3(3.9, 0, 5.8), -90, 0.8, 0.9)
	exhibit("SM_Prop_Cow_Skull_01", c + Vector3(0, 0, 5.6), 180, 0.7, 1.1, false, ROOM_H, Color(1.0, 0.86, 0.68), "Longhorn Skull")
	exhibit("SM_Env_Cactus_03", c + Vector3(-4.2, 0, -2.6), 0, 2.0, 0.0)
	exhibit("SM_Env_Cactus_07", c + Vector3(4.2, 0, -2.6), 0, 1.6, 0.0)
	wall_exhibit("SM_Bld_Sign_01", c + Vector3(-5 + WALL_T, 2.3, 2.2), Vector3(1, 0, 0), 1.8)
	wall_exhibit("SM_Bld_Sign_05", c + Vector3(-5 + WALL_T, 2.3, -2.6), Vector3(1, 0, 0), 1.8)
	var lantern := exhibit("SM_Prop_Lantern_Lit_01", c + Vector3(1.8, 0, -6.0), 0, 0.45, 1.0, false, ROOM_H, Color(1.0, 0.7, 0.4), "Oil Lantern")
	_flick(_omni(ExhibitFactory.bounds(lantern).get_center(), Color(1.0, 0.6, 0.3), 0.9, 4.0))
	_omni(c + Vector3(0, 2.6, 0), Color(1.0, 0.7, 0.45), 0.6, 9.0, "detail_light")

func _scifi_exhibits() -> void:
	var c := Vector3(15, 0, 0)
	exhibit("SM_Veh_Hover_Bike_01", c + Vector3(0, 0, -0.6), -90, 2.6, 0.3, false, ROOM_H, Color(0.6, 0.85, 1.0), "Hover Bike")
	exhibit("SM_Chr_Cop_01", c + Vector3(-1.7, 0, -5.8), 0, 1.85, 0.0, false, ROOM_H, Color(0.6, 0.85, 1.0))
	exhibit("SM_Chr_Robot_01", c + Vector3(0, 0, -6.1), 0, 1.9, 0.0, false, ROOM_H, Color(0.6, 0.85, 1.0))
	exhibit("SM_Chr_Hacker_Female_01", c + Vector3(1.7, 0, -5.8), 0, 1.75, 0.0, false, ROOM_H, Color(1.0, 0.5, 0.9))
	exhibit("SM_Prop_Drone_01", c + Vector3(-3.9, 0, -2.4), -90, 0.6, 1.0, true, ROOM_H, Color(0.6, 0.85, 1.0))
	exhibit("SM_Prop_Drone_Quad_01", c + Vector3(-3.9, 0, 0.0), -90, 0.6, 1.0, true, ROOM_H, Color(0.6, 0.85, 1.0))
	exhibit("SM_Prop_Drone_Ball_01", c + Vector3(-3.9, 0, 2.4), -90, 0.45, 1.0, true, ROOM_H, Color(0.6, 0.85, 1.0))
	exhibit("SM_Wep_Pistol_01", c + Vector3(3.9, 0, -2.4), 90, 0.4, 1.0, true, ROOM_H, Color(1.0, 0.5, 0.9), "Plasma Pistol")
	exhibit("SM_Prop_Robotic_Part_01", c + Vector3(3.9, 0, 0.0), 90, 0.6, 1.0, true, ROOM_H, Color(1.0, 0.5, 0.9), "Robotic Arm")
	exhibit("SM_Prop_Hologram_Bottle_01", c + Vector3(3.9, 0, 2.4), 90, 0.5, 1.0, true, ROOM_H, Color(1.0, 0.5, 0.9), "Hologram Advert")
	exhibit("SM_Veh_Hoverboard_01", c + Vector3(0, 0, 4.4), 180, 1.3, 0.6, false, ROOM_H, Color(0.6, 0.85, 1.0))
	exhibit("SM_Prop_VendingMachine_Soda_01", c + Vector3(4.0, 0, 6.0), -90, 2.1, 0.0, false, ROOM_H, Color(0.6, 0.85, 1.0), "Soda Vending Machine")
	wall_exhibit("SM_Sign_Neon_01", c + Vector3(5 - WALL_T, 2.5, -4.6), Vector3(-1, 0, 0), 1.6, false, ROOM_H, false)
	wall_exhibit("SM_Sign_Neon_05", c + Vector3(-5 + WALL_T, 2.5, -4.6), Vector3(1, 0, 0), 1.6, false, ROOM_H, false)
	wall_exhibit("SM_Sign_Neon_Flat_04", c + Vector3(0, 2.6, 7.5 - WALL_T), Vector3(0, 0, -1), 2.2, false, ROOM_H, false)
	_omni(c + Vector3(4.3, 2.5, -4.6), Color(1.0, 0.25, 0.7), 1.2, 5.0, "detail_light")
	_omni(c + Vector3(-4.3, 2.5, -4.6), Color(0.2, 0.8, 1.0), 1.2, 5.0, "detail_light")
	_omni(c + Vector3(0, 2.6, 6.8), Color(0.4, 1.0, 0.9), 1.0, 5.0, "detail_light")
	_omni(c + Vector3(0, 0.5, -0.6), Color(0.2, 0.6, 1.0), 0.8, 3.5, "detail_light")
	_omni(c + Vector3(0, 3.0, -4.0), Color(0.35, 0.75, 1.0), 1.1, 8.0)
	_omni(c + Vector3(0, 3.0, 3.5), Color(0.9, 0.35, 1.0), 0.8, 8.0)

# ------------------------------------------------------------------ haunted crypt

## Set dressing without plinth, label or spotlight.
func dress(prefab: String, pos: Vector3, yaw: float, size: float) -> Node3D:
	var n := ExhibitFactory.build(prefab)
	exhibits.add_child(n)
	n.rotation_degrees.y = yaw
	ExhibitFactory.fit(n, pos, size)
	return n

## Hangs a prop from the ceiling (chains, chandeliers).
func hang(prefab: String, pos: Vector3, size: float, ceiling := ROOM_H) -> Node3D:
	var n := ExhibitFactory.build(prefab)
	exhibits.add_child(n)
	var ab := ExhibitFactory.fit(n, pos, size)
	n.position.y += ceiling - ab.end.y
	return n

func candle(pos: Vector3, size := 1.3) -> void:
	var st := dress("SM_Prop_Candle_Stand_01", pos, randf() * 360.0, size)
	var top := ExhibitFactory.bounds(st)
	var f := _inst(FX + "FX_Candle_Flame_01.tscn", lights, Vector3(pos.x, top.end.y - 0.02, pos.z))
	f.scale = Vector3.ONE * 0.5
	_flick(_omni(Vector3(pos.x, top.end.y + 0.25, pos.z), Color(1.0, 0.55, 0.22), 0.9, 4.5))

func webs(r: Rect2, height: float) -> void:
	var corners := [[Vector3(r.position.x + 0.55, 0, r.position.y + 0.55), 45.0], [Vector3(r.end.x - 0.55, 0, r.position.y + 0.55), -45.0],
		[Vector3(r.position.x + 0.55, 0, r.end.y - 0.55), 135.0], [Vector3(r.end.x - 0.55, 0, r.end.y - 0.55), -135.0]]
	var kinds := ["SM_Env_SpiderWeb_01", "SM_Env_SpiderWeb_02", "SM_Env_SpiderWeb_03"]
	for i in corners.size():
		var w := ExhibitFactory.build(kinds[i % 3])
		exhibits.add_child(w)
		w.rotation_degrees.y = corners[i][1]
		var ab := ExhibitFactory.fit(w, corners[i][0], 1.5)
		w.position.y += height - ab.end.y - 0.05

func _crypt() -> void:
	var c := Vector3(0, 0, -22.5)
	var r := Rect2(-10, -27.5, 20, 10)
	_label("THE  CRYPT", Vector3(-2.5, 3.05, -17.5 + WALL_T + 0.02), 0, 46, Color(0.75, 1.0, 0.8))
	_label("THE  CRYPT", Vector3(2.5, 3.05, -17.5 + WALL_T + 0.02), 0, 46, Color(0.75, 1.0, 0.8))
	exhibit("SM_Prop_Coffin_01", c + Vector3(-2.6, 0, 0.4), 0, 2.1, 0.0, false, ROOM_H, Color(0.55, 1.0, 0.7), "Sealed Coffin")
	exhibit("SM_Prop_Coffin_01", c + Vector3(2.6, 0, 0.4), 0, 2.1, 0.0, false, ROOM_H, Color(0.55, 1.0, 0.7), "Open Coffin")
	exhibit("SM_Prop_Urn_01", c + Vector3(0, 0, -1.6), 0, 0.7, 1.0, false, ROOM_H, Color(0.55, 1.0, 0.7), "Funerary Urn")
	var chand := hang("SM_Prop_Light_Chandelier_01", c + Vector3(0, 0, 0.4), 1.5)
	_flick(_omni(ExhibitFactory.bounds(chand).get_center() + Vector3(0, -0.4, 0), Color(1.0, 0.6, 0.3), 1.6, 8.0))
	# A caged skeleton that sways eerily, specimen jars and a bird cage.
	exhibit("SM_Gen_Chr_Skeleton_01", c + Vector3(-7.6, 0, -2.8), 35, 1.8, 0.0, false, ROOM_H, Color(0.55, 1.0, 0.7), "Prisoner")
	dress("SM_Prop_Cage_01", c + Vector3(-7.6, 0.12, -2.8), 35, 2.4)
	exhibit("SM_Prop_Specimen_Jar_01", c + Vector3(-9.0, 0, 1.2), 90, 0.55, 1.0, false, ROOM_H, Color(0.55, 1.0, 0.7), "Specimen")
	exhibit("SM_Prop_Specimen_Jar_02", c + Vector3(-9.0, 0, 3.4), 90, 0.55, 1.0, false, ROOM_H, Color(0.55, 1.0, 0.7), "Specimen")
	exhibit("SM_Prop_Bird_Cage_01", c + Vector3(9.0, 0, 1.2), -90, 0.7, 1.0, false, ROOM_H, Color(0.55, 1.0, 0.7), "Empty Cage")
	exhibit("SM_Gen_Prop_Skull_01", c + Vector3(9.0, 0, 3.4), -90, 0.35, 1.05, true, ROOM_H, Color(0.55, 1.0, 0.7), "Skull")
	wall_exhibit("SM_Prop_Exorcist_Cross_01", c + Vector3(0, 1.9, -5 + WALL_T), Vector3(0, 0, 1), 1.3)
	# Dressing: barrels and crates piled in the corners, chains, skulls, candles, webs.
	dress("SM_Gen_Prop_Barrel_Wood_01", c + Vector3(8.8, 0, -3.9), 0, 1.0)
	dress("SM_Gen_Prop_Barrel_Wood_01", c + Vector3(7.8, 0, -4.1), 40, 1.0)
	dress("SM_Gen_Prop_Crate_01", c + Vector3(8.7, 0, -2.6), 15, 0.9)
	dress("SM_Gen_Prop_Chest_02", c + Vector3(-8.6, 0, 4.0), 80, 0.9)
	dress("SM_Gen_Prop_Crate_01", c + Vector3(6.0, 0, 4.2), -20, 0.8)
	for x in [-5.2, -0.6, 4.4, 7.4]:
		hang("SM_Gen_Prop_Chain_01", c + Vector3(x, 0, -3.6 + fmod(absf(x), 2.0)), 1.4)
	for s in [Vector3(-2.2, 0, 2.9), Vector3(3.1, 0, 2.6), Vector3(-0.4, 0, 3.6)]:
		dress("SM_Gen_Prop_Skull_01", c + s, randf() * 360.0, 0.28)
	for p in [c + Vector3(-4.8, 0, -3.8), c + Vector3(4.8, 0, -3.8), c + Vector3(-4.8, 0, 4.0), c + Vector3(4.6, 0, 3.0)]:
		candle(p)
	webs(r, ROOM_H)
	_omni(c + Vector3(0, 2.4, 0), Color(0.35, 0.8, 0.55), 0.7, 12.0)

func _haunt_existing_rooms() -> void:
	webs(Rect2(0, -17.5, 10, 10), ROOM_H)
	webs(Rect2(-10, -7.5, 20, 15), HALL_H)
	candle(Vector3(1.0, 0, -9.0), 1.2)
	candle(Vector3(9.0, 0, -16.6), 1.2)

# ------------------------------------------------------------------ outside & cameras

func _outside() -> void:
	for x in range(-4, 4):
		_inst(H + "Environment/SM_Env_Sidewalk_01.tscn", arch, Vector3(x * 5.0, 0, 12.5))
		_inst(H + "Environment/SM_Env_Road_01.tscn", arch, Vector3(x * 5.0, 0, 17.5))
	var car := _inst(H + "Vehicles/SM_Veh_Car_Police_Heist_01.tscn", arch, Vector3(-6, 0, 15), 90)
	var red := _omni(car.position + Vector3(0.4, 1.9, 0), Color(1, 0.1, 0.1), 0.0, 9.0, "detail_light")
	var blue := _omni(car.position + Vector3(-0.4, 1.9, 0), Color(0.1, 0.3, 1), 0.0, 9.0, "detail_light")
	var t := create_tween().set_loops()
	t.tween_property(red, "light_energy", 3.0, 0.25); t.parallel().tween_property(blue, "light_energy", 0.0, 0.25)
	t.tween_property(red, "light_energy", 0.0, 0.25); t.parallel().tween_property(blue, "light_energy", 3.0, 0.25)
	_spot(Vector3(4, 6.5, 14), Vector3(2, 0, 4), Color(0.55, 0.65, 0.95), 3.0, 40.0, "shadow_med", 20.0)
	_omni(Vector3(8, 4.5, 13), Color(1.0, 0.75, 0.45), 1.5, 9.0)

func _security_cameras() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var cctv: Node = $CCTV
	var cams := [
		["CAM 01 · WILD WEST GALLERY", Vector3(-19.4, ROOM_H - 0.05, 6.9), Rect2(-20, -7.5, 10, 15)],
		["CAM 02 · FUTURE CITY GALLERY", Vector3(19.4, ROOM_H - 0.05, -6.9), Rect2(10, -7.5, 10, 15)],
	]
	for c in cams:
		var cam := SECURITY_CAMERA.new()
		cam.camera_name = c[0]
		cam.area_rect = c[2]
		cam.area_height = ROOM_H
		cam.player = player
		cam.cctv = cctv
		cam.position = c[1]   # set before _ready so the area and viewpoint are built in place
		add_child(cam)
