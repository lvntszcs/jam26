extends Node
## Game flow: loads the levels in order, wires them to the HUD and handles
## restarting, advancing and the ending.

enum State { PLAYING, FAILED, COMPLETED, FINISHED }

## Level scenes, played in this order.
@export var levels: Array[PackedScene] = []

var _index := 0
var _level: Level
var _state := State.PLAYING
## Untouched copy of the level placed in this scene, including anything added to it here
## (like gas zones), so restarts get it back exactly as edited.
var _placed_copy: Level

@onready var hud: Hud = $Hud


func _enter_tree() -> void:
	# Copied before the level's _ready() adds the player and other runtime nodes.
	var placed := get_node_or_null("Level") as Level
	if placed and _placed_copy == null:
		_placed_copy = placed.duplicate()


func _exit_tree() -> void:
	if _placed_copy:
		_placed_copy.free()
		_placed_copy = null


func _ready() -> void:
	# A level placed directly in this scene (so the map shows in the editor) is played first.
	load_level(0, get_node_or_null("Level") as Level)


func load_level(index: int, placed: Level = null) -> void:
	Haptics.stop()
	if _level:
		remove_child(_level)
		_level.queue_free()
	_index = index
	if placed:
		_level = placed
	elif index == 0 and _placed_copy:
		_level = _placed_copy.duplicate()
	else:
		_level = levels[index].instantiate()
	if not placed:
		add_child(_level)
	_level.completed.connect(_on_level_completed)
	_level.failed.connect(_on_level_failed)
	_level.prompt_changed.connect(hud.set_prompt)
	_level.player.air_changed.connect(hud.set_air)
	_level.player.keycard_changed.connect(hud.set_keycard)
	hud.set_keycard(_level.player.keycard_level)
	hud.show_level(_level.title, _level.hint)
	hud.set_air(_level.player.air, _level.player.max_air)
	_state = State.PLAYING


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		load_level(_index)
	elif event.is_action_pressed("interact") and _state != State.PLAYING:
		match _state:
			State.FAILED:
				load_level(_index)
			State.COMPLETED:
				load_level(_index + 1)
			State.FINISHED:
				load_level(0)


func _on_level_completed() -> void:
	if _index + 1 < levels.size():
		_state = State.COMPLETED
		hud.show_message("Sector cleared", "Press E / A to move on to the next sector.")
	else:
		_state = State.FINISHED
		hud.show_message("You escaped the island!", "The facility is behind you. Press E / A to play again.")


func _on_level_failed() -> void:
	_state = State.FAILED
	hud.show_message("You passed out", "The smoke was too thick. Press E / A or R / Y to try again.")

