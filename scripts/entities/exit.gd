@tool
class_name Exit
extends GameObject
## The escape hatch. The level is complete when the player reaches its centre.

## How close (in pixels) the player must get to the centre.
@export var reach_radius := 40.0
## Keycard level needed to leave through this exit; 0 = anyone can.
@export_range(0, 9) var required_keycard := 0


func _init() -> void:
	solid = false


func current_texture() -> Texture2D:
	return ArtTheme.active().exit


func can_leave(by: Player) -> bool:
	return by.keycard_level >= required_keycard


## Only says something while it's locked, so the player learns what they need.
func interaction_prompt() -> String:
	var player := level.player if level else null
	if player == null or can_leave(player):
		return ""
	return "Exit locked: needs keycard level %d" % required_keycard


func interact(_by: Player) -> void:
	Haptics.pulse(0.6, 0.1, 0.18, 2)
