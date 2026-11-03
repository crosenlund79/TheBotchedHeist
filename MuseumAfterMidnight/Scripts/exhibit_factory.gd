class_name ExhibitFactory
extends RefCounted
## Builds museum exhibits from the converted Synty Unity prefabs
## (Assets/Imported/imported_manifest.json, written by Tools/convert_synty_unity.py)
## and from the Godot-native Synty Heist prefabs.

const MANIFEST := "res://Assets/Imported/imported_manifest.json"
const ANIMS := "res://Assets/Animations/heist_female_inplace.res"
const CASE := "res://Assets/Synty/PolygonHeist/Prefab/Props/SM_Prop_DisplayCase_02.tscn"

static var _manifest := {}
static var _mats := {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _manifest

static func _norm(s: String) -> String:
	return s.to_lower().replace(" ", "").replace(".", "_").replace(":", "_")

static func _mat(path: String) -> Material:
	if not _mats.has(path):
		_mats[path] = load(path)
	return _mats[path]

## Instantiates one converted Unity prefab with its materials. Characters play the baked idle.
static func build(prefab: String) -> Node3D:
	var e: Dictionary = manifest()[prefab]
	var root := Node3D.new()
	root.name = prefab
	var scenes := {}
	var order: Array = [e.fbx]
	for p in e.parts:
		if not order.has(p.fbx):
			order.append(p.fbx)
	var main_skel: Skeleton3D = null
	for fbx in order:
		var sc: Node3D = (load(fbx) as PackedScene).instantiate()
		root.add_child(sc)
		scenes[fbx] = sc
		var meshes: Array = sc.find_children("*", "MeshInstance3D", true, false)
		var wanted: Array = e.parts.filter(func(p): return p.fbx == fbx)
		var matched := {}
		for mi in meshes:
			var n := _norm(str(mi.name))
			for p in wanted:
				if _norm(str(p.node)) == n or (str(p.mesh) != "" and _norm(str(p.mesh)) == n):
					matched[mi] = p
					break
		if matched.is_empty() and meshes.size() == 1 and wanted.size() >= 1:
			matched[meshes[0]] = wanted[0]
		for mi in meshes:
			if not matched.has(mi):
				mi.visible = false
				continue
			var mats: Array = matched[mi].materials
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				if mats.size() > 0:
					mi.set_surface_override_material(s, _mat(mats[min(s, mats.size() - 1)]))
		var sk: Array = sc.find_children("*", "Skeleton3D", true, false)
		if fbx == e.fbx and sk.size() > 0:
			main_skel = sk[0]
		elif main_skel and sk.size() > 0:
			# Skinned attachment from its own FBX (Horror Mansion hair, hats, capes):
			# move its meshes onto the character's skeleton so they animate together.
			for mi in sc.find_children("*", "MeshInstance3D", true, false):
				if not mi.visible:
					continue
				var xf: Transform3D = sc.global_transform.affine_inverse() * mi.global_transform
				mi.get_parent().remove_child(mi)
				if mi.skin:
					main_skel.add_child(mi)
					mi.transform = Transform3D.IDENTITY
					mi.skeleton = NodePath("..")
				else:
					# Rigid attachment (hair, hat): follow the head bone from its rest offset.
					var head := main_skel.find_bone("Head")
					var att := BoneAttachment3D.new()
					att.bone_name = "Head"
					main_skel.add_child(att)
					att.add_child(mi)
					mi.transform = main_skel.get_bone_global_rest(head).affine_inverse() * xf if head >= 0 else xf
	if e.character and main_skel:
		var ap: AnimationPlayer = scenes[e.fbx].find_children("*", "AnimationPlayer", true, false)[0] if not scenes[e.fbx].find_children("*", "AnimationPlayer", true, false).is_empty() else null
		if ap == null:
			ap = AnimationPlayer.new()
			scenes[e.fbx].add_child(ap)
		ap.add_animation_library("m", load(ANIMS))
		ap.play("m/idle")
		ap.seek(randf() * 10.0, true)
		ap.speed_scale = randf_range(0.75, 1.0)
	return root

## Bounds of the visible meshes, in `node`'s parent space.
static func bounds(node: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	var inv := node.get_parent_node_3d().global_transform.affine_inverse() if node.get_parent_node_3d() else Transform3D()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var ab: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		if first:
			acc = ab; first = false
		else:
			acc = acc.merge(ab)
	return acc

## Scales `node` so its largest dimension is `size` (0 keeps it), then rests it centred on `base`.
static func fit(node: Node3D, base: Vector3, size: float) -> AABB:
	var ab := bounds(node)
	if size > 0.0:
		var m := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
		if m > 0.001:
			node.scale *= size / m
	ab = bounds(node)
	var c := ab.get_center()
	node.position += Vector3(base.x - c.x, base.y - ab.position.y, base.z - c.z)
	return bounds(node)

static func title_of(prefab: String) -> String:
	var t := prefab.trim_prefix("SM_").trim_prefix("Gen_")
	for pre in ["Prop_", "Wep_", "Veh_", "Env_", "Bld_", "Chr_", "Sign_"]:
		t = t.trim_prefix(pre)
	var parts := Array(t.split("_")).filter(func(s): return not s.is_valid_int() and s != "")
	return " ".join(parts).capitalize()
