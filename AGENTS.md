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

Top-down grid puzzle (GDScript, Godot 4.7): escape a smoke-filled island research facility
by opening and closing doors and switching vents.

- `scripts/core/`: `Palette`, `ArtTheme` and the `Art` autoload (the active art theme).
- `scripts/level/`: `LevelData` (parses `levels/*.txt`), `Level` (grid queries and entity
  spawning), `SmokeField` (smoke diffusion) and `TileLayer` (floor and wall drawing).
- `scripts/entities/`: `Player` and the `GridEntity` subclasses (`Door`, `Vent`,
  `SmokeSource`, `Exit`).
- `scripts/main.gd` / `scenes/main.tscn`: game flow and level order. `scripts/ui/hud.gd`: the HUD.

Conventions:

- Never reference textures from scenes or scripts directly. Add a slot to `ArtTheme`, fill it
  in `art/art_theme.tres` and read it through `Art.theme`. This keeps art swappable
  (see `art/README.md`).
- Levels are text files. See `levels/README.md` for the format and for adding new object types.
- Run `godot --headless --path . res://tests/level_check.tscn` after changing levels or gameplay.
