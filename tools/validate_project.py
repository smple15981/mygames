from __future__ import annotations

import argparse
import re
from pathlib import Path

REQUIRED_FILES = (
    "project.godot",
    "scenes/bootstrap/main.tscn",
    "scenes/world/prototype_world.tscn",
    "scenes/player/player.tscn",
    "scripts/player/movement_math.gd",
    "scripts/player/player_controller.gd",
    "scripts/world/prototype_world.gd",
    "assets/original/player/player.svg",
    "assets/original/player/shadow.svg",
    "assets/original/world/house.svg",
    "assets/original/world/tree.svg",
    "assets/original/world/rock.svg",
    "THIRD_PARTY_NOTICES.md",
    "README.md",
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

    player_scene = root / "scenes/player/player.tscn"
    if player_scene.is_file():
        player_text = _read_text(player_scene)
        if 'type="CharacterBody2D"' not in player_text:
            errors.append("player scene root must be CharacterBody2D")
        if "AnimatedSprite2D" not in player_text:
            errors.append("player scene must use AnimatedSprite2D")
        if "Camera2D" not in player_text:
            errors.append("player scene must include Camera2D")

    world_scene = root / "scenes/world/prototype_world.tscn"
    if world_scene.is_file():
        world_text = _read_text(world_scene)
        if 'type="TileMapLayer"' not in world_text:
            errors.append("world scene must include TileMapLayer")
        if "y_sort_enabled = true" not in world_text:
            errors.append("world entities must enable y sorting")

    movement_path = root / "scripts/player/movement_math.gd"
    if movement_path.is_file():
        movement_text = _read_text(movement_path)
        for method in ("normalized_input", "facing_index", "animation_name"):
            if f"func {method}" not in movement_text:
                errors.append(f"movement_math.gd missing {method}")

    controller_path = root / "scripts/player/player_controller.gd"
    if controller_path.is_file():
        controller_text = _read_text(controller_path)
        if "extends CharacterBody2D" not in controller_text:
            errors.append("player_controller.gd must extend CharacterBody2D")

    builder_path = root / "scripts/world/prototype_world.gd"
    if builder_path.is_file():
        builder_text = _read_text(builder_path)
        for token in ("TileSetAtlasSource", "ground.set_cell", "TILE_SIZE := Vector2i(32, 32)"):
            if token not in builder_text:
                errors.append(f"prototype_world.gd missing 2D tile contract: {token}")

    scan_paths = [project_path]
    scan_paths.extend(root.glob("scenes/**/*.tscn"))
    scan_paths.extend(root.glob("scripts/**/*.gd"))
    for path in scan_paths:
        if not path.is_file():
            continue
        text = _read_text(path)
        for token in PROHIBITED_3D_TOKENS:
            if token in text:
                errors.append(f"3D token remains in {path.relative_to(root).as_posix()}: {token}")

    for scene_path in root.rglob("*.tscn"):
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
    print("Hearthwild 2D project validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
