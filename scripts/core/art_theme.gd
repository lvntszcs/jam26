class_name ArtTheme
extends Resource
## Maps every visual slot in the game to a texture.
## The active theme is res://art/art_theme.tres - see art/README.md for how to swap art.
## Textures of any resolution are scaled to fit one tile, so art can be drawn at any size.

## Size of one grid cell in world pixels.
@export var tile_size := 32

@export_group("Tiles")
@export var floor_tile: Texture2D
@export var wall_tile: Texture2D

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
## One smoke puff, drawn per cell. Keep it white/grey and set the color with smoke_tint,
## or paint it in color and set smoke_tint to white.
@export var smoke: Texture2D
@export var smoke_tint := Palette.VIOLET
@export_range(0.0, 1.0) var smoke_max_alpha := 0.8
## Drawn over the cell the player can interact with.
@export var highlight: Texture2D
