class_name Interactable
extends Node3D
## Something the player can use with the Interact key: plaques, terminals, pickups, containers,
## display mechanisms and cursed relics. The player shows `prompt` when facing it within `radius`.

var prompt := "Inspect"
var radius := 1.8
var action: Callable          # func(player, interactable)
var enabled := true
var once_per_round := false
var used := false
var kind := ""                # "plaque", "pickup", "relic", "terminal", ...
var cooldown := 0.0
var visual: Node3D            # optional model hidden while used (pickups)

func _ready() -> void:
	add_to_group("interactable")

func _process(delta: float) -> void:
	if cooldown > 0.0:
		cooldown -= delta

func can_interact() -> bool:
	return enabled and not used and cooldown <= 0.0 and is_visible_in_tree()

func get_prompt() -> String:
	return "[%s]  %s" % [GameSettings.binding_text("interact").get_slice(" / ", 0), prompt]

func interact(p: Node) -> void:
	if not can_interact():
		return
	cooldown = 0.6
	if once_per_round:
		used = true
		if visual:
			visual.visible = false
	if action.is_valid():
		action.call(p, self)

## Restores pickups and relics for a new round.
func reset() -> void:
	used = false
	if visual:
		visual.visible = true

static func make(parent: Node, pos: Vector3, text: String, act: Callable, r := 1.8, k := "") -> Interactable:
	var i := Interactable.new()
	i.prompt = text
	i.action = act
	i.radius = r
	i.kind = k
	parent.add_child(i)
	i.global_position = pos
	return i
