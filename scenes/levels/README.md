# Building levels

A level is a Godot scene with the `Level` script on its root. Build it in the editor:

```
Level            (level.gd: title, hint, camera zoom, door flow)
├─ Rooms
│  └─ Office     (instance of scenes/rooms/room.tscn)
├─ Doors
│  └─ Door1      (scenes/entities/door.tscn)
├─ Objects
│  ├─ SmokeSource1, Vent1, Exit1 ...
└─ PlayerStart   (Marker2D)
```

The grouping nodes are only there to keep things tidy. The Level finds rooms, doors and objects
anywhere beneath it.

## Rooms

- **Position** is the room's top-left corner, and **Size** is its width and height.
- Put rooms **edge to edge**: the right edge of one is the left edge of the next.
- Set **Room Name**, a **Background** painting (see `art/README.md`) and **Wall Thickness**.
- **Start Smoke** (0–1) lets a room begin already polluted.

## Mazes

- For interior walls, add a node with the `Maze` script (`scripts/level/maze.gd`) as a child of a
  room at position (0, 0).
- **Layout** is one text line per row: `#` is a wall cell, `.` is floor. **Cell Size** (75) is
  the size of one character in world pixels.
- Keep corridors at least two cells wide, and open the cells in front of each door.
- `level_04.tscn` has four mazes to copy from.

## Doors

- Place a door's centre **on the shared edge** between two rooms. It links itself to both
  rooms, cuts a gap in their walls, and turns itself for vertical walls.
- **Footprint** sets the size: x = opening width, y = wall depth.
- Tick **Start Open** to make it start open.

## Objects

- **Smoke source**: fills its room. Tune `emission_rate`.
- **Vent**: clears its room while running. Tune `extraction_rate`, and use `start_on` to choose
  whether it starts running.
- **Exit**: the level ends when the player reaches it.
- Every object has **Footprint** (art size), **Solid** (blocks the player) and **Hide Art**.

## How smoke works

Each room has one smoke level from 0 to 1. Every open door moves smoke from the smokier room
to the cleaner one (`door_flow` on the Level). Sources add smoke and running vents remove it.
Bigger rooms fill and drain more slowly. Players lose air while their room's smoke is above
their `safe_smoke` level.

On screen, each room's smoke visibly enters where it comes in (sources, and open doors from
smokier rooms), spreads across the room, and leaves through vents and doors to cleaner rooms.
That spreading is visual only: the danger is still the room's single smoke level. To change how
the smoke looks in one level, assign a copy of `config/smoke.tres` to the Level's
**Smoke Config**.

## Adding a level

1. Duplicate an existing level scene in `scenes/levels/`.
2. Add it to **Levels** on the `Main` node in `scenes/main.tscn`. Levels play in that order.
3. Run the checks: `godot --headless --path . res://tests/level_check.tscn`. They verify that
   every door joins two rooms, every object is inside a room, the exit is reachable, the smoke
   spreads and the player can move.

## Adding a new object type

1. Create a script in `scripts/entities/` that extends `GameObject` (start it with `@tool`
   so it previews in the editor). Override what it needs: `current_texture`, `affect_smoke`,
   `interaction_prompt` and `interact`.
2. Create its scene in `scenes/entities/`: a `Node2D` with that script and a `Sprite2D` child
   named `Sprite`.
3. Add a texture slot to `scripts/core/art_theme.gd` and fill it in `art/art_theme.tres`.
