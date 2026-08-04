from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.validate_project import validate_repository


class ProjectValidatorTests(unittest.TestCase):
    def test_missing_project_file_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            errors = validate_repository(Path(directory))
        self.assertIn("missing required file: project.godot", errors)

    def test_project_requires_main_scene(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "project.godot").write_text("[application]\n", encoding="utf-8")
            errors = validate_repository(root)
        self.assertIn("project.godot missing run/main_scene", errors)

    def test_project_requires_target_viewport(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "project.godot").write_text(
                '[application]\nrun/main_scene="res://scenes/bootstrap/main.tscn"\n',
                encoding="utf-8",
            )
            errors = validate_repository(root)
        self.assertIn("project.godot must configure a 960x540 viewport", errors)

    def test_player_contract(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            player_scene = root / "scenes/player/player.tscn"
            player_scene.parent.mkdir(parents=True)
            player_scene.write_text('[gd_scene format=3]\n[node name="Player" type="Node3D"]\n', encoding="utf-8")
            movement = root / "scripts/player/movement_math.gd"
            movement.parent.mkdir(parents=True)
            movement.write_text("extends RefCounted\n", encoding="utf-8")
            controller = root / "scripts/player/player_controller.gd"
            controller.write_text("extends Node3D\n", encoding="utf-8")
            errors = validate_repository(root)
        self.assertIn("player scene root must be CharacterBody3D", errors)
        self.assertIn("movement_math.gd missing normalized_input", errors)
        self.assertIn("movement_math.gd missing world_direction", errors)
        self.assertIn("movement_math.gd missing facing_index", errors)
        self.assertIn("player_controller.gd must extend CharacterBody3D", errors)

    def test_third_party_assets_must_be_registered(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            asset = root / "assets/third_party/example/pack/sprite.png"
            asset.parent.mkdir(parents=True)
            asset.write_bytes(b"png")
            (root / "THIRD_PARTY_NOTICES.md").write_text("# Notices\n", encoding="utf-8")
            errors = validate_repository(root)
        self.assertIn(
            "unregistered third-party asset: assets/third_party/example/pack/sprite.png",
            errors,
        )

    def test_scene_resources_must_exist(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/example.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text(
                '[gd_scene format=3]\n[ext_resource type="Texture2D" path="res://missing.png" id="1"]\n',
                encoding="utf-8",
            )
            errors = validate_repository(root)
        self.assertIn("missing scene resource: scenes/example.tscn -> missing.png", errors)

    def test_readme_documents_bootstrap(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        readme = (repository_root / "README.md").read_text(encoding="utf-8")
        for phrase in ("Godot 4", "WASD", "HD-2D", "THIRD_PARTY_NOTICES.md"):
            self.assertIn(phrase, readme)


if __name__ == "__main__":
    unittest.main()
