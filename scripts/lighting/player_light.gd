class_name PlayerLight
extends PointLight2D
## The light the player carries. Its shape, color, flicker and shadows come from a
## LightingConfig, applied by the Level.

const TEXTURE_SIZE := 512

var config: LightingConfig
var _time := 0.0


func apply(target: LightingConfig) -> void:
	config = target
	enabled = config.enabled
	color = config.color
	energy = config.energy
	shadow_enabled = config.shadows
	shadow_color = config.shadow_color
	shadow_filter = PointLight2D.SHADOW_FILTER_PCF5 if config.shadow_smooth > 0.0 else PointLight2D.SHADOW_FILTER_NONE
	shadow_filter_smooth = config.shadow_smooth
	texture = _make_falloff(config.softness)
	texture_scale = config.radius * 2.0 / TEXTURE_SIZE


func _process(delta: float) -> void:
	if config == null or config.flicker_amount == 0.0:
		return
	_time += delta * config.flicker_speed
	# Two out-of-step waves read as an irregular flicker rather than a pulse.
	var wobble := sin(_time * TAU) * 0.6 + sin(_time * TAU * 2.37 + 1.3) * 0.4
	energy = config.energy * (1.0 + wobble * config.flicker_amount)


## A white-to-black radial gradient: fully lit inside, fading out over `softness` of the radius.
func _make_falloff(softness: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.BLACK)
	gradient.set_offset(0, clampf(1.0 - softness, 0.0, 0.999))
	var falloff := GradientTexture2D.new()
	falloff.gradient = gradient
	falloff.fill = GradientTexture2D.FILL_RADIAL
	falloff.fill_from = Vector2(0.5, 0.5)
	falloff.fill_to = Vector2(0.5, 0.0)
	falloff.width = TEXTURE_SIZE
	falloff.height = TEXTURE_SIZE
	return falloff
