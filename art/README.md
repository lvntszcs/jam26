# Art guide

All in-game visuals come from one resource: **`art/art_theme.tres`** (an `ArtTheme`).
No scene or script points at an image directly, so swapping art never needs code changes.

## Replacing art

Pick whichever is easier:

1. **Overwrite a placeholder.** Save your image over the file with the same name in
   `art/placeholder/` (e.g. `door_closed.png`). Godot re-imports it automatically.
2. **Point the theme at a new file.** Put your image anywhere (e.g. `art/final/door_closed.png`),
   open `art/art_theme.tres` in the Godot inspector and drag it into the matching slot.

Any resolution works. Every texture is scaled so its **width fills one tile** (`tile_size`,
32 world pixels by default). Square images look best. Taller images (like a character) stay
centred on their cell and stick out above and below it.

## Slots

| Slot | Placeholder | Notes |
|------|-------------|-------|
| `floor_tile` | `floor.png` | Drawn under every non-wall cell, including the cells under doors, vents and the exit. |
| `wall_tile` | `wall.png` | |
| `player_down` / `player_up` | `player_down.png` / `player_up.png` | |
| `player_side` | `player_side.png` | Draw it facing **right**. It's flipped for left. |
| `door_closed` / `door_open` | `door_*.png` | Draw it for a **horizontal** wall (walls on its left and right). It's rotated 90° in vertical walls. Use transparency so the floor shows through. |
| `vent_on` / `vent_off` | `vent_*.png` | A running vent spins its sprite. Set `spin_speed = 0` in `scenes/entities/vent.tscn` to stop that. |
| `smoke_source` | `smoke_source.png` | Pulses. Tune `pulse_amount` in `scenes/entities/smoke_source.tscn`. |
| `exit` | `exit.png` | The escape hatch. |
| `smoke` | `smoke.png` | One soft puff, drawn once per cell and slightly larger than it so puffs blend. Keep it **white or grey** and set the color with `smoke_tint`, or paint it in color and set `smoke_tint` to white. `smoke_max_alpha` sets how thick the densest smoke looks. |
| `highlight` | `highlight.png` | Drawn over the object the player can interact with. |

## Pixel art vs. smooth art

The project uses **nearest-neighbour** filtering (crisp pixels). This is set under
Project Settings → Rendering → Textures → Canvas Textures → Default Texture Filter.
For painted, high-resolution art, set it to *Linear*. Smoke is always drawn with linear filtering.

## Animation

Each object scene (`scenes/entities/*.tscn`) has a plain `Sprite2D` named `Sprite`. To animate
one, replace that node with an `AnimatedSprite2D` or add an `AnimationPlayer`, and update the
`refresh_visual()` function in the matching script under `scripts/entities/`.

## UI

HUD colors, fonts and boxes live in `art/ui_theme.tres` (a regular Godot `Theme`). To add a
custom font, set *Default Font* on that theme.

## Palette

Stick to the project palette (see `AGENTS.md`, also available in code as `Palette.*`):
`#349189` `#f1fdd9` `#d3fe28` `#c94b01` `#406635` `#400116` `#9625fd` `#a9ff00`.
