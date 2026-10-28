class_name Level
extends Node2D
## Builds a playable level from LevelData and answers grid questions for the player,
## the entities and the smoke ("can I walk here?", "what is in this cell?").

signal completed
signal failed
## Text for the interaction the player can do right now, or "" when there is none.
signal prompt_changed(text: String)

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const DOOR_SCENE := preload("res://scenes/entities/door.tscn")
const VENT_SCENE := preload("res://scenes/entities/vent.tscn")
const SMOKE_SOURCE_SCENE := preload("res://scenes/entities/smoke_source.tscn")
const EXIT_SCENE := preload("res://scenes/entities/exit.tscn")

## Level-file character -> the entity scene it spawns and the properties to set on it.
## Add a new object type by creating its scene and adding a line here.
const LEGEND := {
	"D": {"scene": DOOR_SCENE, "props": {"start_open": false}},
	"d": {"scene": DOOR_SCENE, "props": {"start_open": true}},
	"V": {"scene": VENT_SCENE, "props": {"start_on": true}},
	"v": {"scene": VENT_SCENE, "props": {"start_on": false}},
	"S": {"scene": SMOKE_SOURCE_SCENE, "props": {}},
	"E": {"scene": EXIT_SCENE, "props": {}},
}

var data: LevelData
var player: Player
var is_finished := false
var _entities := {}
var _prompt := ""

@onready var tiles: TileLayer = $Tiles
@onready var entities_root: Node2D = $Entities
@onready var smoke: SmokeField = $Smoke
@onready var highlight: Sprite2D = $Highlight


func build(level_data: LevelData) -> void:
	data = level_data
	tiles.setup(data)
	for cell: Vector2i in data.cells:
		var symbol: String = data.cells[cell]
		if symbol == LevelData.PLAYER_START:
			_spawn_player(cell)
		elif LEGEND.has(symbol):
			_spawn_entity(cell, LEGEND[symbol])
	if player == null:
		push_error("Level '%s' has no player start ('%s')." % [data.title, LevelData.PLAYER_START])
	smoke.setup(self)
	Art.apply(highlight, Art.theme.highlight)


func _process(_delta: float) -> void:
	_update_interaction_hint()


func size_in_pixels() -> Vector2:
	return Vector2(data.size) * Art.theme.tile_size


func cell_to_local(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Art.theme.tile_size


func entity_at(cell: Vector2i) -> GridEntity:
	return _entities.get(cell)


func is_occupied_by_player(cell: Vector2i) -> bool:
	return player != null and player.cell == cell


func is_walkable(cell: Vector2i) -> bool:
	if not data.is_floor(cell):
		return false
	var entity := entity_at(cell)
	return entity == null or not entity.blocks_movement()


func is_smoke_passable(cell: Vector2i) -> bool:
	if not data.is_floor(cell):
		return false
	var entity := entity_at(cell)
	return entity == null or not entity.blocks_smoke()


func smoke_at(cell: Vector2i) -> float:
	return smoke.density_at(cell)


## Returns true if something in the cell reacted.
func interact_at(cell: Vector2i, by: Player) -> bool:
	var entity := entity_at(cell)
	if entity == null or entity.interaction_prompt() == "":
		return false
	entity.interact(by)
	return true


func on_player_entered(cell: Vector2i) -> void:
	var entity := entity_at(cell)
	if entity:
		entity.on_player_entered(player)


func complete() -> void:
	_finish()
	completed.emit()


func fail() -> void:
	_finish()
	failed.emit()


func _finish() -> void:
	is_finished = true
	player.is_active = false


func _spawn_player(cell: Vector2i) -> void:
	player = PLAYER_SCENE.instantiate()
	player.setup(self, cell)
	player.died.connect(fail)
	add_child(player)


func _spawn_entity(cell: Vector2i, entry: Dictionary) -> void:
	var entity: GridEntity = entry.scene.instantiate()
	for property: String in entry.props:
		entity.set(property, entry.props[property])
	entity.place(self, cell)
	entities_root.add_child(entity)
	_entities[cell] = entity


func _update_interaction_hint() -> void:
	var text := ""
	var target: GridEntity = null
	if player and player.is_active:
		target = entity_at(player.facing_cell())
		if target:
			text = target.interaction_prompt()
	highlight.visible = text != ""
	if highlight.visible:
		highlight.position = target.position
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
