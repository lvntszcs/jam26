@tool
class_name Exit
extends GameObject
## The escape hatch. The level is complete when the player reaches its centre.

## How close (in pixels) the player must get to the centre.
@export var reach_radius := 40.0


func _init() -> void:
	solid = false


func current_texture() -> Texture2D:
	return ArtTheme.active().exit
