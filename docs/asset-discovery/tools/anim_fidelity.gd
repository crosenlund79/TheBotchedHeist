extends SceneTree
# Compares limb directions of the Mixamo source vs the baked Synty clip, frame by frame,
# and measures foot height (ground contact) on the Synty character.
const SEG := [["LeftArm","LeftForeArm","Shoulder_L","Elbow_L"],["LeftForeArm","LeftHand","Elbow_L","Hand_L"],
	["RightArm","RightForeArm","Shoulder_R","Elbow_R"],["RightForeArm","RightHand","Elbow_R","Hand_R"],
	["LeftUpLeg","LeftLeg","UpperLeg_L","LowerLeg_L"],["LeftLeg","LeftFoot","LowerLeg_L","Ankle_L"],
	["RightUpLeg","RightLeg","UpperLeg_R","LowerLeg_R"],["RightLeg","RightFoot","LowerLeg_R","Ankle_R"],
	["Hips","Neck","Hips","Neck"],["Neck","Head","Neck","Head"]]
func _initialize() -> void: _run()
func _run() -> void:
	await process_frame
	var out := {}
	var tgt: Node3D = load("res://Assets/Synty/PolygonHeist/Prefab/Characters/SM_Chr_Female_Shirt_01.tscn").instantiate(); root.add_child(tgt)
	var tsk: Skeleton3D = tgt.get_node("Skeleton3D"); var tap: AnimationPlayer = tgt.get_node("AnimationPlayer")
	tap.add_animation_library("m", load("res://Assets/AnimBaked/synty_female_mixamo_rootmotion.res"))
	var t_rest_ankle := tsk.get_bone_global_rest(tsk.find_bone("Ankle_L")).origin.y
	for f in DirAccess.get_files_at("res://Assets/AnimRaw"):
		if not f.ends_with(".fbx"): continue
		var clip := f.get_basename().replace("Female_", "").to_lower().replace(" ", "_")
		var src: Node3D = load("res://Assets/AnimRaw/" + f).instantiate(); root.add_child(src)
		var ssk: Skeleton3D = src.get_node("Skeleton3D"); var sap: AnimationPlayer = src.get_node("AnimationPlayer")
		var an := sap.get_animation("mixamo_com")
		sap.play("mixamo_com"); sap.pause(); tap.play("m/" + clip); tap.pause()
		var errs := []; var maxe := 0.0; var min_ankle := 99.0; var src_min_ankle := 99.0
		var s_rest_ankle := ssk.get_bone_global_rest(ssk.find_bone("mixamorig_LeftFoot")).origin.y
		var n := 40
		for i in n + 1:
			var t := an.length * i / n
			sap.seek(t, true); tap.seek(t, true)
			for s in SEG:
				var a := ssk.get_bone_global_pose(ssk.find_bone("mixamorig_" + s[1])).origin - ssk.get_bone_global_pose(ssk.find_bone("mixamorig_" + s[0])).origin
				var b := tsk.get_bone_global_pose(tsk.find_bone(s[3])).origin - tsk.get_bone_global_pose(tsk.find_bone(s[2])).origin
				var ang := rad_to_deg(a.angle_to(b)); errs.append(ang); maxe = max(maxe, ang)
			min_ankle = min(min_ankle, min(tsk.get_bone_global_pose(tsk.find_bone("Ankle_L")).origin.y, tsk.get_bone_global_pose(tsk.find_bone("Ankle_R")).origin.y))
			src_min_ankle = min(src_min_ankle, min(ssk.get_bone_global_pose(ssk.find_bone("mixamorig_LeftFoot")).origin.y, ssk.get_bone_global_pose(ssk.find_bone("mixamorig_RightFoot")).origin.y))
		var mean := 0.0
		for e in errs: mean += e
		out[clip] = {"mean_deg": mean / errs.size(), "max_deg": maxe,
			"synty_ankle_min_over_rest_m": min_ankle - t_rest_ankle,
			"source_ankle_min_over_rest_scaled_m": (src_min_ankle - s_rest_ankle) * 0.8404}
		src.queue_free(); await process_frame
	var fa := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE); fa.store_string(JSON.stringify(out, "  "))
	quit()
