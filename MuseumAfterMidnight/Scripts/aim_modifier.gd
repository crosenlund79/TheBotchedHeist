class_name AimModifier
extends SkeletonModifier3D
## Upper-body weapon rig, applied on top of the locomotion clip each frame:
##  1. the "Firing Rifle" stance (from the baked Mixamo library) on spine, neck and arms;
##  2. spine yaw twist so the weapon (measured from the posed hands) points along aim_dir;
##     this lets the hips face the real movement direction with no body offset;
##  3. upper-chest pitch for aim pitch plus recoil kick;
##  4. a decaying hit-reaction jolt;
##  5. hands_posed signal with both hands in skeleton space, so the weapon and the support-hand
##     IK target are placed inside the same skeleton update (modifier poses are not visible outside it).

signal hands_posed(right: Transform3D, left: Transform3D)

const BONES := ["Spine_02", "Spine_03", "Neck", "Clavicle_L", "Shoulder_L", "Elbow_L", "Hand_L",
	"Clavicle_R", "Shoulder_R", "Elbow_R", "Hand_R"]

var pose_anim: Animation
var pose_time := 0.25
var aim_dir := Vector3.FORWARD          # desired weapon direction, world space
var recoil := 0.0                       # radians of extra upward kick (decays in the owner)
var hit := Vector3.ZERO                 # axis * angle jolt in skeleton space (decays in the owner)
var max_twist := 1.9
var hand_r := -1
var hand_l := -1
var _tracks := {}
var _spine1 := -1
var _spine2 := -1
var _spine3 := -1

func setup(anim: Animation) -> void:
	pose_anim = anim
	_tracks.clear()
	var sk := get_skeleton()
	for b in BONES:
		var t := anim.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		var bi := sk.find_bone(b)
		if t >= 0 and bi >= 0:
			_tracks[bi] = t
	_spine1 = sk.find_bone("Spine_01")
	_spine2 = sk.find_bone("Spine_02")
	_spine3 = sk.find_bone("Spine_03")
	hand_r = sk.find_bone("Hand_R")
	hand_l = sk.find_bone("Hand_L")

## Rotates a bone by `q` expressed in skeleton space, keeping its children attached.
func _rotate_global(sk: Skeleton3D, bone: int, q: Quaternion) -> void:
	var g := sk.get_bone_global_pose(bone)
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var nb := Basis(q) * g.basis.orthonormalized()
	sk.set_bone_pose_rotation(bone, (pg.inverse() * nb).get_rotation_quaternion())

func _weapon_dir(sk: Skeleton3D) -> Vector3:
	return sk.get_bone_global_pose(hand_l).origin - sk.get_bone_global_pose(hand_r).origin

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or pose_anim == null or hand_r < 0:
		return
	for bi in _tracks:
		sk.set_bone_pose_rotation(bi, pose_anim.rotation_track_interpolate(_tracks[bi], pose_time))
	var target := (sk.global_basis.orthonormalized().inverse() * aim_dir).normalized()
	# Yaw: split between the lower and middle spine.
	var d := _weapon_dir(sk)
	var err := wrapf(atan2(target.x, target.z) - atan2(d.x, d.z), -PI, PI)
	err = clampf(err, -max_twist, max_twist)
	if _spine1 >= 0: _rotate_global(sk, _spine1, Quaternion(Vector3.UP, err * 0.5))
	if _spine2 >= 0: _rotate_global(sk, _spine2, Quaternion(Vector3.UP, err * 0.5))
	# Pitch on the upper chest (plus recoil kick).
	d = _weapon_dir(sk)
	var flat := Vector3(d.x, 0, d.z)
	if flat.length() > 0.01 and _spine3 >= 0:
		var tp := atan2(target.y, Vector2(target.x, target.z).length())
		var cp := atan2(d.y, flat.length())
		var axis := flat.normalized().cross(Vector3.UP).normalized()
		_rotate_global(sk, _spine3, Quaternion(axis, clampf(tp - cp + recoil, -1.1, 1.1)))
	if hit.length() > 0.001 and _spine2 >= 0:
		_rotate_global(sk, _spine2, Quaternion(hit.normalized(), hit.length()))
	hands_posed.emit(sk.get_bone_global_pose(hand_r), sk.get_bone_global_pose(hand_l))
