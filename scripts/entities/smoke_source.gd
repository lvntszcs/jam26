@tool
class_name SmokeSource
extends GameObject
## A ruptured canister that keeps pumping toxic smoke into its room.

## Smoke added per second to a 1000x700 room. Bigger rooms fill more slowly.
@export var emission_rate := 0.08
## Pulse animation of the sprite. 0 disables it.
@export var pulse_amount := 0.06
@export var pulse_speed := 3.0

var _time := 0.0
var _base_scale := Vector2.ONE


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or pulse_amount == 0.0:
		return
	_time += delta
	sprite.scale = _base_scale * (1.0 + sin(_time * pulse_speed) * pulse_amount)


func current_texture() -> Texture2D:
	return ArtTheme.active().smoke_source


func affect_smoke(smoke: float, delta: float) -> float:
	return smoke + emission_rate * delta / room.capacity()


func refresh_visual() -> void:
	super()
	if is_node_ready():
		_base_scale = sprite.scale
