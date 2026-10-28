class_name PlayerLight
extends PointLight2D
## The light the player carries. Its shape, color, flicker and shadows come from a
## LightingConfig, applied by the Level.

const TEXTURE_SIZE := 512

var config: LightingConfig
var _time := 0.0
var _until_blackout := 0.0
var _blackout_left := 0.0


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
	_schedule_blackout()


func is_blacked_out() -> bool:
	return _blackout_left > 0.0


func _process(delta: float) -> void:
	if config == null:
		return
	if config.blackout_duration > 0.0:
		if _blackout_left > 0.0:
			_blackout_left -= delta
			if _blackout_left <= 0.0:
				_schedule_blackout()
		else:
			_until_blackout -= delta
			if _until_blackout <= 0.0:
				_blackout_left = config.blackout_duration
	if is_blacked_out():
		energy = 0.0
		return
	_time += delta * config.flicker_speed
	# Two out-of-step waves read as an irregular flicker rather than a pulse.
	var wobble := sin(_time * TAU) * 0.6 + sin(_time * TAU * 2.37 + 1.3) * 0.4
	energy = config.energy * (1.0 + wobble * config.flicker_amount)


func _schedule_blackout() -> void:
	_until_blackout = randf_range(config.blackout_interval_min, config.blackout_interval_max)


## How strongly the light reaches a global point, 0..1: the same falloff curve as the
## light texture, times the current (flickering) energy, and 0 when a wall or closed door
## is in the way. `exclude` lists collision bodies to see through (e.g. the target itself).
func brightness_at(point: Vector2, exclude: Array[RID] = []) -> float:
	if config == null or not enabled:
		return 1.0
	var level := falloff(global_position.distance_to(point) / config.radius, config.softness)
	if level <= 0.0:
		return 0.0
	if config.shadows:
		var query := PhysicsRayQueryParameters2D.create(global_position, point)
		query.exclude = exclude
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return 0.0
	return level * energy


## Light falloff at `t` = distance / radius: full inside, then an eased fade over the outer
## `softness` of the radius whose long dim tail avoids a visible cut-off edge.
static func falloff(t: float, softness: float) -> float:
	var inner := clampf(1.0 - softness, 0.0, 0.999)
	if t <= inner:
		return 1.0
	var u := clampf((t - inner) / (1.0 - inner), 0.0, 1.0)
	return pow(1.0 - u, 2.0) * (1.0 + 2.0 * u)


## A white-to-black radial gradient sampled from `falloff()`.
func _make_falloff(softness: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	var steps := 16
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in steps + 1:
		var t := float(i) / steps
		offsets.append(t)
		var v := falloff(t, softness)
		colors.append(Color(v, v, v))
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = TEXTURE_SIZE
	tex.height = TEXTURE_SIZE
	return tex
