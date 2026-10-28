# Art guide

The game is drawn from two kinds of art:

- **Room paintings**: one image per room, set on each `Room` node.
- **Shared sprites**: the player, doors, vents and so on, all listed in **`art/art_theme.tres`**.

No script points at an image directly, so swapping art never needs code changes.
See `art/rooms/lab_reference.webp` for the target style. It's already used as the Lab in level 1.

## Room paintings

Each room is a single painting with its walls, floor and decoration painted in.

Every room uses the **default room painting** (`room_background` in `art/art_theme.tres`,
currently `art/rooms/room_floor.webp`) unless it has its own. The painting is stretched over the
room, so it fits best on rooms with the same proportions as the image (10:7, e.g. 1000x700).
Long or tall rooms get their own painting, or a differently shaped default.

To give a room its own painting:

1. Save the painting in `art/rooms/` (PNG or WebP).
2. Open the level scene (`scenes/levels/level_NN.tscn`), select the room under `Rooms`, and drag
   the image into **Background**. The painting is stretched over the room's **Size**, so paint
   at the same aspect ratio (e.g. 2000x1400 for a 1000x700 room).
3. Set **Wall Thickness** to roughly match the painted border, in room units
   (a 50 px border on a 2000 px painting of a 1000-wide room = 25).

Doors cut gaps in the walls automatically. Paint the wall continuous, since the door sprite
covers the gap. If props are painted into the room (like the lab's broken canister), place the
matching object on top and tick **Hide Art** so only its gameplay remains.

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
| `player_sheet` | Spritesheet of the player seen from above (`art/characters/player_sheet.webp`). Draw the character facing **up**: the game rotates it toward where it walks. Frames are a grid read left to right, top to bottom. Set `player_sheet_columns` / `player_sheet_rows`, `player_idle_frame` and the walk-cycle order in `player_walk_frames`. `player_walk_fps` is the cycle speed at full walking speed (it slows down as the player slows). If the art faces another way, set `player_art_angle` (-90 = up, 0 = right, 90 = down). The frame size is fitted into the Player's `footprint` (`scenes/entities/player.tscn`). |
| `door_closed` / `door_open` | Draw for a **horizontal** wall: width = the opening, height = the wall depth. It's rotated 90° in vertical walls. Use transparency so the room shows through an open door. |
| `vent_on` / `vent_off` | A running vent spins its sprite. Set `spin_speed = 0` on the vent to stop that. |
| `exit` | The escape hatch. |
| `highlight` | Stretched around whatever the player can interact with. |

## Gas

The gas needs no art: a shader (`scripts/smoke/smoke.gdshader`) draws it as slowly swirling
noise, the same everywhere in the world, so neighbouring gas zones join seamlessly. Thin gas
breaks into ragged wisps instead of fading evenly. Everything about its look is in
**`config/smoke.tres`** (a level can use its own through its Level node's **Smoke Config**):

| Setting | Effect |
|---------|--------|
| `color`, `highlight_color`, `highlight_amount` | Color of the gas body, of its brightest wisps, and how much of the gas gets the wisp color. |
| `opacity` | How opaque Strong gas is. |
| `noise_scale` | World size of one large billow (a small room is about 1000 wide). |
| `drift` | Slow slide of the whole gas, in world pixels per second. |
| `swirl_speed`, `warp` | How fast the billows change shape, and how strongly they curl into each other. |
| `edge_breakup`, `edge_softness` | How ragged thin gas looks (0 = plain fade), and how soft those ragged edges are. |
| `blend_width` | Width over which touching zones of different strengths blend into each other. Only the look blends; the danger switches right at the edge. |
| `edge_fade` | Width of a soft fade on zone edges that face open floor. Edges against a wall or another zone never fade, so there are no gaps there. |
| `low_density`, `medium_density`, `strong_density` | How thick each gas strength looks. This is also how dangerous it is. |
| `clear_speed` | How fast a running vent clears its room's gas, and how fast it returns. |

Where the gas is, and which strength, is set by the GasZone nodes in each level (see
`scenes/levels/README.md`).

## Lighting

Only the area around the player is lit. All settings are in **`config/lighting.tres`**. Open it
in the inspector:

| Setting | Effect |
|---------|--------|
| `enabled` | Turn the darkness off entirely (handy while building levels). |
| `darkness` | Tint of everything outside the light. Black hides it completely, and a lighter color leaves rooms faintly visible. |
| `radius` | Size of the lit circle in world pixels (a room is about 1000 wide). |
| `softness` | 0 = hard edge, 1 = fades out from the centre. |
| `color` / `energy` | Light color and brightness. Raising `energy` above 1 washes out the art. |
| `flicker_amount` / `flicker_speed` | Torch-like wobble. Set the amount to 0 for a steady light. |
| `blackout_interval_min` / `_max`, `blackout_duration` | The light goes out for `blackout_duration` seconds at a random time between the two intervals. Set the duration to 0 to turn this off. |
| `shadows`, `shadow_color`, `shadow_smooth` | Walls and closed doors block the light, so you can't see into other rooms. |

To give one level different lighting (e.g. a darker final level), duplicate the file and assign
it to the Level node's **Lighting** property.

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
