# World, UI, Camera, and Collision Enhancement Design

**Date:** 2026-08-04  
**Project:** Hearthwild 2D  
**Status:** Approved design for implementation planning

## 1. Goal

Improve the current playable prototype so the world feels materially larger, navigation is clearer, UI is more informative, inventory input is reliable, camera zoom is controllable, and world props behave as solid physical objects without breaking top-down depth presentation.

This phase covers:

- expanding the prototype world from 40×24 logical cells to 96×64;
- establishing four readable gameplay regions;
- fixing reliable Tab inventory toggling;
- adding a three-resource player status HUD;
- adding a simplified full-map minimap;
- adding smooth mouse-wheel camera zoom;
- retaining quickbar selection through Ctrl + mouse wheel and number keys;
- replacing oversized visual collisions with base-only prop collisions;
- validating passability, spawn safety, world bounds, and UI behavior.

This phase does **not** add combat damage, enemy AI, harvesting results, farming progression, or magic abilities. It only creates the world, input, HUD, minimap, camera, collision, and player-stat foundations those systems will consume later.

## 2. Existing Constraints

The implementation must preserve:

- Godot 4.x and pure 2D architecture;
- 640×360 internal viewport and pixel-accurate presentation;
- 16×16 source tiles rendered at 2× scale as 32×32 logical cells;
- existing player movement, item data, inventory, hotbar, portable crafting, and open-art loading;
- single-player world pause while the inventory is open;
- no third-party plugins;
- headless Godot validation and main-scene smoke testing.

## 3. Chosen Architecture

Use a gradual modular refactor rather than continuing to expand `PrototypeWorld` as one large script or rebuilding the entire map in the editor.

```text
PrototypeWorld
├── WorldLayoutConfig
├── WorldLayout
├── WorldPropFactory
├── WorldCollisionRegistry
├── GameInputRouter
├── Player
│   ├── PlayerStats
│   └── CameraRig
└── HUD
    ├── StatsHUD
    ├── MiniMap
    ├── HotbarUI
    └── InventoryUI
```

Each unit has one responsibility:

- `WorldLayoutConfig`: authoritative world dimensions, regions, spawn points, roads, water, and coordinate conversion.
- `WorldLayout`: paints terrain and requests prop placement from configuration.
- `WorldPropFactory`: creates visual props, base collisions, sort origins, and minimap registrations.
- `WorldCollisionRegistry`: tracks solid geometry, validates spacing, and finds nearby safe positions.
- `GameInputRouter`: owns global gameplay actions such as inventory toggle, Escape behavior, zoom, and quickbar wheel selection.
- `PlayerStats`: authoritative health, stamina, and mana state with clamped mutations and signals.
- `CameraRig`: smooth follow, bounded zoom, and world-limit handling.
- `StatsHUD`: observes `PlayerStats` and displays three resource bars.
- `MiniMap`: draws simplified world regions and registered markers without rendering a second full world.

Consumers depend on public methods and signals, not implementation details.

## 4. World Dimensions and Regions

### 4.1 Authoritative Size

The world becomes:

```text
96 × 64 logical cells
32 × 32 display pixels per cell
3072 × 2048 world pixels
```

`WorldLayoutConfig` exposes:

- `map_size_cells: Vector2i = Vector2i(96, 64)`;
- `display_cell_size: Vector2i = Vector2i(32, 32)`;
- `world_size_pixels() -> Vector2i`;
- `world_rect() -> Rect2`;
- `cell_to_world(cell: Vector2i) -> Vector2`;
- `world_to_normalized(position: Vector2) -> Vector2`;
- `normalized_to_minimap(position: Vector2, minimap_size: Vector2) -> Vector2`.

World dimensions must no longer be duplicated in camera, river, prop, or minimap scripts.

### 4.2 Region Layout

The first large map contains four clear regions:

- **Southwest — Farmstead:** farmhouse, workshop, initial farm plot, safe spawn area, and broad paths.
- **Center — Meadow Crossroads:** open grassland, main road network, tutorial pickups, and future social space.
- **East — Stonefield:** rock clusters, grey terrain accents, and a clear future mining route.
- **North — Whisperwood:** denser tree placement, forest paths, and future slime activity space.

The map edge should not appear as a bare rectangular cutoff. Tree walls, rock ridges, deep water, and inaccessible decorative terrain create natural boundaries.

### 4.3 Passability Rules

- Main roads and house entrances are at least two logical cells wide.
- Player spawn has a 3×3-cell collision-free safety area.
- No generated gap between two solid props may be narrower than the player collision width unless intentionally blocked.
- Water blockers form continuous segments without visible or physical gaps.
- The main route between farmstead, meadow, forest, and stonefield remains traversable.

## 5. World Prop Definitions

Create `WorldPropDefinition` as a resource-backed description for world props.

Required fields:

- stable `id`;
- atlas region or fallback texture path;
- visual scale;
- visual offset;
- solid or decorative classification;
- collision shape type;
- collision size;
- collision offset;
- optional multiple collision shapes;
- Y-sort origin offset;
- minimap marker category;
- development display name.

### 5.1 Base-Only Collision Policy

Visual size never directly defines collision size.

- **Small tree:** only trunk and roots collide; canopy is visual and can cover the player.
- **Tree cluster:** use multiple small trunk/root collisions instead of one canopy-sized rectangle.
- **House:** walls and sides collide; doorway remains open.
- **Large house:** may split into wall body, roof overlay, doorway trigger, and several wall collision segments.
- **Rock:** use a small rectangle or capsule-like footprint aligned to its base.
- **Fence:** horizontal and vertical variants use tight segment collisions.
- **River:** use continuous border collisions or blocked water cells with no seam gaps.
- **Grass, flowers, tiny stones, ground debris:** decorative and non-solid.
- **Small animals:** lightweight dynamic collision only; they must not create permanent path blocking.

### 5.2 Collision Layers

Preserve the existing world/player layer relationship:

- world solids: collision layer 1;
- player: collision layer 2 and mask 1;
- decorative props: no collision layer;
- future interaction areas use separate areas rather than enlarging physical collision.

## 6. Y Sorting and Occlusion

World sorting uses the base of an object, not the center of its texture.

```text
prop sort Y = collision/base origin Y
player sort Y = player foot position Y
```

Requirements:

- the player appears in front of a tree when below its base;
- the player appears behind the canopy when above the tree base;
- roofs may be separate overlays when a single sprite cannot produce correct ordering;
- rocks, fences, future enemies, and the player follow the same base-origin convention;
- HUD and minimap remain in `CanvasLayer` and never participate in world sorting.

## 7. Collision Registry and Safety Recovery

`WorldCollisionRegistry` tracks solid footprints generated for the current world.

Public responsibilities:

- register and unregister solid footprints;
- test whether a point or player footprint overlaps world solids;
- validate spawn safety;
- identify narrow accidental gaps during development;
- find the nearest valid position around a requested point;
- support save-load recovery when a stored player position is now invalid.

When loading a player inside collision:

1. test the saved position;
2. search nearby positions in increasing cell-radius order;
3. choose the nearest valid position connected to walkable ground;
4. fall back to the farmhouse safe spawn if no local point is valid;
5. report the recovery through a development warning without failing startup.

## 8. Camera Rig

Move camera behavior into a focused `CameraRig` component attached to the player or player scene.

### 8.1 Follow and Limits

- smooth follow remains enabled;
- camera limits derive from `WorldLayoutConfig.world_rect()`;
- limits account for current zoom so the viewport cannot reveal outside the world;
- the camera updates limits if world configuration changes;
- pixel alignment and nearest filtering remain enabled.

### 8.2 Zoom

Approved zoom behavior:

```text
minimum zoom: 0.75
initial zoom: 1.00
maximum zoom: 1.50
wheel step: 0.125
```

- direct mouse wheel changes camera zoom;
- zoom interpolates toward a target value;
- zoom is uniform on both axes;
- inventory and pause menus block gameplay zoom;
- minimap rendering is independent from main camera zoom;
- zoom cannot reveal space beyond world bounds.

## 9. Input Routing

Create `GameInputRouter` as the owner of global gameplay inputs.

### 9.1 Inventory Toggle

The router captures inventory input during `_input()` before GUI focus traversal can consume Tab.

```text
Tab pressed
→ GameInputRouter receives event
→ verify gameplay menu transition is allowed
→ toggle InventoryUI
→ update pause ownership
→ mark event handled
```

Inventory behavior:

- Tab opens and closes the inventory reliably;
- the close button also closes it;
- Escape closes inventory before opening or toggling the pause menu;
- player movement and item use are blocked while inventory is open;
- the world is paused in single player;
- closing inventory releases only its own pause reason and does not cancel another active pause reason;
- hotbar and minimap stay visible but dim while inventory is open.

### 9.2 Mouse Wheel and Quickbar

Approved controls:

- mouse wheel: camera zoom;
- Ctrl + mouse wheel: cycle quickbar selection;
- number keys 1–5: select quickbar slots directly;
- while inventory is open, wheel input belongs to the UI and does not zoom or change the hotbar.

The router emits intent signals or calls narrow public methods. It does not mutate inventory slots or camera internals directly.

## 10. Player Stats

Create `PlayerStats` as the authoritative resource model for player resources.

Initial values:

- health: 100 / 100;
- stamina: 100 / 100;
- mana: 100 / 100.

Public behavior:

- clamped setters and additive change methods;
- signals for health, stamina, and mana changes;
- maximum-value change support;
- full restore helpers;
- invulnerability state placeholder for later combat;
- stamina regeneration state placeholder for later dodge logic;
- mana regeneration interface placeholder without adding magic abilities in this phase.

HUD scripts observe signals and never become the source of truth.

## 11. Stats HUD

The upper-left HUD becomes a compact three-resource panel.

```text
┌──────────────────────┐
│ ♥  Health  100 / 100 │
│ ⚡ Stamina 100 / 100 │
│ ✦  Mana    100 / 100 │
│ Morningdew · Early Spring │
└──────────────────────┘
```

Presentation requirements:

- health uses red;
- stamina uses green or warm gold;
- mana uses blue;
- displayed bar values interpolate smoothly;
- numerical values remain readable at 640×360;
- low health may pulse subtly;
- insufficient stamina only flashes the stamina row;
- mana appears and updates even though no magic skill is implemented yet;
- area and season text occupies one compact line;
- HUD layout does not overlap the minimap or central interaction prompts.

## 12. Minimap

The upper-right corner gains a simplified approximately 160×160-pixel minimap.

### 12.1 Rendering Strategy

Use a data-drawn simplified map, not a second full-world camera.

Benefits:

- no duplicate world, particle, lighting, or entity rendering;
- deterministic region colors and marker placement;
- simple headless coordinate tests;
- independence from camera zoom and screen occlusion.

### 12.2 Base Layers

The minimap draws:

- grass/background;
- roads;
- farmland;
- forest region;
- stonefield region;
- river and water;
- inaccessible border regions.

### 12.3 Markers

- player: white or gold arrow;
- farmhouse: house icon;
- workshop: hammer icon;
- farm plot: brown region or plot marker;
- key objective: gold diamond;
- forest and stonefield remain primarily region coloration;
- ordinary decorations, pickups, and normal slimes are omitted.

Markers register through stable IDs. Removing a world object unregisters its marker.

The first version always displays the full 96×64 map. It does not implement fog of war, rotating maps, floors, caves, or exploration memory.

## 13. HUD Layout

Final screen layout:

```text
upper-left: health, stamina, mana, area/season
upper-right: minimap
center: temporary interaction prompts and future damage numbers
bottom-center: five-slot hotbar
Tab overlay: 20-slot inventory and portable crafting
Escape overlay: pause menu
```

The current persistent control hint becomes contextual:

- visible on first entry;
- visible after input remapping;
- visible near an interactable;
- visible when required by a tutorial objective;
- otherwise fades out.

## 14. Error Handling and Validation

### 14.1 Prop Validation

When loading a prop definition, validate:

- atlas region fits its texture;
- stable ID is non-empty and unique;
- solid props provide valid collision shapes;
- collision sizes are positive;
- collision offsets are plausibly near the visual footprint;
- minimap marker category is valid;
- placement is inside world bounds.

Invalid behavior:

- emit a clear warning naming the prop and failed field;
- never create malformed collision geometry;
- use a safe visual placeholder for severe visual configuration errors;
- reject duplicate stable IDs to protect future save and minimap state.

### 14.2 Input and Pause Safety

- repeated Tab key events must not double-toggle in one frame;
- inventory close must release only the inventory pause reason;
- missing UI references produce explicit startup errors rather than silent failure;
- gameplay input is blocked while a modal UI owns input;
- window focus changes must not leave the game permanently paused or unpaused incorrectly.

### 14.3 Camera Safety

- target zoom is always clamped;
- invalid world bounds fall back to current camera limits and warn;
- zero-size viewport or map configuration fails validation during tests;
- camera interpolation uses frame-rate-independent delta handling.

## 15. Testing Strategy

### 15.1 Pure and Headless Tests

Add Godot headless suites for:

- map size equals 96×64;
- world pixel size equals 3072×2048;
- normalized minimap coordinates at center and four corners;
- player marker remains inside minimap bounds;
- player stats clamp to valid ranges;
- stat change signals emit expected values;
- target camera zoom clamps to 0.75–1.50;
- zoom step behavior is deterministic;
- Tab input opens and closes inventory;
- Escape closes inventory first;
- inventory pause ownership is acquired and released correctly;
- solid prop definitions create base collisions;
- decorative prop definitions create no collision;
- farmhouse doorway remains unblocked;
- river blockers form continuous coverage;
- safe-spawn validation passes;
- invalid saved positions recover to a nearby safe point.

### 15.2 Scene and Repository Tests

Extend repository and scene checks to require:

- `WorldLayoutConfig`;
- `WorldPropDefinition`;
- `WorldCollisionRegistry`;
- `GameInputRouter`;
- `PlayerStats`;
- `CameraRig`;
- `StatsHUD`;
- `MiniMap`;
- player, HUD, and world scene wiring;
- no accidental 3D nodes;
- no missing external resources.

### 15.3 Full Validation Gate

The final phase gate runs:

```text
Python unit tests
repository validator
Python compile checks
Godot project import
headless gameplay suites
main-scene smoke run
```

Any `SCRIPT ERROR`, resource error, missing node, invalid collision configuration, or test timeout fails the phase.

## 16. Acceptance Criteria

The phase is accepted when:

- the visible world is 96×64 logical cells and feels substantially larger;
- natural borders prevent exposing a bare map edge;
- direct mouse wheel smoothly zooms the main camera;
- Ctrl + mouse wheel and number keys select hotbar slots;
- Tab reliably opens and closes the existing 20-slot inventory;
- Escape closes inventory before other pause behavior;
- the left HUD displays working health, stamina, and mana bars;
- the right HUD displays a full-map minimap with a correctly positioned player marker;
- trees, houses, rocks, fences, and water boundaries cannot be walked through;
- collision remains limited to physical bases rather than full visual canopies or roofs;
- the player can visually move in front of and behind tall props with correct Y sorting;
- farmhouse doors and main paths remain traversable;
- the spawn point is safe and invalid saved positions recover safely;
- existing inventory, hotbar, crafting, movement, and art loading do not regress;
- all automated validation passes.

## 17. Explicit Non-Goals

This phase does not implement:

- player attacks or damage resolution;
- slime AI or enemy spawning rules;
- resource-node durability or harvesting rewards;
- crop planting, watering, growth, or harvesting;
- functional spells or mana costs;
- fog of war or minimap discovery;
- indoor maps or building entry transitions;
- procedural world generation;
- multiplayer input or non-pausing multiplayer menus.

These remain separate later phases built on the interfaces established here.
