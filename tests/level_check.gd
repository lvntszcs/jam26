extends Node
## Headless sanity check for every level listed in main.tscn. Run with:
##   godot --headless --path . res://tests/level_check.tscn
## Exits with code 0 if all checks pass, 1 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LEVEL_SCENE := preload("res://scenes/level.tscn")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var _failures := 0


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	var files: PackedStringArray = main.level_files
	main.free()
	for path in files:
		await _check_level(path)
	print("level_check: %s" % ("OK" if _failures == 0 else "%d failure(s)" % _failures))
	get_tree().quit(1 if _failures else 0)


func _check_level(path: String) -> void:
	var data := LevelData.from_file(path)
	_expect(data != null, path, "file loads")
	if data == null:
		return
	var level: Level = LEVEL_SCENE.instantiate()
	add_child(level)
	level.build(data)
	_expect(level.player != null, path, "has a player start")
	_expect(data.title != "", path, "has a title")

	var exits := []
	for cell: Vector2i in data.cells:
		if level.entity_at(cell) is Exit:
			exits.append(cell)
	_expect(not exits.is_empty(), path, "has an exit")
	_expect(_exit_reachable(level), path, "exit reachable with all doors open")

	# Let the smoke run for a while: it must spread out of its source.
	for i in 40:
		level.smoke._step()
	var smoky := 0
	for cell: Vector2i in data.cells:
		if level.smoke_at(cell) > 0.1:
			smoky += 1
	_expect(smoky > 1, path, "smoke spreads (%d smoky cells)" % smoky)

	# Doors toggle and block smoke when closed.
	for cell: Vector2i in data.cells:
		var door := level.entity_at(cell) as Door
		if door:
			var was_open := door.is_open
			door.interact(level.player)
			_expect(door.is_open != was_open, path, "door at %s toggles" % cell)
			_expect(level.is_smoke_passable(cell) == door.is_open, path, "door at %s smoke blocking" % cell)
			door.interact(level.player)

	# The player can take a step on its own input.
	var start := level.player.cell
	var free_dir := Vector2i.ZERO
	for dir in DIRECTIONS:
		if level.is_walkable(start + dir):
			free_dir = dir
			break
	level.player.facing = free_dir
	level.player._try_step(free_dir)
	await get_tree().create_timer(level.player.move_duration + 0.1).timeout
	_expect(level.player.cell == start + free_dir, path, "player steps")

	remove_child(level)
	level.free()


func _exit_reachable(level: Level) -> bool:
	var open := {level.player.cell: true}
	var queue := [level.player.cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if level.entity_at(cell) is Exit:
			return true
		for dir in DIRECTIONS:
			var next: Vector2i = cell + dir
			if open.has(next) or not level.data.is_floor(next):
				continue
			var entity := level.entity_at(next)
			if entity and entity.blocks_movement() and not entity is Door:
				continue
			open[next] = true
			queue.append(next)
	return false


func _expect(condition: bool, path: String, what: String) -> void:
	if not condition:
		_failures += 1
		push_error("%s: expected %s" % [path, what])
