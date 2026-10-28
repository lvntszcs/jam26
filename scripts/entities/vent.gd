class_name Vent
extends GridEntity
## An extractor fan. While running it removes all smoke from its cell, which slowly
## clears the room around it.

signal toggled(is_on: bool)

@export var start_on := true
## Rotation speed of the sprite while running, in radians per second. 0 disables spinning.
@export var spin_speed := 4.0

var is_on := false


func place(target_level: Level, at_cell: Vector2i) -> void:
	super(target_level, at_cell)
	is_on = start_on


func _process(delta: float) -> void:
	if is_on:
		sprite.rotation += spin_speed * delta


func modify_smoke(density: float) -> float:
	return 0.0 if is_on else density


func interaction_prompt() -> String:
	return "Switch vent off" if is_on else "Switch vent on"


func interact(_by: Player) -> void:
	is_on = not is_on
	refresh_visual()
	toggled.emit(is_on)


func refresh_visual() -> void:
	Art.apply(sprite, Art.theme.vent_on if is_on else Art.theme.vent_off)
