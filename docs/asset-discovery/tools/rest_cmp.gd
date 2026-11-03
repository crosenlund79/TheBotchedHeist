extends SceneTree
func _initialize() -> void:
	var base: Skeleton3D = null; var D := "res://Assets/Synty/PolygonHeist/Prefab/Characters/"
	for f in DirAccess.get_files_at(D):
		var sk: Skeleton3D = load(D + f).instantiate().get_node("Skeleton3D")
		if base == null: base = sk
		var maxd := 0.0; var names_ok := sk.get_bone_count() == base.get_bone_count()
		for i in sk.get_bone_count():
			names_ok = names_ok and sk.get_bone_name(i) == base.get_bone_name(i)
			maxd = max(maxd, (sk.get_bone_rest(i).origin - base.get_bone_rest(i).origin).length() + (sk.get_bone_rest(i).basis.get_rotation_quaternion().angle_to(base.get_bone_rest(i).basis.get_rotation_quaternion())))
		var vis := ""
		for c in sk.get_children():
			if c is MeshInstance3D and c.visible: vis += str(c.name) + " "
		print("REST ", f, " bones=", sk.get_bone_count(), " same_names=", names_ok, " max_rest_diff=", maxd, " visible=", vis)
	quit()
