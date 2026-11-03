extends SceneTree
# list lines: res_path|name|cx,cy,cz|dist|bg(dark/light)
func _initialize() -> void:
	root.size = Vector2i(320, 320)
	DisplayServer.window_set_size(root.size)
	_run()
func _run() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	var lines := FileAccess.get_file_as_string(a[0]).split("\n", false)
	var out: String = a[1]
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e; root.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50,-35,0); root.add_child(l)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.22, 0.23, 0.26); floor.material_override = fm
	root.add_child(floor)
	var cam := Camera3D.new(); cam.fov = 40; root.add_child(cam); cam.make_current()
	for line in lines:
		var p := line.split("|")
		var c := p[2].split(","); var center := Vector3(float(c[0]), float(c[1]), float(c[2]))
		var dist := float(p[3])
		e.background_color = Color(0.09, 0.10, 0.12) if p[4] == "dark" else Color(0.55, 0.62, 0.70)
		var n: Node3D = load(p[0]).instantiate()
		root.add_child(n)
		cam.global_position = center + Vector3(0, dist * 0.25, dist)
		cam.look_at(center)
		for i in 150: await process_frame
		for f in 24:
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("%s_%02d.png" % [p[1], f]))
		print("ANIM ", p[1])
		n.queue_free()
		await process_frame
	quit()
