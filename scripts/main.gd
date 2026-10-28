extends Node
## Game flow: loads the levels in order, wires them to the HUD and handles
## restarting, advancing and the ending.

enum State { PLAYING, FAILED, COMPLETED, FINISHED }

## Level scenes, played in this order.
@export var levels: Array[PackedScene] = []

var _index := 0
var _level: Level
var _state := State.PLAYING

@onready var hud: Hud = $Hud


func _ready() -> void:
	load_level(0)


func load_level(index: int) -> void:
	if _level:
		remove_child(_level)
		_level.queue_free()
	_index = index
	_level = levels[index].instantiate()
	add_child(_level)
	_level.completed.connect(_on_level_completed)
	_level.failed.connect(_on_level_failed)
	_level.prompt_changed.connect(hud.set_prompt)
	_level.player.air_changed.connect(hud.set_air)
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
		hud.show_message("Sector cleared", "Press E to move on to the next sector.")
	else:
		_state = State.FINISHED
		hud.show_message("You escaped the island!", "The facility is behind you. Press E to play again.")


func _on_level_failed() -> void:
	_state = State.FAILED
	hud.show_message("You passed out", "The smoke was too thick. Press E or R to try again.")

