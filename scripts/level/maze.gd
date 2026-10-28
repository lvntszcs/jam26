@tool
class_name Maze
extends Node2D
## Interior walls of a room, laid out as text: one string per row, "#" is a wall cell and
## anything else is floor. Add it as a child of a Room at position (0, 0) so the grid starts at
## the room's top-left corner. Keep corridors at least two cells wide so the player fits.
## With `from_painting`, the walls come from the Room's painting instead (for rooms like a vent
## duct, where the painting already shows the walls).

@export var cell_size := 75.0:
	set(value):
		cell_size = value
		queue_redraw()
@export var layout: PackedStringArray:
	set(value):
		layout = value
		queue_redraw()
## Build the walls from the parent Room's painting instead of `layout`: every cell with any
## transparent part in the painting is a wall. The painting shows the walls, so none are drawn.
@export var from_painting := false:
	set(value):
		from_painting = value
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		if from_painting:
			layout = _layout_from_painting()
		_build()


func is_wall(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= layout.size():
		return false
	var row := layout[cell.y]
	return cell.x >= 0 and cell.x < row.length() and row[cell.x] == "#"


## Wall cells merged into as few rectangles as possible (rows first, then stacked runs).
func wall_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var open := {}  # Vector2i(start, length) -> index in rects, for runs continuing downwards
	for y in layout.size():
		var row := layout[y]
		var next_open := {}
		var x := 0
		while x < row.length():
			if row[x] != "#":
				x += 1
				continue
			var start := x
			while x < row.length() and row[x] == "#":
				x += 1
			var run := Vector2i(start, x - start)
			if open.has(run):
				rects[open[run]].size.y += cell_size
				next_open[run] = open[run]
			else:
				rects.append(Rect2(start * cell_size, y * cell_size, run.y * cell_size, cell_size))
				next_open[run] = rects.size() - 1
		open = next_open
	return rects


func _build() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for rect in wall_rects():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		body.add_child(shape)
		# Maze walls block the player's light like room walls.
		var occluder := LightOccluder2D.new()
		occluder.occluder = Lighting.rect_occluder(rect)
		add_child(occluder)


## One row per cell of the parent Room: "#" where any part of the cell is transparent in the
## painting (so thin painted walls still block), "." elsewhere.
func _layout_from_painting() -> PackedStringArray:
	var rows := PackedStringArray()
	var room := get_parent() as Room
	if room == null or room.background == null:
		push_warning("%s: from_painting needs a parent Room with a background." % name)
		return rows
	var image := room.background.get_image()
	if image.is_compressed():
		image.decompress()
	var cells := Vector2i((room.size / cell_size).ceil())
	var texel := Vector2(image.get_size()) / room.size
	var last := Vector2(image.get_size() - Vector2i.ONE)
	# Samples about two texels apart, spread inside each cell so neighbouring cells don't share
	# them: lines a few texels wide are caught without widening every wall by a whole cell.
	var samples := maxi(2, ceili(cell_size * maxf(texel.x, texel.y) / 2.0))
	for y in cells.y:
		var row := ""
		for x in cells.x:
			var wall := false
			for sy in samples:
				for sx in samples:
					var local := (Vector2(x, y) + (Vector2(sx, sy) + Vector2(0.5, 0.5)) / samples) * cell_size
					var point := (local * texel).floor().clamp(Vector2.ZERO, last)
					if image.get_pixelv(Vector2i(point)).a < 0.5:
						wall = true
						break
				if wall:
					break
			row += "#" if wall else "."
		rows.append(row)
	return rows


func _draw() -> void:
	if from_painting:
		return
	for rect in wall_rects():
		draw_rect(rect, Palette.TEAL)
		draw_rect(rect, Palette.MAROON, false, 3.0)
