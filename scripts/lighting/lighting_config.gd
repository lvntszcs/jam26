@tool
class_name LightingConfig
extends Resource
## Settings for the player's local illumination: everything outside a soft circle around the
## player is dark. The default is res://config/lighting.tres. A Level can use its own
## LightingConfig through its `lighting` property.

const DEFAULT_PATH := "res://config/lighting.tres"

## Turn local illumination off to see the whole level (handy while building levels).
@export var enabled := true
## Color the world is tinted with outside the light. Black hides everything, and lighter
## colors leave the room faintly visible.
@export var darkness := Color(0.06, 0.0, 0.025, 1.0)

@export_group("Player light")
## Radius of the lit area, in world pixels.
@export_range(16.0, 4000.0) var radius := 300.0
## How much of the radius fades out: 0 = hard edge, 1 = fades from the centre.
@export_range(0.0, 1.0) var softness := 0.55
@export var color := Palette.CREAM
@export_range(0.0, 4.0) var energy := 0.85

@export_group("Flicker")
## How much the light's brightness wobbles (0 = steady).
@export_range(0.0, 1.0) var flicker_amount := 0.06
## Flicker speed in wobbles per second.
@export var flicker_speed := 7.0

@export_group("Blackout")
## The light goes out now and then, at a random time between these two (seconds).
## Set the duration to 0 to turn blackouts off.
@export var blackout_interval_min := 10.0
@export var blackout_interval_max := 20.0
## How long the light stays out, in seconds.
@export var blackout_duration := 0.5

@export_group("Shadows")
## Walls and closed doors block the light, so other rooms stay dark.
@export var shadows := true
@export var shadow_color := Color(0.0, 0.0, 0.0, 1.0)
## Blur of shadow edges in pixels (0 = sharp).
@export_range(0.0, 20.0) var shadow_smooth := 4.0


static func load_default() -> LightingConfig:
	return load(DEFAULT_PATH)
