# Level format

Each level is a plain text file. Lines starting with `;` are `key: value` headers, and the
rest is the map, one character per grid cell.

```
; title: 01 - Containment Breach
; hint: Text shown at the bottom of the screen.
#########
#..P..d.#
#.....#S#
####D####
#......E#
#########
```

| Char | Meaning |
|------|---------|
| `#` | Wall |
| `.` | Floor |
| ` ` (space) | Nothing (outside the facility) |
| `P` | Player start (exactly one) |
| `D` / `d` | Door, closed / open |
| `V` / `v` | Vent, running / off. A running vent removes smoke from its cell and clears the area around it. |
| `S` | Smoke source |
| `E` | Exit (escape hatch) |

Rules of thumb:

- Put doors in a gap between two walls. A door figures out on its own whether it sits in a
  horizontal or a vertical wall.
- Vents, smoke sources and closed doors block movement. To interact with a vent or door, the
  player has to stand next to it and face it, so leave a free floor cell beside each one.
- Smoke spreads through floor, open doors, vents and sources. Walls and closed doors stop it.

## Adding a level

1. Create `levels/level_NN.txt`.
2. Add it to `Level Files` on the `Main` node in `scenes/main.tscn`. Levels play in that order.
3. Run the checks: `godot --headless --path . res://tests/level_check.tscn`
   (this verifies that the exit can be reached, the smoke spreads, and the doors work).

## Adding a new object type

1. Create a script extending `GridEntity` in `scripts/entities/`, and override what it needs:
   `blocks_movement`, `blocks_smoke`, `modify_smoke`, `interaction_prompt`, `interact`,
   `on_player_entered`, `refresh_visual`.
2. Create its scene in `scenes/entities/`: a `Node2D` with that script and a `Sprite2D` child
   named `Sprite`.
3. Add a texture slot to `scripts/core/art_theme.gd` and fill it in `art/art_theme.tres`.
4. Map a character to it in `LEGEND` in `scripts/level/level.gd`.

## Exporting

Level files are plain `.txt`, so Godot won't pack them by default. In the export preset, under
**Resources → Filters to export non-resource files**, add `levels/*.txt`.
