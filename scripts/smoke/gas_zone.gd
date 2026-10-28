@tool
class_name GasZone
extends Node2D
## A patch of toxic gas. Add it anywhere under a Level (in the level's scene or on the Level in
## main.tscn), with the node's position as the top-left corner, and pick its `size` and
## `strength`. Gas never moves or spreads: it stays where it is placed, a running Vent in the
## same room clears it, and it comes back once that vent is switched off.
## Where zones touch, their gas blends from one strength into the other over `blend_width`
## (in the smoke settings); only the look blends, the danger switches right at the edge.

enum Strength { LOW, MEDIUM, STRONG }

const SHADER := preload("res://scripts/smoke/smoke.gdshader")
## World pixels per texel of the density mask.
const MASK_STEP := 20.0
const LABELS := ["Low gas", "Medium gas", "Strong gas"]

@export var strength := Strength.MEDIUM:
	set(value):
		strength = value
		_refresh_level()
@export var size := Vector2(600, 400):
	set(value):
		size = value
		_refresh_level()

## The room this zone's center is in; its vents clear the zone. Set by the Level.
var room: Room
## 0 = full gas, 1 = completely cleared by a vent.
var cleared := 0.0
var _config: SmokeConfig
var _sprite: Sprite2D
## True while a refresh of every zone in the level is waiting for the end of the frame.
static var _level_refresh_queued := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Above the player (4) and doors (2), so the player walks inside the gas.
	_sprite.z_index = 5
	add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		set_notify_transform(true)
	_refresh()


func _notification(what: int) -> void:
	# Moving a zone in the editor changes how it and its old and new neighbours blend.
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_refresh_level()


func rect() -> Rect2:
	return Rect2(global_position, size)


func contains(point: Vector2) -> bool:
	return rect().has_point(point)


## How thick the gas is right now, 0 to 1. The player loses air in proportion to it.
func density() -> float:
	return _strength_density() * (1.0 - cleared)


## Called by the Level every physics frame.
func step(delta: float, vent_running: bool) -> void:
	cleared = move_toward(cleared, 1.0 if vent_running else 0.0, _settings().clear_speed * delta)
	_sprite.material.set_shader_parameter("amount", 1.0 - cleared)


## The strongest of these zones' densities at a point, or -1 if none of them covers it.
func _density_at(zones: Array, point: Vector2) -> float:
	var result := -1.0
	for zone: GasZone in zones:
		if zone.contains(point):
			result = maxf(result, zone._strength_density())
	return result


func _strength_density() -> float:
	var settings := _settings()
	match strength:
		Strength.LOW:
			return settings.low_density
		Strength.MEDIUM:
			return settings.medium_density
	return settings.strong_density


## The owning Level's smoke settings, or the default ones.
func _settings() -> SmokeConfig:
	if _config == null:
		var level := _level_node()
		# get() rather than .smoke_config: in the editor the Level's script doesn't run.
		var level_config: SmokeConfig = level.get("smoke_config") if level else null
		_config = level_config if level_config else SmokeConfig.load_default()
	return _config


## The Level this zone belongs to (a plain node in the editor), or null.
func _level_node() -> Node:
	var node := get_parent()
	while node and not node is Level:
		node = node.get_parent()
	return node


## Every Room in the same level.
func _level_rooms() -> Array[Room]:
	var rooms: Array[Room] = []
	var level := _level_node()
	if level:
		for node in level.find_children("*", "Node2D", true, false):
			if node is Room:
				rooms.append(node)
	return rooms


## Whether two points are inside the same room.
func _same_room(rooms: Array[Room], a: Vector2, b: Vector2) -> bool:
	for room in rooms:
		if room.contains(a):
			return room.contains(b)
	return false


## Every gas zone in the same level, including this one.
func _level_zones() -> Array[GasZone]:
	var zones: Array[GasZone] = []
	var level := _level_node()
	if level == null:
		zones.append(self)
		return zones
	for node in level.find_children("*", "Node2D", true, false):
		if node is GasZone:
			zones.append(node)
	return zones


## Rebuilds every zone in the level once at the end of the frame, so neighbours blend again.
func _refresh_level() -> void:
	if not is_inside_tree():
		return
	if not Engine.is_editor_hint():
		_refresh()
		return
	if _level_refresh_queued:
		return
	_level_refresh_queued = true
	(func() -> void:
		_level_refresh_queued = false
		if is_inside_tree():
			for zone in _level_zones():
				zone._refresh()
	).call_deferred()


## Rebuilds the density mask and material after the size or strength changes.
func _refresh() -> void:
	queue_redraw()
	if _sprite == null:
		return
	var settings := _settings()
	var area := rect()
	var neighbours := _level_zones().filter(func(zone: GasZone) -> bool:
		return zone != self and zone.rect().intersects(area.grow(1.0)))
	var rooms := _level_rooms()
	var texels := Vector2i(maxi(1, ceili(size.x / MASK_STEP)), maxi(1, ceili(size.y / MASK_STEP)))
	var mask := Image.create(texels.x, texels.y, false, Image.FORMAT_L8)
	var value := _strength_density()
	for y in texels.y:
		for x in texels.x:
			var local := (Vector2(x, y) + Vector2(0.5, 0.5)) * size / Vector2(texels)
			var point := area.position + local
			var density := value
			var fade := 1.0
			# Each side: blend toward the zone across it. With no zone there, fade out only if the
			# other side is open floor of the same room; at a wall the gas stays thick.
			var sides := [
				[local.x, Vector2(area.position.x - 1.0, point.y)],
				[size.x - local.x, Vector2(area.end.x + 1.0, point.y)],
				[local.y, Vector2(point.x, area.position.y - 1.0)],
				[size.y - local.y, Vector2(point.x, area.end.y + 1.0)],
			]
			for side in sides:
				var distance: float = side[0]
				var across := _density_at(neighbours, side[1])
				if across >= 0.0:
					if distance < settings.blend_width:
						# Half way to the neighbour's density at the edge, where the neighbour
						# does the same from its side, so both meet at the same value.
						density += (across - value) * 0.5 * (1.0 - smoothstep(0.0, settings.blend_width, distance))
				elif settings.edge_fade > 0.0 and _same_room(rooms, point, side[1]):
					fade = minf(fade, smoothstep(0.0, settings.edge_fade, distance))
			mask.set_pixel(x, y, Color(clampf(density * fade, 0.0, 1.0), 0.0, 0.0))
	_sprite.texture = ImageTexture.create_from_image(mask)
	_sprite.scale = size / Vector2(texels)

	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("color", settings.color)
	shader_material.set_shader_parameter("highlight_color", settings.highlight_color)
	shader_material.set_shader_parameter("highlight_amount", settings.highlight_amount)
	shader_material.set_shader_parameter("opacity", settings.opacity)
	shader_material.set_shader_parameter("noise_scale", settings.noise_scale)
	shader_material.set_shader_parameter("drift", settings.drift)
	shader_material.set_shader_parameter("swirl_speed", settings.swirl_speed)
	shader_material.set_shader_parameter("warp", settings.warp)
	shader_material.set_shader_parameter("edge_breakup", settings.edge_breakup)
	shader_material.set_shader_parameter("edge_softness", settings.edge_softness)
	shader_material.set_shader_parameter("amount", 1.0 - cleared)
	_sprite.material = shader_material


## In the editor, outlines the zone and names its strength so it's easy to find and select.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var colors := [Palette.LIME, Palette.RUST, Palette.VIOLET]
	var color: Color = colors[strength]
	draw_rect(Rect2(Vector2.ZERO, size), color, false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(12, 32), LABELS[strength], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
