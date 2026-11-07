class_name Fx
extends RefCounted
## Shared visual effects: impacts by surface, bullet-hole decals, bursts and flashes.
## Sprites are the generated template_ textures in Assets/Generated (override by replacing them).

const SPARK := "res://Assets/Generated/template_spark.png"
const HOLE := "res://Assets/Generated/template_bullet_hole.png"
const DUST := "res://Assets/Generated/template_dust_puff.png"
const WISP := "res://Assets/Generated/template_ghost_wisp.png"
const MAX_DECALS := 32

static var _mats := {}
static var _decals: Array = []

static func _sprite_mat(tex: String, color: Color, additive := true) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [tex, color.to_html(), additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(tex)
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	_mats[key] = m
	return m

## Surface type of whatever a ray hit: collider meta "surface", else guessed from names.
static func surface_of(col: Object) -> String:
	if col == null:
		return "stone"
	if col.has_meta("surface"):
		return col.get_meta("surface")
	var n: Node = col as Node
	var path := ""
	var cur := n
	for i in 5:
		if cur == null: break
		path += str(cur.name).to_lower() + "/"
		cur = cur.get_parent()
	for w in ["glass", "case", "window", "jar", "mirror"]:
		if path.contains(w): return "glass"
	for w in ["veh_", "car", "cage", "chain", "anvil", "vending", "axe", "sword", "trolley", "metal", "drone", "safe", "atm", "camera", "detector", "pole", "rope"]:
		if path.contains(w): return "metal"
	for w in ["barrel", "crate", "chest", "coffin", "desk", "shelf", "piano", "stagecoach", "boat", "box", "drawers", "seat", "table", "bookshelf", "clock", "door"]:
		if path.contains(w): return "wood"
	return "stone"

static func particles(parent: Node, pos: Vector3, dir: Vector3, color: Color, amount: int, speed: float,
		life := 0.4, size := 0.04, gravity := -9.0, tex := SPARK, additive := true, spread := 45.0, keep := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(int(amount * GameSettings.particle_density), 3)
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _sprite_mat(tex, color, additive)
	p.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1)); grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	parent.add_child(p)
	p.global_position = pos
	if keep:
		p.one_shot = false
		p.explosiveness = 0.0
	p.emitting = true
	if not keep:
		parent.get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)
	return p

## Bullet impact: particles, sound and (for static surfaces) a fading decal.
static func impact(parent: Node, pos: Vector3, normal: Vector3, surface: String, static_surface: bool) -> void:
	match surface:
		"stone":
			particles(parent, pos, normal, Color(1, 0.85, 0.6), 10, 4.0, 0.25, 0.035)
			particles(parent, pos, normal, Color(0.75, 0.72, 0.66, 0.7), 5, 0.8, 0.9, 0.35, 0.3, DUST, false, 30.0)
		"wood":
			particles(parent, pos, normal, Color(0.45, 0.3, 0.18), 12, 3.5, 0.5, 0.05, -9.0, SPARK, false)
			particles(parent, pos, normal, Color(0.6, 0.5, 0.4, 0.6), 4, 0.6, 0.8, 0.25, 0.2, DUST, false, 30.0)
		"metal":
			particles(parent, pos, normal, Color(1, 0.9, 0.6), 18, 6.0, 0.35, 0.03, -12.0)
		"glass":
			particles(parent, pos, normal, Color(0.8, 0.95, 1.0), 14, 3.0, 0.6, 0.04, -9.0, SPARK, true, 70.0)
		"flesh":
			particles(parent, pos, normal, Color(0.35, 0.02, 0.04), 14, 2.5, 0.5, 0.06, -9.0, SPARK, false)
		"spirit":
			particles(parent, pos, normal, Color(0.5, 1.0, 0.8), 14, 1.6, 0.8, 0.12, 1.5, WISP)
		"statue":
			particles(parent, pos, normal, Color(0.85, 0.85, 0.82), 12, 3.0, 0.5, 0.05, -9.0, SPARK, false)
			particles(parent, pos, normal, Color(0.8, 0.8, 0.78, 0.7), 6, 0.9, 1.0, 0.35, 0.3, DUST, false, 30.0)
	Sfx.play(parent, "impact_" + ("stone" if surface == "statue" else surface), pos, -6.0)
	if static_surface and surface != "glass":
		decal(parent, pos, normal)

static func decal(parent: Node, pos: Vector3, normal: Vector3) -> void:
	var d := Decal.new()
	d.texture_albedo = load(HOLE)
	d.size = Vector3(0.14, 0.12, 0.14)
	d.cull_mask = 1
	parent.add_child(d)
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	d.global_transform = Transform3D(Basis(side, up, side.cross(up)).rotated(up, randf() * TAU), pos)
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old = _decals.pop_front()
		if is_instance_valid(old): old.queue_free()
	var t := d.create_tween()
	t.tween_interval(10.0)
	t.tween_property(d, "albedo_mix", 0.0, 2.0)
	t.tween_callback(func():
		_decals.erase(d)
		d.queue_free())

static func glass_burst(parent: Node, pos: Vector3) -> void:
	particles(parent, pos, Vector3.UP, Color(0.8, 0.95, 1.0), 40, 4.0, 1.0, 0.05, -9.0, SPARK, true, 120.0)
	Sfx.play(parent, "glass_break", pos, -2.0)

static func ghost_burst(parent: Node, pos: Vector3, color := Color(0.5, 1.0, 0.8)) -> void:
	particles(parent, pos, Vector3.UP, color, 30, 2.0, 1.4, 0.18, 0.8, WISP, true, 60.0)

## A short bright flash of light (awakenings, blackouts, artefacts).
static func flash(parent: Node, pos: Vector3, color: Color, energy := 6.0, rng := 6.0, dur := 0.5) -> void:
	var l := OmniLight3D.new()
	l.light_color = color; l.light_energy = energy; l.omni_range = rng
	parent.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, dur)
	t.tween_callback(l.queue_free)

## Puts every visual of a node on the given render layers (used by the CCTV system).
static func set_layers(node: Node, mask: int) -> void:
	for v in node.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = mask
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = mask
