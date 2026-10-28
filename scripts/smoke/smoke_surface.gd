class_name SmokeSurface
extends Sprite2D
## The visible smoke of one room. It keeps a coarse density grid over the room: smoke is added
## where it comes in (smoke sources, open doors from smokier rooms) and removed where it leaves
## (running vents, open doors to cleaner rooms), then spreads cell to cell. The grid's total
## follows the room's gameplay smoke level, so it only changes where the smoke is drawn,
## not how much there is. Doors only pass smoke once the grid's smoke has spread up to them
## (see Level.doorway_smoke), so smoke never shows up in the next room before reaching the door.
## The Level steps the grid together with the gameplay smoke. The grid is drawn by
## smoke.gdshader with the ArtTheme's smoke frames.
## Created by the Level, so it isn't saved in any scene.

const SHADER := preload("res://scripts/smoke/smoke.gdshader")

var room: Room
var level: Level
var config: SmokeConfig
var _columns := 0
var _rows := 0
var _cells := PackedFloat32Array()
var _image: Image
var _mask: ImageTexture
var _frames: Array[Texture2D] = []
var _frame_time := 0.0
var _shown_frame := -1


func setup(target_level: Level, target_room: Room, target_config: SmokeConfig) -> void:
	level = target_level
	room = target_room
	config = target_config


func _ready() -> void:
	z_index = 3
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_columns = maxi(1, ceili(room.size.x / config.cell_size))
	_rows = maxi(1, ceili(room.size.y / config.cell_size))
	_cells.resize(_columns * _rows)
	_cells.fill(room.smoke)
	_image = Image.create(_columns, _rows, false, Image.FORMAT_L8)
	_mask = ImageTexture.create_from_image(_image)
	texture = _mask
	scale = room.size / Vector2(_columns, _rows)

	var art := ArtTheme.active()
	_frames = art.smoke_animation_frames()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("tint", config.tint)
	shader_material.set_shader_parameter("opacity", config.opacity)
	shader_material.set_shader_parameter("tile_size", config.tile_size)
	shader_material.set_shader_parameter("drift", config.drift)
	shader_material.set_shader_parameter("luminance_as_alpha", config.alpha_source == SmokeConfig.AlphaSource.LUMINANCE)
	shader_material.set_shader_parameter("edge_breakup", config.edge_breakup)
	shader_material.set_shader_parameter("edge_softness", config.edge_softness)
	shader_material.set_shader_parameter("use_edge_mask", art.smoke_edge_mask != null)
	shader_material.set_shader_parameter("edge_mask", art.smoke_edge_mask)
	shader_material.set_shader_parameter("edge_mask_size", config.edge_mask_size)
	material = shader_material
	visible = not _frames.is_empty()
	if _frames.is_empty():
		push_warning("ArtTheme has no smoke_sheet or smoke_frames; smoke is invisible.")
	_upload()


func _process(delta: float) -> void:
	_upload()
	_animate(delta)


## How thick the drawn smoke is at a point in the room (0 to 1).
func density_at(point: Vector2) -> float:
	return _cells[_cell_at(point)]


## Moves the grid's total toward the room's smoke level at the entry or exit points,
## then lets it spread.
func simulate(delta: float) -> void:
	var mean := 0.0
	for value in _cells:
		mean += value
	mean /= _cells.size()
	var change := (room.smoke - mean) * minf(1.0, config.fill_speed * delta)
	if absf(change) > 0.00001:
		var points := _entry_cells() if change > 0.0 else _exit_cells()
		if points.is_empty():
			for i in _cells.size():
				_cells[i] = clampf(_cells[i] + change, 0.0, 1.0)
		else:
			var per_point := change * _cells.size() / points.size()
			for i in points:
				_cells[i] = clampf(_cells[i] + per_point, 0.0, 1.0)
	# Spreading more than one cell's worth per step is unstable, so fast spreading takes substeps.
	var amount := config.spread_speed * delta
	var steps := maxi(1, ceili(amount))
	for step in steps:
		_spread(amount / steps)


func _spread(rate: float) -> void:
	var next := _cells.duplicate()
	for y in _rows:
		for x in _columns:
			var i := y * _columns + x
			var current := _cells[i]
			var flow := 0.0
			var neighbours := 0
			if x > 0:
				flow += _cells[i - 1]
				neighbours += 1
			if x < _columns - 1:
				flow += _cells[i + 1]
				neighbours += 1
			if y > 0:
				flow += _cells[i - _columns]
				neighbours += 1
			if y < _rows - 1:
				flow += _cells[i + _columns]
				neighbours += 1
			next[i] = current + rate * (flow - current * neighbours) * 0.25
	_cells = next


## Cells where smoke comes in: smoke sources, and open doors from smokier rooms.
func _entry_cells() -> PackedInt32Array:
	var points := PackedInt32Array()
	for object in level.objects:
		if object.room == room and object is SmokeSource:
			points.append(_cell_at(object.global_position))
	for door in room.doors:
		if door.is_open and _other_room(door) and _other_room(door).smoke > room.smoke:
			points.append(_cell_at(door.global_position))
	return points


## Cells where smoke leaves: running vents, and open doors to cleaner rooms.
func _exit_cells() -> PackedInt32Array:
	var points := PackedInt32Array()
	for object in level.objects:
		if object.room == room and object is Vent and (object as Vent).is_on:
			points.append(_cell_at(object.global_position))
	for door in room.doors:
		if door.is_open and _other_room(door) and _other_room(door).smoke < room.smoke:
			points.append(_cell_at(door.global_position))
	return points


func _other_room(door: Door) -> Room:
	for other in door.rooms:
		if other != room:
			return other
	return null


func _cell_at(point: Vector2) -> int:
	var local := (point - room.global_position) / room.size
	var x := clampi(int(local.x * _columns), 0, _columns - 1)
	var y := clampi(int(local.y * _rows), 0, _rows - 1)
	return y * _columns + x


func _upload() -> void:
	var bytes := PackedByteArray()
	bytes.resize(_cells.size())
	for i in _cells.size():
		bytes[i] = int(clampf(_cells[i], 0.0, 1.0) * 255.0)
	_image.set_data(_columns, _rows, false, Image.FORMAT_L8, bytes)
	_mask.update(_image)


## Steps through the animation frames, optionally fading each into the next.
func _animate(delta: float) -> void:
	if _frames.is_empty():
		return
	_frame_time += delta * config.frame_rate
	var index := int(_frame_time) % _frames.size()
	if index != _shown_frame:
		_shown_frame = index
		material.set_shader_parameter("frame_a", _frames[index])
		material.set_shader_parameter("frame_b", _frames[(index + 1) % _frames.size()])
	var progress := fmod(_frame_time, 1.0)
	var blend := 0.0
	if config.crossfade > 0.0:
		blend = smoothstep(1.0 - config.crossfade, 1.0, progress)
	material.set_shader_parameter("blend", blend)
