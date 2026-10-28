class_name SmokeSource
extends GridEntity
## A ruptured canister that keeps its cell full of toxic smoke.

## Smoke density this source holds its cell at.
@export_range(0.0, 1.0) var output := 1.0
## Pulse animation of the sprite. 0 disables it.
@export var pulse_amount := 0.08
@export var pulse_speed := 3.0

var _time := 0.0
var _base_scale := Vector2.ONE


func _process(delta: float) -> void:
	_time += delta
	sprite.scale = _base_scale * (1.0 + sin(_time * pulse_speed) * pulse_amount)


func modify_smoke(_density: float) -> float:
	return output


func refresh_visual() -> void:
	Art.apply(sprite, Art.theme.smoke_source)
	_base_scale = sprite.scale
