@tool
class_name ArtTheme
extends Resource
## Maps every shared visual in the game to a texture. Room paintings are not here: each Room
## node has its own `background`.
## The active theme is res://art/art_theme.tres. See art/README.md for how to swap art.
## Textures can be any resolution. Each object fits its art into its own `footprint`.

const ACTIVE_PATH := "res://art/art_theme.tres"

@export_group("Player")
## The player seen from above, as a grid of equally sized frames, read left to right and
## top to bottom (frame 0 is the top-left). The sprite is rotated to face where it walks.
@export var player_sheet: Texture2D
@export var player_sheet_columns := 2
@export var player_sheet_rows := 2
## Frame shown while standing still.
@export var player_idle_frame := 0
## Frames of the walk cycle, in playback order.
@export var player_walk_frames := PackedInt32Array([0, 1, 2, 3])
## Walk-cycle frames per second at full walking speed.
@export var player_walk_fps := 8.0
## Which way the character faces in the art, in degrees: -90 = up, 0 = right, 90 = down.
@export var player_art_angle := -90.0

@export_group("Objects")
## Drawn for a door in a horizontal wall; rotated 90 degrees for vertical walls.
@export var door_closed: Texture2D
@export var door_open: Texture2D
@export var vent_on: Texture2D
@export var vent_off: Texture2D
@export var smoke_source: Texture2D
@export var exit: Texture2D

@export_group("Effects")
## One smoke puff. Keep it white/grey and set the color with smoke_tint,
## or paint it in color and set smoke_tint to white.
@export var smoke: Texture2D
@export var smoke_tint := Palette.VIOLET
## Opacity of a single puff in a room full of smoke. Puffs overlap, so keep this low.
@export_range(0.0, 1.0) var smoke_max_alpha := 0.5
## Drawn around the object the player can interact with.
@export var highlight: Texture2D


## Holds the active theme. Godot's resource cache only keeps weak references, so without this
## every active() call would reload the theme and all its textures from disk.
static var _active: ArtTheme


static func active() -> ArtTheme:
	if _active == null:
		_active = load(ACTIVE_PATH)
	return _active
