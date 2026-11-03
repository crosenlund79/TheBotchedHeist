extends SceneTree
func _initialize() -> void: _run()
func _sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r = _sk(c)
		if r: return r
	return null
func _run() -> void:
	await process_frame
	for p in OS.get_cmdline_user_args():
		var inst: Node = load(p).instantiate(); root.add_child(inst)
		var sk := _sk(inst)
		print("== ", p, " bones=", sk.get_bone_count(), " skel_xform=", sk.global_transform)
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if n.contains("Finger") or n.contains("Thumb") or n.contains("Index") or n.contains("Middle") or n.contains("Ring") or n.contains("Pinky"):
				if not (n.ends_with("1") or n.ends_with("01_L") or n.ends_with("01_R")): continue
			var g := sk.get_bone_global_rest(i)
			var par := sk.get_bone_parent(i)
			print("%-26s parent=%-22s pos=(%.3f, %.3f, %.3f) Ybasis=(%.2f,%.2f,%.2f)" % [n, sk.get_bone_name(par) if par >= 0 else "-", g.origin.x, g.origin.y, g.origin.z, g.basis.y.x, g.basis.y.y, g.basis.y.z])
		inst.queue_free()
	quit()
