@tool
class_name ArtTheme
extends Resource
## Maps every shared visual in the game to a texture. Room paintings are not here: each Room
## node has its own `background`.
## The active theme is res://art/art_theme.tres. See art/README.md for how to swap art.
## Textures can be any resolution. Each object fits its art into its own `footprint`.

const ACTIVE_PATH := "res://art/art_theme.tres"

@export_group("Player")
@export var player_down: Texture2D
@export var player_up: Texture2D
## Facing right. Flipped horizontally for facing left.
@export var player_side: Texture2D

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


static func active() -> ArtTheme:
	return load(ACTIVE_PATH)
