@tool
class_name SmokeConfig
extends Resource
## How the smoke looks and spreads on screen. The default is res://config/smoke.tres, and a
## Level can use its own through its `smoke_config` property. The smoke art itself (the
## tileable animation frames) is `smoke_frames` in res://art/art_theme.tres.
## Apart from the gas strengths and `clear_speed`, these settings only change the visuals.
## Where the gas is, and which strength, is set by the GasZone nodes in each level.

const DEFAULT_PATH := "res://config/smoke.tres"

enum AlphaSource {
	## Use the texture's own transparency (for frames painted on a transparent background).
	ALPHA,
	## Use the texture's brightness (for frames painted white-on-black with no transparency).
	LUMINANCE,
}

@export_group("Look")
## Multiplied with the frames' colors. Use white for frames that are already colored.
@export var tint := Palette.VIOLET
## Opacity of the thickest (Strong) gas.
@export_range(0.0, 1.0) var opacity := 0.85
## Multiplies how opaque the frames are, as painted. 1 = as painted, 2 = twice as opaque
## (anything already half opaque becomes solid). Raise it when the smoke looks too see-through.
@export_range(0.0, 4.0) var thickness := 1.0
## Width and height in world pixels of one repeat of the tileable texture
## (a small room is about 1000 wide).
@export var tile_size := 360.0
## Which channel of the frames says how thick the smoke is.
@export var alpha_source := AlphaSource.ALPHA

@export_group("Animation")
## Animation frames shown per second.
@export var frame_rate := 3.0
## 0 = frames swap instantly (hand-drawn "boil"), 1 = each frame fades smoothly into the next.
@export_range(0.0, 1.0) var crossfade := 0.25
## The texture slowly slides in this direction, in world pixels per second.
@export var drift := Vector2(14.0, -8.0)

@export_group("Edges")
## How thin smoke looks. 0 = it fades out evenly, 1 = it breaks up along the texture's own
## shapes, so the edge of a cloud is ragged instead of a soft fade.
@export_range(0.0, 1.0) var edge_breakup := 0.7
## Softness of those ragged edges.
@export_range(0.01, 1.0) var edge_softness := 0.25
## World size of one repeat of the ArtTheme's `smoke_edge_mask`, if there is one.
@export var edge_mask_size := 300.0

@export_group("Gas")
## How thick Low, Medium and Strong gas zones are (0 to 1). This is also how dangerous they are:
## the player loses `air_loss_per_second` times this much air per second while inside.
@export_range(0.0, 1.0) var low_density := 0.35
@export_range(0.0, 1.0) var medium_density := 0.65
@export_range(0.0, 1.0) var strong_density := 1.0
## Width in world pixels of the soft fade at a gas zone's edges. Only changes the look.
@export var edge_fade := 80.0
## How fast a running vent clears its room's gas, and how fast the gas returns once it stops:
## the fraction of the gas cleared per second (1 = one second).
@export var clear_speed := 0.5


static func load_default() -> SmokeConfig:
	return load(DEFAULT_PATH)
