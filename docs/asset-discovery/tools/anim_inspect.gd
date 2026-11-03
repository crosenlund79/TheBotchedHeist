extends SceneTree
# Inspect each imported animation FBX: skeleton, meshes, clips, root motion, play test.
func _initialize() -> void: _run()
func _find(n: Node, cls: String, acc: Array) -> void:
	if n.is_class(cls): acc.append(n)
	for c in n.get_children(): _find(c, cls, acc)
func _run() -> void:
	await process_frame
	var dir: String = OS.get_cmdline_user_args()[0]
	var out := []
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".fbx"): continue
		var ps: PackedScene = load(dir.path_join(f))
		var r := {"file": f, "loaded": ps != null}
		if ps == null: out.append(r); continue
		var inst: Node = ps.instantiate(); root.add_child(inst)
		var sks := []; _find(inst, "Skeleton3D", sks)
		var mis := []; _find(inst, "MeshInstance3D", mis)
		var aps := []; _find(inst, "AnimationPlayer", aps)
		r["skeletons"] = sks.size(); r["meshes"] = mis.size()
		r["mesh_info"] = mis.map(func(m): return {"name": m.name, "verts": m.mesh.get_faces().size() if m.mesh else 0, "skinned": m.skin != null})
		if sks.size() > 0:
			var sk: Skeleton3D = sks[0]
			r["bone_count"] = sk.get_bone_count()
			var names := []
			for i in sk.get_bone_count(): names.append(sk.get_bone_name(i))
			r["bones"] = names
			r["skeleton_path"] = str(inst.get_path_to(sk))
			var hips := sk.find_bone(names[0] if sk.find_bone("mixamorig_Hips") < 0 else "mixamorig_Hips")
			r["hips_rest_y"] = sk.get_bone_global_rest(hips).origin.y
			var hb := sk.find_bone("mixamorig_Head") if sk.find_bone("mixamorig_Head") >= 0 else sk.find_bone("mixamorig:Head")
			if hb >= 0: r["head_rest_y"] = sk.get_bone_global_rest(hb).origin.y
			r["skeleton_scale"] = sk.global_transform.basis.get_scale().x
		var clips := []
		if aps.size() > 0:
			var ap: AnimationPlayer = aps[0]
			for a in ap.get_animation_list():
				var an := ap.get_animation(a)
				var c := {"name": a, "length": an.length, "tracks": an.get_track_count(), "loop": an.loop_mode}
				var maxk := 0; var hip_travel := Vector3.ZERO; var paths := {}
				for t in an.get_track_count():
					maxk = max(maxk, an.track_get_key_count(t))
					paths[str(an.track_get_path(t)).get_slice(":", 0)] = true
					if an.track_get_type(t) == Animation.TYPE_POSITION_3D and str(an.track_get_path(t)).ends_with("Hips") and an.track_get_key_count(t) > 1:
						hip_travel = an.track_get_key_value(t, an.track_get_key_count(t) - 1) - an.track_get_key_value(t, 0)
				c["max_keys"] = maxk; c["hip_travel"] = [hip_travel.x, hip_travel.y, hip_travel.z]; c["track_roots"] = paths.keys()
				clips.append(c)
			# play test: does a bone actually move?
			if clips.size() > 0 and sks.size() > 0:
				var sk: Skeleton3D = sks[0]
				var b := sk.find_bone("mixamorig_RightHand")
				if b < 0: b = sk.get_bone_count() - 1
				ap.play(clips[0]["name"])
				var p0 := sk.get_bone_global_pose(b).origin
				var moved := 0.0
				for i in 40:
					await process_frame
					moved = max(moved, p0.distance_to(sk.get_bone_global_pose(b).origin))
				r["play_ok"] = ap.is_playing() or moved > 0.0
				r["hand_moved_m"] = moved
		r["clips"] = clips
		out.append(r)
		inst.queue_free(); await process_frame
	var fa := FileAccess.open(OS.get_environment("AUDIT_OUT"), FileAccess.WRITE); fa.store_string(JSON.stringify(out, "  "))
	quit()
