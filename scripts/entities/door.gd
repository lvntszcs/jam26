class_name Door
extends GridEntity
## A door the player can open and close. Closed doors block both the player and the smoke.

signal toggled(is_open: bool)

@export var start_open := false

var is_open := false
## True when the door sits in a vertical wall (walls above and below it).
var vertical := false


func place(target_level: Level, at_cell: Vector2i) -> void:
	super(target_level, at_cell)
	is_open = start_open
	vertical = not (level.data.is_wall(cell + Vector2i.LEFT) and level.data.is_wall(cell + Vector2i.RIGHT))


func blocks_movement() -> bool:
	return not is_open


func blocks_smoke() -> bool:
	return not is_open


func interaction_prompt() -> String:
	return "Close door" if is_open else "Open door"


func interact(_by: Player) -> void:
	if is_open and level.is_occupied_by_player(cell):
		return
	is_open = not is_open
	refresh_visual()
	toggled.emit(is_open)


func refresh_visual() -> void:
	Art.apply(sprite, Art.theme.door_open if is_open else Art.theme.door_closed)
	sprite.rotation = PI / 2.0 if vertical else 0.0
