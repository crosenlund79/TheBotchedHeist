class_name HeistClipCatalog
extends RefCounted
## Display metadata for the retargeted Mixamo clips.
## The bake tool stores these values as metadata on each baked Animation, and the
## showcase reads them back. A clip not listed here is still baked; it goes in
## "Other" and loops if its name looks like locomotion.

const CATEGORY_ORDER := ["Idle", "Locomotion", "Strafing", "Turning", "Stealth", "Interaction", "Combat", "Reactions", "Other"]

# clip id -> [category, display name, loops]
const CLIPS := {
	"idle": ["Idle", "Idle", true],
	"walking": ["Locomotion", "Walk", true],
	"running": ["Locomotion", "Run", true],
	"left_strafe": ["Strafing", "Strafe Left", true],
	"right_strafe": ["Strafing", "Strafe Right", true],
	"left_turn": ["Turning", "Turn Left", false],
	"right_turn": ["Turning", "Turn Right", false],
	"sneak_walk": ["Stealth", "Sneak Walk", true],
	"crouched_walking": ["Stealth", "Crouched Walk", true],
	"crouching": ["Stealth", "Crouch Down", false],
	"carrying": ["Interaction", "Carry (Hold)", true],
	"picking_up_object": ["Interaction", "Pick Up Object", false],
	"opening": ["Interaction", "Open", false],
	"button_pushing": ["Interaction", "Push Button", false],
	"firing_rifle": ["Combat", "Fire Rifle", true],
	"hit_reaction": ["Reactions", "Hit Reaction", false],
}

## "Female_Sneak Walk.fbx" -> "sneak_walk"
static func clip_id_from_file(file_name: String) -> String:
	var base := file_name.get_basename()
	for prefix in ["Female_", "Male_"]:
		if base.begins_with(prefix):
			base = base.substr(prefix.length())
	return base.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

static func info(clip_id: String) -> Dictionary:
	if CLIPS.has(clip_id):
		var c: Array = CLIPS[clip_id]
		return {"category": c[0], "display_name": c[1], "loop": c[2]}
	var looks_cyclic := false
	for word in ["walk", "run", "strafe", "idle", "jog"]:
		if clip_id.contains(word):
			looks_cyclic = true
	return {"category": "Other", "display_name": clip_id.capitalize(), "loop": looks_cyclic}
