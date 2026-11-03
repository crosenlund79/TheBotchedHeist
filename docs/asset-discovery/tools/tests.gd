extends SceneTree
# Functional tests: skinning, bone attachment, animation playback, FX integration.
const P := "res://Assets/Synty/PolygonHeist/"
var out_dir := ""
var results := {}

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(1024, 640))
	root.size = Vector2i(1024, 640)
	_run()

func _stage() -> Camera3D:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.82, 0.84, 0.87)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_energy = 0.6
	we.environment = e
	root.add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-50, -35, 0)
	l.shadow_enabled = true
	root.add_child(l)
	var c := Camera3D.new()
	c.fov = 35
	root.add_child(c)
	c.make_current()
	return c

func _shot(name: String, frames := 8) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("SHOT ", name)

func _clear(keep: Array) -> void:
	for c in root.get_children():
		if not keep.has(c):
			c.queue_free()
	await process_frame

func _run() -> void:
	await process_frame
	# --- Test 1: skinning + pose ---
	var cam := _stage()
	var keep := root.get_children()
	var names := ["SM_Chr_Male_SWAT_01", "SM_Chr_Female_Overall_01", "SM_Chr_Male_SuitVest_01", "SM_Chr_Female_FBI_01"]
	var x := -1.5
	var poses_ok := true
	for n in names:
		var ch: Node3D = load(P + "Prefab/Characters/" + n + ".tscn").instantiate()
		root.add_child(ch)
		ch.position = Vector3(x, 0, 0)
		x += 1.0
		var sk: Skeleton3D = ch.get_node("Skeleton3D")
		for side in ["L", "R"]:
			var b := sk.find_bone("Shoulder_" + side)
			if b < 0: poses_ok = false; continue
			var axis := Vector3(0, 0, 1) if side == "L" else Vector3(0, 0, 1)
			var q := sk.get_bone_pose_rotation(b) * Quaternion(axis, deg_to_rad(-70 if side == "L" else 70))
			sk.set_bone_pose_rotation(b, q)
		var hb := sk.find_bone("Head")
		sk.set_bone_pose_rotation(hb, sk.get_bone_pose_rotation(hb) * Quaternion(Vector3(0, 1, 0), deg_to_rad(25)))
		var kb := sk.find_bone("LowerLeg_L")
		sk.set_bone_pose_rotation(kb, sk.get_bone_pose_rotation(kb) * Quaternion(Vector3(0, 0, 1), deg_to_rad(40)))
	results["pose_bones_found"] = poses_ok
	cam.global_position = Vector3(0, 1.1, 5.2)
	cam.look_at(Vector3(0, 0.9, 0))
	await _shot("test_skinning_pose")
	await _clear(keep)

	# --- Test 2: masks attached to head bone ---
	var masks := ["Fox", "Clown", "Chicken", "Balaclava"]
	x = -1.5
	for m in masks:
		var ch: Node3D = load(P + "Prefab/Characters/SM_Chr_Male_Shirt_01.tscn").instantiate()
		root.add_child(ch)
		ch.position = Vector3(x, 0, 0)
		x += 1.0
		var att: BoneAttachment3D = ch.get_node("Skeleton3D/Head_Bone_Attachments")
		for c in att.get_children(): c.visible = false
		var mask: Node3D = load(P + "Prefab/Masks/SM_Item_Mask_%s_01.tscn" % m).instantiate()
		att.add_child(mask)
		var sk: Skeleton3D = ch.get_node("Skeleton3D")
		for side in ["L", "R"]:
			var b := sk.find_bone("Shoulder_" + side)
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(Vector3(0, 0, 1), deg_to_rad(-70 if side == "L" else 70)))
		# duffel bag skinned mesh toggled on as test
		if m == "Fox":
			ch.get_node("Skeleton3D/Item_Duffel_Bag").visible = true
	cam.global_position = Vector3(0, 1.4, 3.6)
	cam.look_at(Vector3(0, 1.2, 0))
	await _shot("test_masks_on_head_bone")
	await _clear(keep)

	# --- Test 3: animation resource playback ---
	var ch3: Node3D = load(P + "Prefab/Characters/SM_Chr_Male_SWAT_01.tscn").instantiate()
	root.add_child(ch3)
	var ap: AnimationPlayer = ch3.get_node("AnimationPlayer")
	var anim: Animation = load(P + "Model/extracted/animation.tres")
	var lib := AnimationLibrary.new()
	lib.add_animation("take001", anim)
	ap.add_animation_library("", lib)
	ap.play("take001")
	var sk3: Skeleton3D = ch3.get_node("Skeleton3D")
	var p0 := sk3.get_bone_global_pose(sk3.find_bone("Hand_L")).origin
	for i in 30: await process_frame
	var p1 := sk3.get_bone_global_pose(sk3.find_bone("Hand_L")).origin
	results["anim_take001_length"] = anim.length
	results["anim_take001_tracks"] = anim.get_track_count()
	results["anim_take001_hand_moved"] = p0.distance_to(p1)
	results["anim_playing"] = ap.is_playing()
	await _clear(keep)

	# --- Test 4: FX library inside the Heist Demo lobby ---
	for c in keep: c.queue_free()
	await process_frame
	var demo: Node3D = load(P + "Scenes/Demo.tscn").instantiate()
	root.add_child(demo)
	var dcam := _find_cam(demo)
	dcam.make_current()
	var fwd := -dcam.global_transform.basis.z
	var base := dcam.global_position + fwd * 7.0
	base.y = 0.0
	var right := dcam.global_transform.basis.x
	var fx := {"FX_Fire_Medium_01": base - right * 1.6, "FX_Smoke_01": base - right * 1.6 + Vector3(0, 0.8, 0), "FX_Dust_01": base + Vector3(0, 1.5, 0), "FX_Fire_Small_01": base + right * 1.8}
	for k in fx.keys():
		var f: Node3D = load("res://Assets/Particle_FX_test/Prefabs/FX/%s.tscn" % k).instantiate()
		demo.add_child(f)
		f.global_position = fx[k]
	var swat: Node3D = load(P + "Prefab/Characters/SM_Chr_Male_SWAT_01.tscn").instantiate()
	demo.add_child(swat)
	swat.global_position = base + right * 0.2 + fwd * 0.5
	swat.look_at(dcam.global_position * Vector3(1, 0, 1), Vector3.UP, true)
	var bag: Node3D = load(P + "Prefab/Items/SM_Item_DuffleBag_Open_Full_01.tscn").instantiate()
	demo.add_child(bag)
	bag.global_position = base + right * 0.9 - fwd * 1.5
	await _shot("test_fx_in_heist_lobby", 160)

	var f := FileAccess.open(out_dir.path_join("tests.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	print("RESULTS ", JSON.stringify(results))
	quit()

func _find_cam(n: Node) -> Camera3D:
	if n is Camera3D: return n
	for c in n.get_children():
		var r = _find_cam(c)
		if r: return r
	return null
