@tool
class_name GameObject
extends Node2D
## Base class for things placed in a level: doors, vents, smoke sources, the exit.
## The art is fitted into `footprint`, so it works at any resolution. Place and size objects
## in the editor. The Level finds them automatically and works out which room each one is in.
## Every object scene needs a Sprite2D child named "Sprite".

## Size in world pixels that the object's art is fitted into.
@export var footprint := Vector2(96, 96):
	set(value):
		footprint = value
		refresh_visual()
## Stretch the art to fill the footprint exactly instead of keeping its aspect ratio.
@export var stretch_art := false:
	set(value):
		stretch_art = value
		refresh_visual()
## Hide the sprite, e.g. when the object is already painted into the room background.
@export var hide_art := false:
	set(value):
		hide_art = value
		refresh_visual()
## Blocks the player. The collision box is `footprint * solid_scale`, centred.
@export var solid := true
@export var solid_scale := Vector2(0.7, 0.7)

var level: Level
var room: Room

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	refresh_visual()
	if not Engine.is_editor_hint() and solid:
		_add_collision()


## Called by the Level once every room and object has been found.
func setup(target_level: Level, target_room: Room) -> void:
	level = target_level
	room = target_room


## Texture for the current state. Override in subclasses.
func current_texture() -> Texture2D:
	return null


## Gets the room's smoke level each physics frame and returns the new level.
func affect_smoke(smoke: float, _delta: float) -> float:
	return smoke


## Text shown when the player is close enough. Empty means it can't be interacted with.
func interaction_prompt() -> String:
	return ""


func interact(_by: Player) -> void:
	pass


func refresh_visual() -> void:
	if not is_node_ready():
		return
	var texture := current_texture()
	sprite.texture = texture
	sprite.visible = texture != null and not hide_art
	if texture:
		var fit := footprint / texture.get_size()
		sprite.scale = fit if stretch_art else Vector2.ONE * minf(fit.x, fit.y)


func _add_collision() -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = footprint * solid_scale
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
