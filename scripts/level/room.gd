@tool
class_name Room
extends Node2D
## One room of the facility. Its painting is stretched over `size`, with the node's position as
## the top-left corner. At runtime, walls are built along the inside of the border, leaving a
## gap wherever a Door sits on an edge. Rooms that share a door share their smoke.

enum Edge { TOP, BOTTOM, LEFT, RIGHT }

@export var room_name := "Room":
	set(value):
		room_name = value
		queue_redraw()
@export var size := Vector2(1000, 700):
	set(value):
		size = value
		queue_redraw()
## The room's painting. Leave empty to draw a placeholder.
@export var background: Texture2D:
	set(value):
		background = value
		queue_redraw()
## Thickness of the painted border that counts as wall.
@export var wall_thickness := 28.0:
	set(value):
		wall_thickness = value
		queue_redraw()
@export_range(0.0, 1.0) var start_smoke := 0.0

## Current smoke level, 0 (clean) to 1 (unbreathable).
var smoke := 0.0
var doors: Array[Door] = []


func _ready() -> void:
	smoke = start_smoke


func rect() -> Rect2:
	return Rect2(global_position, size)


func contains(point: Vector2) -> bool:
	return rect().has_point(point)


## Bigger rooms fill and drain more slowly. A 1000x700 room has capacity 1.
func capacity() -> float:
	return maxf(0.1, size.x * size.y / 700000.0)


## The edge nearest to a global point, and the point's distance along that edge.
func nearest_edge(point: Vector2) -> Dictionary:
	var local := point - global_position
	var distances := {
		Edge.TOP: absf(local.y),
		Edge.BOTTOM: absf(local.y - size.y),
		Edge.LEFT: absf(local.x),
		Edge.RIGHT: absf(local.x - size.x),
	}
	var edge: Edge = Edge.TOP
	for candidate: Edge in distances:
		if distances[candidate] < distances[edge]:
			edge = candidate
	var along := local.x if edge == Edge.TOP or edge == Edge.BOTTOM else local.y
	return {"edge": edge, "along": along, "distance": distances[edge]}


## Builds the wall colliders and the smoke overlay. Called by the Level after doors are linked.
func build() -> void:
	for edge: Edge in Edge.values():
		var horizontal := edge == Edge.TOP or edge == Edge.BOTTOM
		var spans: Array[Vector2] = [Vector2(0.0, size.x if horizontal else size.y)]
		for door in doors:
			var hit := nearest_edge(door.global_position)
			if hit.edge == edge:
				var half := door.footprint.x * 0.5
				spans = _cut(spans, hit.along - half, hit.along + half)
		for span in spans:
			if span.y - span.x > 1.0:
				_add_wall(edge, span)
	var overlay := SmokeOverlay.new()
	overlay.room = self
	add_child(overlay)


func _cut(spans: Array[Vector2], from: float, to: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for span in spans:
		if to <= span.x or from >= span.y:
			result.append(span)
			continue
		if from > span.x:
			result.append(Vector2(span.x, from))
		if to < span.y:
			result.append(Vector2(to, span.y))
	return result


func _add_wall(edge: Edge, span: Vector2) -> void:
	var length := span.y - span.x
	var t := wall_thickness
	var wall_rect: Rect2
	match edge:
		Edge.TOP:
			wall_rect = Rect2(span.x, 0.0, length, t)
		Edge.BOTTOM:
			wall_rect = Rect2(span.x, size.y - t, length, t)
		Edge.LEFT:
			wall_rect = Rect2(0.0, span.x, t, length)
		Edge.RIGHT:
			wall_rect = Rect2(size.x - t, span.x, t, length)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = wall_rect.size
	shape.shape = box
	shape.position = wall_rect.get_center()
	body.add_child(shape)
	add_child(body)
	# Walls block the player's light so neighbouring rooms stay dark.
	var occluder := LightOccluder2D.new()
	occluder.occluder = Lighting.rect_occluder(wall_rect)
	add_child(occluder)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	if background:
		draw_texture_rect(background, area, false)
	else:
		_draw_placeholder(area)


func _draw_placeholder(area: Rect2) -> void:
	draw_rect(area, Palette.CREAM)
	var grid := Color(Palette.TEAL, 0.35)
	var step := 70.0
	var x := step
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), grid, 3.0)
		x += step
	var y := step
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), grid, 3.0)
		y += step
	var t := wall_thickness
	draw_rect(Rect2(0.0, 0.0, size.x, t), Palette.TEAL)
	draw_rect(Rect2(0.0, size.y - t, size.x, t), Palette.TEAL)
	draw_rect(Rect2(0.0, 0.0, t, size.y), Palette.TEAL)
	draw_rect(Rect2(size.x - t, 0.0, t, size.y), Palette.TEAL)
	draw_rect(area.grow(-t), Palette.MAROON, false, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(t + 16.0, t + 40.0), room_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, Color(Palette.TEAL, 0.8))
