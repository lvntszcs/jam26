# Building levels

A level is a Godot scene with the `Level` script on its root. Build it in the editor:

```
Level            (level.gd: title, hint, camera zoom)
├─ Rooms
│  └─ Office     (instance of scenes/rooms/room.tscn)
├─ Doors
│  └─ Door1      (scenes/entities/door.tscn)
├─ Gas
│  └─ LabGas     (GasZone: strength and size)
├─ Objects
│  ├─ Vent1, Exit1 ...
└─ PlayerStart   (Marker2D)
```

The grouping nodes are only there to keep things tidy. The Level finds rooms, doors, gas zones
and objects anywhere beneath it.

## Rooms

- **Position** is the room's top-left corner, and **Size** is its width and height.
- Put rooms **edge to edge**: the right edge of one is the left edge of the next.
- Set **Room Name**, a **Background** painting (see `art/README.md`) and **Wall Thickness**.

## Mazes

- For interior walls, add a node with the `Maze` script (`scripts/level/maze.gd`) as a child of a
  room at position (0, 0).
- **Layout** is one text line per row: `#` is a wall cell, `.` is floor. **Cell Size** (75) is
  the size of one character in world pixels.
- Keep corridors at least two cells wide, and open the cells in front of each door.
- `level_04.tscn` has three mazes to copy from.
- **From Painting** builds the walls from the room's painting instead: every transparent cell is
  a wall, and nothing extra is drawn. Paint the corridors on a transparent background, so the
  painting shows exactly where the player can go (see the vent duct, `EastMaze` in
  `level_04.tscn`, with a Cell Size of 25). Corridors and doors must line up with the painted
  floor.

## Crawl spaces

- Tick **Crawl Space** on a Room (like the vent duct) and the player crawls there instead of
  walking, using the ArtTheme's `player_crawl_sheet`.

## Doors

- Place a door's centre **on the shared edge** between two rooms. It links itself to both
  rooms, cuts a gap in their walls, and turns itself for vertical walls.
- **Footprint** sets the size: x = opening width, y = wall depth.
- Tick **Start Open** to make it start open.

## Objects

- **Vent**: clears every gas zone in its room while running. Use `start_on` to choose whether it
  starts running.
- **Exit**: the level ends when the player reaches it.
- Every object has **Footprint** (art size), **Solid** (blocks the player) and **Hide Art**.

## Gas

Gas never moves or spreads. It sits in **gas zones**, each with one of three strengths:

1. Add a **GasZone** node (Add Child Node → GasZone) anywhere under the Level. In `main.tscn`,
   select the placed **Level** and add it there. That works without opening the level scene,
   and restarting keeps it.
2. Its **position** is the top-left corner. Set **Size** and **Strength** (Low, Medium or
   Strong). In the editor the zone shows the gas itself, with an outline and its strength
   (lime = Low, rust = Medium, violet = Strong).
3. Zones may overlap; the strongest one counts. Where zones touch, the gas blends from one
   strength into the other over `blend_width` (only the look: the danger changes right at the
   edge). The gas draws over the player.

A running **Vent** clears every zone whose centre is in its room, and the gas comes back when it
is switched off. Doors only block the way.

How thick and how dangerous each strength is (`low_density`, `medium_density`,
`strong_density`), and how fast vents clear the gas (`clear_speed`), are in
`config/smoke.tres`. The player loses `air_loss_per_second` × that density per second while
it is above their `safe_smoke` level. To change them for one level, assign a copy of
`config/smoke.tres` to the Level's **Smoke Config**.

## Adding a level

1. Duplicate an existing level scene in `scenes/levels/`.
2. Add it to **Levels** on the `Main` node in `scenes/main.tscn`. Levels play in that order.
3. Run the checks: `godot --headless --path . res://tests/level_check.tscn`. They verify that
   every door joins two rooms, every object and gas zone is inside a room, the exit is
   reachable, the player starts out of the gas, vents clear their room's gas and the player
   can move.

## Adding a new object type

1. Create a script in `scripts/entities/` that extends `GameObject` (start it with `@tool`
   so it previews in the editor). Override what it needs: `current_texture`,
   `interaction_prompt` and `interact`.
2. Create its scene in `scenes/entities/`: a `Node2D` with that script and a `Sprite2D` child
   named `Sprite`.
3. Add a texture slot to `scripts/core/art_theme.gd` and fill it in `art/art_theme.tres`.
