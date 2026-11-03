extends SceneTree
# Renders N time samples per clip on a Synty prefab driven by a baked library.
# args: <prefab> <library.res> <out_dir> <samples> [clip,clip,...]
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
	cam.global_position = Vector3(3.3, 1.7, 4.7); cam.look_at(Vector3(0.1, 0.8, 0.15))
	var ch: Node3D = load(a[0]).instantiate(); root.add_child(ch)
	var ap: AnimationPlayer = ch.get_node("AnimationPlayer")
	ap.add_animation_library("m", load(a[1]))
	var n := int(a[3])
	var clips: Array = a[4].split(",") if a.size() > 4 else ap.get_animation_library("m").get_animation_list()
	for c in clips:
		var an := ap.get_animation("m/" + c)
		ap.play("m/" + c); ap.pause()
		for i in n:
			var t := an.length * (float(i) / n)
			ap.seek(t, true)
			for k in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(a[2].path_join("%s_%02d.png" % [c, i]))
		print("SHEET ", c)
	quit()
