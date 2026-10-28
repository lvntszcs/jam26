@tool
class_name Vent
extends GameObject
## An extractor fan. While running it clears every GasZone in its room; switched off, the gas
## comes back.

signal toggled(is_on: bool)

@export var start_on := true:
	set(value):
		start_on = value
		is_on = value
		refresh_visual()
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


func interaction_prompt() -> String:
	return "Switch vent off" if is_on else "Switch vent on"


func interact(_by: Player) -> void:
	is_on = not is_on
	refresh_visual()
	toggled.emit(is_on)
