@tool
class_name ArtTheme
extends Resource
## Maps every shared visual in the game to a texture. A Room can override the default room
## background with its own `background` painting.
## The active theme is res://art/art_theme.tres. See art/README.md for how to swap art.
## Textures can be any resolution. Each object fits its art into its own `footprint`.

const ACTIVE_PATH := "res://art/art_theme.tres"

## Frames cut out of smoke sheets, keyed by sheet and layout, so each sheet is sliced only once.
static var _sliced_sheets := {}

@export_group("Rooms")
## Painting used for every room that has no `background` of its own. It's stretched over the
## room, so it looks best on rooms with the same aspect ratio (1000x700 for a 2000x1400 image).
@export var room_background: Texture2D

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

@export_group("Smoke")
## All smoke animation frames in one image: a grid of equally sized cells, numbered left to
## right, top to bottom (0 = top-left). Each frame must tile seamlessly: its left edge continues
## its right edge, and its top continues its bottom. Used instead of `smoke_frames` when set.
## Color, size on screen, speed and edges are set in res://config/smoke.tres.
@export var smoke_sheet: Texture2D
@export var smoke_sheet_columns := 2
@export var smoke_sheet_rows := 2
## Which cells of the sheet are frames, in playback order. Other cells are ignored.
@export var smoke_sheet_frames := PackedInt32Array([0, 1])
## The same frames as separate images, played in order and looped.
## Only used when `smoke_sheet` is empty.
@export var smoke_frames: Array[Texture2D] = []
## Optional tileable mask that decides where thinning smoke breaks up: the most opaque areas
## of the mask (and of the frames themselves, such as outlines) stay longest. Use it when the
## frames have large evenly opaque areas, so thin smoke gets ragged edges instead of a flat fade.
## Leave it empty to use the frames' own transparency instead.
@export var smoke_edge_mask: Texture2D

@export_group("Effects")
## Drawn around the object the player can interact with.
@export var highlight: Texture2D


## Holds the active theme. Godot's resource cache only keeps weak references, so without this
## every active() call would reload the theme and all its textures from disk.
static var _active: ArtTheme


static func active() -> ArtTheme:
	if _active == null:
		_active = load(ACTIVE_PATH)
	return _active


## The smoke animation frames, cut from `smoke_sheet` if it is set, otherwise `smoke_frames`.
## Sheet frames become separate textures (with mipmaps) so the shader can repeat each one.
func smoke_animation_frames() -> Array[Texture2D]:
	if smoke_sheet == null:
		return smoke_frames.duplicate()
	var key := "%s|%d|%d|%s" % [smoke_sheet.get_rid(), smoke_sheet_columns, smoke_sheet_rows, smoke_sheet_frames]
	if not _sliced_sheets.has(key):
		var sheet := smoke_sheet.get_image()
		if sheet.is_compressed():
			sheet.decompress()
		var cell := Vector2i(sheet.get_width() / smoke_sheet_columns, sheet.get_height() / smoke_sheet_rows)
		var frames: Array[Texture2D] = []
		for index in smoke_sheet_frames:
			var origin := Vector2i(index % smoke_sheet_columns, index / smoke_sheet_columns) * cell
			var frame := sheet.get_region(Rect2i(origin, cell))
			frame.generate_mipmaps()
			frames.append(ImageTexture.create_from_image(frame))
		_sliced_sheets[key] = frames
	return _sliced_sheets[key]
