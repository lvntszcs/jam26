class_name Player
extends Node2D
## Grid-based top-down player. Moves one cell at a time, interacts with whatever it
## faces, and loses air while standing in smoke.

signal air_changed(air: float, max_air: float)
signal died

## Seconds to slide from one cell to the next.
@export var move_duration := 0.12
## Tapping a new direction only turns the player; holding it this long starts walking.
## This lets the player face an open door without stepping into it.
@export var turn_delay := 0.1
@export var max_air := 100.0
## Air lost per second while standing in full-density smoke.
@export var air_loss_per_second := 45.0
@export var air_recovery_per_second := 20.0
## Smoke below this density is safe to breathe.
@export_range(0.0, 1.0) var safe_density := 0.15

var level: Level
var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var air := 0.0
var is_active := true
var _moving := false
var _turn_timer := 0.0

@onready var sprite: Sprite2D = $Sprite


## Called by the Level before the player is added to the tree.
func setup(target_level: Level, start_cell: Vector2i) -> void:
	level = target_level
	cell = start_cell
	position = level.cell_to_local(cell)
	air = max_air


func _ready() -> void:
	_refresh_visual()
	air_changed.emit(air, max_air)


func facing_cell() -> Vector2i:
	return cell + facing


func _process(delta: float) -> void:
	if not is_active:
		return
	_breathe(delta)
	if not is_active or _moving:
		return
	var direction := _read_direction()
	if direction == Vector2i.ZERO:
		_turn_timer = 0.0
		return
	if direction != facing:
		facing = direction
		_turn_timer = turn_delay
		_refresh_visual()
		return
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_try_step(direction)


func _unhandled_input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interact"):
		level.interact_at(facing_cell(), self)
		get_viewport().set_input_as_handled()


func _read_direction() -> Vector2i:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(input.x) > absf(input.y):
		return Vector2i(int(signf(input.x)), 0)
	return Vector2i(0, int(signf(input.y)))


func _try_step(direction: Vector2i) -> void:
	var target := cell + direction
	if not level.is_walkable(target):
		return
	cell = target
	_moving = true
	var tween := create_tween()
	tween.tween_property(self, "position", level.cell_to_local(cell), move_duration)
	tween.tween_callback(_on_step_finished)


func _on_step_finished() -> void:
	_moving = false
	level.on_player_entered(cell)


func _breathe(delta: float) -> void:
	var density := level.smoke_at(cell)
	var previous := air
	if density > safe_density:
		air -= air_loss_per_second * density * delta
	else:
		air += air_recovery_per_second * delta
	air = clampf(air, 0.0, max_air)
	if air != previous:
		air_changed.emit(air, max_air)
	if air <= 0.0:
		is_active = false
		died.emit()


func _refresh_visual() -> void:
	match facing:
		Vector2i.UP:
			Art.apply(sprite, Art.theme.player_up)
			sprite.flip_h = false
		Vector2i.DOWN:
			Art.apply(sprite, Art.theme.player_down)
			sprite.flip_h = false
		_:
			Art.apply(sprite, Art.theme.player_side)
			sprite.flip_h = facing == Vector2i.LEFT
