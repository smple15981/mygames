# Pure 2D Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the merged HD-2D foundation with a pure 2D Godot project containing a 32×32 TileMapLayer world, CharacterBody2D player, Camera2D, Y sorting, open-licensed 2D assets, and automated guards against 3D regressions.

**Architecture:** `PrototypeWorld` creates the temporary TileSet and paints the map; `PlayerController` owns input and movement; `MovementMath` owns pure direction decisions. Static repository validation runs without Godot and rejects missing 2D contracts or any remaining 3D scene/script nodes.

**Tech Stack:** Godot 4.3+, GDScript, Godot text scenes, SVG placeholders, Python 3.11+, GitHub Actions.

## Global Constraints

- Base viewport is exactly 640×360.
- Ground cell size is exactly 32×32.
- Runtime scenes and scripts must not contain Godot 3D node types.
- Player root is `CharacterBody2D`.
- Player visual is `AnimatedSprite2D`.
- Player owns a `Camera2D`.
- World owns a `TileMapLayer`.
- World entity container enables Y sorting.
- Third-party files require exact paths in `THIRD_PARTY_NOTICES.md`.

---

### Task 1: Write the pure 2D contract tests

**Files:**
- Modify: `tests/test_validate_project.py`
- Modify: `tools/validate_project.py`

- [x] Add failing tests for 640×360, CharacterBody2D, AnimatedSprite2D, Camera2D, TileMapLayer, Y sorting and forbidden 3D tokens.
- [x] Run `python -m unittest discover -s tests -v` and verify the old HD-2D tree fails.
- [x] Implement the validator contract.
- [x] Run the tests again.

### Task 2: Replace the engine and player foundation

**Files:**
- Modify: `project.godot`
- Modify: `scenes/bootstrap/main.tscn`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/movement_math.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `assets/original/player/player.svg`

- [x] Change the viewport to 640×360.
- [x] Replace CharacterBody3D/Sprite3D with CharacterBody2D/AnimatedSprite2D.
- [x] Remove gravity and 3D world-direction conversion.
- [x] Add Camera2D and 2D collision.
- [x] Preserve normalized eight-direction movement.

### Task 3: Replace the 3D world with TileMapLayer

**Files:**
- Modify: `scenes/world/prototype_world.tscn`
- Create: `scripts/world/prototype_world.gd`
- Create: `assets/original/world/house.svg`
- Create: `assets/original/world/tree.svg`
- Create: `assets/original/world/rock.svg`
- Create: `assets/original/world/crop.svg`
- Create: `assets/original/world/slime.svg`

- [x] Add a TileMapLayer and runtime 32×32 TileSet.
- [x] Paint farm, path, water and stone regions.
- [x] Add Y-sorted 2D scene props and collision.
- [x] Add a minimal CanvasLayer HUD.

### Task 4: Import verified open 2D assets

**Files:**
- Keep: `assets/third_party/kenney/starter-kit-3d-platformer/particle.png`
- Create: `assets/third_party/tabler/tabler-icons/heart.svg`
- Create: `assets/third_party/tabler/tabler-icons/sword.svg`
- Create: `assets/third_party/tabler/tabler-icons/LICENSE`
- Modify: `assets/third_party/kenney/starter-kit-3d-platformer/LICENSE.md`
- Modify: `THIRD_PARTY_NOTICES.md`

- [x] Reuse the already audited Kenney CC0 particle in the pure 2D world.
- [x] Import Tabler heart and sword SVG icons under MIT.
- [x] Use the icons in the HUD and record exact repository paths and usage.

### Task 5: Documentation and verification

**Files:**
- Modify: `README.md`
- Create: `docs/superpowers/specs/2026-08-04-hearthwild-pure-2d-design.md`
- Create: `docs/superpowers/plans/2026-08-04-pure-2d-foundation.md`
- Modify: `.github/workflows/validate.yml`

- [x] Document that the HD-2D route is superseded.
- [x] Run `python -m unittest discover -s tests -v`.
- [x] Run `python tools/validate_project.py .`.
- [x] Run `python -m compileall -q tools tests`.
- [x] Confirm no 3D tokens remain in runtime project files.
