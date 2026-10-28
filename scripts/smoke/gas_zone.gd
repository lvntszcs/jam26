@tool
class_name GasZone
extends Node2D
## A patch of toxic gas. Add it anywhere under a Level (in the level's scene or on the Level in
## main.tscn), with the node's position as the top-left corner, and pick its `size` and
## `strength`. Gas never moves or spreads: it stays where it is placed, a running Vent in the
## same room clears it, and it comes back once that vent is switched off.

enum Strength { LOW, MEDIUM, STRONG }

const SHADER := preload("res://scripts/smoke/smoke.gdshader")
## World pixels per texel of the edge-fade mask.
const MASK_STEP := 20.0
const LABELS := ["Low gas", "Medium gas", "Strong gas"]

@export var strength := Strength.MEDIUM:
	set(value):
		strength = value
		_refresh()
@export var size := Vector2(600, 400):
	set(value):
		size = value
		_refresh()

## The room this zone's center is in; its vents clear the zone. Set by the Level.
var room: Room
## 0 = full gas, 1 = completely cleared by a vent.
var cleared := 0.0
var _config: SmokeConfig
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.z_index = 3
	add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)
	_refresh()


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
		var node := get_parent()
		while node and not node is Level:
			node = node.get_parent()
		# get() rather than .smoke_config: in the editor the Level's script doesn't run.
		var level_config: SmokeConfig = node.get("smoke_config") if node else null
		_config = level_config if level_config else SmokeConfig.load_default()
	return _config


## Rebuilds the density mask and material after the size or strength changes.
func _refresh() -> void:
	queue_redraw()
	if _sprite == null:
		return
	var settings := _settings()
	var texels := Vector2i(maxi(1, ceili(size.x / MASK_STEP)), maxi(1, ceili(size.y / MASK_STEP)))
	var mask := Image.create(texels.x, texels.y, false, Image.FORMAT_L8)
	var value := _strength_density()
	for y in texels.y:
		for x in texels.x:
			var point := (Vector2(x, y) + Vector2(0.5, 0.5)) * size / Vector2(texels)
			var edge := minf(minf(point.x, size.x - point.x), minf(point.y, size.y - point.y))
			var fade := 1.0 if settings.edge_fade <= 0.0 else smoothstep(0.0, settings.edge_fade, edge)
			mask.set_pixel(x, y, Color(value * fade, 0.0, 0.0))
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
