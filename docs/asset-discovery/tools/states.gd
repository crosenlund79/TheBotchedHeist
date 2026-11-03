extends SceneTree
const P := "res://Assets/Synty/PolygonHeist/Prefab/"
func _initialize() -> void:
	root.size = Vector2i(1280, 640)
	DisplayServer.window_set_size(root.size)
	_run()
func _run() -> void:
	await process_frame
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.82,0.84,0.87)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_energy = 0.6
	we.environment = e; root.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50,-35,0); l.shadow_enabled = true; root.add_child(l)
	var cam := Camera3D.new(); cam.fov = 40; root.add_child(cam); cam.make_current()
	var items := [
		["Environment/SM_Env_VaultDoor_Frame_01", Vector3(-3.5,0,0), {"SM_Env_VaultDoor_Lid_01": Vector3(0,-100,0)}],
		["Vehicles/SM_Veh_SwatVan_01", Vector3(2.5,0,-1), {"SM_Veh_SwatVan_Door_l": Vector3(0,110,0), "SM_Veh_SwatVan_Door_r": Vector3(0,-110,0)}],
		["Props/SM_Prop_DisplayCase_01", Vector3(-0.5,0,1.5), {}],
		["Items/SM_Item_Briefcase_01", Vector3(0.6,0.0,2.4), {"SM_Item_Briefcase_Lid_01": Vector3(-75,0,0)}],
	]
	for it in items:
		var n: Node3D = load(P + it[0] + ".tscn").instantiate()
		root.add_child(n); n.position = it[1]
		if it[0].ends_with("SwatVan_01"): n.rotation_degrees.y = 200
		for k in it[2]:
			var c: Node3D = n.find_child(k, true, false)
			print(k, " found=", c != null)
			if c: c.rotation_degrees = it[2][k]
		if it[0].ends_with("DisplayCase_01"):
			n.get_node("SM_Prop_DisplayCase_Glass_01").visible = false
			n.get_node("SM_Prop_DisplayCase_Glass_1_Broken").visible = true
	cam.global_position = Vector3(0, 3.2, 8.5); cam.look_at(Vector3(-0.3, 1.0, 0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
