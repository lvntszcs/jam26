class_name Player
extends CharacterBody2D
## Free-moving top-down player. Walks with smooth acceleration, interacts with the nearest
## object in reach, and loses air while in a smoky room.

signal air_changed(air: float, max_air: float)
## Actual air lost to smoke during this simulation tick (never emitted for recovery).
signal tick_damage(amount: float)
signal died
## The keycard's level changed (0 = no keycard).
signal keycard_changed(keycard_level: int)

@export var speed := 300.0
@export var acceleration := 2400.0
@export var friction := 2800.0
## Size in world pixels that one spritesheet frame is fitted into.
@export var footprint := Vector2(200, 200)
## How quickly the sprite turns toward the walking direction (higher = snappier).
@export var turn_speed := 14.0
## How close (from the player's centre) an object must be to interact with it.
@export var interact_range := 170.0
@export var max_air := 100.0
## Air lost per second in a room full of smoke.
@export var air_loss_per_second := 30.0
@export var air_recovery_per_second := 15.0
## Smoke below this level is safe to breathe.
@export_range(0.0, 1.0) var safe_smoke := 0.2

## Debug god mode (G): no air is lost. Static so it survives level restarts.
static var invincible := false
## Debug noclip (N): walk through walls and closed doors.
static var noclip := false

var level: Level
var facing := Vector2.DOWN
var air := 0.0
var is_active := true
## Level of the keycard the player carries; 0 = none. Doors check it against their
## `required_keycard`.
var keycard_level := 0
var _walk_time := 0.0
var _step_distance := 0.0
var _footstep_index := 0

@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera
@onready var light: PlayerLight = $Light
@onready var footstep: AudioStreamPlayer = $Footstep
@onready var radius: float = ($Collision.shape as CircleShape2D).radius


func _ready() -> void:
	air = max_air
	_setup_sprite()
	_refresh_cheat_tint()
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
		facing = input
	var previous_position := global_position
	if noclip:
		global_position += velocity * delta
	else:
		move_and_slide()
	_movement_feedback(global_position.distance_to(previous_position))
	_animate(delta)
	_breathe(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_active and event.is_action_pressed("interact"):
		level.interact(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("god_mode"):
		invincible = not invincible
		_refresh_cheat_tint()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("noclip"):
		noclip = not noclip
		_refresh_cheat_tint()
		get_viewport().set_input_as_handled()


func set_keycard_level(value: int) -> void:
	if value != keycard_level:
		keycard_level = value
		keycard_changed.emit(keycard_level)


## Raises the keycard one level, e.g. at an upgrade station. Does nothing without a keycard.
func upgrade_keycard() -> void:
	if keycard_level > 0:
		set_keycard_level(keycard_level + 1)


## Lime tint = god mode, violet = noclip, a blend of both when both are on.
func _refresh_cheat_tint() -> void:
	if invincible and noclip:
		sprite.modulate = Palette.LIME.lerp(Palette.VIOLET, 0.5)
	elif invincible:
		sprite.modulate = Palette.LIME
	elif noclip:
		sprite.modulate = Palette.VIOLET
	else:
		sprite.modulate = Color.WHITE


func _movement_feedback(distance: float) -> void:
	# Distance, rather than held input, avoids footsteps while pushing against a wall.
	if distance < 0.1:
		_step_distance = 0.0
	else:
		_step_distance += distance
		if _step_distance >= 65.0:
			_step_distance = fmod(_step_distance, 65.0)
			Haptics.pulse(0.12, 0.04, 0.035)
			# A lower footstep every two, then three steps (2, 5, 7, 10, ...).
			_footstep_index = (_footstep_index + 1) % 5
			footstep.pitch_scale = 0.92 if _footstep_index == 2 or _footstep_index == 0 else 1.0
			footstep.play()


func _breathe(delta: float) -> void:
	var smoke := level.smoke_at(global_position)
	var previous := air
	if invincible:
		air = max_air
	elif smoke > safe_smoke:
		air -= air_loss_per_second * smoke * delta
	else:
		air += air_recovery_per_second * delta
	air = clampf(air, 0.0, max_air)
	if air < previous:
		tick_damage.emit(previous - air)
	if air != previous:
		air_changed.emit(air, max_air)
	if air <= 0.0:
		is_active = false
		died.emit()


func _setup_sprite() -> void:
	var art := ArtTheme.active()
	sprite.texture = art.player_sheet
	sprite.hframes = art.player_sheet_columns
	sprite.vframes = art.player_sheet_rows
	sprite.frame = art.player_idle_frame
	if art.player_sheet:
		var frame_size := art.player_sheet.get_size() / Vector2(art.player_sheet_columns, art.player_sheet_rows)
		var fit := footprint / frame_size
		sprite.scale = Vector2.ONE * minf(fit.x, fit.y)
	sprite.rotation = facing.angle() - deg_to_rad(art.player_art_angle)


## Turns the sprite toward the walking direction and steps through the walk cycle at a rate
## that follows the current speed, so the feet don't slide.
func _animate(delta: float) -> void:
	var art := ArtTheme.active()
	var target := facing.angle() - deg_to_rad(art.player_art_angle)
	sprite.rotation = lerp_angle(sprite.rotation, target, minf(1.0, turn_speed * delta))
	var pace := velocity.length() / speed
	if pace < 0.1 or art.player_walk_frames.is_empty():
		_walk_time = 0.0
		sprite.frame = art.player_idle_frame
		return
	_walk_time += delta * art.player_walk_fps * pace
	sprite.frame = art.player_walk_frames[int(_walk_time) % art.player_walk_frames.size()]
