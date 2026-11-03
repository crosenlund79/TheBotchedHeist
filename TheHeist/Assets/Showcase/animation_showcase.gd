extends Node3D
## Animation showcase: plays the retargeted Mixamo clips on the Synty Heist characters.
## Inspection only: no gameplay. The clips come from tools/bake_animations.gd.

const CHARACTER_DIR := "res://Assets/Synty/PolygonHeist/Prefab/Characters/"
const CHARACTERS := [
	["SM_Chr_Female_Shirt_01", "Female · Shirt"],
	["SM_Chr_Female_SuitVest_01", "Female · Suit"],
	["SM_Chr_Female_Overall_01", "Female · Overalls"],
	["SM_Chr_Female_FBI_01", "Female · FBI"],
	["SM_Chr_Male_Shirt_01", "Male · Shirt"],
	["SM_Chr_Male_SuitVest_01", "Male · Suit"],
	["SM_Chr_Male_Overall_01", "Male · Overalls"],
	["SM_Chr_Male_FBI_01", "Male · FBI"],
	["SM_Chr_Male_SWAT_01", "Male · SWAT"],
]
const LIB_INPLACE := "res://Assets/Showcase/Animations/heist_female_inplace.res"
const LIB_ROOTMOTION := "res://Assets/Showcase/Animations/heist_female_rootmotion.res"
const RIFLE := "res://Assets/Synty/PolygonHeist/Prefab/Weapons/SM_Wep_RifleSwat_01.tscn"
const BOX := "res://Assets/Synty/PolygonHeist/Prefab/Props/SM_Prop_Box_01.tscn"
const IDLE := "idle"
const BLEND := 0.2
const STAGE_RADIUS := 5.0   # root-motion playback returns the character to the centre beyond this

@onready var spawn: Node3D = $CharacterSpawn
@onready var rig: Node3D = $CameraRig

var lib_inplace: AnimationLibrary
var lib_rootmotion: AnimationLibrary
var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var character_index := 0
var current_clip := IDLE
var root_motion := false
var speed := 1.0
var paused := false
var rifle: Node3D
var box: Node3D

# UI
var ui_now: Label
var ui_now_detail: Label
var ui_pause: Button
var ui_root_motion: CheckButton
var ui_root_note: Label
var ui_speed_label: Label
var ui_progress: ProgressBar
var clip_buttons := {}

func _ready() -> void:
	lib_inplace = load(LIB_INPLACE)
	lib_rootmotion = load(LIB_ROOTMOTION)
	rifle = load(RIFLE).instantiate(); add_child(rifle); rifle.visible = false
	box = load(BOX).instantiate(); add_child(box); box.visible = false
	box.scale = Vector3.ONE * 0.75
	_build_ui()
	_spawn_character(0)
	play_clip(IDLE)

# ------------------------------------------------------------------ characters

func _spawn_character(index: int) -> void:
	var keep_time := 0.0
	if player and player.current_animation != "":
		keep_time = player.current_animation_position
	var old_xf := Transform3D()
	if character:
		old_xf = character.global_transform
		character.queue_free()
	character_index = index
	character = load(CHARACTER_DIR + CHARACTERS[index][0] + ".tscn").instantiate()
	spawn.add_child(character)
	character.global_transform = old_xf
	skeleton = character.get_node("Skeleton3D")
	player = character.get_node("AnimationPlayer")
	player.add_animation_library("ip", lib_inplace)
	player.add_animation_library("rm", lib_rootmotion)
	# Root motion lives on the Synty Root bone. The mixer strips it from the pose;
	# _process applies it to the character when root-motion playback is on.
	player.root_motion_track = NodePath("Skeleton3D:Root")
	player.animation_finished.connect(_on_animation_finished)
	if current_clip != "":
		_start(current_clip, 0.0)
		player.seek(keep_time, true)
		if paused:
			player.pause()

func _on_character_selected(index: int) -> void:
	_spawn_character(index)

# ------------------------------------------------------------------ playback

func _has_root_variant(clip: String) -> bool:
	return lib_rootmotion.has_animation(clip) and bool(lib_rootmotion.get_animation(clip).get_meta("has_root_motion", false))

func _anim_name(clip: String) -> String:
	return ("rm/" if root_motion and _has_root_variant(clip) else "ip/") + clip

func play_clip(clip: String) -> void:
	paused = false
	_start(clip, BLEND)
	_refresh_ui()

func _start(clip: String, blend: float) -> void:
	current_clip = clip
	player.speed_scale = speed
	player.play(_anim_name(clip), blend)
	_update_props()

func replay() -> void:
	paused = false
	player.stop()
	player.play(_anim_name(current_clip), 0.0)
	player.seek(0.0, true)
	_refresh_ui()

func toggle_pause() -> void:
	paused = not paused
	if paused:
		player.pause()
	else:
		player.play()
	_refresh_ui()

func set_speed(value: float) -> void:
	speed = value
	player.speed_scale = value
	ui_speed_label.text = "Speed  %.2f×" % value

func set_root_motion(enabled: bool) -> void:
	root_motion = enabled
	if not enabled:
		reset_position()
	if _has_root_variant(current_clip):
		var t := player.current_animation_position
		player.play(_anim_name(current_clip), 0.0)
		player.seek(t, true)
		if paused:
			player.pause()
	_refresh_ui()

func reset_position() -> void:
	if character:
		character.global_transform = Transform3D()
		rig.target_point = _frame_point()
		rig.snap()

func _on_animation_finished(anim_name: StringName) -> void:
	var clip := String(anim_name).get_slice("/", 1)
	var a := lib_inplace.get_animation(clip) if lib_inplace.has_animation(clip) else null
	if a and a.loop_mode == Animation.LOOP_NONE and clip != IDLE:
		current_clip = IDLE
		player.play(_anim_name(IDLE), 0.35)
		_update_props()
		_refresh_ui()

func _process(delta: float) -> void:
	if character == null:
		return
	if root_motion and not paused:
		var body_q := character.global_basis.get_rotation_quaternion()
		var rm_rot := player.get_root_motion_rotation()
		var rm_pos := player.get_root_motion_position()
		var move := (player.get_root_motion_rotation_accumulator().inverse() * body_q) * rm_pos
		character.global_basis = Basis(body_q * rm_rot)
		character.global_position += move
		if Vector2(character.global_position.x, character.global_position.z).length() > STAGE_RADIUS:
			reset_position()
	_place_props()
	rig.target_point = _frame_point()
	if ui_progress and player.current_animation != "":
		ui_progress.max_value = maxf(player.current_animation_length, 0.01)
		ui_progress.value = player.current_animation_position

func _frame_point() -> Vector3:
	var hips := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	return Vector3(hips.x, clampf(hips.y * 0.75 + 0.35, 0.55, 1.1), hips.z)

# ------------------------------------------------------------------ props

func _update_props() -> void:
	rifle.visible = current_clip == "firing_rifle"
	box.visible = current_clip == "carrying"

func _place_props() -> void:
	if not (rifle.visible or box.visible):
		return
	var rh := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Hand_R")).origin
	var lh := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Hand_L")).origin
	if rifle.visible:
		var fwd := (lh - rh).normalized()
		rifle.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP, true), rh + fwd * 0.04 + Vector3(0, -0.03, 0))
	if box.visible:
		var facing := character.global_basis.z
		box.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP, true).scaled(Vector3.ONE * 0.75), (lh + rh) * 0.5 + facing * 0.05 + Vector3(0, -0.13, 0))

# ------------------------------------------------------------------ UI

func _refresh_ui() -> void:
	var a := lib_inplace.get_animation(current_clip)
	var name := str(a.get_meta("display_name", current_clip))
	ui_now.text = name + ("  (paused)" if paused else "")
	var bits := ["%.2f s" % a.length, "loops" if a.loop_mode != Animation.LOOP_NONE else "plays once, then idle"]
	if _has_root_variant(current_clip):
		bits.append("root motion" if root_motion else "in place")
	bits.append(str(a.get_meta("source_file", "")))
	ui_now_detail.text = "  ·  ".join(bits)
	ui_pause.text = "Resume" if paused else "Pause"
	ui_root_motion.set_pressed_no_signal(root_motion)
	var has_rm := _has_root_variant(current_clip)
	ui_root_note.text = "This clip has a root-motion variant." if has_rm else "No root-motion variant for this clip: it plays in place."
	for c in clip_buttons:
		(clip_buttons[c] as Button).button_pressed = c == current_clip

func _style(color: Color, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 12; s.content_margin_bottom = 12
	return s

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.86, 0.68, 0.30))
	return l

func _build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var theme := Theme.new()
	theme.default_font_size = 15
	var btn := _style(Color(1, 1, 1, 0.06), 6); btn.content_margin_top = 6; btn.content_margin_bottom = 6
	var btn_h := _style(Color(1, 1, 1, 0.14), 6); btn_h.content_margin_top = 6; btn_h.content_margin_bottom = 6
	var btn_p := _style(Color(0.86, 0.68, 0.30, 0.9), 6); btn_p.content_margin_top = 6; btn_p.content_margin_bottom = 6
	for state in ["normal", "focus"]: theme.set_stylebox(state, "Button", btn)
	theme.set_stylebox("hover", "Button", btn_h)
	theme.set_stylebox("pressed", "Button", btn_p)
	theme.set_stylebox("hover_pressed", "Button", btn_p)
	theme.set_color("font_pressed_color", "Button", Color(0.08, 0.09, 0.11))
	theme.set_color("font_hover_pressed_color", "Button", Color(0.08, 0.09, 0.11))

	var panel := PanelContainer.new()
	panel.theme = theme
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.10, 0.86), 12))
	panel.anchor_top = 0; panel.anchor_bottom = 1
	panel.offset_left = 16; panel.offset_top = 16; panel.offset_bottom = -16; panel.offset_right = 16 + 320
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)

	var title := Label.new(); title.text = "Heist Animation Showcase"
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	var sub := Label.new(); sub.text = "Mixamo clips retargeted onto the Synty Heist rig"
	sub.add_theme_font_size_override("font_size", 12); sub.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	v.add_child(sub)

	v.add_child(_header("Character"))
	var pick := OptionButton.new()
	for c in CHARACTERS: pick.add_item(c[1])
	pick.item_selected.connect(_on_character_selected)
	v.add_child(pick)

	v.add_child(_header("Now playing"))
	ui_now = Label.new(); ui_now.add_theme_font_size_override("font_size", 18); v.add_child(ui_now)
	ui_now_detail = Label.new(); ui_now_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_now_detail.add_theme_font_size_override("font_size", 12); ui_now_detail.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	v.add_child(ui_now_detail)
	ui_progress = ProgressBar.new(); ui_progress.show_percentage = false; ui_progress.custom_minimum_size.y = 6
	v.add_child(ui_progress)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6); v.add_child(row)
	ui_pause = Button.new(); ui_pause.text = "Pause"; ui_pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_pause.pressed.connect(toggle_pause); row.add_child(ui_pause)
	var rep := Button.new(); rep.text = "Replay"; rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep.pressed.connect(replay); row.add_child(rep)
	var rst := Button.new(); rst.text = "Re-centre"; rst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rst.pressed.connect(reset_position); row.add_child(rst)

	ui_speed_label = Label.new(); ui_speed_label.text = "Speed  1.00×"; v.add_child(ui_speed_label)
	var slider := HSlider.new(); slider.min_value = 0.1; slider.max_value = 2.0; slider.step = 0.05; slider.value = 1.0
	slider.value_changed.connect(set_speed); v.add_child(slider)

	ui_root_motion = CheckButton.new(); ui_root_motion.text = "Root motion (else in place)"
	ui_root_motion.toggled.connect(set_root_motion); v.add_child(ui_root_motion)
	ui_root_note = Label.new(); ui_root_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_root_note.add_theme_font_size_override("font_size", 12); ui_root_note.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	v.add_child(ui_root_note)

	# Animation list, grouped by category in the catalogue's order.
	var groups := {}
	for clip in lib_inplace.get_animation_list():
		var a := lib_inplace.get_animation(clip)
		var cat := str(a.get_meta("category", "Other"))
		if not groups.has(cat): groups[cat] = []
		groups[cat].append(clip)
	var order: Array = HeistClipCatalog.CATEGORY_ORDER.duplicate()
	for cat in groups:
		if not order.has(cat): order.append(cat)
	var count := 0
	for cat in order:
		if not groups.has(cat): continue
		v.add_child(_header(cat))
		var grid := GridContainer.new(); grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6)
		v.add_child(grid)
		var clips: Array = groups[cat]
		clips.sort_custom(func(x, y): return str(lib_inplace.get_animation(x).get_meta("display_name", x)) < str(lib_inplace.get_animation(y).get_meta("display_name", y)))
		for clip in clips:
			var a := lib_inplace.get_animation(clip)
			var b := Button.new()
			b.toggle_mode = true
			b.text = str(a.get_meta("display_name", clip)) + ("" if a.loop_mode != Animation.LOOP_NONE else "  ¹")
			b.tooltip_text = "%s · %.2f s · %s%s" % [a.get_meta("source_file", ""), a.length, "loops" if a.loop_mode != Animation.LOOP_NONE else "one-shot", " · root motion available" if _has_root_variant(clip) else ""]
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(play_clip.bind(clip))
			grid.add_child(b)
			clip_buttons[clip] = b
			count += 1
	var foot := Label.new()
	foot.text = "%d clips · ¹ plays once, then returns to idle.\nDrag to orbit · wheel to zoom." % count
	foot.add_theme_font_size_override("font_size", 12); foot.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	v.add_child(foot)
