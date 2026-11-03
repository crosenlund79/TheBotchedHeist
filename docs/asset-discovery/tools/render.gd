extends SceneTree
# Usage: godot --path <proj> -s render.gd -- <list_file> <out_dir> <mode: model|fx|scene> [size]

var cam: Camera3D
var env_node: WorldEnvironment
var light: DirectionalLight3D
var holder: Node3D

func _visible_aabb(n: Node, acc: Array) -> void:
	if n is VisualInstance3D and n.is_visible_in_tree() and (n is MeshInstance3D or n is GPUParticles3D):
		var ab: AABB
		if n is MeshInstance3D and n.mesh:
			ab = n.global_transform * n.mesh.get_aabb()
		elif n is GPUParticles3D:
			ab = n.global_transform * n.visibility_aabb
		else:
			ab = AABB()
		if ab.size.length() > 0.0001:
			if acc.is_empty(): acc.append(ab)
			else: acc[0] = acc[0].merge(ab)
	for c in n.get_children():
		_visible_aabb(c, acc)

func _find_cam(n: Node) -> Camera3D:
	if n is Camera3D: return n
	for c in n.get_children():
		var r = _find_cam(c)
		if r: return r
	return null

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var files := FileAccess.get_file_as_string(a[0]).split("\n", false)
	var out_dir: String = a[1]
	var mode: String = a[2]
	var dims := (a[3] if a.size() > 3 else "512x512").split("x")
	var vs := Vector2i(int(dims[0]), int(dims[1]))
	DisplayServer.window_set_size(vs)
	root.size = vs
	_run(files, out_dir, mode)

func _setup_stage(mode: String) -> void:
	env_node = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.11, 0.12, 0.14) if mode == "fx" else Color(0.82, 0.84, 0.87)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55 if mode != "fx" else 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = e
	root.add_child(env_node)
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	root.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.35
	root.add_child(fill)
	cam = Camera3D.new()
	cam.fov = 35
	root.add_child(cam)
	cam.make_current()

func _run(files: PackedStringArray, out_dir: String, mode: String) -> void:
	await process_frame
	if mode != "scene":
		_setup_stage(mode)
	for line in files:
		var parts := line.split("|")
		var p := parts[0]
		var name := parts[1] if parts.size() > 1 else p.get_file().get_basename()
		var ps: PackedScene = load(p)
		if ps == null:
			print("RENDERFAIL ", p); continue
		var inst: Node = ps.instantiate()
		holder = Node3D.new()
		root.add_child(holder)
		holder.add_child(inst)
		await process_frame
		if mode == "scene":
			var c := _find_cam(inst)
			if c: c.make_current()
		else:
			var acc := []
			_visible_aabb(inst, acc)
			var ab: AABB = acc[0] if acc.size() > 0 else AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
			var center := ab.get_center()
			var radius: float = max(ab.size.length() * 0.5, 0.02)
			var dir := Vector3(0.75, 0.5, 1.0).normalized()
			if mode == "fx": dir = Vector3(0.0, 0.25, 1.0).normalized()
			var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.05
			cam.near = max(dist * 0.01, 0.005)
			cam.far = dist * 10 + 100
			cam.global_position = center + dir * dist
			cam.look_at(center, Vector3.UP)
		var wait := 6
		if mode == "fx": wait = 150
		if mode == "scene": wait = 30
		for i in wait:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out_dir.path_join(name + ".png"))
		print("RENDERED ", name)
		holder.queue_free()
		await process_frame
	quit()
