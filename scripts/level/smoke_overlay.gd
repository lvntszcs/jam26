class_name SmokeOverlay
extends Node2D
## Draws a room's smoke as slowly drifting puffs (one Sprite2D each). Their opacity follows the
## room's smoke level. Created by Room.build(), so it isn't saved in any scene.

## Distance between puff centres.
@export var spacing := 120.0
## Puff size as a multiple of `spacing`. Above 1, puffs overlap and blend.
@export var puff_scale := 2.2
## How far puffs wander from their resting spot, in pixels.
@export var drift := 24.0
## How quickly the drawn smoke catches up with the simulation.
@export var smoothing := 2.5

var room: Room
var _shown := 0.0
var _time := 0.0
var _puffs: Array[Dictionary] = []


func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shown = room.smoke
	var art := ArtTheme.active()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room.get_path())
	var inset := spacing * 0.5
	var y := inset
	while y < room.size.y:
		var x := inset
		while x < room.size.x:
			var sprite := Sprite2D.new()
			sprite.texture = art.smoke
			if art.smoke:
				sprite.scale = Vector2.ONE * spacing * puff_scale / art.smoke.get_size()
			sprite.rotation = rng.randf() * TAU
			add_child(sprite)
			_puffs.append({
				"sprite": sprite,
				"home": Vector2(x, y) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * spacing,
				"phase": rng.randf() * TAU,
				"speed": rng.randf_range(0.2, 0.5),
				"weight": rng.randf_range(0.6, 1.0),
			})
			x += spacing
		y += spacing
	_update_puffs()


func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, room.smoke, minf(1.0, delta * smoothing))
	_update_puffs()


func _update_puffs() -> void:
	visible = _shown >= 0.005
	if not visible:
		return
	var art := ArtTheme.active()
	for puff in _puffs:
		var t: float = _time * puff.speed + puff.phase
		var sprite: Sprite2D = puff.sprite
		sprite.position = puff.home + Vector2(sin(t), cos(t * 0.8)) * drift
		var color := art.smoke_tint
		color.a *= _shown * art.smoke_max_alpha * puff.weight
		sprite.modulate = color
