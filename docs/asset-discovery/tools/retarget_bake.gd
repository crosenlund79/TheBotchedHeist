extends SceneTree
# Bakes Mixamo clips onto the unmodified Synty Heist character skeleton.
# Method: per frame, each mapped bone's world-space rotation delta from its T-pose rest on the
# Mixamo rig is applied to the matching Synty bone's world-space rest. The hips translation is
# scaled by the hip-height ratio. Output: Synty-named AnimationLibrary resources (.res).
# Usage: godot --headless --path <heist project> -s retarget_bake.gd -- <src_dir> <out_dir> <report.json>

const MAP := {
	"Hips": "Hips", "Spine": "Spine_01", "Spine1": "Spine_02", "Spine2": "Spine_03", "Neck": "Neck", "Head": "Head",
	"LeftShoulder": "Clavicle_L", "LeftArm": "Shoulder_L", "LeftForeArm": "Elbow_L", "LeftHand": "Hand_L",
	"RightShoulder": "Clavicle_R", "RightArm": "Shoulder_R", "RightForeArm": "Elbow_R", "RightHand": "Hand_R",
	"LeftUpLeg": "UpperLeg_L", "LeftLeg": "LowerLeg_L", "LeftFoot": "Ankle_L", "LeftToeBase": "Ball_L",
	"RightUpLeg": "UpperLeg_R", "RightLeg": "LowerLeg_R", "RightFoot": "Ankle_R", "RightToeBase": "Ball_R",
	"LeftHandThumb1": "Thumb_01_L", "LeftHandThumb2": "Thumb_02_L", "LeftHandThumb3": "Thumb_03_L",
	"LeftHandIndex1": "IndexFinger_01_L", "LeftHandIndex2": "IndexFinger_02_L", "LeftHandIndex3": "IndexFinger_03_L",
	"LeftHandMiddle1": "Finger_01_L", "LeftHandMiddle2": "Finger_02_L", "LeftHandMiddle3": "Finger_03_L",
	"RightHandThumb1": "Thumb_01_R", "RightHandThumb2": "Thumb_02_R", "RightHandThumb3": "Thumb_03_R",
	"RightHandIndex1": "IndexFinger_01_R", "RightHandIndex2": "IndexFinger_02_R", "RightHandIndex3": "IndexFinger_03_R",
	"RightHandMiddle1": "Finger_01_R", "RightHandMiddle2": "Finger_02_R", "RightHandMiddle3": "Finger_03_R",
}
# loop flag, in-place (strip horizontal hip travel) flag, per clip
const CLIPS := {
	"Female_Idle": [true, false], "Female_Walking": [true, true], "Female_Running": [true, true],
	"Female_Sneak Walk": [true, true], "Female_Crouched Walking": [true, true], "Female_Firing Rifle": [true, false],
	"Female_Carrying": [true, false], "Female_Crouching": [false, false], "Female_Opening": [false, false],
	"Female_Picking Up Object": [false, false], "Female_Button Pushing": [false, false],
}
const FPS := 30.0
const TARGET := "res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Female_Shirt_01.tscn"

func _initialize() -> void: _run()

func _sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r = _sk(c)
		if r: return r
	return null
func _ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r = _ap(c)
		if r: return r
	return null

func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var src_dir: String = args[0]; var out_dir: String = args[1]
	var tgt_inst: Node = load(TARGET).instantiate(); root.add_child(tgt_inst)
	var tsk: Skeleton3D = tgt_inst.get_node("Skeleton3D")
	var tn := tsk.get_bone_count()
	var t_rest_g := []
	for i in tn: t_rest_g.append(tsk.get_bone_global_rest(i).basis.get_rotation_quaternion())
	var report := []
	var lib := AnimationLibrary.new()
	var lib_inplace := AnimationLibrary.new()
	for f in DirAccess.get_files_at(src_dir):
		if not f.ends_with(".fbx"): continue
		var key := f.get_basename()
		var cfg = CLIPS.get(key, [false, false])
		var src: Node = load(src_dir.path_join(f)).instantiate(); root.add_child(src)
		var ssk := _sk(src); var ap := _ap(src)
		var an: Animation = ap.get_animation(ap.get_animation_list()[0])
		var sn := ssk.get_bone_count()
		var s_rest_g := []; var s_rest_l := []
		for i in sn:
			s_rest_g.append(ssk.get_bone_global_rest(i).basis.get_rotation_quaternion())
			s_rest_l.append(ssk.get_bone_rest(i))
		# track lookup per source bone
		var rot_t := {}; var pos_t := {}
		for t in an.get_track_count():
			var bn := str(an.track_get_path(t)).get_slice(":", 1)
			var bi := ssk.find_bone(bn)
			if bi < 0: continue
			if an.track_get_type(t) == Animation.TYPE_ROTATION_3D: rot_t[bi] = t
			elif an.track_get_type(t) == Animation.TYPE_POSITION_3D: pos_t[bi] = t
		# target bone -> source bone
		var t2s := {}
		var mapped := 0
		for k in MAP:
			var si := ssk.find_bone("mixamorig_" + k); var ti := tsk.find_bone(MAP[k])
			if si >= 0 and ti >= 0: t2s[ti] = si; mapped += 1
		var s_hips := ssk.find_bone("mixamorig_Hips"); var t_hips := tsk.find_bone("Hips")
		var scale := tsk.get_bone_global_rest(t_hips).origin.y / ssk.get_bone_global_rest(s_hips).origin.y
		var s_hips_rest_pos := ssk.get_bone_global_rest(s_hips).origin
		var t_hips_rest_pos := tsk.get_bone_global_rest(t_hips).origin
		var frames := int(ceil(an.length * FPS)) + 1
		var out := Animation.new(); out.length = an.length
		var out_ip := Animation.new(); out_ip.length = an.length
		out.loop_mode = Animation.LOOP_LINEAR if cfg[0] else Animation.LOOP_NONE
		out_ip.loop_mode = out.loop_mode
		var rtracks := {}; var rtracks_ip := {}
		for ti in tn:
			var tr := out.add_track(Animation.TYPE_ROTATION_3D); out.track_set_path(tr, "Skeleton3D:" + tsk.get_bone_name(ti)); rtracks[ti] = tr
			var tr2 := out_ip.add_track(Animation.TYPE_ROTATION_3D); out_ip.track_set_path(tr2, "Skeleton3D:" + tsk.get_bone_name(ti)); rtracks_ip[ti] = tr2
		var ptr := out.add_track(Animation.TYPE_POSITION_3D); out.track_set_path(ptr, "Skeleton3D:Hips")
		var ptr_ip := out_ip.add_track(Animation.TYPE_POSITION_3D); out_ip.track_set_path(ptr_ip, "Skeleton3D:Hips")
		# hip travel for in-place stripping
		var hp0: Vector3 = an.position_track_interpolate(pos_t[s_hips], 0.0) if pos_t.has(s_hips) else s_rest_l[s_hips].origin
		var hp1: Vector3 = an.position_track_interpolate(pos_t[s_hips], an.length) if pos_t.has(s_hips) else hp0
		var travel := hp1 - hp0
		var max_err := 0.0
		for fi in frames:
			var time: float = min(fi / FPS, an.length)
			# source globals
			var sg := []; sg.resize(sn)
			for si in sn:
				var lq: Quaternion = an.rotation_track_interpolate(rot_t[si], time) if rot_t.has(si) else s_rest_l[si].basis.get_rotation_quaternion()
				var p := ssk.get_bone_parent(si)
				sg[si] = (sg[p] * lq) if p >= 0 else lq
			# target globals top-down (bones are ordered parent-first? enforce by recursion)
			var tg := []; tg.resize(tn)
			var done := []; done.resize(tn); done.fill(false)
			for ti in tn: _solve(ti, tsk, t2s, sg, s_rest_g, t_rest_g, tg, done)
			for ti in tn:
				var p := tsk.get_bone_parent(ti)
				var lq: Quaternion = (tg[p].inverse() * tg[ti]) if p >= 0 else tg[ti]
				lq = lq.normalized()
				out.rotation_track_insert_key(rtracks[ti], time, lq)
				out_ip.rotation_track_insert_key(rtracks_ip[ti], time, lq)
			var hp: Vector3 = an.position_track_interpolate(pos_t[s_hips], time) if pos_t.has(s_hips) else hp0
			var root_g := tsk.get_bone_global_rest(tsk.get_bone_parent(t_hips))
			var world := t_hips_rest_pos + (hp - s_hips_rest_pos) * scale
			out.position_track_insert_key(ptr, time, root_g.affine_inverse() * world)
			var hp_ip := hp - travel * (time / an.length) if cfg[1] else hp
			out_ip.position_track_insert_key(ptr_ip, time, root_g.affine_inverse() * (t_hips_rest_pos + (hp_ip - s_hips_rest_pos) * scale))
		var clip_name := key.replace("Female_", "").to_lower().replace(" ", "_")
		lib.add_animation(clip_name, out)
		lib_inplace.add_animation(clip_name, out_ip if cfg[1] else out)
		report.append({"file": f, "clip": clip_name, "length": an.length, "frames": frames, "mapped_bones": mapped,
			"source_tracks": an.get_track_count(), "loop": cfg[0], "in_place_variant": cfg[1],
			"root_travel_m": (travel * scale).length(), "hip_scale": scale})
		src.queue_free(); await process_frame
	ResourceSaver.save(lib, out_dir.path_join("synty_female_mixamo_rootmotion.res"))
	ResourceSaver.save(lib_inplace, out_dir.path_join("synty_female_mixamo_inplace.res"))
	var fa := FileAccess.open(args[2], FileAccess.WRITE); fa.store_string(JSON.stringify(report, "  "))
	print("BAKED ", report.size())
	quit()

func _solve(ti: int, tsk: Skeleton3D, t2s: Dictionary, sg: Array, s_rest_g: Array, t_rest_g: Array, tg: Array, done: Array) -> void:
	if done[ti]: return
	var p := tsk.get_bone_parent(ti)
	if p >= 0: _solve(p, tsk, t2s, sg, s_rest_g, t_rest_g, tg, done)
	if t2s.has(ti):
		var si: int = t2s[ti]
		var delta: Quaternion = sg[si] * s_rest_g[si].inverse()
		tg[ti] = (delta * t_rest_g[ti]).normalized()
	else:
		var lq := tsk.get_bone_rest(ti).basis.get_rotation_quaternion()
		tg[ti] = (tg[p] * lq) if p >= 0 else lq
	done[ti] = true
