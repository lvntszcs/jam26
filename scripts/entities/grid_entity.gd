class_name GridEntity
extends Node2D
## Base class for anything that occupies one grid cell (doors, vents, exits, ...).
## Subclasses override the virtual methods below to define their behaviour.
## Every entity scene needs a Sprite2D child named "Sprite".

var level: Level
var cell := Vector2i.ZERO

@onready var sprite: Sprite2D = $Sprite


## Called by the Level before the entity is added to the tree.
func place(target_level: Level, at_cell: Vector2i) -> void:
	level = target_level
	cell = at_cell
	position = level.cell_to_local(cell)


func _ready() -> void:
	refresh_visual()


func blocks_movement() -> bool:
	return true


func blocks_smoke() -> bool:
	return false


## Gets this cell's smoke density after each simulation step and returns the new value.
func modify_smoke(density: float) -> float:
	return density


## Text shown to the player when facing this entity. Empty means it can't be interacted with.
func interaction_prompt() -> String:
	return ""


func interact(_by: Player) -> void:
	pass


func on_player_entered(_player: Player) -> void:
	pass


## Updates the sprite from the ArtTheme to match the current state.
func refresh_visual() -> void:
	pass
