extends Node
## Headless sanity check for every level listed in main.tscn. Run with:
##   godot --headless --path . res://tests/level_check.tscn
## Exits with code 0 if all checks pass, 1 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MOVES := ["move_right", "move_left", "move_down", "move_up"]

var _failures := 0


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	var levels: Array[PackedScene] = main.levels
	main.free()
	for scene in levels:
		await _check_level(scene)
	print("level_check: %s" % ("OK" if _failures == 0 else "%d failure(s)" % _failures))
	get_tree().quit(1 if _failures else 0)


func _check_level(scene: PackedScene) -> void:
	var level: Level = scene.instantiate()
	var name := scene.resource_path.get_file()
	add_child(level)
	_expect(level.player != null, name, "has a PlayerStart")
	_expect(level.title != "", name, "has a title")
	_expect(not level.rooms.is_empty(), name, "has rooms")
	_expect(level.room_at(level.player.global_position) != null, name, "player starts inside a room")
	for door in level.doors:
		_expect(door.rooms.size() == 2, name, "%s connects two rooms (got %d)" % [door.name, door.rooms.size()])
	var exits := level.objects.filter(func(o: GameObject) -> bool: return o is Exit)
	_expect(not exits.is_empty(), name, "has an exit")
	for object in level.objects:
		if not object is Door:
			_expect(object.room != null, name, "%s is inside a room" % object.name)
	if not exits.is_empty():
		_expect(_reachable(level, level.room_at(level.player.global_position), exits[0].room), name,
			"exit room reachable with all doors open")

	# Smoke must spread out of the room it starts in.
	for i in 300:
		level.step_smoke(0.1)
	var smoky := level.rooms.filter(func(r: Room) -> bool: return r.smoke > 0.05).size()
	_expect(smoky > 1, name, "smoke spreads (%d smoky rooms)" % smoky)

	# Doors toggle and stop smoke flowing when closed.
	for door in level.doors:
		var was_open := door.is_open
		door.interact(level.player)
		_expect(door.is_open != was_open, name, "%s toggles" % door.name)
		door.interact(level.player)
	for door in level.doors:
		if door.is_open:
			door.interact(level.player)
	for room in level.rooms:
		room.smoke = 0.0
	level.doors[0].rooms[0].smoke = 1.0
	var before := level.doors[0].rooms[1].smoke
	var sources := level.objects.filter(func(o: GameObject) -> bool: return o is SmokeSource and o.room == level.doors[0].rooms[1])
	if sources.is_empty():
		level.step_smoke(1.0)
		_expect(is_equal_approx(level.doors[0].rooms[1].smoke, before), name, "closed door blocks smoke")

	# The player walks when movement input is held.
	for room in level.rooms:
		room.smoke = 0.0
	var start := level.player.global_position
	for action: String in MOVES:
		Input.action_press(action)
		await get_tree().create_timer(0.3).timeout
		Input.action_release(action)
		if level.player.global_position.distance_to(start) > 20.0:
			break
	_expect(level.player.global_position.distance_to(start) > 20.0, name, "player moves")

	remove_child(level)
	level.free()


func _reachable(level: Level, from: Room, to: Room) -> bool:
	var seen := {from: true}
	var queue: Array[Room] = [from]
	while not queue.is_empty():
		var room: Room = queue.pop_front()
		if room == to:
			return true
		for door in room.doors:
			for next in door.rooms:
				if not seen.has(next):
					seen[next] = true
					queue.append(next)
	return false


func _expect(condition: bool, level_name: String, what: String) -> void:
	if not condition:
		_failures += 1
		push_error("%s: expected %s" % [level_name, what])
