@tool
class_name Keycard
extends GameObject
## A keycard lying in a room. Picking it up raises the player's keycard to `grants_level`
## (never lowers it). Doors with `required_keycard` open once the player's card is at least
## that level, and the card can be upgraded later through Player.upgrade_keycard().

@export_range(1, 9) var grants_level := 1


func _init() -> void:
	footprint = Vector2(70, 70)
	solid = false


func current_texture() -> Texture2D:
	return ArtTheme.active().keycard


func interaction_prompt() -> String:
	return "Pick up keycard"


func interact(by: Player) -> void:
	by.set_keycard_level(maxi(by.keycard_level, grants_level))
	Haptics.pulse(0.2, 0.6, 0.1, 2)
	level.objects.erase(self)
	queue_free()
