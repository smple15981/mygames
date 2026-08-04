# Open-Art Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the placeholder-looking Hearthwild 2D presentation with a cohesive open-asset pixel-art scene while preserving the current movement-only gameplay scope.

**Architecture:** Ninja Adventure is pinned as a Git submodule. Because the upstream directory is itself a Godot project, the main project loads its selected PNG files through `Image.load()` and caches them as `ImageTexture` objects. Ground and props are built from atlas regions at runtime, the player uses the upstream 4×7 sheet, and all open assets have local fallback art.

**Tech Stack:** Godot 4.3+, GDScript, TileMapLayer, Sprite2D atlas animation, Git submodules, Python 3.13 validation, GitHub Actions, official Godot 4.6.3 headless verification.

## Global Constraints

- Runtime remains pure 2D.
- Base viewport remains 640×360 with nearest-neighbor filtering and pixel snapping.
- Ninja Adventure is pinned to `6ac78232d5aedcc85ce5f27d060ea92366f7c24a`.
- Original SVG assets remain available as fallbacks.
- This phase does not add combat, inventory, farming simulation, saves or multiplayer.

## Task 1: Pin and validate the open asset source

- [x] Add `.gitmodules` and the `vendor/ninja-adventure` gitlink.
- [x] Configure recursive submodule checkout in GitHub Actions.
- [x] Test the URL, checked-out paths and CI configuration.
- [x] Register authors, CC0 status, commit and consumed paths.

## Task 2: Add fallback-aware asset loading

- [x] Add `OpenAssetLibrary` constants for floor, village, player, pig and shadow images.
- [x] Decode PNG files under the nested vendor project with `Image.load()`.
- [x] Cache generated `ImageTexture` instances.
- [x] Fall back to original local art with one-time warnings.

## Task 3: Rebuild the player visual

- [x] Replace the single-frame visual with a `Sprite2D` using 4 columns × 7 rows.
- [x] Map Down=0, Up=1, Left=2 and Right=3.
- [x] Keep idle on row 0 and loop rows 0–3 while moving.
- [x] Preserve normalized movement, collision and Camera2D.

## Task 4: Replace generated color tiles

- [x] Define explicit 16×16 floor atlas coordinates.
- [x] Build the `TileSetAtlasSource` from the open floor texture at runtime.
- [x] Display the source at 2× scale for a 32×32 logical grid.
- [x] Keep deterministic grass variation and generated-color fallback tiles.

## Task 5: Replace placeholder props

- [x] Remove fixed SVG house/tree/rock nodes from the runtime scene.
- [x] Spawn houses, tree clusters, rocks and a fence from the village atlas.
- [x] Attach simplified 2D collisions and preserve Y sorting.
- [x] Add the upstream two-frame `pig/pig.png` as the visual creature placeholder.
- [x] Preserve SVG fallback props and slime fallback.

## Task 6: Add environment polish

- [x] Add animated pixel water.
- [x] Add `CanvasModulate`, warm/cool `PointLight2D` nodes and ambient motes.
- [x] Replace the prototype label with compact health, area and control panels.
- [x] Enable pixel snapping and document recursive clone/update commands.

## Task 7: Final remote verification

- [x] Run 13 Python unit tests.
- [x] Run the repository contract validator.
- [x] Compile Python validation tools.
- [x] Import and parse the project with official Godot 4.6.3.
- [x] Smoke-run the main scene for eight frames.
- [x] Make CI fail on Godot `SCRIPT ERROR` and runtime `ERROR:` output.
- [x] Confirm runtime files remain 2D-only and third-party paths are registered.
- [x] Create draft PR #4.

## Remaining manual review

The project imports and starts successfully in official headless Godot. A human visual review on a desktop remains useful for judging atlas region choices, composition, color balance and subjective image quality before merging.
