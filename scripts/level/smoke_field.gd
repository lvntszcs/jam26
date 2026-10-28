class_name SmokeField
extends Node2D
## Toxic smoke, simulated as a density value (0..1) per floor cell that diffuses into
## neighbouring cells. Walls and closed doors block it; entities can add or remove smoke
## through GridEntity.modify_smoke().

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Seconds between simulation steps.
@export var step_interval := 0.15
## How fast smoke spreads per step (0 = never, 1 = as fast as stays stable).
@export_range(0.0, 1.0) var spread := 0.6
## How quickly the drawn smoke catches up with the simulation, for smooth visuals.
@export var display_smoothing := 6.0
## Puffs are drawn this much larger than a tile (as a fraction) so they blend together.
@export var puff_overlap := 0.35

var level: Level
var _density := {}
var _shown := {}
var _timer := 0.0


func setup(target: Level) -> void:
	level = target
	for cell: Vector2i in level.data.cells:
		if level.data.is_floor(cell):
			_density[cell] = 0.0
			_shown[cell] = 0.0


func density_at(cell: Vector2i) -> float:
	return _density.get(cell, 0.0)


func _process(delta: float) -> void:
	if level == null:
		return
	_timer += delta
	while _timer >= step_interval:
		_timer -= step_interval
		_step()
	var weight := minf(1.0, delta * display_smoothing)
	for cell: Vector2i in _shown:
		_shown[cell] = lerpf(_shown[cell], _density[cell], weight)
	queue_redraw()


func _step() -> void:
	var next := {}
	for cell: Vector2i in _density:
		if not level.is_smoke_passable(cell):
			next[cell] = 0.0
			continue
		var current: float = _density[cell]
		var flow := 0.0
		for dir in DIRECTIONS:
			var neighbour := cell + dir
			if _density.has(neighbour) and level.is_smoke_passable(neighbour):
				flow += _density[neighbour] - current
		next[cell] = clampf(current + spread * flow * 0.25, 0.0, 1.0)
	for cell: Vector2i in next:
		var entity := level.entity_at(cell)
		if entity:
			next[cell] = clampf(entity.modify_smoke(next[cell]), 0.0, 1.0)
	_density = next


func _draw() -> void:
	var tile := float(Art.theme.tile_size)
	var pad := tile * puff_overlap
	var texture := Art.theme.smoke
	for cell: Vector2i in _shown:
		var amount: float = _shown[cell]
		if amount < 0.02:
			continue
		var rect := Rect2(Vector2(cell) * tile - Vector2.ONE * pad, Vector2.ONE * (tile + pad * 2.0))
		var color := Art.theme.smoke_tint
		color.a *= amount * Art.theme.smoke_max_alpha
		if texture:
			draw_texture_rect(texture, rect, false, color)
		else:
			draw_rect(rect, color)
