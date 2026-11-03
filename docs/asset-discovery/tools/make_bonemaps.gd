extends SceneTree
const SYNTY := {"Root":"Root","Hips":"Hips","Spine":"Spine_01","Chest":"Spine_02","UpperChest":"Spine_03","Neck":"Neck","Head":"Head","Jaw":"Jaw"}
const MIX := {"Hips":"Hips","Spine":"Spine","Chest":"Spine1","UpperChest":"Spine2","Neck":"Neck","Head":"Head"}
func _initialize() -> void:
	var prof := SkeletonProfileHumanoid.new()
	var s := BoneMap.new(); s.profile = prof
	var m := BoneMap.new(); m.profile = SkeletonProfileHumanoid.new()
	for k in SYNTY: s.set_skeleton_bone_name(k, SYNTY[k])
	for k in MIX: m.set_skeleton_bone_name(k, "mixamorig_" + MIX[k])
	for side in [["Left","L"],["Right","R"]]:
		var L: String = side[0]; var c: String = side[1]
		var sy := {"Shoulder":"Clavicle_","UpperArm":"Shoulder_","LowerArm":"Elbow_","Hand":"Hand_","UpperLeg":"UpperLeg_","LowerLeg":"LowerLeg_","Foot":"Ankle_","Toes":"Ball_",
			"ThumbMetacarpal":"Thumb_01_","ThumbProximal":"Thumb_02_","ThumbDistal":"Thumb_03_","IndexProximal":"IndexFinger_01_","IndexIntermediate":"IndexFinger_02_","IndexDistal":"IndexFinger_03_",
			"MiddleProximal":"Finger_01_","MiddleIntermediate":"Finger_02_","MiddleDistal":"Finger_03_"}
		for k in sy: s.set_skeleton_bone_name(L + k, sy[k] + c)
		var mx := {"Shoulder":"Shoulder","UpperArm":"Arm","LowerArm":"ForeArm","Hand":"Hand","UpperLeg":"UpLeg","LowerLeg":"Leg","Foot":"Foot","Toes":"ToeBase",
			"ThumbMetacarpal":"HandThumb1","ThumbProximal":"HandThumb2","ThumbDistal":"HandThumb3","IndexProximal":"HandIndex1","IndexIntermediate":"HandIndex2","IndexDistal":"HandIndex3",
			"MiddleProximal":"HandMiddle1","MiddleIntermediate":"HandMiddle2","MiddleDistal":"HandMiddle3","RingProximal":"HandRing1","RingIntermediate":"HandRing2","RingDistal":"HandRing3",
			"LittleProximal":"HandPinky1","LittleIntermediate":"HandPinky2","LittleDistal":"HandPinky3"}
		for k in mx: m.set_skeleton_bone_name(L + k, "mixamorig_" + L + mx[k])
	ResourceSaver.save(s, "res://Assets/AnimOfficial/synty_bonemap.tres")
	ResourceSaver.save(m, "res://Assets/AnimOfficial/mixamo_bonemap.tres")
	print("BONEMAPS OK")
	quit()
