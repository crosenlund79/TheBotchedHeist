class_name AimModifier
extends SkeletonModifier3D
## Overrides the upper body with a pose sampled from the baked "firing_rifle" clip, on top of
## whatever the AnimationPlayer is playing (walk, run, idle). Blend with `influence`.

const BONES := ["Spine_02", "Spine_03", "Neck", "Clavicle_L", "Shoulder_L", "Elbow_L", "Hand_L",
	"Clavicle_R", "Shoulder_R", "Elbow_R", "Hand_R"]

var pose_anim: Animation
var pose_time := 0.25
var _tracks := {}

func setup(anim: Animation) -> void:
	pose_anim = anim
	_tracks.clear()
	var sk := get_skeleton()
	for b in BONES:
		var t := anim.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		var bi := sk.find_bone(b) if sk else -1
		if t >= 0 and bi >= 0:
			_tracks[bi] = t

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or pose_anim == null:
		return
	for bi in _tracks:
		sk.set_bone_pose_rotation(bi, pose_anim.rotation_track_interpolate(_tracks[bi], pose_time))
