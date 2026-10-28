@tool
class_name KeycardStation
extends GameObject
## A machine that hands out or upgrades the player's keycard (E / A next to it). It raises the
## keycard to `gives_level` if the player already carries at least `requires_level`
## (0 = no keycard needed, so the station gives out the first card). Doors and exits with
## `required_keycard` then let the player through. Usually painted into the room: tick Hide Art.

@export_range(0, 9) var requires_level := 0
@export_range(1, 9) var gives_level := 1


func _init() -> void:
	footprint = Vector2(120, 120)
	solid = false


func current_texture() -> Texture2D:
	return ArtTheme.active().keycard


func interaction_prompt() -> String:
	var player := level.player if level else null
	if player == null or player.keycard_level >= gives_level:
		return ""
	if player.keycard_level < requires_level:
		return "Needs keycard level %d" % requires_level
	if requires_level == 0:
		return "Take keycard"
	return "Upgrade keycard to level %d" % gives_level


func interact(by: Player) -> void:
	if by.keycard_level >= gives_level:
		return
	if by.keycard_level < requires_level:
		Haptics.pulse(0.6, 0.1, 0.18, 2)
		return
	by.set_keycard_level(gives_level)
	Haptics.pulse(0.2, 0.6, 0.1, 2)
