# Open-Art Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder-looking Hearthwild 2D presentation with a cohesive open-asset pixel-art scene while preserving the current movement-only gameplay scope.

**Architecture:** Pin Ninja Adventure as a Git submodule, load its textures through a fallback-aware asset library, build the ground and props from atlas regions at runtime, and animate the player from the upstream 4×7 sprite sheet. Visual effects remain isolated in small 2D scripts so they can be replaced without touching gameplay systems.

**Tech Stack:** Godot 4.3+, GDScript, TileMapLayer, Sprite2D atlas animation, Git submodules, Python 3.13 repository validation, GitHub Actions.

## Global Constraints

- Runtime remains pure 2D; no `Node3D`, `Sprite3D`, `Camera3D`, `MeshInstance3D`, `StaticBody3D` or `CharacterBody3D`.
- Base viewport remains 640×360 with nearest-neighbor texture filtering.
- Open-source asset reference is pinned to Ninja Adventure commit `6ac78232d5aedcc85ce5f27d060ea92366f7c24a`.
- Original SVG assets remain available as fallback files.
- This phase does not add combat, inventory, farming simulation, saves or multiplayer.

---

### Task 1: Pin and validate the open asset source

**Files:**
- Create: `.gitmodules`
- Add gitlink: `vendor/ninja-adventure`
- Modify: `.github/workflows/validate.yml`
- Modify: `THIRD_PARTY_NOTICES.md`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Produces: checked-out textures under `res://vendor/ninja-adventure/content/`.

- [ ] Add the Ninja Adventure repository as a submodule pinned to the approved commit.
- [ ] Configure `actions/checkout@v4` with `submodules: recursive`.
- [ ] Add tests asserting the submodule URL, pinned asset paths and CI checkout setting.
- [ ] Register the upstream authors, CC0 statement, commit and consumed paths in notices.
- [ ] Run `python -m unittest discover -s tests -v` and confirm the new tests pass.

### Task 2: Add fallback-aware asset loading

**Files:**
- Create: `scripts/assets/open_asset_library.gd`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Produces: `OpenAssetLibrary.load_texture(primary_path: String, fallback_path: String) -> Texture2D`.
- Produces: constants for floor atlas, village atlas, player sheet, pig sheet and shadow texture.

- [ ] Add failing contract tests for the class, paths and fallback method.
- [ ] Implement the loader with one-time warnings when the submodule is missing.
- [ ] Ensure a missing primary resource returns the fallback texture instead of `null` when the fallback exists.
- [ ] Run the validator tests.

### Task 3: Rebuild the player visual from the open sprite sheet

**Files:**
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/player_controller.gd`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Consumes: `OpenAssetLibrary.PLAYER_SHEET` and `OpenAssetLibrary.SHADOW_TEXTURE`.
- Produces: `_direction_column(direction: Vector2) -> int` and `_animation_row(moving: bool, delta: float) -> int`.

- [ ] Change the visual node to `Sprite2D` with `hframes = 4` and `vframes = 7`.
- [ ] Load the Ninja Adventure player and shadow textures at runtime, preserving original SVG fallbacks.
- [ ] Map columns Down=0, Up=1, Left=2 and Right=3.
- [ ] Keep idle on row 0 and loop rows 0–3 at six frames per second while moving.
- [ ] Preserve eight-direction velocity normalization, collision and Camera2D.
- [ ] Run contract tests.

### Task 4: Replace color tiles with the open floor atlas

**Files:**
- Modify: `scripts/world/prototype_world.gd`
- Create: `scripts/world/open_atlas_regions.gd`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Consumes: `OpenAssetLibrary.FLOOR_ATLAS`.
- Produces: named atlas coordinates for grass variants, path, soil and stone.

- [ ] Define explicit 16×16 atlas coordinates and map them to the five ground types.
- [ ] Build a TileSetAtlasSource from the external floor texture and scale the TileMapLayer by 2.
- [ ] Add deterministic grass variation without changing collision or map layout.
- [ ] Keep the generated-color fallback tileset for clones without submodules.
- [ ] Run tests and repository validation.

### Task 5: Replace placeholder props with village atlas slices

**Files:**
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Consumes: `OpenAssetLibrary.VILLAGE_ATLAS` and region constants from `OpenAtlasRegions`.
- Produces: `_spawn_atlas_prop(name: String, region: Rect2i, position: Vector2, scale_factor: float, collision_size: Vector2) -> Node2D`.

- [ ] Remove the fixed SVG house/tree/rock scene nodes.
- [ ] Spawn a large house, small house, several tree clusters, rocks and fences from atlas regions.
- [ ] Attach simplified StaticBody2D collisions only to solid props.
- [ ] Preserve Y sorting and use SVG props when the village atlas is unavailable.
- [ ] Add an idle pig sprite from the open character sheet as the enemy placeholder.
- [ ] Run tests.

### Task 6: Add water, lighting, particles and polished HUD

**Files:**
- Create: `scripts/world/water_surface.gd`
- Create: `scripts/world/floating_motes.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `README.md`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Produces: animated `_draw()` water surface and deterministic ambient motes.

- [ ] Draw the river with layered pixel bands and moving sine highlights.
- [ ] Add CanvasModulate and two PointLight2D nodes using gradient textures.
- [ ] Add subtle floating particles around the house and pickup area.
- [ ] Replace the long prototype label with compact health, area and controls panels.
- [ ] Document recursive clone and submodule update commands.
- [ ] Run unit tests, validator and Python compile checks.

### Task 7: Final remote verification

**Files:**
- Modify only if verification finds defects.

- [ ] Confirm all changed runtime files remain 2D-only.
- [ ] Confirm GitHub Actions checks out the submodule and passes all tests.
- [ ] Confirm exact third-party paths are registered.
- [ ] Confirm the branch diff contains no accidental source-project scripts outside the gitlink.
- [ ] Create a draft PR and record the remaining Godot interactive-run gate.
