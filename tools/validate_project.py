from __future__ import annotations

import argparse
import re
from pathlib import Path

REQUIRED_FILES = (
    "project.godot",
    "scenes/bootstrap/main.tscn",
    "scenes/world/prototype_world.tscn",
    "scenes/player/player.tscn",
    "scripts/assets/open_asset_library.gd",
    "scripts/player/movement_math.gd",
    "scripts/player/player_controller.gd",
    "scripts/world/floating_motes.gd",
    "scripts/world/open_atlas_regions.gd",
    "scripts/world/prototype_world.gd",
    "scripts/world/visual_critter.gd",
    "scripts/world/water_surface.gd",
    "tests/godot/test_assert.gd",
    "tests/godot/test_runner.gd",
    "tests/godot/suites/test_action_protocol.gd",
    "assets/original/player/player.svg",
    "assets/original/player/shadow.svg",
    "assets/original/world/house.svg",
    "assets/original/world/tree.svg",
    "assets/original/world/rock.svg",
    "THIRD_PARTY_NOTICES.md",
    "README.md",
)

GAMEPLAY_FOUNDATION_FILES = (
    "scripts/actions/action_request.gd",
    "scripts/actions/action_result.gd",
    "scripts/items/item_definition.gd",
    "scripts/items/item_catalog.gd",
    "scripts/inventory/inventory_slot.gd",
    "scripts/inventory/inventory_model.gd",
    "scripts/crafting/recipe_definition.gd",
    "scripts/crafting/crafting_result.gd",
    "scripts/crafting/crafting_service.gd",
    "scripts/player/item_user.gd",
    "scripts/ui/hotbar_ui.gd",
    "scripts/ui/inventory_ui.gd",
    "scenes/ui/hotbar_ui.tscn",
    "scenes/ui/inventory_ui.tscn",
    "tests/godot/suites/test_inventory_model.gd",
    "tests/godot/suites/test_crafting_service.gd",
    "data/items/branch.tres",
    "data/items/loose_stone.tres",
    "data/items/wood.tres",
    "data/items/stone.tres",
    "data/items/grass.tres",
    "data/items/slime_gel.tres",
    "data/items/stone_axe.tres",
    "data/items/stone_pickaxe.tres",
    "data/items/wooden_sword.tres",
    "data/items/wooden_hoe.tres",
    "data/items/worn_watering_can.tres",
    "data/items/moon_dew_seed.tres",
    "data/items/moon_dew_radish.tres",
    "data/items/torch.tres",
    "data/items/simple_bandage.tres",
    "data/recipes/stone_axe.tres",
    "data/recipes/stone_pickaxe.tres",
    "data/recipes/wooden_sword.tres",
    "data/recipes/torch.tres",
    "data/recipes/wooden_hoe.tres",
    "data/recipes/simple_bandage.tres",
)

WORLD_ENHANCEMENT_FILES = (
    "scripts/world/world_layout_config.gd",
    "data/world/default_world_layout.tres",
    "scripts/player/player_stats.gd",
    "scripts/ui/stats_hud.gd",
    "scenes/ui/stats_hud.tscn",
    "scripts/player/camera_rig.gd",
    "scripts/core/pause_coordinator.gd",
    "scripts/input/game_input_router.gd",
    "scripts/world/world_prop_definition.gd",
    "scripts/world/world_collision_registry.gd",
    "scripts/world/world_prop_factory.gd",
    "scripts/world/world_layout.gd",
    "data/world/props/farmhouse.tres",
    "data/world/props/workshop.tres",
    "data/world/props/tree_small.tres",
    "data/world/props/tree_cluster.tres",
    "data/world/props/rock_cluster.tres",
    "data/world/props/fence_horizontal.tres",
    "tests/godot/suites/test_world_layout_config.gd",
    "tests/godot/suites/test_player_stats.gd",
    "tests/godot/suites/test_camera_rig.gd",
    "tests/godot/suites/test_game_input_router.gd",
    "tests/godot/suites/test_world_collisions.gd",
    "tests/godot/suites/test_world_integration.gd",
)

OPEN_ASSET_FILES = (
    "assets/third_party/ninja-adventure/tileset_floor.png",
    "assets/third_party/ninja-adventure/tileset_village_abandoned.png",
    "assets/third_party/ninja-adventure/ninja_blue.png",
    "assets/third_party/ninja-adventure/pig.png",
    "assets/third_party/ninja-adventure/shadow.png",
)

EXT_RESOURCE_PATTERN = re.compile(r'path="res://([^"\n]+)"')
PROHIBITED_3D_TOKENS = (
    "CharacterBody3D",
    "Node3D",
    "Sprite3D",
    "Camera3D",
    "StaticBody3D",
    "CollisionShape3D",
    "MeshInstance3D",
    "DirectionalLight3D",
    "WorldEnvironment",
)


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise ValueError(f"cannot read text file {path}: {exc}") from exc


def _require_tokens(errors: list[str], text: str, tokens: tuple[str, ...], label: str) -> None:
    for token in tokens:
        if token not in text:
            errors.append(f"{label} missing contract token: {token}")


def validate_repository(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []

    for relative in REQUIRED_FILES + GAMEPLAY_FOUNDATION_FILES + WORLD_ENHANCEMENT_FILES:
        if not (root / relative).is_file():
            errors.append(f"missing required file: {relative}")

    for relative in OPEN_ASSET_FILES:
        if not (root / relative).is_file():
            errors.append(f"missing bundled open asset: {relative}")

    project_path = root / "project.godot"
    if project_path.is_file():
        project_text = _read_text(project_path)
        if 'run/main_scene="res://scenes/bootstrap/main.tscn"' not in project_text:
            errors.append("project.godot missing run/main_scene")
        if "viewport_width=640" not in project_text or "viewport_height=360" not in project_text:
            errors.append("project.godot must configure a 640x360 viewport")
        _require_tokens(
            errors,
            project_text,
            (
                "textures/canvas_textures/default_texture_filter=0",
                "2d/snap/snap_2d_transforms_to_pixel=true",
                "2d/snap/snap_2d_vertices_to_pixel=true",
                "inventory={",
                "quick_slot_5={",
            ),
            "project.godot",
        )
        if 'ItemCatalog="*res://scripts/items/item_catalog.gd"' in project_text:
            errors.append("project.godot must not expose ItemCatalog only as an autoload")

    player_scene = root / "scenes/player/player.tscn"
    if player_scene.is_file():
        player_text = _read_text(player_scene)
        if 'type="CharacterBody2D"' not in player_text:
            errors.append("player scene root must be CharacterBody2D")
        _require_tokens(
            errors,
            player_text,
            (
                'type="Sprite2D"',
                "hframes = 4",
                "vframes = 7",
                "Camera2D",
                "scripts/inventory/inventory_model.gd",
                "scripts/player/item_user.gd",
                "scripts/player/player_stats.gd",
                "scripts/player/camera_rig.gd",
                'NodePath("../Inventory")',
            ),
            "player scene",
        )

    world_scene = root / "scenes/world/prototype_world.tscn"
    if world_scene.is_file():
        _require_tokens(
            errors,
            _read_text(world_scene),
            (
                'type="TileMapLayer"',
                "y_sort_enabled = true",
                "CanvasModulate",
                "WorldLayout",
                "WorldCollisionRegistry",
                "PauseCoordinator",
                "GameInputRouter",
                "PointLight2D",
                "CanvasLayer",
                "scenes/ui/hotbar_ui.tscn",
                "scenes/ui/inventory_ui.tscn",
            ),
            "world scene",
        )

    hotbar_scene = root / "scenes/ui/hotbar_ui.tscn"
    if hotbar_scene.is_file():
        _require_tokens(
            errors,
            _read_text(hotbar_scene),
            ("HotbarUI", "HBoxContainer"),
            "hotbar scene",
        )

    inventory_scene = root / "scenes/ui/inventory_ui.tscn"
    if inventory_scene.is_file():
        _require_tokens(
            errors,
            _read_text(inventory_scene),
            ("GridContainer", "columns = 5", "RecipeList", "CraftButton"),
            "inventory scene",
        )

    controller_path = root / "scripts/player/player_controller.gd"
    if controller_path.is_file():
        _require_tokens(
            errors,
            _read_text(controller_path),
            (
                "extends CharacterBody2D",
                "OpenAssetLibrary.PLAYER_SHEET",
                "OpenAssetLibrary.SHADOW_TEXTURE",
                "func aim_direction",
                "item_user.request_use",
                "func set_gameplay_input_blocked",
                "func _direction_column",
                "func _animation_row",
                "frame_coords",
            ),
            "player_controller.gd",
        )

    catalog_path = root / "scripts/items/item_catalog.gd"
    if catalog_path.is_file():
        _require_tokens(
            errors,
            _read_text(catalog_path),
            (
                "class_name ItemCatalog",
                "static func get_item",
                "static func has_item",
                "static func all_items",
                'res://data/items/wooden_sword.tres',
            ),
            "item_catalog.gd",
        )

    library_path = root / "scripts/assets/open_asset_library.gd"
    if library_path.is_file():
        library_text = _read_text(library_path)
        _require_tokens(
            errors,
            library_text,
            (
                "class_name OpenAssetLibrary",
                "res://assets/third_party/ninja-adventure",
                "const FLOOR_ATLAS",
                "const VILLAGE_ATLAS",
                "const PLAYER_SHEET",
                "const PIG_SHEET",
                "func load_texture",
                "using local fallback",
            ),
            "open_asset_library.gd",
        )
        if "res://vendor/ninja-adventure" in library_text:
            errors.append("open_asset_library.gd must not depend on the vendor submodule")

    atlas_path = root / "scripts/world/open_atlas_regions.gd"
    if atlas_path.is_file():
        _require_tokens(
            errors,
            _read_text(atlas_path),
            (
                "class_name OpenAtlasRegions",
                "SOURCE_TILE_SIZE := Vector2i(16, 16)",
                "GRASS_TILES",
                "HOUSE_LARGE",
                "TREE_CLUSTER",
                "func region_fits",
            ),
            "open_atlas_regions.gd",
        )

    composition_path = root / "scripts/world/prototype_world.gd"
    if composition_path.is_file():
        _require_tokens(
            errors,
            _read_text(composition_path),
            (
                "world_layout.build()",
                "world_layout.spawn_position()",
                "world_layout.recover_player_position",
                "camera_rig.configure_world",
                "input_router.bind",
                "hotbar_ui.bind(player_inventory)",
                "inventory_ui.bind(player_inventory)",
            ),
            "prototype_world.gd",
        )

    layout_path = root / "scripts/world/world_layout.gd"
    if layout_path.is_file():
        _require_tokens(
            errors,
            _read_text(layout_path),
            (
                "class_name WorldLayout",
                "TileSetAtlasSource",
                "OpenAssetLibrary.FLOOR_ATLAS",
                "OpenAssetLibrary.VILLAGE_ATLAS",
                "OpenAtlasRegions",
                "ground.set_cell",
                "_build_fallback_props",
                "assets/original/world/house.svg",
                "WorldPropFactory.spawn_atlas_prop",
                "func boundary_cells",
                "func validate_required_routes",
                "func recover_player_position",
                "_build_river_collisions",
            ),
            "world_layout.gd",
        )

    workflow_path = root / ".github/workflows/validate.yml"
    if workflow_path.is_file():
        workflow_text = _read_text(workflow_path)
        if "submodules: recursive" in workflow_text:
            errors.append("validation workflow must prove a normal checkout works without submodules")
        if "Upload pinned runtime art" in workflow_text:
            errors.append("validation workflow must not inject runtime art before testing")
        if "--script res://tests/godot/test_runner.gd" not in workflow_text:
            errors.append("validation workflow must run headless gameplay tests")

    scan_paths = [project_path]
    if (root / "scenes").is_dir():
        scan_paths.extend((root / "scenes").rglob("*.tscn"))
    if (root / "scripts").is_dir():
        scan_paths.extend((root / "scripts").rglob("*.gd"))
    for path in scan_paths:
        if not path.is_file():
            continue
        text = _read_text(path)
        for token in PROHIBITED_3D_TOKENS:
            if token in text:
                errors.append(f"3D token remains in {path.relative_to(root).as_posix()}: {token}")

    scenes_root = root / "scenes"
    if scenes_root.is_dir():
        for scene_path in scenes_root.rglob("*.tscn"):
            scene_text = _read_text(scene_path)
            for referenced in EXT_RESOURCE_PATTERN.findall(scene_text):
                if not (root / referenced).exists():
                    scene_relative = scene_path.relative_to(root).as_posix()
                    errors.append(f"missing scene resource: {scene_relative} -> {referenced}")

    notices_path = root / "THIRD_PARTY_NOTICES.md"
    notices = _read_text(notices_path) if notices_path.is_file() else ""
    third_party_root = root / "assets/third_party"
    if third_party_root.is_dir():
        license_names = {"LICENSE", "LICENSE.MD", "README", "README.MD", "SOURCE.MD"}
        for asset in third_party_root.rglob("*"):
            if not asset.is_file() or asset.name.upper() in license_names:
                continue
            relative = asset.relative_to(root).as_posix()
            if relative not in notices:
                errors.append(f"unregistered third-party asset: {relative}")

    for relative in OPEN_ASSET_FILES:
        if relative not in notices:
            errors.append(f"unregistered open asset: {relative}")

    return sorted(set(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the Hearthwild 2D Godot project repository.")
    parser.add_argument("root", nargs="?", default=".", type=Path)
    args = parser.parse_args()
    errors = validate_repository(args.root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Hearthwild world-enhancement 2D project validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
