extends SceneTree
# Preview reels of Synty Heist characters driven by the retargeted (baked) Mixamo clips.
# args: <out_dir> <mode: lineup|sequence> <w>x<h> <fps>
const P := "res://Assets/Synty/PolygonHeist/Prefab/"
const LIB := "res://Assets/AnimBaked/synty_female_mixamo_inplace.res"
var props := []  # [char, kind, node]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var d := a[2].split("x")
	root.size = Vector2i(int(d[0]), int(d[1])); DisplayServer.window_set_size(root.size)
	_run(a[0], a[1], float(a[3]))

func _stage() -> Camera3D:
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.80, 0.83, 0.87)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e; root.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-55, -30, 0); l.shadow_enabled = true; l.light_energy = 1.1; root.add_child(l)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.62, 0.65, 0.69); fm.roughness = 0.9; fl.material_override = fm; root.add_child(fl)
	var cam := Camera3D.new(); cam.fov = 34; root.add_child(cam); cam.make_current()
	return cam

func _char(file: String, pos: Vector3, yaw: float, mask := "") -> Node3D:
	var ch: Node3D = load(P + "Characters/" + file + ".tscn").instantiate()
	root.add_child(ch); ch.position = pos; ch.rotation_degrees.y = yaw
	var ap: AnimationPlayer = ch.get_node("AnimationPlayer")
	ap.add_animation_library("m", load(LIB))
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if mask != "":
		var att: Node3D = ch.get_node("Skeleton3D/Head_Bone_Attachments")
		for c in att.get_children(): c.visible = false
		att.add_child(load(P + "Masks/SM_Item_Mask_%s_01.tscn" % mask).instantiate())
	return ch

func _prop(ch: Node3D, kind: String) -> Node3D:
	var f: String = {"rifle": "Weapons/SM_Wep_RifleSwat_01", "box": "Props/SM_Prop_Box_01"}[kind]
	var n: Node3D = load(P + f + ".tscn").instantiate(); root.add_child(n)
	props.append([ch, kind, n]); return n

func _update_props() -> void:
	for p in props:
		var ch: Node3D = p[0]; var n: Node3D = p[2]
		if not n.visible: continue
		var sk: Skeleton3D = ch.get_node("Skeleton3D")
		var rh := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hand_R")).origin
		var lh := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hand_L")).origin
		if p[1] == "rifle":
			var fwd := (lh - rh).normalized()
			n.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP, true), rh + fwd * 0.04 + Vector3(0, -0.03, 0))
		else:
			var facing := ch.global_transform.basis.z
			n.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP, true).scaled(Vector3(0.75, 0.75, 0.75)), (lh + rh) * 0.5 + facing * 0.05 + Vector3(0, -0.13, 0))

func _shot(out: String, i: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("f_%04d.png" % i))

func _run(out: String, mode: String, fps: float) -> void:
	await process_frame
	var cam := _stage()
	var labels := []
	if mode == "lineup":
		var cast := [["SM_Chr_Female_Shirt_01", "idle", ""], ["SM_Chr_Female_Overall_01", "sneak_walk", ""], ["SM_Chr_Female_FBI_01", "firing_rifle", "rifle"],
			["SM_Chr_Female_SuitVest_01", "button_pushing", ""], ["SM_Chr_Male_SWAT_01", "running", ""], ["SM_Chr_Male_Overall_01", "carrying", "box"],
			["SM_Chr_Male_Shirt_01", "picking_up_object", ""], ["SM_Chr_Male_FBI_01", "walking", ""], ["SM_Chr_Male_SuitVest_01", "crouched_walking", ""]]
		var chars := []
		for i in cast.size():
			var x := (i - 4) * 1.05
			var ch := _char(cast[i][0], Vector3(x, 0, -abs(x) * 0.12), -x * 6.0)
			ch.get_node("AnimationPlayer").play("m/" + cast[i][1])
			if cast[i][2] != "": _prop(ch, cast[i][2])
			chars.append(ch)
		cam.global_position = Vector3(0, 1.45, 6.4); cam.look_at(Vector3(0, 0.88, -0.3))
		var frames := int(fps * 4.0)
		for f in frames:
			for ch in chars: ch.get_node("AnimationPlayer").advance(1.0 / fps)
			_update_props()
			await process_frame
			await _shot(out, f)
	else:
		var ch := _char("SM_Chr_Female_Overall_01", Vector3.ZERO, 25.0, "Fox")
		var rifle := _prop(ch, "rifle"); var box := _prop(ch, "box")
		var seq := [["idle", 2.5], ["walking", 2.5], ["sneak_walk", 2.5], ["crouched_walking", 2.5], ["running", 2.5],
			["firing_rifle", 2.5], ["carrying", 2.5], ["button_pushing", 3.2], ["picking_up_object", 3.4], ["opening", 5.2], ["crouching", 4.0]]
		cam.global_position = Vector3(1.6, 1.45, 4.2); cam.look_at(Vector3(0, 0.8, 0))
		var ap: AnimationPlayer = ch.get_node("AnimationPlayer")
		var f := 0
		var timeline := []
		for s in seq:
			ap.play("m/" + s[0], 0.25)
			rifle.visible = s[0] == "firing_rifle"; box.visible = s[0] == "carrying"
			timeline.append({"clip": s[0], "start_frame": f})
			for k in int(s[1] * fps):
				ap.advance(1.0 / fps); _update_props()
				await process_frame
				await _shot(out, f); f += 1
		var fa := FileAccess.open(out.path_join("timeline.json"), FileAccess.WRITE); fa.store_string(JSON.stringify(timeline))
	print("REEL DONE ", mode)
	quit()
