@tool
class_name SmokeConfig
extends Resource
## How the smoke looks and spreads on screen. The default is res://config/smoke.tres, and a
## Level can use its own through its `smoke_config` property. The smoke art itself (the
## tileable animation frames) is `smoke_frames` in res://art/art_theme.tres.
## These settings only change the visuals: how much smoke a room holds, and how dangerous it
## is, is decided by the smoke sources, vents and doors.

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
## Opacity of a room completely full of smoke.
@export_range(0.0, 1.0) var opacity := 0.85
## Width and height in world pixels of one repeat of the tileable texture
## (a room is about 1000 wide).
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

@export_group("Spread")
## Size of one cell of the on-screen density grid, in world pixels. Smaller = finer detail.
@export var cell_size := 50.0
## How fast smoke spreads across a room from where it comes in.
@export var spread_speed := 6.0
## How quickly the drawn amount of smoke catches up with the room's actual smoke level.
@export var fill_speed := 2.0


static func load_default() -> SmokeConfig:
	return load(DEFAULT_PATH)
