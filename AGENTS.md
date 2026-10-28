# AGENTS.md

Guidelines for AI agents working on this Godot project.

## Git workflow

- Always create a new feature branch for any change (e.g. `feature/<short-description>`).
- Never commit directly to `main`.

## Color palette

Use these colors as the main color palette for all visuals (UI, art, materials, effects):

| Hex       |
|-----------|
| `#349189` |
| `#f1fdd9` |
| `#d3fe28` |
| `#c94b01` |
| `#406635` |
| `#400116` |
| `#9625fd` |
| `#a9ff00` |

In code, use the constants in `scripts/core/palette.gd` (`Palette.TEAL`, `Palette.VIOLET`, ...).

## Project structure

Top-down puzzle (GDScript, Godot 4.7) with free movement: escape a smoke-filled island research
facility by opening and closing doors and switching vents. Each room is one painted image
(target style: `art/rooms/lab_reference.webp`).

- `scripts/core/`: `Palette` and `ArtTheme` (shared sprites; `ArtTheme.active()`).
- `scripts/level/`: `Level` (finds rooms, doors and objects, links doors, runs the per-room smoke
  simulation and interactions) and `Room` (painting, generated walls with door gaps).
- `scripts/smoke/`: `SmokeConfig` (look and spread settings, default `config/smoke.tres`, per-level
  override via `Level.smoke_config`), `SmokeSurface` (one per room: a coarse density grid that
  spreads smoke from entry points and drives `smoke.gdshader`, which tiles the ArtTheme's smoke
  frames, sliced from `smoke_sheet` by `ArtTheme.smoke_animation_frames()`, plus the optional
  `smoke_edge_mask`). Gameplay smoke is still one level per room, and the grid only places it on screen.
- `scripts/lighting/`: `LightingConfig` (settings, default `config/lighting.tres`, per-level override
  via `Level.lighting`), `PlayerLight` (the player's PointLight2D) and `Lighting` (occluder helpers).
  Walls and closed doors get `LightOccluder2D`s.
- `scripts/entities/`: `Player` (CharacterBody2D) and the `GameObject` subclasses (`Door`, `Vent`,
  `SmokeSource`, `Exit`).
- `scenes/levels/`: one scene per level, built in the editor. `scenes/main.tscn` sets the level
  order. `scripts/ui/hud.gd`: the HUD.

Conventions:

- Never reference shared textures from scenes or scripts directly. Add a slot to `ArtTheme`,
  fill it in `art/art_theme.tres` and read it through `ArtTheme.active()`. Room paintings go in
  the Room's `background`. See `art/README.md`.
- Size art through `footprint`, never by assuming a texture's resolution.
- Entity and room scripts are `@tool` so levels preview in the editor. Guard runtime-only code
  with `Engine.is_editor_hint()`.
- See `scenes/levels/README.md` for building levels and adding object types.
- Avoid mixing `draw_rect` and `draw_texture_rect` in one `_draw()`. On this setup the textures
  then render as solid squares, so use `Sprite2D` nodes for textured effects.
- Run `godot --headless --path . res://tests/level_check.tscn` after changing levels or gameplay.
