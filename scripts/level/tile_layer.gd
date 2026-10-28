class_name TileLayer
extends Node2D
## Draws the floor and wall tiles of a level from the ArtTheme.

var _data: LevelData


func setup(data: LevelData) -> void:
	_data = data
	queue_redraw()


func _draw() -> void:
	if _data == null:
		return
	var tile := Vector2.ONE * Art.theme.tile_size
	for cell: Vector2i in _data.cells:
		var texture := Art.theme.wall_tile if _data.is_wall(cell) else Art.theme.floor_tile
		var rect := Rect2(Vector2(cell) * tile, tile)
		if texture:
			draw_texture_rect(texture, rect, false)
		else:
			draw_rect(rect, Palette.MOSS if _data.is_wall(cell) else Palette.TEAL)
