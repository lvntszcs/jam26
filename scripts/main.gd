extends Node
## Game flow: loads the levels in order, wires them to the HUD and handles
## restarting, advancing and the ending.

enum State { PLAYING, FAILED, COMPLETED, FINISHED }

@export var level_scene: PackedScene
## Level files, played in this order.
@export var level_files: PackedStringArray
## Screen space (in pixels) kept free for the HUD above and below the level.
@export var hud_margin_top := 64.0
@export var hud_margin_bottom := 96.0

var _index := 0
var _level: Level
var _state := State.PLAYING

@onready var hud: Hud = $Hud
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera)
	load_level(0)


func load_level(index: int) -> void:
	var data := LevelData.from_file(level_files[index])
	if data == null:
		return
	if _level:
		remove_child(_level)
		_level.queue_free()
	_index = index
	_level = level_scene.instantiate()
	add_child(_level)
	_level.build(data)
	_level.completed.connect(_on_level_completed)
	_level.failed.connect(_on_level_failed)
	_level.prompt_changed.connect(hud.set_prompt)
	_level.player.air_changed.connect(hud.set_air)
	hud.show_level(data.title, data.hint)
	hud.set_air(_level.player.air, _level.player.max_air)
	_state = State.PLAYING
	_fit_camera()


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
	if _index + 1 < level_files.size():
		_state = State.COMPLETED
		hud.show_message("Sector cleared", "Press E to move on to the next sector.")
	else:
		_state = State.FINISHED
		hud.show_message("You escaped the island!", "The facility is behind you. Press E to play again.")


func _on_level_failed() -> void:
	_state = State.FAILED
	hud.show_message("You passed out", "The smoke was too thick. Press E or R to try again.")


## Zooms and centres the camera so the whole level fits between the HUD bars.
func _fit_camera() -> void:
	if _level == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var available := screen - Vector2(64.0, hud_margin_top + hud_margin_bottom)
	var level_size := _level.size_in_pixels()
	var zoom := minf(available.x / level_size.x, available.y / level_size.y)
	camera.zoom = Vector2.ONE * zoom
	var hud_offset := (hud_margin_bottom - hud_margin_top) * 0.5 / zoom
	camera.position = level_size * 0.5 + Vector2(0.0, hud_offset)
