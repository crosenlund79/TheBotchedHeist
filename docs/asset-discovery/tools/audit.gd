extends SceneTree
# Loads every .tscn under given root, instantiates, and dumps JSON stats.

var out := []

func _walk(dir_path: String, acc: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.begins_with("."):
			f = d.get_next(); continue
		var p := dir_path.path_join(f)
		if d.current_is_dir():
			_walk(p, acc)
		elif f.ends_with(".tscn"):
			acc.append(p)
		f = d.get_next()

func _tex_name(t) -> String:
	if t == null: return ""
	return t.resource_path.get_file()

func _mat_info(m: Material) -> Dictionary:
	var i := {"class": m.get_class() if m else "null", "path": m.resource_path.get_file() if m else ""}
	if m is BaseMaterial3D:
		i["albedo_tex"] = _tex_name(m.albedo_texture)
		i["albedo_color"] = m.albedo_color.to_html()
		i["emission"] = m.emission_enabled
		i["emission_tex"] = _tex_name(m.emission_texture)
		i["transparency"] = m.transparency
		i["metallic_tex"] = _tex_name(m.metallic_texture)
	elif m is ShaderMaterial:
		i["shader"] = m.shader.resource_path if m.shader else "null"
	return i

func _scan(n: Node, s: Dictionary, root: Node) -> void:
	s["node_types"][n.get_class()] = s["node_types"].get(n.get_class(), 0) + 1
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			s["errors"].append("MeshInstance3D without mesh: " + str(root.get_path_to(n)))
		else:
			var verts := 0; var tris := 0
			for si in mesh.get_surface_count():
				var arr = mesh.surface_get_arrays(si)
				if arr[Mesh.ARRAY_VERTEX] != null:
					verts += arr[Mesh.ARRAY_VERTEX].size()
				if arr[Mesh.ARRAY_INDEX] != null:
					tris += arr[Mesh.ARRAY_INDEX].size() / 3
				var m: Material = mi.get_active_material(si)
				var mn = _mat_info(m) if m else {"class":"NONE"}
				s["materials"].append(mn)
				if m == null:
					s["errors"].append("surface without material: %s/%d" % [str(root.get_path_to(n)), si])
				if mesh is ArrayMesh:
					var fmt = mesh.surface_get_format(si)
					if fmt & Mesh.ARRAY_FORMAT_BONES: s["skinned"] = true
			s["verts"] += verts; s["tris"] += tris
			s["meshes"].append({"node": str(root.get_path_to(n)), "mesh": mesh.resource_path.get_file(), "verts": verts, "tris": tris, "surfaces": mesh.get_surface_count(), "visible": mi.is_visible_in_tree()})
			var ab: AABB = mi.global_transform * mesh.get_aabb() if mi.is_inside_tree() else mesh.get_aabb()
			s["aabbs"].append([ab.position.x, ab.position.y, ab.position.z, ab.size.x, ab.size.y, ab.size.z])
		if mi.skin: s["skinned"] = true
	if n is Skeleton3D:
		s["skeleton_bones"] = (n as Skeleton3D).get_bone_count()
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		for a in ap.get_animation_list():
			var anim := ap.get_animation(a)
			s["animations"].append({"name": a, "length": anim.length, "tracks": anim.get_track_count()})
	if n is GPUParticles3D or n is CPUParticles3D:
		var p = {"node": str(root.get_path_to(n)), "class": n.get_class(), "amount": n.amount, "lifetime": n.lifetime}
		if n is GPUParticles3D:
			p["process_material"] = n.process_material.get_class() if n.process_material else "null"
			p["process_material_path"] = n.process_material.resource_path.get_file() if n.process_material else ""
			var dp = []
			for i in n.draw_passes:
				var dm = n.get_draw_pass_mesh(i)
				if dm:
					var mat = dm.surface_get_material(0) if dm.get_surface_count() > 0 else null
					dp.append({"mesh": dm.get_class(), "material": _mat_info(mat) if mat else {}})
			p["draw_passes"] = dp
			if n.process_material == null: s["errors"].append("particles without process material: " + p["node"])
		s["particles"].append(p)
	if n is Light3D:
		s["lights"].append({"class": n.get_class(), "energy": n.light_energy, "color": n.light_color.to_html()})
	if n is CollisionShape3D:
		s["collision"].append((n as CollisionShape3D).shape.get_class() if (n as CollisionShape3D).shape else "null")
	if n.get_script():
		s["scripts"].append(n.get_script().resource_path)
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D:
		s["audio"].append(str(n.stream))
	for c in n.get_children():
		_scan(c, s, root)

func _init() -> void:
	var roots := OS.get_cmdline_user_args()
	var files := []
	for r in roots:
		_walk(r, files)
	files.sort()
	for p in files:
		var s := {"path": p, "loaded": false, "errors": [], "node_types": {}, "meshes": [], "materials": [], "verts": 0, "tris": 0, "skinned": false, "skeleton_bones": 0, "animations": [], "particles": [], "lights": [], "collision": [], "scripts": [], "audio": [], "aabbs": [], "deps": []}
		for dep in ResourceLoader.get_dependencies(p):
			var dp: String = dep.get_slice("::", 2) if dep.contains("::") else dep
			var uid_part: String = dep.get_slice("::", 0)
			var ok := ResourceLoader.exists(dp)
			if not ok and uid_part.begins_with("uid://"):
				ok = ResourceUID.has_id(ResourceUID.text_to_id(uid_part))
			s["deps"].append({"dep": dep, "resolvable": ok})
			if not ok: s["errors"].append("missing dep: " + dep)
		var ps = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
		if ps == null:
			s["errors"].append("load failed")
			out.append(s); continue
		var inst: Node = ps.instantiate()
		if inst == null:
			s["errors"].append("instantiate failed"); out.append(s); continue
		s["loaded"] = true
		root.add_child(inst)
		_scan(inst, s, inst)
		inst.queue_free()
		root.remove_child(inst)
		out.append(s)
	var f := FileAccess.open(OS.get_environment("AUDIT_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("AUDITED ", files.size())
	quit()
