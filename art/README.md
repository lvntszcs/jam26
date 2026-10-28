# Art guide

The game is drawn from two kinds of art:

- **Room paintings**: one image per room, set on each `Room` node.
- **Shared sprites**: the player, doors, vents, smoke and so on, all listed in **`art/art_theme.tres`**.

No script points at an image directly, so swapping art never needs code changes.
See `art/rooms/lab_reference.webp` for the target style. It's already used as the Lab in level 1.

## Room paintings

Each room is a single painting with its walls, floor and decoration painted in.

1. Save the painting in `art/rooms/` (PNG or WebP).
2. Open the level scene (`scenes/levels/level_NN.tscn`), select the room under `Rooms`, and drag
   the image into **Background**. The painting is stretched over the room's **Size**, so paint
   at the same aspect ratio (e.g. 2000x1400 for a 1000x700 room).
3. Set **Wall Thickness** to roughly match the painted border, in room units
   (a 50 px border on a 2000 px painting of a 1000-wide room = 25).

Doors cut gaps in the walls automatically. Paint the wall continuous, since the door sprite
covers the gap. If props are painted into the room (like the lab's broken canister), place the
matching object on top and tick **Hide Art** so only its gameplay remains. The smoke source
in level 1 shows how.

Rooms without a background draw a cream placeholder with their name.

## Shared sprites

Replace one in either of two ways:

1. **Overwrite the placeholder** in `art/placeholder/` with a file of the same name.
2. **Point the theme at a new file** by opening `art/art_theme.tres` in the inspector and
   dragging your image into the slot.

Any resolution works. Each object fits its art into its **Footprint** (set per object in the
level, in world pixels), keeping the aspect ratio. Doors stretch to fill theirs.

| Slot | Notes |
|------|-------|
| `player_down` / `player_up` | |
| `player_side` | Draw facing **right**. It's flipped for left. |
| `door_closed` / `door_open` | Draw for a **horizontal** wall: width = the opening, height = the wall depth. It's rotated 90° in vertical walls. Use transparency so the room shows through an open door. |
| `vent_on` / `vent_off` | A running vent spins its sprite. Set `spin_speed = 0` on the vent to stop that. |
| `smoke_source` | Pulses. Set `pulse_amount = 0` to stop. |
| `exit` | The escape hatch. |
| `smoke` | One soft puff. Rooms are covered in drifting puffs whose opacity follows the room's smoke level. Keep it **white or grey** and set the color with `smoke_tint`, or paint it in color and set `smoke_tint` to white. `smoke_max_alpha` sets how thick a full room looks. |
| `highlight` | Stretched around whatever the player can interact with. |

## Filtering

The project uses smooth (linear) texture filtering, which suits painted art. For pixel art,
change Project Settings → Rendering → Textures → Canvas Textures → Default Texture Filter.

## Animation

Each object scene (`scenes/entities/*.tscn`) has a plain `Sprite2D` named `Sprite`. To animate
one, add an `AnimationPlayer`, or replace the sprite and update `current_texture()` /
`refresh_visual()` in the matching script under `scripts/entities/`.

## UI

HUD colors, fonts and boxes live in `art/ui_theme.tres`, a regular Godot `Theme`.

## Palette

Stick to the project palette (see `AGENTS.md`, also available in code as `Palette.*`):
`#349189` `#f1fdd9` `#d3fe28` `#c94b01` `#406635` `#400116` `#9625fd` `#a9ff00`.
