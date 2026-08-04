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

    def test_project_requires_pixel_viewport(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "project.godot").write_text(
                '[application]\nrun/main_scene="res://scenes/bootstrap/main.tscn"\n',
                encoding="utf-8",
            )
            errors = validate_repository(root)
        self.assertIn("project.godot must configure a 640x360 viewport", errors)

    def test_player_requires_pure_2d_nodes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/player/player.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text('[node name="Player" type="CharacterBody3D"]\n', encoding="utf-8")
            errors = validate_repository(root)
        self.assertIn("player scene root must be CharacterBody2D", errors)
        self.assertIn("player scene must use AnimatedSprite2D", errors)
        self.assertIn("player scene must include Camera2D", errors)

    def test_world_requires_tilemap_and_y_sort(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/world/prototype_world.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text('[node name="World" type="Node2D"]\n', encoding="utf-8")
            errors = validate_repository(root)
        self.assertIn("world scene must include TileMapLayer", errors)
        self.assertIn("world entities must enable y sorting", errors)

    def test_3d_nodes_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/example.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text('[node name="Camera" type="Camera3D"]\n', encoding="utf-8")
            errors = validate_repository(root)
        self.assertIn("3D token remains in scenes/example.tscn: Camera3D", errors)

    def test_scene_resources_must_exist(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/example.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text(
                '[ext_resource type="Texture2D" path="res://missing.png" id="1"]\n',
                encoding="utf-8",
            )
            errors = validate_repository(root)
        self.assertIn("missing scene resource: scenes/example.tscn -> missing.png", errors)

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

    def test_readme_documents_pure_2d_stack(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        readme = (repository_root / "README.md").read_text(encoding="utf-8")
        for phrase in ("Hearthwild 2D", "TileMapLayer", "CharacterBody2D", "纯 2D"):
            self.assertIn(phrase, readme)
        self.assertNotIn("Sprite3D", readme)


if __name__ == "__main__":
    unittest.main()
