class_name Level
extends Node2D
## A playable level, built in the editor from Room, Door and other GameObject nodes
## (anywhere under this node) plus a Marker2D named "PlayerStart".
## At runtime it links doors to rooms, runs the smoke simulation and handles interactions.

signal completed
signal failed
## Text for the interaction the player can do right now, or "" when there is none.
signal prompt_changed(text: String)

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
## How far past the map's edge the black backdrop reaches (covers any zoomed-out view).
const VOID_MARGIN := 10000.0

@export var title := ""
@export_multiline var hint := ""
@export var camera_zoom := 1.0
## Smoke moved per second through one open door between two rooms, per unit of difference
## in their smoke levels.
@export var door_flow := 0.5
## Local illumination for this level. Leave empty to use res://config/lighting.tres.
@export var lighting: LightingConfig
## How the smoke looks in this level. Leave empty to use res://config/smoke.tres.
@export var smoke_config: SmokeConfig

var player: Player
var rooms: Array[Room] = []
var doors: Array[Door] = []
var objects: Array[GameObject] = []
var is_finished := false
var _prompt := ""
var _focus: GameObject
var _highlight: Sprite2D
var _smoke_surfaces := {}


func _ready() -> void:
	_collect(self)
	for door in doors:
		_link_door(door)
	for room in rooms:
		room.build()
	for object in objects:
		object.setup(self, room_at(object.global_position))
		if object is Door:
			(object as Door).toggled.connect(_on_door_toggled)
		elif object is Vent:
			(object as Vent).toggled.connect(_on_vent_toggled)
		if object.room == null and not object is Door:
			push_warning("%s is not inside any room." % object.name)
	_setup_smoke()
	_spawn_player()
	_setup_lighting()
	_add_void_backdrop()
	_highlight = Sprite2D.new()
	_highlight.texture = ArtTheme.active().highlight
	_highlight.z_index = 5
	_highlight.visible = false
	add_child(_highlight)


func _physics_process(delta: float) -> void:
	if is_finished:
		return
	step_smoke(delta)
	_check_exits()


func _process(_delta: float) -> void:
	_update_focus()


func room_at(point: Vector2) -> Room:
	for room in rooms:
		if room.contains(point):
			return room
	return null


func smoke_at(point: Vector2) -> float:
	var room := room_at(point)
	return room.smoke if room else 0.0


## The union of all rooms, in global coordinates.
func bounds() -> Rect2:
	var result := rooms[0].rect()
	for room in rooms:
		result = result.merge(room.rect())
	return result


## How thick the smoke is in `room` right next to `door`.
func doorway_smoke(door: Door, room: Room) -> float:
	var surface: SmokeSurface = _smoke_surfaces.get(room)
	return surface.density_at(door.global_position) if surface else room.smoke


## 0 to 1: how freely smoke leaves `source` through `door`. Smoke only passes through once the
## drawn smoke has spread up to the door, and fully once it is as thick there as the room average.
func _doorway_gate(door: Door, source: Room) -> float:
	if source.smoke <= 0.0:
		return 0.0
	return minf(1.0, doorway_smoke(door, source) / source.smoke)


func step_smoke(delta: float) -> void:
	for door in doors:
		if door.is_open and door.rooms.size() == 2:
			var a := door.rooms[0]
			var b := door.rooms[1]
			var source := a if a.smoke > b.smoke else b
			var flow := door_flow * (a.smoke - b.smoke) * delta * _doorway_gate(door, source)
			a.smoke -= flow / a.capacity()
			b.smoke += flow / b.capacity()
	for object in objects:
		if object.room:
			object.room.smoke = object.affect_smoke(object.room.smoke, delta)
	for room in rooms:
		room.smoke = clampf(room.smoke, 0.0, 1.0)
	for surface: SmokeSurface in _smoke_surfaces.values():
		surface.simulate(delta)


func interact(by: Player) -> void:
	if _focus:
		_focus.interact(by)


func complete() -> void:
	_finish()
	Haptics.pulse(0.65, 0.25, 0.35, 3)
	completed.emit()


func fail() -> void:
	_finish()
	Haptics.pulse(0.35, 0.85, 0.5, 3)
	failed.emit()


func _finish() -> void:
	Haptics.stop()
	is_finished = true
	player.is_active = false
	_highlight.visible = false


func _on_door_toggled(_is_open: bool) -> void:
	Haptics.pulse(0.35, 0.5, 0.12, 2)


func _on_vent_toggled(_is_on: bool) -> void:
	Haptics.pulse(0.45, 0.15, 0.08, 2)


func _collect(node: Node) -> void:
	for child in node.get_children():
		if child is Room:
			rooms.append(child)
		elif child is Door:
			doors.append(child)
			objects.append(child)
		elif child is GameObject:
			objects.append(child)
		_collect(child)


func _link_door(door: Door) -> void:
	for room in rooms:
		if room.rect().grow(door.footprint.y * 0.5).has_point(door.global_position):
			var hit := room.nearest_edge(door.global_position)
			door.rooms.append(room)
			room.doors.append(door)
			door.vertical = hit.edge == Room.Edge.LEFT or hit.edge == Room.Edge.RIGHT
	if door.rooms.size() != 2:
		push_warning("%s touches %d rooms; doors should sit on the wall between two rooms." % [door.name, door.rooms.size()])


func _spawn_player() -> void:
	var start := get_node_or_null("PlayerStart") as Node2D
	if start == null:
		push_error("Level '%s' has no Marker2D named PlayerStart." % title)
		return
	player = PLAYER_SCENE.instantiate()
	player.level = self
	player.position = start.global_position
	player.died.connect(fail)
	player.tick_damage.connect(_on_player_tick_damage)
	add_child(player)
	var area := bounds()
	player.camera.zoom = Vector2.ONE * camera_zoom
	player.camera.limit_left = int(area.position.x)
	player.camera.limit_top = int(area.position.y)
	player.camera.limit_right = int(area.end.x)
	player.camera.limit_bottom = int(area.end.y)
	player.camera.reset_smoothing()


## Gives every room a SmokeSurface that draws its smoke.
func _setup_smoke() -> void:
	var config := smoke_config if smoke_config else SmokeConfig.load_default()
	for room in rooms:
		var surface := SmokeSurface.new()
		surface.setup(self, room, config)
		room.add_child(surface)
		_smoke_surfaces[room] = surface


func _on_player_tick_damage(_amount: float) -> void:
	Haptics.play_event(&"tick_damage")


## Darkens the world with a CanvasModulate and gives the player's light its settings.
## The HUD sits on its own CanvasLayer, so it stays unaffected.
func _setup_lighting() -> void:
	var config := lighting if lighting else LightingConfig.load_default()
	if player:
		player.light.apply(config)
	if config.enabled:
		var dark := CanvasModulate.new()
		dark.color = config.darkness
		add_child(dark)


## Everything outside the rooms (gaps between them and the area past the map's edge) is
## plain black instead of the window's clear color.
func _add_void_backdrop() -> void:
	var void_rect := bounds().grow(VOID_MARGIN)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([
		void_rect.position,
		Vector2(void_rect.end.x, void_rect.position.y),
		void_rect.end,
		Vector2(void_rect.position.x, void_rect.end.y),
	])
	backdrop.color = Color.BLACK
	backdrop.z_index = RenderingServer.CANVAS_ITEM_Z_MIN
	add_child(backdrop)


func _check_exits() -> void:
	for object in objects:
		var exit := object as Exit
		if exit and player.global_position.distance_to(exit.global_position) <= exit.reach_radius:
			complete()
			return


## Picks the nearest interactable object within the player's reach.
func _update_focus() -> void:
	var best: GameObject = null
	if player and player.is_active:
		var best_distance := player.interact_range
		for object in objects:
			if object.interaction_prompt() == "":
				continue
			var distance := player.global_position.distance_to(object.global_position)
			if distance < best_distance:
				best = object
				best_distance = distance
	_focus = best
	_highlight.visible = best != null
	if best:
		var target_size := (best as Door).doorway_size() if best is Door else best.footprint
		_highlight.global_position = best.global_position
		_highlight.scale = target_size * 1.15 / _highlight.texture.get_size()
	var text := best.interaction_prompt() if best else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
