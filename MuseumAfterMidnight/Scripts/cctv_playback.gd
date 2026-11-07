extends Node
## Renders CCTV footage from the recorded world-state buffer: a SubViewport camera placed at the
## security camera, looking at render layer 1 (static museum) + layer 8 (playback puppets).
## Puppets are rebuilt from snapshots (position, rotation, animation clip and time, aim, weapon)
## and never touch gameplay objects. Live mode instead shows layers 1|2|4 (live characters and
## camera-only phantoms).

const PUPPET_LAYER := 8
const PLAYBACK_MASK := 1 | 8
const LIVE_MASK := 1 | 2 | 4

var cctv: Node
var viewport: SubViewport
var cam: Camera3D
var source: Node3D              # security camera node
var t := 0.0
var t_start := 0.0
var t_end := 0.0
var speed := 1.0
var playing := false
var active := false
var live := false
var loop := false
var _puppets := {}
var _fx_done := {}

func setup(owner_cctv: Node, size: Vector2i, always: bool) -> void:
	cctv = owner_cctv
	process_mode = Node.PROCESS_MODE_ALWAYS if always else Node.PROCESS_MODE_PAUSABLE
	viewport = SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	cam = Camera3D.new()
	cam.cull_mask = PLAYBACK_MASK
	viewport.add_child(cam)

func texture() -> Texture2D:
	return viewport.get_texture()

func start(src: Node3D, a: float, b: float, from_t := -1.0) -> void:
	source = src
	t_start = a
	t_end = maxf(b, a + 0.1)
	t = from_t if from_t >= 0.0 else a
	speed = 1.0
	playing = true
	active = true
	live = false
	_fx_done.clear()
	cam.cull_mask = PLAYBACK_MASK
	_place_camera()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_apply(t)

func start_live(src: Node3D) -> void:
	source = src
	active = true
	live = true
	playing = false
	_hide_all()
	cam.cull_mask = LIVE_MASK
	_place_camera()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func stop() -> void:
	active = false
	playing = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for id in _puppets:
		if is_instance_valid(_puppets[id].root):
			_puppets[id].root.queue_free()
	_puppets.clear()

func seek(to: float) -> void:
	t = clampf(to, t_start, t_end)
	_fx_done.clear()
	if active and not live:
		_apply(t)

func _place_camera() -> void:
	if source and source.camera:
		cam.global_transform = source.camera.global_transform
		cam.fov = source.camera.fov

func _process(delta: float) -> void:
	if not active or live:
		return
	if playing:
		t += delta * speed
		if t >= t_end:
			if loop:
				t = t_start
				_fx_done.clear()
			else:
				t = t_end
				playing = false
		elif t <= t_start and speed < 0.0:
			t = t_start
			playing = false
	_apply(t)

func signal_lost() -> bool:
	if source == null:
		return true
	if live:
		return not source.is_working()
	return cctv.glitched_at(source, t)

func _hide_all() -> void:
	for id in _puppets:
		_puppets[id].root.visible = false

func _apply(time: float) -> void:
	var fr: Array = cctv.frames_at(time)
	if fr.is_empty():
		_hide_all()
		return
	var a: Dictionary = fr[0]
	var b: Dictionary = fr[1]
	var w: float = fr[2]
	var seen := {}
	for id in a.ents:
		var sa: Dictionary = a.ents[id]
		# Entities inside the coverage area, plus a margin for doorways.
		if not (source.area_rect.grow(2.0)).has_point(Vector2(sa.pos.x, sa.pos.z)):
			continue
		var sb: Dictionary = b.ents.get(id, sa)
		var p := _puppet(id, sa)
		if p.is_empty():
			continue
		seen[id] = true
		_pose(p, sa, sb, w, time - float(a.t))
	for id in _puppets:
		if not seen.has(id):
			_puppets[id].root.visible = false
	# Recorded events inside this camera's view: re-create their effect once.
	for e in cctv.events:
		if e.t <= time and e.t > time - 0.25 and not _fx_done.has(e):
			_fx_done[e] = true
			if source.covers(e.pos):
				_event_fx(e)

func _puppet(id: String, s: Dictionary) -> Dictionary:
	if _puppets.has(id):
		return _puppets[id]
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	var model: Node3D
	var anim: AnimationPlayer
	var p := {"root": root, "clip": "", "kind": s.kind}
	if s.kind == "player":
		model = load(s.model).instantiate()
		root.add_child(model)
		anim = model.get_node("AnimationPlayer")
		anim.add_animation_library("m", load(ExhibitFactory.ANIMS))
		var sk: Skeleton3D = model.get_node("Skeleton3D")
		var rig := AimModifier.new()
		sk.add_child(rig)
		rig.setup(anim.get_animation("m/firing_rifle"))
		p.rig = rig
		p.weapons = []
		for spec in ["SM_Wep_RifleBandit_01", "SM_Wep_PistolBandit_01"]:
			var wn: Node3D = load("res://Assets/Synty/PolygonHeist/Prefab/Weapons/" + spec + ".tscn").instantiate()
			for body in wn.find_children("*", "CollisionObject3D", true, false):
				body.queue_free()
			wn.top_level = true
			root.add_child(wn)
			p.weapons.append(wn)
		rig.hands_posed.connect(func(right: Transform3D, _left: Transform3D):
			var wi: int = p.get("weapon", 0)
			for k in p.weapons.size():
				p.weapons[k].visible = k == wi and p.get("alive", true)
			var rh: Vector3 = sk.global_transform * right.origin
			var aim: Vector3 = p.get("aim", -root.global_basis.z)
			var bas := Basis.looking_at(aim.normalized(), model.global_basis.y, true)
			p.weapons[wi].global_transform = Transform3D(bas, rh + bas * Vector3(0, -0.035, 0.03)))
	else:
		model = Enemy.build_visual(s.model)
		root.add_child(model)
		Enemy.fit_height(model, s.get("h", 1.85))
		anim = Enemy.find_anim(model)
		if s.get("stone", false):
			Enemy.apply_stone(model)
		if s.get("ghost", false) or s.kind == "phantom":
			p.ghost = Enemy.ghost_material(s.get("color", Color(0.5, 1, 0.8)), 1.0)
			Enemy.apply_ghost(model, p.ghost)
	p.model = model
	p.anim = anim
	Fx.set_layers(root, PUPPET_LAYER)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puppets[id] = p
	return p

func _pose(p: Dictionary, a: Dictionary, b: Dictionary, w: float, dt: float) -> void:
	var root: Node3D = p.root
	root.visible = true
	root.global_position = (a.pos as Vector3).lerp(b.pos, w)
	var model: Node3D = p.model
	var yaw := lerp_angle(float(a.yaw), float(b.yaw), w)
	if a.kind == "player":
		model.rotation = Vector3(float(a.get("pitch", 0.0)), yaw, 0)
		p.aim = (a.aim as Vector3).lerp(b.aim, w)
		p.weapon = int(a.weapon)
		p.alive = bool(a.alive)
		p.rig.aim_dir = p.aim
		p.rig.influence = 1.0 if a.alive else 0.0
	else:
		root.rotation.y = 0.0
		model.rotation = Vector3(float(a.get("pitch", 0.0)), yaw, 0)
		model.position.y = float(a.get("hover", 0.0))
		if p.has("ghost"):
			# Cameras pick up what the eye cannot: phased entities stay faintly visible.
			p.ghost.set_shader_parameter("alpha", maxf(float(a.get("alpha", 1.0)), 0.45))
	var anim: AnimationPlayer = p.anim
	if anim == null:
		return
	var key := str(a.get("clip", ""))
	if key == "":
		return
	var clip := key.trim_suffix("_rev")
	var pos := float(a.t)
	match key:
		"crouch_idle":
			clip = "crouching"
			pos = 2.6
		"dying", "rising":
			clip = "crouching"
		_:
			pos = float(a.t) + dt * float(a.get("speed", 1.0)) * (-1.0 if key.ends_with("_rev") else 1.0)
	var name := "m/" + clip
	if not anim.has_animation(name):
		return
	if p.clip != name:
		p.clip = name
		anim.play(name, 0.0)
	anim.speed_scale = 0.0
	var length := maxf(anim.current_animation_length, 0.01)
	anim.seek(fposmod(pos, length) if anim.get_animation(name).loop_mode != Animation.LOOP_NONE else clampf(pos, 0.0, length), true)

func _event_fx(e: Dictionary) -> void:
	var nodes: Array = []
	match e.type:
		"shatter":
			nodes.append(Fx.particles(self, e.pos, Vector3.UP, Color(0.8, 0.95, 1.0), 40, 4.0, 1.0, 0.05, -9.0, Fx.SPARK, true, 120.0))
		"awaken", "phantom", "totem", "occult", "fog", "phase":
			nodes.append(Fx.particles(self, e.pos + Vector3.UP, Vector3.UP, Color(0.5, 1.0, 0.8), 26, 1.5, 1.4, 0.2, 0.6, Fx.WISP, true, 70.0))
		"fall":
			nodes.append(Fx.particles(self, e.pos + Vector3.UP * 0.5, Vector3.UP, Color(0.75, 0.72, 0.66, 0.6), 14, 0.8, 1.4, 0.4, 0.3, Fx.DUST, false, 70.0))
	for n in nodes:
		if n:
			n.layers = PUPPET_LAYER
