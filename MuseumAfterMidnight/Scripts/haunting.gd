extends Node
## Haunting director: schedules supernatural events. Intensity rises with time in the round,
## kills and the danger of the player's current zone; difficulty scales how often events fire.
## Every event is logged to the CCTV buffer, so recordings show (or explain) what happened.

const PHANTOM_MODELS := ["SM_Chr_Yokai_01", "SM_Chr_Witch_01", "SM_Chr_Count_01", "SM_Chr_Ghoul_01"]
## name -> [minimum intensity, cooldown seconds, label]
const EVENTS := {
	"flicker": [0.0, 18.0, "Lights flicker"],
	"distant_fall": [0.0, 28.0, "Something falls in the distance"],
	"statue_turn": [0.1, 35.0, "A statue turns its head"],
	"camera_glitch": [0.1, 40.0, "Camera malfunction"],
	"painting_change": [0.15, 45.0, "A painting changes"],
	"ghost_crossing": [0.2, 40.0, "Ghost silhouette (visible on CCTV)"],
	"case_shatter": [0.3, 40.0, "Display case shatters"],
	"exhibit_awaken": [0.25, 30.0, "An exhibit awakens"],
	"alarm": [0.45, 60.0, "Alarm triggers by itself"],
	"longship_fog": [0.45, 70.0, "Fog rolls off the longship"],
	"blackout": [0.55, 75.0, "Blackout - emergency lighting"],
	"totem_pulse": [0.6, 80.0, "The Stone Totem pulses"],
}

var museum: Node3D
var director: Node
var player: Node3D
var intensity := 0.0
var last_event := "-"
var enabled := false
var _cooldowns := {}
var _next := 25.0
var _blackout := false
var _flickering: Array = []   # [light, until]
var _phantom_id := 0

func setup(m: Node3D, d: Node) -> void:
	museum = m
	director = d
	player = get_tree().get_first_node_in_group("player")

func reset() -> void:
	_cooldowns.clear()
	_next = randf_range(18.0, 26.0)
	intensity = 0.0
	if _blackout:
		_end_blackout()

func _process(delta: float) -> void:
	_update_flicker()
	if not enabled or player == null or museum == null:
		return
	var zone: Dictionary = museum.zone_at(player.global_position)
	var target := minf(director.round_time / 240.0, 1.0) * 0.5 + minf(director.round_kills * 0.05, 0.3) \
		+ float(zone.get("danger", 0.2)) * 0.3
	intensity = lerpf(intensity, clampf(target, 0.0, 1.0), 1.0 - exp(-0.5 * delta))
	for k in _cooldowns.keys():
		_cooldowns[k] -= delta
	_next -= delta
	if _next <= 0.0:
		_next = lerpf(38.0, 15.0, intensity) / float(GameSettings.diff("events")) * randf_range(0.8, 1.25)
		var options := []
		for k in EVENTS:
			if intensity >= EVENTS[k][0] and _cooldowns.get(k, 0.0) <= 0.0:
				options.append(k)
		if options.size() > 0:
			trigger(options[randi() % options.size()])

func trigger(event: String) -> void:
	if not EVENTS.has(event):
		return
	_cooldowns[event] = EVENTS[event][1]
	last_event = EVENTS[event][2]
	call("_ev_" + event)

func _log(type: String, pos: Vector3, text: String, extra := {}) -> void:
	get_tree().call_group("cctv", "record_event", type, pos, text, extra)

func _toast(text: String) -> void:
	director.hud.toast(text, 3.5)

func _random_zone(away_from_player := 0.0) -> Dictionary:
	var zs: Array = museum.zones.filter(func(z): return away_from_player <= 0.0 or (z.rect as Rect2).get_center().distance_to(Vector2(player.global_position.x, player.global_position.z)) > away_from_player)
	return zs[randi() % zs.size()] if zs.size() > 0 else museum.zones[0]

# ------------------------------------------------------------------ events

func _ev_flicker() -> void:
	var z: Dictionary = museum.zone_at(player.global_position)
	if z.is_empty():
		z = museum.zones[0]
	flicker_zone(z.rect, 2.6)
	Sfx.play(self, "power_down", null, -16.0, 1.6)
	_log("flicker", player.global_position, "Lights flickered in %s" % z.name)

func flicker_zone(rect: Rect2, seconds: float) -> void:
	var until := Time.get_ticks_msec() / 1000.0 + seconds
	for l in museum.lights_in(rect):
		_flickering.append([l, until])

func _update_flicker() -> void:
	if _flickering.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_flickering.size() - 1, -1, -1):
		var f: Array = _flickering[i]
		if not is_instance_valid(f[0]):
			_flickering.remove_at(i)
			continue
		if now > f[1]:
			f[0].visible = not _blackout
			_flickering.remove_at(i)
		else:
			f[0].visible = randf() < 0.55 and not _blackout

func _ev_blackout() -> void:
	if _blackout:
		return
	_blackout = true
	for l in museum.lights_in(Rect2(-25, -30, 50, 45)):
		l.visible = false
	for e in museum.emergency_lights:
		e.visible = true
		e.light_energy = 0.75
	Sfx.play(self, "power_down", null, -2.0)
	_toast("Power failure! Emergency lighting only.  [F] flashlight")
	_log("blackout", player.global_position, "Power failure - emergency lighting")
	get_tree().create_timer(9.0, false).timeout.connect(_end_blackout)

func _end_blackout() -> void:
	if not _blackout:
		return
	_blackout = false
	for l in museum.lights_in(Rect2(-25, -30, 50, 45)):
		l.visible = true
	for e in museum.emergency_lights:
		e.visible = false
	Sfx.play(self, "power_up", null, -4.0)
	_log("power", player.global_position, "Power restored")

func _ev_statue_turn() -> void:
	var cands: Array = museum.classical_statues.filter(func(s): return is_instance_valid(s) and s.visible and not player.camera.is_position_in_frustum(s.global_position + Vector3.UP))
	if cands.is_empty():
		return
	var s: Node3D = cands[randi() % cands.size()]
	var to := player.global_position - s.global_position
	var t := s.create_tween()
	t.tween_property(s, "rotation:y", atan2(to.x, to.z), 0.4)
	Sfx.play(self, "stone_grind", s.global_position + Vector3.UP, -8.0)
	_log("statue", s.global_position, "A statue turned to face the guard")

func _ev_case_shatter() -> void:
	var cands: Array = museum.cases.filter(func(c): return is_instance_valid(c.node) and c.node.visible and c.pos.distance_to(player.global_position) > 4.0)
	if cands.is_empty():
		return
	var c: Dictionary = cands[randi() % cands.size()]
	c.node.visible = false
	Fx.glass_burst(museum, c.pos)
	get_tree().call_group("enemies", "hear_noise", c.pos, 18.0, false)
	_log("shatter", c.pos, "Display case shattered in %s" % museum.zone_name(c.pos))
	if c.pos.distance_to(player.global_position) > 12.0:
		_toast("Glass shatters somewhere in the %s..." % museum.zone_name(c.pos))

func _ev_ghost_crossing() -> void:
	var cams: Array = get_tree().get_nodes_in_group("security_cameras").filter(func(c): return c.recording)
	if cams.is_empty():
		return
	var cam: Node3D = cams[randi() % cams.size()]
	var r: Rect2 = cam.area_rect
	var a := Vector3(r.position.x + 1.2, 0, r.position.y + randf_range(1.5, r.size.y - 1.5))
	var b := Vector3(r.end.x - 1.2, 0, r.position.y + randf_range(1.5, r.size.y - 1.5))
	if randf() < 0.5:
		var tmp := a
		a = b
		b = tmp
	var map := museum.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		a = NavigationServer3D.map_get_closest_point(map, a)
		b = NavigationServer3D.map_get_closest_point(map, b)
		a.y = 0.0
		b.y = 0.0
	var ph := Phantom.new()
	_phantom_id += 1
	ph.pid = "ph%d" % _phantom_id
	ph.prefab = PHANTOM_MODELS[randi() % PHANTOM_MODELS.size()]
	ph.a = a
	ph.b = b
	museum.add_child(ph)
	Sfx.play(self, "whisper", null, -6.0)
	_toast("Whispering... the cameras may have caught something. Check the Security Office.")
	_log("phantom", (a + b) * 0.5, "Unidentified figure crossed %s" % cam.camera_name)

func _ev_painting_change() -> void:
	var cands: Array = museum.paintings.filter(func(p): return is_instance_valid(p))
	if cands.is_empty():
		return
	var p: Node3D = cands[randi() % cands.size()]
	var m := Enemy.ghost_material(Color(1.0, 0.15, 0.1), 0.0)
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = m
	var t := p.create_tween()
	t.tween_method(func(a): m.set_shader_parameter("alpha", a), 0.0, 1.4, 1.2)
	t.parallel().tween_property(p, "rotation:z", p.rotation.z + PI, 1.2).set_trans(Tween.TRANS_BACK)
	Sfx.play(self, "creak", p.global_position, -4.0)
	Sfx.play(self, "whisper", p.global_position, -6.0)
	_log("painting", p.global_position, "A painting in the Occult Exhibition changed")

func _ev_alarm() -> void:
	director.set_alarm(true)
	_log("alarm", Vector3.ZERO, "Alarm triggered with nobody at the panel")
	get_tree().create_timer(7.0, false).timeout.connect(func(): director.set_alarm(false))

func _ev_exhibit_awaken() -> void:
	if director.awaken_exhibit(""):
		_toast("Something in the museum has started to move...")

func _ev_camera_glitch() -> void:
	var cams := get_tree().get_nodes_in_group("security_cameras")
	if cams.is_empty():
		return
	var cam: Node3D = cams[randi() % cams.size()]
	cam.glitch(8.0)
	Sfx.play(self, "phase", cam.global_position, -6.0, 0.6)
	_log("glitch", cam.global_position, "%s lost signal" % cam.camera_name, {"cam": cam, "dur": 8.0})

func _ev_distant_fall() -> void:
	var z := _random_zone(14.0)
	var p: Vector3 = z.points[randi() % z.points.size()]
	Sfx.play(self, "impact_stone", p + Vector3.UP, 6.0, 0.55)
	Sfx.play(self, "creak", p + Vector3.UP, 0.0, 0.8)
	Fx.particles(museum, p + Vector3.UP * 0.4, Vector3.UP, Color(0.75, 0.72, 0.66, 0.6), 14, 0.8, 1.4, 0.4, 0.3, Fx.DUST, false, 70.0)
	get_tree().call_group("enemies", "hear_noise", p, 14.0, false)
	_log("fall", p, "Something fell in %s" % z.name)

func _ev_totem_pulse() -> void:
	totem_pulse(false)

func totem_pulse(relic: bool) -> void:
	var t: Node3D = museum.totem
	if t == null:
		return
	var p := t.global_position + Vector3.UP * 1.4
	var l := OmniLight3D.new()
	l.light_color = Color(0.3, 1.0, 0.5)
	l.omni_range = 7.0
	museum.add_child(l)
	l.global_position = p
	var tw := l.create_tween()
	for i in 3:
		tw.tween_property(l, "light_energy", 6.0, 0.25)
		tw.tween_property(l, "light_energy", 0.3, 0.45)
	tw.tween_callback(l.queue_free)
	Fx.ghost_burst(museum, p, Color(0.3, 1.0, 0.5))
	Sfx.play(self, "awaken", p, 2.0, 0.6)
	Sfx.play(self, "heartbeat", null, -4.0)
	_log("totem", p, "The Stone Totem pulsed with green light")
	if relic:
		director.spawn_bonus(Enemy.Kind.ENTITY, t.global_position + Vector3(0, 0, 2.2), "SM_Chr_Yokai_01")
	else:
		director.awaken_exhibit("")

func _ev_longship_fog() -> void:
	longship_fog(false)

func longship_fog(relic: bool) -> void:
	var p := Vector3(0, 0.6, -0.8)
	for i in 4:
		var f := Fx.particles(museum, p + Vector3(randf_range(-4, 4), 0, randf_range(-1.5, 1.5)), Vector3.UP, Color(0.75, 0.85, 0.9, 0.35), 16, 0.25, 6.0, 1.6, 0.02, Fx.DUST, false, 90.0)
		f.explosiveness = 0.3
	Sfx.play(self, "horn", p, 2.0)
	_log("fog", p, "Fog rolled off the Viking longship")
	if relic:
		if not director.awaken_exhibit("Chief"):
			director.spawn_bonus(Enemy.Kind.STAFF, Vector3(-6.2, 0, 0.6), "SM_Chr_Chief_01_Brown")
		director.spawn_bonus(Enemy.Kind.ENTITY, Vector3(4.8, 0, 1.6), "SM_Chr_Ghoul_01")
	else:
		_toast("A horn sounds from the longship...")

func occult_encounter() -> void:
	var r := Rect2(0, -17.5, 10, 10)
	var c := Vector3(5, 1.2, -12.5)
	for l in museum.lights_in(r):
		var old: Color = l.light_color
		l.light_color = Color(0.7, 0.2, 1.0)
		get_tree().create_timer(12.0, false).timeout.connect(func(): if is_instance_valid(l): l.light_color = old)
	flicker_zone(r, 4.0)
	Fx.flash(museum, c, Color(0.7, 0.2, 1.0), 10.0, 10.0, 2.0)
	Fx.ghost_burst(museum, c, Color(0.7, 0.3, 1.0))
	Sfx.play(self, "ghost_wail", c, 4.0, 0.8)
	Sfx.play(self, "whisper", null, -2.0)
	_log("occult", c, "Seance: the Occult Exhibition came alive")
	director.awaken_exhibit("Count")
	director.awaken_exhibit("Witch")
	director.spawn_bonus(Enemy.Kind.ENTITY, Vector3(5, 0, -10.0), "SM_Chr_Witch_01")

func tomb_encounter() -> void:
	var c := Vector3(-14.4, 0.5, -12.9)
	Sfx.play(self, "stone_grind", c, 4.0, 0.7)
	Fx.particles(museum, c + Vector3.UP * 0.4, Vector3.UP, Color(0.85, 0.75, 0.55, 0.6), 30, 1.2, 1.6, 0.5, 0.3, Fx.DUST, false, 90.0)
	Fx.flash(museum, c + Vector3.UP, Color(1.0, 0.7, 0.3), 6.0, 8.0, 1.2)
	flicker_zone(Rect2(-20, -17.5, 10, 10), 3.0)
	_log("tomb", c, "The sarcophagus seal broke")
	if not director.awaken_exhibit("Tomb Guardian"):
		director.spawn_bonus(Enemy.Kind.EXHIBIT, Vector3(-17.5, 0, -10.0), "SM_Gen_Chr_Skeleton_01")
	director.spawn_bonus(Enemy.Kind.ENTITY, Vector3(-12.5, 0, -15.0), "SM_Chr_Count_01")

func mirror_scare(pos: Vector3) -> void:
	Fx.flash(museum, pos, Color(0.6, 1.0, 0.9), 6.0, 4.0, 0.6)
	Fx.ghost_burst(museum, pos)
	Sfx.play(self, "ghost_wail", pos, 0.0, 1.3)
	player.camera_kick(-2.0)
	_log("mirror", pos, "Something looked back from the mirror")

# ------------------------------------------------------------------ camera-only phantom

## A ghost that only security cameras can see (render layer 4): it walks across a room once and
## is recorded like any other entity, so CCTV playback reveals it.
class Phantom extends Node3D:
	var pid := ""
	var prefab := ""
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var _model: Node3D
	var _anim: AnimationPlayer
	var _t := 0.0
	var _dur := 5.0
	var _mat: ShaderMaterial

	func _ready() -> void:
		add_to_group("recordable")
		_model = Enemy.build_visual(prefab)
		add_child(_model)
		Enemy.fit_height(_model, 1.9)
		_mat = Enemy.ghost_material(Color(0.6, 1.0, 0.9), 1.0)
		Enemy.apply_ghost(_model, _mat)
		Fx.set_layers(self, 4)
		_anim = Enemy.find_anim(_model)
		if _anim:
			_anim.play("m/sneak_walk")
			_anim.speed_scale = 0.55
		global_position = a
		_dur = maxf(a.distance_to(b) / 1.3, 2.0)
		var d := b - a
		_model.rotation.y = atan2(d.x, d.z)

	func _process(delta: float) -> void:
		_t += delta
		global_position = a.lerp(b, clampf(_t / _dur, 0.0, 1.0))
		if _t >= _dur:
			queue_free()

	func snapshot() -> Dictionary:
		return {"kind": "phantom", "id": pid, "model": prefab, "pos": global_position, "yaw": _model.rotation.y,
			"clip": "sneak_walk", "t": _anim.current_animation_position if _anim else 0.0, "speed": 0.55,
			"alive": true, "ghost": true, "alpha": 1.0, "h": 1.9, "color": Color(0.6, 1.0, 0.9)}
