from __future__ import annotations

import argparse
import re
from pathlib import Path

REQUIRED_FILES = (
    ".gitmodules",
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
    "assets/original/player/player.svg",
    "assets/original/player/shadow.svg",
    "assets/original/world/house.svg",
    "assets/original/world/tree.svg",
    "assets/original/world/rock.svg",
    "THIRD_PARTY_NOTICES.md",
    "README.md",
)

OPEN_ASSET_FILES = (
    "vendor/ninja-adventure/content/map/tileset_floor.png",
    "vendor/ninja-adventure/content/map/tileset_village_abandoned.png",
    "vendor/ninja-adventure/content/character/ninja_blue/sprite.png",
    "vendor/ninja-adventure/content/character/pig/pig.png",
    "vendor/ninja-adventure/content/character/Shadow.png",
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

    for relative in REQUIRED_FILES:
        if not (root / relative).is_file():
            errors.append(f"missing required file: {relative}")

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
            ),
            "project.godot",
        )

    player_scene = root / "scenes/player/player.tscn"
    if player_scene.is_file():
        player_text = _read_text(player_scene)
        if 'type="CharacterBody2D"' not in player_text:
            errors.append("player scene root must be CharacterBody2D")
        _require_tokens(
            errors,
            player_text,
            ('type="Sprite2D"', "hframes = 4", "vframes = 7", "Camera2D"),
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
                "WaterSurface",
                "PointLight2D",
                "CanvasLayer",
            ),
            "world scene",
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
                "func _direction_column",
                "func _animation_row",
                "frame_coords",
            ),
            "player_controller.gd",
        )

    library_path = root / "scripts/assets/open_asset_library.gd"
    if library_path.is_file():
        _require_tokens(
            errors,
            _read_text(library_path),
            (
                "class_name OpenAssetLibrary",
                "const FLOOR_ATLAS",
                "const VILLAGE_ATLAS",
                "const PLAYER_SHEET",
                "const PIG_SHEET",
                "func load_texture",
                "git submodule update --init --recursive",
            ),
            "open_asset_library.gd",
        )

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

    builder_path = root / "scripts/world/prototype_world.gd"
    if builder_path.is_file():
        _require_tokens(
            errors,
            _read_text(builder_path),
            (
                "TileSetAtlasSource",
                "OpenAssetLibrary.FLOOR_ATLAS",
                "OpenAssetLibrary.VILLAGE_ATLAS",
                "OpenAtlasRegions",
                "ground.set_cell",
                "_build_fallback_props",
                "assets/original/world/house.svg",
            ),
            "prototype_world.gd",
        )

    gitmodules_path = root / ".gitmodules"
    if gitmodules_path.is_file():
        _require_tokens(
            errors,
            _read_text(gitmodules_path),
            (
                "path = vendor/ninja-adventure",
                "url = https://github.com/pixel-boy/NinjaAdventure.git",
            ),
            ".gitmodules",
        )
        for relative in OPEN_ASSET_FILES:
            if not (root / relative).is_file():
                errors.append(f"missing checked-out open asset: {relative}")

    workflow_path = root / ".github/workflows/validate.yml"
    if workflow_path.is_file() and "submodules: recursive" not in _read_text(workflow_path):
        errors.append("validation workflow must recursively check out submodules")

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
    print("Hearthwild open-art 2D project validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
