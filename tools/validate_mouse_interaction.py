from __future__ import annotations

import argparse
import re
from pathlib import Path

MOUSE_INTERACTION_FILES = (
    "scripts/input/cursor_state_manager.gd",
    "scripts/player/auto_move_agent.gd",
    "scripts/player/mouse_interaction_controller.gd",
    "scripts/ui/action_feedback.gd",
    "scripts/world/interaction_target.gd",
    "scripts/world/harvestable_resource.gd",
    "scripts/world/world_pickup.gd",
    "scripts/world/world_pickup_factory.gd",
    "scripts/world/world_path_grid.gd",
    "scripts/world/world_interaction_manager.gd",
    "assets/original/ui/interaction_outline.gdshader",
    "assets/original/ui/cursors/default.svg",
    "assets/original/ui/cursors/axe.svg",
    "assets/original/ui/cursors/pickaxe.svg",
    "assets/original/ui/cursors/pickup.svg",
    "assets/original/ui/cursors/interact.svg",
    "assets/original/ui/cursors/unreachable.svg",
    "assets/original/ui/cursors/tool_locked.svg",
    "tests/godot/suites/test_world_path_grid.gd",
    "tests/godot/suites/test_interaction_target.gd",
    "tests/godot/suites/test_harvestable_resource.gd",
    "tests/godot/suites/test_world_pickup.gd",
    "tests/godot/suites/test_auto_move_agent.gd",
    "tests/godot/suites/test_mouse_interaction.gd",
    "tests/godot/suites/test_playable_loop.gd",
    "tests/test_validate_mouse_interaction.py",
)

AREA_NODE_PATTERN = re.compile(
    r'^\[node\s+name="(?P<name>[^"]+)"[^\]]*type="Area2D"[^\]]*\]\n'
    r'(?P<body>.*?)(?=^\[node\s|\Z)',
    re.MULTILINE | re.DOTALL,
)


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise ValueError(f"cannot read text file {path}: {exc}") from exc


def _require_tokens(
    errors: list[str],
    text: str,
    tokens: tuple[str, ...],
    label: str,
) -> None:
    for token in tokens:
        if token not in text:
            errors.append(f"{label} missing contract token: {token}")


def _integer_property(body: str, name: str, default: int) -> int:
    match = re.search(rf"^{re.escape(name)}\s*=\s*(-?\d+)\s*$", body, re.MULTILINE)
    return int(match.group(1)) if match else default


def _validate_area_layers(root: Path, errors: list[str]) -> None:
    scenes_root = root / "scenes"
    if not scenes_root.is_dir():
        return

    for scene_path in scenes_root.rglob("*.tscn"):
        text = _read_text(scene_path)
        relative = scene_path.relative_to(root).as_posix()
        for match in AREA_NODE_PATTERN.finditer(text):
            name = match.group("name")
            body = match.group("body")
            layer = _integer_property(body, "collision_layer", 1)
            mask = _integer_property(body, "collision_mask", 1)
            if name == "InteractionTarget" and (layer != 4 or mask != 0):
                errors.append(
                    f"{relative} InteractionTarget must use collision layer 4 and mask 0"
                )
            if name == "PickupArea" and (layer != 8 or mask != 0):
                errors.append(
                    f"{relative} PickupArea must use collision layer 8 and mask 0"
                )


def validate_mouse_interaction(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []

    for relative in MOUSE_INTERACTION_FILES:
        if not (root / relative).is_file():
            errors.append(f"missing mouse interaction file: {relative}")

    contracts = (
        (
            "scenes/world/prototype_world.tscn",
            (
                "WorldPathGrid",
                "WorldInteractionManager",
                "CursorStateManager",
                "ActionFeedback",
            ),
            "world scene",
        ),
        (
            "scenes/player/player.tscn",
            (
                "AutoMoveAgent",
                "MouseInteractionController",
                "scripts/player/auto_move_agent.gd",
                "scripts/player/mouse_interaction_controller.gd",
            ),
            "player scene",
        ),
        (
            "scripts/world/world_prop_factory.gd",
            (
                "InteractionTarget.new()",
                "target.collision_layer = 4",
                "target.collision_mask = 0",
                'harvestable.add_to_group("harvestables")',
            ),
            "world_prop_factory.gd",
        ),
        (
            "scripts/world/world_pickup.gd",
            (
                "class_name WorldPickup",
                "area.collision_layer = 8",
                "area.collision_mask = 0",
                "inventory.add_item",
            ),
            "world_pickup.gd",
        ),
        (
            "scripts/world/world_path_grid.gd",
            (
                "class_name WorldPathGrid",
                "AStarGrid2D",
                "func find_path",
                "footprint_registered",
                "footprint_unregistered",
            ),
            "world_path_grid.gd",
        ),
        (
            "scripts/player/mouse_interaction_controller.gd",
            (
                "class_name MouseInteractionController",
                "CursorStateManager.State.TOOL_LOCKED",
                "CursorStateManager.State.UNREACHABLE",
                "target_requested.emit",
            ),
            "mouse_interaction_controller.gd",
        ),
        (
            "scripts/world/world_interaction_manager.gd",
            (
                "class_name WorldInteractionManager",
                "func begin_interaction",
                "func _perform_harvest_hit",
                "WorldPickupFactory.spawn",
                "harvest_completed.emit",
            ),
            "world_interaction_manager.gd",
        ),
    )

    for relative, tokens, label in contracts:
        path = root / relative
        if path.is_file():
            _require_tokens(errors, _read_text(path), tokens, label)

    _validate_area_layers(root, errors)
    return sorted(set(errors))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate Hearthwild mouse interaction and harvesting contracts."
    )
    parser.add_argument("root", nargs="?", default=".", type=Path)
    args = parser.parse_args()
    errors = validate_mouse_interaction(args.root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Hearthwild mouse interaction MVP validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
