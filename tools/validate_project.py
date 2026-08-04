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
    "assets/original/player/player.svg",
    "THIRD_PARTY_NOTICES.md",
    "README.md",
)

TEXT_SUFFIXES = {".gd", ".godot", ".tscn", ".tres", ".md", ".py", ".yml", ".yaml", ".svg", ".json"}
EXT_RESOURCE_PATTERN = re.compile(r'path="res://([^"\n]+)"')


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
        if "viewport_width=960" not in project_text or "viewport_height=540" not in project_text:
            errors.append("project.godot must configure a 960x540 viewport")

    player_scene = root / "scenes/player/player.tscn"
    if player_scene.is_file():
        player_scene_text = _read_text(player_scene)
        if 'type="CharacterBody3D"' not in player_scene_text:
            errors.append("player scene root must be CharacterBody3D")
        if "Sprite3D" not in player_scene_text or "player.svg" not in player_scene_text:
            errors.append("player scene must present player.svg through Sprite3D")

    movement_path = root / "scripts/player/movement_math.gd"
    if movement_path.is_file():
        movement_text = _read_text(movement_path)
        for method in ("normalized_input", "world_direction", "facing_index"):
            if f"func {method}" not in movement_text:
                errors.append(f"movement_math.gd missing {method}")

    controller_path = root / "scripts/player/player_controller.gd"
    if controller_path.is_file():
        controller_text = _read_text(controller_path)
        if "extends CharacterBody3D" not in controller_text:
            errors.append("player_controller.gd must extend CharacterBody3D")

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
    parser = argparse.ArgumentParser(description="Validate the Hearthwild Godot project repository.")
    parser.add_argument("root", nargs="?", default=".", type=Path)
    args = parser.parse_args()
    errors = validate_repository(args.root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Hearthwild project validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
