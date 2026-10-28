@tool
class_name Vent
extends GameObject
## An extractor fan. While running it pulls smoke out of the room it's in.

signal toggled(is_on: bool)

@export var start_on := true:
	set(value):
		start_on = value
		is_on = value
		refresh_visual()
## Smoke removed per second from a 1000x700 room. Bigger rooms clear more slowly.
@export var extraction_rate := 0.12
## Rotation speed of the sprite while running, in radians per second. 0 disables spinning.
@export var spin_speed := 3.0

var is_on := false


func _ready() -> void:
	is_on = start_on
	super()


func _process(delta: float) -> void:
	if is_on and not Engine.is_editor_hint():
		sprite.rotation += spin_speed * delta


func current_texture() -> Texture2D:
	var art := ArtTheme.active()
	return art.vent_on if is_on else art.vent_off


func affect_smoke(smoke: float, delta: float) -> float:
	if not is_on:
		return smoke
	return smoke - extraction_rate * delta / room.capacity()


func interaction_prompt() -> String:
	return "Switch vent off" if is_on else "Switch vent on"


func interact(_by: Player) -> void:
	is_on = not is_on
	refresh_visual()
	toggled.emit(is_on)
