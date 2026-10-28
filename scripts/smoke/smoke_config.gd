@tool
class_name SmokeConfig
extends Resource
## How the gas looks, and how strong each gas strength is. The default is
## res://config/smoke.tres, and a Level can use its own through its `smoke_config` property.
## The gas is drawn by a shader (res://scripts/smoke/smoke.gdshader), not from art.
## Apart from the gas strengths and `clear_speed`, these settings only change the visuals.
## Where the gas is, and which strength, is set by the GasZone nodes in each level.

const DEFAULT_PATH := "res://config/smoke.tres"

@export_group("Look")
## Color of the gas body.
@export var color := Palette.VIOLET
## Color of the brightest wisps.
@export var highlight_color := Palette.CHARTREUSE
## How much of the gas is tinted with `highlight_color` (0 = none).
@export_range(0.0, 1.0) var highlight_amount := 0.25
## Opacity of the thickest (Strong) gas.
@export_range(0.0, 1.0) var opacity := 0.85
## World pixels covered by one large billow (a small room is about 1000 wide).
@export var noise_scale := 420.0

@export_group("Motion")
## The whole gas slowly slides in this direction, in world pixels per second.
@export var drift := Vector2(14.0, -8.0)
## How fast the billows change shape.
@export var swirl_speed := 0.08
## How strongly the billows curl into each other.
@export_range(0.0, 3.0) var warp := 1.2

@export_group("Edges")
## How thin gas looks. 0 = it fades out evenly, 1 = it breaks up into ragged wisps.
@export_range(0.0, 1.0) var edge_breakup := 0.5
## Softness of those ragged edges.
@export_range(0.01, 1.0) var edge_softness := 0.25

@export_group("Gas")
## How thick Low, Medium and Strong gas zones are (0 to 1). This is also how dangerous they are:
## the player loses `air_loss_per_second` times this much air per second while inside.
@export_range(0.0, 1.0) var low_density := 0.35
@export_range(0.0, 1.0) var medium_density := 0.65
@export_range(0.0, 1.0) var strong_density := 1.0
## Width in world pixels of the soft fade at a gas zone's edges. Only changes the look.
@export var edge_fade := 0.0
## How fast a running vent clears its room's gas, and how fast the gas returns once it stops:
## the fraction of the gas cleared per second (1 = one second).
@export var clear_speed := 0.5


static func load_default() -> SmokeConfig:
	return load(DEFAULT_PATH)
