extends SceneTree
## Automated check of the animation showcase: plays every clip on every character,
## exercises pause, replay, speed, root motion and the one-shot return to idle, and
## saves screenshots.
##   godot --path TheHeist -s res://Assets/Showcase/tools/showcase_smoke_test.gd -- <out_dir> [all]
## With "all", each clip is captured on all nine characters (otherwise on one).

var out_dir := ""
var results := {"clips": {}, "characters": {}, "checks": {}}

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[0] if a.size() > 0 else "user://showcase_test"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1600, 900)
	DisplayServer.window_set_size(root.size)
	_run(a.size() > 1 and a[1] == "all")

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func _hand_motion(s: Node, frames: int) -> float:
	var sk: Skeleton3D = s.skeleton
	var b := sk.find_bone("Hand_R")
	var p0 := sk.get_bone_global_pose(b).origin
	var m := 0.0
	for i in frames:
		await process_frame
		m = maxf(m, p0.distance_to(sk.get_bone_global_pose(b).origin))
	return m

func _run(all_chars: bool) -> void:
	var s: Node = load("res://Assets/Showcase/AnimationShowcase.tscn").instantiate()
	root.add_child(s)
	await _wait(30)
	await _shot("00_start")
	var clips: Array = s.lib_inplace.get_animation_list()
	# Every clip on the default character: plays, moves bones, screenshot mid-clip.
	for clip in clips:
		s.play_clip(clip)
		var len: float = s.lib_inplace.get_animation(clip).length
		var moved: float = await _hand_motion(s, 20)
		s.player.seek(minf(len * 0.45, len - 0.05), true)
		await _wait(4)
		await _shot("clip_" + clip)
		results.clips[clip] = {"plays": s.player.current_animation.ends_with(clip), "hand_moved_m": moved, "length": len,
			"loops": s.lib_inplace.get_animation(clip).loop_mode != Animation.LOOP_NONE, "root_motion_variant": s._has_root_variant(clip)}
	# One-shot returns to idle.
	s.set_speed(2.0)
	for clip in clips:
		if s.lib_inplace.get_animation(clip).loop_mode == Animation.LOOP_NONE:
			s.play_clip(clip)
			var len2: float = s.lib_inplace.get_animation(clip).length
			await _wait(int(len2 / 2.0 * 60) + 40)
			results.clips[clip]["returned_to_idle"] = s.current_clip == "idle" and s.player.current_animation.ends_with("idle")
	s.set_speed(1.0)
	# Pause / resume / replay.
	s.play_clip("walking")
	await _wait(10)
	s.toggle_pause()
	var t0: float = s.player.current_animation_position
	await _wait(20)
	results.checks["pause_holds_time"] = absf(s.player.current_animation_position - t0) < 0.0001
	s.toggle_pause()
	await _wait(20)
	results.checks["resume_advances"] = s.player.current_animation_position != t0
	s.replay()
	results.checks["replay_restarts"] = s.player.current_animation_position < 0.05
	# Speed.
	s.set_speed(0.5); await _wait(2)
	results.checks["speed_applied"] = is_equal_approx(s.player.speed_scale, 0.5)
	s.set_speed(1.0)
	# Root motion: the character should travel and stay framed.
	s.set_root_motion(true)
	s.play_clip("walking")
	var p_start: Vector3 = s.character.global_position
	await _wait(60)
	results.checks["root_motion_moves_character_m"] = p_start.distance_to(s.character.global_position)
	results.checks["root_motion_uses_rm_library"] = s.player.current_animation.begins_with("rm/")
	await _shot("rootmotion_walking")
	var cam: Camera3D = s.get_node("CameraRig/Camera3D")
	results.checks["character_on_screen"] = cam.is_position_in_frustum(s._frame_point())
	s.set_root_motion(false)
	results.checks["inplace_after_toggle"] = s.player.current_animation.begins_with("ip/")
	# Characters.
	var cast: Array = s.CHARACTERS
	var shot_clips := ["idle", "running", "sneak_walk", "firing_rifle", "picking_up_object", "crouching"]
	for i in cast.size():
		s._on_character_selected(i)
		var clip: String = shot_clips[i % shot_clips.size()]
		s.play_clip(clip)
		var moved2: float = await _hand_motion(s, 20)
		results.characters[cast[i][0]] = {"clip": clip, "hand_moved_m": moved2, "plays": s.player.current_animation.ends_with(clip)}
		await _shot("char_%d_%s" % [i, cast[i][0]])
		if all_chars:
			for c in clips:
				s.play_clip(c); await _wait(15)
				results.characters[cast[i][0]][c] = s.player.current_animation.ends_with(c)
	var f := FileAccess.open(out_dir.path_join("results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "  "))
	print("SHOWCASE TEST DONE")
	quit()
