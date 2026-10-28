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
| `player_sheet` | Spritesheet of the player seen from above (`art/characters/player_sheet.webp`). Draw the character facing **up**: the game rotates it toward where it walks. Frames are a grid read left to right, top to bottom. Set `player_sheet_columns` / `player_sheet_rows`, `player_idle_frame` and the walk-cycle order in `player_walk_frames`. `player_walk_fps` is the cycle speed at full walking speed (it slows down as the player slows). If the art faces another way, set `player_art_angle` (-90 = up, 0 = right, 90 = down). The frame size is fitted into the Player's `footprint` (`scenes/entities/player.tscn`). |
| `door_closed` / `door_open` | Draw for a **horizontal** wall: width = the opening, height = the wall depth. It's rotated 90° in vertical walls. Use transparency so the room shows through an open door. |
| `vent_on` / `vent_off` | A running vent spins its sprite. Set `spin_speed = 0` on the vent to stop that. |
| `smoke_source` | Pulses. Set `pulse_amount = 0` to stop. |
| `exit` | The escape hatch. |
| `smoke_frames` | The smoke animation: tileable frames played in order and looped (see **Smoke** below). |
| `highlight` | Stretched around whatever the player can interact with. |

## Smoke

Smoke is one **tileable texture** repeated across each room, animated by swapping between its
frames. No edge tiles are needed: where smoke thins out, only the texture's thickest parts stay
visible, so the edge of a cloud takes its ragged shape from the texture itself.

**Painting the frames**

- Every frame must **tile seamlessly**: the left edge continues the right edge, and the top
  continues the bottom. All frames should be the same size and show the same smoke in slightly
  different shapes, so swapping between them reads as movement (a "boil").
- Paint the smoke on a **transparent background**, and use opacity to show how thick it is.
  Thick, opaque areas are the last to disappear when smoke thins. If the frames come
  white-on-black with no transparency instead, set `alpha_source` to *Luminance* in the smoke
  settings.
- Paint it **white/grey** and let `tint` color it, or paint it in color and set `tint` to white.

**Plugging them in:** open `art/art_theme.tres` and put the frames, in order, into
**Smoke Frames**. Any number of frames works. The two in `art/placeholder/smoke_frame_*.png` are
placeholders.

**Tuning:** everything else is in **`config/smoke.tres`** (a level can use its own through its
Level node's **Smoke Config**):

| Setting | Effect |
|---------|--------|
| `tint`, `opacity` | Color, and how opaque a completely full room is. |
| `tile_size` | World size of one texture repeat (a room is about 1000 wide). |
| `alpha_source` | Read thickness from the frames' transparency or brightness. |
| `frame_rate` | Frames per second. |
| `crossfade` | 0 = frames swap instantly (hand-drawn boil), 1 = they blend smoothly. |
| `drift` | Slow slide of the texture, in world pixels per second. |
| `edge_breakup`, `edge_softness` | How ragged thin smoke looks (0 = plain fade), and how soft those ragged edges are. |
| `cell_size`, `spread_speed`, `fill_speed` | How finely and how fast smoke visibly creeps in from doors and sources and gets pulled toward vents. |

These only change how the smoke looks. How much smoke a room holds, and how dangerous it is,
are set by the smoke sources, vents and doors in the level.

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
