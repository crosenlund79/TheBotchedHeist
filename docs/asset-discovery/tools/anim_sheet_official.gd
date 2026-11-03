extends SceneTree
func _initialize() -> void:
	root.size = Vector2i(300, 360); DisplayServer.window_set_size(root.size); _run()
func _run() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.82,0.84,0.87)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_energy = 0.6
	we.environment = e; root.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50,-35,0); l.shadow_enabled = true; root.add_child(l)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(10,10); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.7,0.72,0.75); fl.material_override = fm; root.add_child(fl)
	var cam := Camera3D.new(); cam.fov = 30; root.add_child(cam); cam.make_current()
	cam.global_position = Vector3(2.6, 1.6, 3.6); cam.look_at(Vector3(0, 0.85, 0))
	var ch: Node3D = load("res://Assets/AnimOfficial/Characters_Retarget.fbx").instantiate(); root.add_child(ch)
	var mat = load("res://Assets/Synty/PolygonHeist/Materials/PolygonHeist_Character_01_mat.tres")
	for m in ch.get_node("GeneralSkeleton").get_children():
		if m is MeshInstance3D:
			m.visible = m.name == "Character_Female_Shirt_01"; m.material_override = mat
	var ap: AnimationPlayer = ch.get_node("AnimationPlayer")
	var lib := AnimationLibrary.new()
	var names := []
	for f in DirAccess.get_files_at("res://Assets/AnimOfficial/clips"):
		if f.ends_with(".res"):
			lib.add_animation(f.get_basename(), load("res://Assets/AnimOfficial/clips/" + f)); names.append(f.get_basename())
	ap.add_animation_library("o", lib)
	print("TRACK0 ", lib.get_animation(names[0]).track_get_path(0), " motion_scale=", ch.get_node("GeneralSkeleton").motion_scale)
	for c in names:
		var an := ap.get_animation("o/" + c)
		ap.play("o/" + c); ap.pause()
		for i in 6:
			ap.seek(an.length * i / 6.0, true)
			for k in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(a[0].path_join("%s_%02d.png" % [c, i]))
	print("OFFICIAL DONE ", names.size())
	quit()
