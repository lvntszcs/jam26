extends Node
## Headless sanity check for every level listed in main.tscn. Run with:
##   godot --headless --path . res://tests/level_check.tscn
## Exits with code 0 if all checks pass, 1 otherwise.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MOVES := ["move_right", "move_left", "move_down", "move_up"]

var _failures := 0


func _ready() -> void:
	_check_controller_bindings()
	var main := MAIN_SCENE.instantiate()
	var levels: Array[PackedScene] = main.levels
	main.free()
	_expect(not levels.is_empty(), "main.tscn", "lists levels to play")
	for scene in levels:
		await _check_level(scene)
	print("level_check: %s" % ("OK" if _failures == 0 else "%d failure(s)" % _failures))
	get_tree().quit(1 if _failures else 0)


func _check_controller_bindings() -> void:
	var actions := ["move_up", "move_down", "move_left", "move_right", "interact", "restart"]
	var buttons := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT,
		JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, JOY_BUTTON_Y]
	for device_id in [0, 3]:
		for i in actions.size():
			var event := InputEventJoypadButton.new()
			event.device = device_id
			event.button_index = buttons[i]
			event.pressed = true
			_expect(InputMap.event_is_action(event, actions[i]), "controls",
				"%s works on controller %d" % [actions[i], device_id])
	for i in MOVES.size():
		var event := InputEventJoypadMotion.new()
		event.device = 3
		event.axis = JOY_AXIS_LEFT_X if i < 2 else JOY_AXIS_LEFT_Y
		event.axis_value = 1.0 if i % 2 == 0 else -1.0
		_expect(InputMap.event_is_action(event, MOVES[i]), "controls", "%s uses left stick" % MOVES[i])
	var hud: Hud = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	hud.set_prompt("Open door")
	var press := InputEventJoypadButton.new()
	press.device = 3
	press.pressed = true
	Haptics._input(press)
	_expect(hud.prompt_label.text == "[A] Open door", "controls", "controller updates prompt")
	var drift := InputEventJoypadMotion.new()
	drift.device = 4
	drift.axis_value = 0.05
	Haptics._input(drift)
	_expect(Haptics.device == 3, "controls", "stick drift does not switch controller")
	Haptics._on_joy_connection_changed(3, false)
	_expect(Haptics.device == -1, "controls", "disconnect clears controller")
	Haptics._input(press)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Haptics._input(key)
	_expect(hud.prompt_label.text == "[E] Open door", "controls", "keyboard restores prompt")
	hud.free()


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

	_check_keycards(level, name)

	# Gas zones sit in a room, the player doesn't start in gas, and gas never spreads.
	for zone in level.gas_zones:
		_expect(zone.room != null, name, "%s is inside a room" % zone.name)
	_expect(level.smoke_at(level.player.global_position) == 0.0, name, "player starts out of the gas")
	var densities := level.gas_zones.map(func(z: GasZone) -> float: return z.density())
	for door in level.doors:
		if not door.is_open:
			door.interact(level.player)
	level.step_gas(5.0)
	var vented := level.gas_zones.filter(func(z: GasZone) -> bool: return level._has_running_vent(z.room))
	for i in level.gas_zones.size():
		var zone: GasZone = level.gas_zones[i]
		if not zone in vented:
			_expect(is_equal_approx(zone.density(), densities[i]), name, "%s stays put with doors open" % zone.name)

	# Vents clear the gas in their room, and it returns when they stop.
	for vent: Vent in level.objects.filter(func(o: GameObject) -> bool: return o is Vent):
		var zones := level.gas_zones.filter(func(z: GasZone) -> bool: return z.room == vent.room)
		var was_on := vent.is_on
		if not was_on:
			vent.interact(level.player)
		level.step_gas(10.0)
		for zone: GasZone in zones:
			_expect(zone.density() == 0.0, name, "%s clears %s" % [vent.name, zone.name])
		vent.interact(level.player)
		level.step_gas(10.0)
		for zone: GasZone in zones:
			_expect(zone.density() > 0.0, name, "%s comes back when %s stops" % [zone.name, vent.name])
		if was_on:
			vent.interact(level.player)
		level.step_gas(10.0)

	# Doors toggle.
	for door in level.doors:
		var was_open := door.is_open
		door.interact(level.player)
		_expect(door.is_open != was_open, name, "%s toggles" % door.name)
		door.interact(level.player)

	# The player walks when movement input is held.
	var start := level.player.global_position
	for action: String in MOVES:
		Input.action_press(action)
		await get_tree().create_timer(0.3).timeout
		Input.action_release(action)
		if level.player.global_position.distance_to(start) > 20.0:
			break
	_expect(level.player.global_position.distance_to(start) > 20.0, name, "player moves")
	_check_damage_feedback(level, name)

	remove_child(level)
	level.free()


## Locked doors stay shut without a good enough keycard, the level's keycards are enough to
## open every one of them, and they open afterwards. Leaves the player with those keycards.
func _check_keycards(level: Level, level_name: String) -> void:
	var player := level.player
	var locked := level.doors.filter(func(d: Door) -> bool: return d.is_locked() and not d.is_open)
	for door: Door in locked:
		door.interact(player)
		_expect(not door.is_open, level_name, "%s stays shut without a keycard" % door.name)
	var cards := level.objects.filter(func(o: GameObject) -> bool: return o is Keycard)
	for card: Keycard in cards:
		card.interact(player)
		_expect(not card in level.objects, level_name, "%s is gone once picked up" % card.name)
	for door: Door in locked:
		_expect(player.keycard_level >= door.required_keycard, level_name,
			"a keycard in the level opens %s" % door.name)
		door.interact(player)
		_expect(door.is_open and not door.is_locked(), level_name, "%s opens with the keycard" % door.name)
		door.interact(player)
	var before := player.keycard_level
	player.upgrade_keycard()
	_expect(player.keycard_level == before + 1 or before == 0, level_name, "keycard upgrades one level")


func _check_damage_feedback(level: Level, level_name: String) -> void:
	var player := level.player
	player.global_position = level.rooms[0].rect().get_center()
	player.air = player.max_air
	# A Strong zone of its own over the player, so other gas doesn't affect the check.
	var level_zones := level.gas_zones
	var zone := GasZone.new()
	zone.strength = GasZone.Strength.STRONG
	zone.size = level.rooms[0].size
	zone.position = level.rooms[0].global_position
	level.add_child(zone)
	level.gas_zones = [zone]
	_expect(is_equal_approx(level.smoke_at(player.global_position), 1.0), level_name, "strong gas is full density")
	var damage: Array[float] = []
	var events: Array[StringName] = []
	var record_damage := func(amount: float) -> void: damage.append(amount)
	var record_event := func(event_name: StringName) -> void: events.append(event_name)
	player.tick_damage.connect(record_damage)
	Haptics.event_triggered.connect(record_event)
	Haptics.stop()
	player._breathe(0.1)
	_expect(damage.size() == 1 and is_equal_approx(damage[0], player.air_loss_per_second * 0.1),
		level_name, "tick_damage reports actual air loss even above low-air threshold")
	_expect(events == [Haptics.TICK_DAMAGE], level_name, "damage triggers named haptic event")
	player._breathe(0.1)
	_expect(damage.size() == 2 and events.size() == 1, level_name,
		"continuous damage emits damage ticks but throttles haptic events")
	zone.cleared = 1.0
	player._breathe(0.1)
	_expect(damage.size() == 2 and events.size() == 1, level_name, "recovery emits no damage or haptic event")
	Haptics._process(Haptics.DAMAGE_INTERVAL)
	zone.cleared = 0.0
	player.air = 1.0
	player._breathe(0.1)
	_expect(damage.size() == 3 and is_equal_approx(damage[2], 1.0), level_name,
		"lethal tick reports remaining air rather than unclamped damage")
	_expect(events.size() == 2, level_name, "damage haptic resumes after cooldown")
	_expect(not player.is_active and level.is_finished, level_name, "lethal damage still ends level")
	level.gas_zones = level_zones
	player.tick_damage.disconnect(record_damage)
	Haptics.event_triggered.disconnect(record_event)
	Haptics.stop()


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
