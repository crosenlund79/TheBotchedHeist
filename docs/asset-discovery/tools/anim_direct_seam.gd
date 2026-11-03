extends SceneTree
func _initialize() -> void: _run()
func _run() -> void:
	await process_frame
	var out := {}
	var ch: Node3D = load("res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Female_Shirt_01.tscn").instantiate(); root.add_child(ch)
	var sk: Skeleton3D = ch.get_node("Skeleton3D"); var ap: AnimationPlayer = ch.get_node("AnimationPlayer")
	var raw := AnimationLibrary.new()
	for f in DirAccess.get_files_at("res://Assets/AnimRaw"):
		if f.ends_with(".fbx"):
			var s: Node = load("res://Assets/AnimRaw/" + f).instantiate()
			raw.add_animation(f.get_basename().replace("Female_", "").to_lower().replace(" ", "_"), s.get_node("AnimationPlayer").get_animation("mixamo_com"))
			s.free()
	ap.add_animation_library("raw", raw)
	ap.add_animation_library("baked", load("res://Assets/AnimBaked/synty_female_mixamo_inplace.res"))
	var hand := sk.find_bone("Hand_R")
	for c in raw.get_animation_list():
		# 1) raw clip directly on the Synty skeleton
		sk.reset_bone_poses()
		var p0 := sk.get_bone_global_pose(hand).origin
		ap.play("raw/" + c); var moved := 0.0
		for t in [0.2, 0.5, 0.8]:
			ap.seek(ap.current_animation_length * t, true)
			moved = max(moved, p0.distance_to(sk.get_bone_global_pose(hand).origin))
		ap.stop()
		# 2) loop seam of the baked clip
		var an := ap.get_animation("baked/" + c); var seam := 0.0
		for tr in an.get_track_count():
			if an.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
				var a: Quaternion = an.rotation_track_interpolate(tr, 0.0); var b: Quaternion = an.rotation_track_interpolate(tr, an.length)
				seam = max(seam, rad_to_deg(a.angle_to(b)))
		out[c] = {"raw_direct_hand_moved_m": moved, "loop_seam_max_deg": seam, "loop": an.loop_mode != 0}
	var fa := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE); fa.store_string(JSON.stringify(out, "  "))
	quit()
