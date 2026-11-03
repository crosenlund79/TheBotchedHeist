extends SceneTree
## Bakes the Mixamo FBX clips onto the Synty Heist character skeleton.
##
## This is the baked retarget from docs/asset-discovery (section 9): each frame, every
## mapped bone's world-space rotation away from its T-pose is transferred from the Mixamo rig
## to the Synty rig, and the hips translation is scaled by the hip-height ratio. The existing
## Synty prefabs play the result unchanged.
##
## It writes two AnimationLibrary resources:
##   heist_female_inplace.res   - horizontal travel removed; character stays on the spot.
##   heist_female_rootmotion.res - travel (and the heading change of turn clips) baked onto
##                                 the Synty "Root" bone, for AnimationMixer.root_motion_track.
## Each Animation carries metadata: category, display_name, loops, has_root_motion,
## source_file, travel_m, yaw_deg.
##
## Run from the repository root:
##   godot --headless --path TheHeist -s res://Assets/Showcase/tools/bake_animations.gd
## Optional argument: a folder of FBX files (default: <repo>/Animations/Female).

const OUT_DIR := "res://Assets/Showcase/Animations"
const TARGET := "res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Female_Shirt_01.tscn"
const FPS := 30.0
const TRAVEL_THRESHOLD_M := 0.25   # horizontal hip travel that counts as root motion
const TURN_THRESHOLD_DEG := 30.0   # net heading change that counts as a turn
const SAME_CLIP_DEG := 2.0         # mean pose difference below which two clips are duplicates

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

var tsk: Skeleton3D
var t_rest_g := []

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var src_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://").path_join("../Animations/Female").simplify_path()
	print("Source folder: ", src_dir)
	var files := Array(DirAccess.get_files_at(src_dir)).filter(func(f): return f.to_lower().ends_with(".fbx"))
	files.sort()
	if files.is_empty():
		push_error("No FBX files in " + src_dir); quit(1); return

	var tgt: Node = load(TARGET).instantiate(); root.add_child(tgt)
	tsk = tgt.get_node("Skeleton3D")
	for i in tsk.get_bone_count():
		t_rest_g.append(tsk.get_bone_global_rest(i).basis.get_rotation_quaternion())

	# Previous bake, used to detect a re-uploaded clip that changed.
	var old_ip: AnimationLibrary = null; var old_rm: AnimationLibrary = null
	if ResourceLoader.exists(OUT_DIR + "/heist_female_inplace.res"):
		old_ip = ResourceLoader.load(OUT_DIR + "/heist_female_inplace.res", "", ResourceLoader.CACHE_MODE_IGNORE)
		old_rm = ResourceLoader.load(OUT_DIR + "/heist_female_rootmotion.res", "", ResourceLoader.CACHE_MODE_IGNORE)

	var lib_ip := AnimationLibrary.new(); var lib_rm := AnimationLibrary.new()
	var report := {"source_folder": src_dir, "clips": [], "duplicates": [], "changed": [], "errors": []}
	for f in files:
		var r := _bake_file(src_dir.path_join(f))
		if r.is_empty():
			report.errors.append(f); continue
		var id: String = r.id
		# Same clip id baked before but the source changed: keep both versions.
		if old_ip and old_ip.has_animation(id):
			var diff := _pose_diff(old_ip.get_animation(id), r.inplace)
			if diff > SAME_CLIP_DEG:
				var old_a := old_ip.get_animation(id).duplicate(true)
				if not lib_ip.has_animation(id):
					lib_ip.add_animation(id, old_a); lib_rm.add_animation(id, old_rm.get_animation(id).duplicate(true))
				id = id + "_v2"
				r.inplace.set_meta("display_name", str(r.inplace.get_meta("display_name")) + " (v2)")
				r.rootmotion.set_meta("display_name", r.inplace.get_meta("display_name"))
				report.changed.append({"clip": r.id, "mean_pose_diff_deg": diff, "kept_as": [r.id, id]})
		# A second file that duplicates an already-baked clip is skipped.
		var dup_of := ""
		for other in lib_ip.get_animation_list():
			var oa := lib_ip.get_animation(other)
			if absf(oa.length - r.inplace.length) / maxf(oa.length, 0.01) < 0.05 and _pose_diff(oa, r.inplace) < SAME_CLIP_DEG:
				dup_of = other
		if dup_of != "":
			report.duplicates.append({"file": f, "duplicate_of": dup_of}); continue
		lib_ip.add_animation(id, r.inplace); lib_rm.add_animation(id, r.rootmotion)
		report.clips.append({"id": id, "file": f, "length": r.inplace.length, "loops": r.inplace.loop_mode != Animation.LOOP_NONE,
			"category": r.inplace.get_meta("category"), "has_root_motion": r.rootmotion.get_meta("has_root_motion"),
			"travel_m": r.rootmotion.get_meta("travel_m"), "yaw_deg": r.rootmotion.get_meta("yaw_deg")})
		print("  baked %-22s %5.2fs  %s%s" % [id, r.inplace.length, "loop" if r.inplace.loop_mode else "once",
			"  root motion" if r.rootmotion.get_meta("has_root_motion") else ""])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	ResourceSaver.save(lib_ip, OUT_DIR + "/heist_female_inplace.res")
	ResourceSaver.save(lib_rm, OUT_DIR + "/heist_female_rootmotion.res")
	var fa := FileAccess.open(OUT_DIR + "/bake_report.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(report, "  "))
	print("Baked %d clips (%d duplicates skipped, %d changed, %d errors)" % [report.clips.size(), report.duplicates.size(), report.changed.size(), report.errors.size()])
	quit()

func _load_fbx(path: String) -> Node:
	var doc := FBXDocument.new(); var st := FBXState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	return doc.generate_scene(st)

func _bake_file(path: String) -> Dictionary:
	var src := _load_fbx(path)
	if src == null:
		push_error("Could not read " + path); return {}
	root.add_child(src)
	var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var an: Animation = ap.get_animation(ap.get_animation_list()[0])
	var id := HeistClipCatalog.clip_id_from_file(path.get_file())
	var meta := HeistClipCatalog.info(id)

	var sn := ssk.get_bone_count()
	var s_rest_g := []; var s_rest_l := []
	for i in sn:
		s_rest_g.append(ssk.get_bone_global_rest(i).basis.get_rotation_quaternion())
		s_rest_l.append(ssk.get_bone_rest(i).basis.get_rotation_quaternion())
	var rot_t := {}; var pos_t := {}
	for t in an.get_track_count():
		var bi := ssk.find_bone(str(an.track_get_path(t)).get_slice(":", 1))
		if bi < 0: continue
		if an.track_get_type(t) == Animation.TYPE_ROTATION_3D: rot_t[bi] = t
		elif an.track_get_type(t) == Animation.TYPE_POSITION_3D: pos_t[bi] = t
	var t2s := {}
	for k in MAP:
		var si := _find_mixamo_bone(ssk, k); var ti := tsk.find_bone(MAP[k])
		if si >= 0 and ti >= 0: t2s[ti] = si
	var s_hips := _find_mixamo_bone(ssk, "Hips")
	var t_hips := tsk.find_bone("Hips"); var t_root := tsk.find_bone("Root")
	var scale := tsk.get_bone_global_rest(t_hips).origin.y / ssk.get_bone_global_rest(s_hips).origin.y
	var s_hips_rest := ssk.get_bone_global_rest(s_hips).origin
	var t_hips_rest := tsk.get_bone_global_rest(t_hips).origin
	var root_rest := tsk.get_bone_rest(t_root)
	var length := an.length
	var frames := int(ceil(length * FPS)) + 1
	var tn := tsk.get_bone_count()

	# Pass 1: per-frame target global rotations, hips world position and heading.
	var samples := []
	var yaw_prev := 0.0; var yaw_acc := 0.0
	for fi in frames:
		var time: float = min(fi / FPS, length)
		var sg := []; sg.resize(sn)
		for si in sn:
			var lq: Quaternion = an.rotation_track_interpolate(rot_t[si], time) if rot_t.has(si) else s_rest_l[si]
			var p := ssk.get_bone_parent(si)
			sg[si] = (sg[p] * lq) if p >= 0 else lq
		var tg := []; tg.resize(tn)
		var done := []; done.resize(tn); done.fill(false)
		for ti in tn: _solve(ti, t2s, sg, s_rest_g, tg, done)
		var hp: Vector3 = an.position_track_interpolate(pos_t[s_hips], time) if pos_t.has(s_hips) else s_hips_rest
		var hips_world := t_hips_rest + (hp - s_hips_rest) * scale
		var fwd: Vector3 = (tg[t_hips] * t_rest_g[t_hips].inverse()) * Vector3.FORWARD * -1.0  # character faces +Z
		var yaw := atan2(fwd.x, fwd.z)
		if fi > 0: yaw_acc += wrapf(yaw - yaw_prev, -PI, PI)
		yaw_prev = yaw
		samples.append({"t": time, "tg": tg, "hips": hips_world, "yaw": yaw_acc})

	var travel: Vector3 = samples[-1].hips - samples[0].hips
	travel.y = 0.0
	var has_travel := travel.length() > TRAVEL_THRESHOLD_M
	var net_yaw: float = samples[-1].yaw
	var is_turn := absf(rad_to_deg(net_yaw)) > TURN_THRESHOLD_DEG

	var ip := _new_anim(length, meta, id, path)
	var rm := _new_anim(length, meta, id, path)
	ip.set_meta("has_root_motion", false)
	rm.set_meta("has_root_motion", has_travel or is_turn)
	for a in [ip, rm]:
		a.set_meta("travel_m", travel.length())
		a.set_meta("yaw_deg", rad_to_deg(net_yaw))
	var tracks_ip := _add_tracks(ip); var tracks_rm := _add_tracks(rm)
	var root_pos_rm: int = rm.add_track(Animation.TYPE_POSITION_3D); rm.track_set_path(root_pos_rm, "Skeleton3D:Root")
	var root_rot_rm: int = tracks_rm[t_root]

	# Pass 2: write keys.
	for s in samples:
		var time: float = s.t
		var tg: Array = s.tg
		var hips_world: Vector3 = s.hips
		var progress: float = time / length if length > 0.0 else 0.0
		for ti in tn:
			var p := tsk.get_bone_parent(ti)
			var lq: Quaternion = ((tg[p].inverse() * tg[ti]) if p >= 0 else tg[ti]).normalized()
			ip.rotation_track_insert_key(tracks_ip[ti], time, lq)
			if ti != t_hips and ti != t_root:
				rm.rotation_track_insert_key(tracks_rm[ti], time, lq)
		# In place: subtract straight-line horizontal travel from the hips.
		var hips_ip := hips_world - travel * progress if has_travel else hips_world
		ip.position_track_insert_key(tracks_ip.hips_pos, time, root_rest.affine_inverse() * hips_ip)
		# Root motion: Root carries the straight-line travel (and the heading of turns);
		# the hips keep their natural sway relative to Root.
		var root_yaw := Quaternion(Vector3.UP, s.yaw) if is_turn else Quaternion.IDENTITY
		var root_pos := travel * progress if has_travel else Vector3.ZERO
		var root_xf := Transform3D(Basis(root_rest.basis.get_rotation_quaternion() * root_yaw), root_rest.origin + root_pos)
		rm.position_track_insert_key(root_pos_rm, time, root_xf.origin)
		rm.rotation_track_insert_key(root_rot_rm, time, root_xf.basis.get_rotation_quaternion())
		var hips_local_rot: Quaternion = (root_xf.basis.get_rotation_quaternion().inverse() * tg[t_hips]).normalized()
		rm.rotation_track_insert_key(tracks_rm[t_hips], time, hips_local_rot)
		rm.position_track_insert_key(tracks_rm.hips_pos, time, root_xf.affine_inverse() * hips_world)
	src.queue_free()
	return {"id": id, "inplace": ip, "rootmotion": rm}

func _find_mixamo_bone(ssk: Skeleton3D, name: String) -> int:
	for prefix in ["mixamorig_", "mixamorig:", "mixamorig1_", ""]:
		var i := ssk.find_bone(prefix + name)
		if i >= 0: return i
	return -1

func _new_anim(length: float, meta: Dictionary, id: String, path: String) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if meta.loop else Animation.LOOP_NONE
	a.set_meta("category", meta.category)
	a.set_meta("display_name", meta.display_name)
	a.set_meta("loops", meta.loop)
	a.set_meta("clip_id", id)
	a.set_meta("source_file", path.get_file())
	return a

func _add_tracks(a: Animation) -> Dictionary:
	var d := {}
	for ti in tsk.get_bone_count():
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, "Skeleton3D:" + tsk.get_bone_name(ti))
		d[ti] = tr
	var hp := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(hp, "Skeleton3D:Hips")
	d["hips_pos"] = hp
	return d

func _solve(ti: int, t2s: Dictionary, sg: Array, s_rest_g: Array, tg: Array, done: Array) -> void:
	if done[ti]: return
	var p := tsk.get_bone_parent(ti)
	if p >= 0: _solve(p, t2s, sg, s_rest_g, tg, done)
	if t2s.has(ti):
		var si: int = t2s[ti]
		tg[ti] = ((sg[si] * s_rest_g[si].inverse()) * t_rest_g[ti]).normalized()
	else:
		var lq := tsk.get_bone_rest(ti).basis.get_rotation_quaternion()
		tg[ti] = (tg[p] * lq) if p >= 0 else lq
	done[ti] = true

## Mean angular difference between two baked clips over 20 samples of every rotation track.
func _pose_diff(a: Animation, b: Animation) -> float:
	var total := 0.0; var n := 0
	for tr in a.get_track_count():
		if a.track_get_type(tr) != Animation.TYPE_ROTATION_3D: continue
		var tb := b.find_track(a.track_get_path(tr), Animation.TYPE_ROTATION_3D)
		if tb < 0: continue
		for i in 20:
			var qa: Quaternion = a.rotation_track_interpolate(tr, a.length * i / 19.0)
			var qb: Quaternion = b.rotation_track_interpolate(tb, b.length * i / 19.0)
			total += rad_to_deg(qa.angle_to(qb)); n += 1
	return total / max(n, 1)
