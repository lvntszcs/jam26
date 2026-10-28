@tool
class_name Door
extends GameObject
## A door between two rooms. Place it on the shared wall: footprint.x is the opening width and
## footprint.y the depth that covers both walls. Closed doors block the player and the smoke.
## The Level links it to the rooms on either side and works out whether the wall is vertical.

signal toggled(is_open: bool)

@export var start_open := false:
	set(value):
		start_open = value
		is_open = value
		refresh_visual()
## True for a door in a vertical wall. The Level corrects this from the door's position at runtime.
@export var vertical := false:
	set(value):
		vertical = value
		refresh_visual()

var is_open := false
var rooms: Array[Room] = []
var _blocker_shape: CollisionShape2D
var _occluder: LightOccluder2D


func _init() -> void:
	footprint = Vector2(140, 64)
	stretch_art = true
	solid = false


func _ready() -> void:
	is_open = start_open
	super()
	if not Engine.is_editor_hint():
		_add_blocker()


func current_texture() -> Texture2D:
	var art := ArtTheme.active()
	return art.door_open if is_open else art.door_closed


func interaction_prompt() -> String:
	return "Close door" if is_open else "Open door"


func interact(by: Player) -> void:
	if is_open and _overlaps(by):
		return
	is_open = not is_open
	_blocker_shape.set_deferred("disabled", is_open)
	_occluder.visible = not is_open
	refresh_visual()
	toggled.emit(is_open)


## The doorway area in global coordinates (used for the interaction highlight too).
func doorway_size() -> Vector2:
	return Vector2(footprint.y, footprint.x) if vertical else footprint


func refresh_visual() -> void:
	super()
	if is_node_ready():
		sprite.rotation = PI / 2.0 if vertical else 0.0
	if _blocker_shape:
		_blocker_shape.rotation = sprite.rotation
		_occluder.rotation = sprite.rotation


func _add_blocker() -> void:
	var body := StaticBody2D.new()
	_blocker_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = footprint
	_blocker_shape.shape = box
	_blocker_shape.rotation = sprite.rotation
	_blocker_shape.disabled = is_open
	body.add_child(_blocker_shape)
	add_child(body)
	# A closed door blocks light like the wall around it.
	_occluder = LightOccluder2D.new()
	_occluder.occluder = Lighting.rect_occluder(Rect2(-footprint * 0.5, footprint))
	_occluder.rotation = sprite.rotation
	_occluder.visible = not is_open
	add_child(_occluder)


func _overlaps(by: Player) -> bool:
	var half := doorway_size() * 0.5 + Vector2.ONE * by.radius
	var offset := by.global_position - global_position
	return absf(offset.x) < half.x and absf(offset.y) < half.y
