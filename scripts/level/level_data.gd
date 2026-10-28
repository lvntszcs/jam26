class_name LevelData
extends RefCounted
## A level parsed from a plain-text map file. See levels/README.md for the format.

const WALL := "#"
const VOID := " "
const PLAYER_START := "P"
const COMMENT := ";"

var title := ""
var hint := ""
## Every "; key: value" header line, by key.
var meta := {}
var size := Vector2i.ZERO
## Vector2i -> one-character String. Void cells are not stored.
var cells := {}


static func from_file(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open level file '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	return from_text(file.get_as_text())


static func from_text(text: String) -> LevelData:
	var data := LevelData.new()
	var y := 0
	for raw_line in text.split("\n"):
		var line := raw_line.trim_suffix("\r")
		if line.begins_with(COMMENT):
			data._parse_meta(line.substr(1))
			continue
		if line.strip_edges().is_empty():
			continue
		for x in line.length():
			if line[x] != VOID:
				data.cells[Vector2i(x, y)] = line[x]
		data.size.x = maxi(data.size.x, line.length())
		y += 1
	data.size.y = y
	data.title = data.meta.get("title", "")
	data.hint = data.meta.get("hint", "")
	return data


func is_wall(cell: Vector2i) -> bool:
	return cells.get(cell, "") == WALL


## Any non-wall, non-void cell. Entities stand on floor cells.
func is_floor(cell: Vector2i) -> bool:
	return cells.has(cell) and cells[cell] != WALL


func _parse_meta(line: String) -> void:
	var colon := line.find(":")
	if colon == -1:
		return
	meta[line.substr(0, colon).strip_edges()] = line.substr(colon + 1).strip_edges()
