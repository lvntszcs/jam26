extends Node
## Autoload "Art": gives every node access to the active ArtTheme.

const THEME_PATH := "res://art/art_theme.tres"

var theme: ArtTheme = load(THEME_PATH)


## Assigns a texture to a sprite and scales it so its width fills exactly one tile.
func apply(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	if texture:
		sprite.scale = Vector2.ONE * (float(theme.tile_size) / texture.get_width())
