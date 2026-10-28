class_name Exit
extends GridEntity
## The escape hatch. Stepping onto it completes the level.


func blocks_movement() -> bool:
	return false


func on_player_entered(_player: Player) -> void:
	level.complete()


func refresh_visual() -> void:
	Art.apply(sprite, Art.theme.exit)
