class_name Player
extends CharacterBody2D
## Free-moving top-down player. Walks with smooth acceleration, interacts with the nearest
## object in reach, and loses air while in a smoky room.

signal air_changed(air: float, max_air: float)
signal died

@export var speed := 300.0
@export var acceleration := 2400.0
@export var friction := 2800.0
## Size in world pixels that the player art is fitted into.
@export var footprint := Vector2(72, 72)
## How close (from the player's centre) an object must be to interact with it.
@export var interact_range := 120.0
@export var max_air := 100.0
## Air lost per second in a room full of smoke.
@export var air_loss_per_second := 30.0
@export var air_recovery_per_second := 15.0
## Smoke below this level is safe to breathe.
@export_range(0.0, 1.0) var safe_smoke := 0.2

var level: Level
var facing := Vector2.DOWN
var air := 0.0
var is_active := true

@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera
@onready var radius: float = ($Collision.shape as CircleShape2D).radius


func _ready() -> void:
	air = max_air
	_refresh_visual()
	air_changed.emit(air, max_air)


func _physics_process(delta: float) -> void:
	if not is_active:
		velocity = Vector2.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(input * speed, acceleration * delta)
		if _direction_of(input) != _direction_of(facing):
			facing = input
			_refresh_visual()
		facing = input
	move_and_slide()
	_breathe(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interact"):
		level.interact(self)
		get_viewport().set_input_as_handled()


func _breathe(delta: float) -> void:
	var smoke := level.smoke_at(global_position)
	var previous := air
	if smoke > safe_smoke:
		air -= air_loss_per_second * smoke * delta
	else:
		air += air_recovery_per_second * delta
	air = clampf(air, 0.0, max_air)
	if air != previous:
		air_changed.emit(air, max_air)
	if air <= 0.0:
		is_active = false
		died.emit()


## Snaps a vector to the main direction it points in: up, down, left or right.
func _direction_of(vector: Vector2) -> Vector2i:
	if absf(vector.x) > absf(vector.y):
		return Vector2i(int(signf(vector.x)), 0)
	return Vector2i(0, int(signf(vector.y)))


func _refresh_visual() -> void:
	var art := ArtTheme.active()
	var direction := _direction_of(facing)
	var texture: Texture2D = art.player_side
	if direction == Vector2i.UP:
		texture = art.player_up
	elif direction == Vector2i.DOWN:
		texture = art.player_down
	sprite.texture = texture
	sprite.flip_h = direction == Vector2i.LEFT
	if texture:
		var fit := footprint / texture.get_size()
		sprite.scale = Vector2.ONE * minf(fit.x, fit.y)
