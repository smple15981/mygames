from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.validate_project import (
    GAMEPLAY_FOUNDATION_FILES,
    OPEN_ASSET_FILES,
    validate_repository,
)


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
        self.assertIn(
            "project.godot missing contract token: 2d/snap/snap_2d_transforms_to_pixel=true",
            errors,
        )

    def test_player_requires_open_sprite_atlas(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/player/player.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text('[node name="Player" type="CharacterBody3D"]\n', encoding="utf-8")
            errors = validate_repository(root)
        self.assertIn("player scene root must be CharacterBody2D", errors)
        self.assertIn('player scene missing contract token: type="Sprite2D"', errors)
        self.assertIn("player scene missing contract token: hframes = 4", errors)
        self.assertIn("player scene missing contract token: vframes = 7", errors)
        self.assertIn("player scene missing contract token: Camera2D", errors)

    def test_world_requires_polished_2d_stack(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/world/prototype_world.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text('[node name="World" type="Node2D"]\n', encoding="utf-8")
            errors = validate_repository(root)
        for token in (
            'type="TileMapLayer"',
            "y_sort_enabled = true",
            "CanvasModulate",
            "WaterSurface",
            "PointLight2D",
            "CanvasLayer",
        ):
            self.assertIn(f"world scene missing contract token: {token}", errors)

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

    def test_runtime_art_is_bundled_in_normal_checkout(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        for relative in OPEN_ASSET_FILES:
            self.assertTrue((repository_root / relative).is_file(), relative)

    def test_gameplay_foundation_files_exist(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        for relative in GAMEPLAY_FOUNDATION_FILES:
            self.assertTrue((repository_root / relative).is_file(), relative)

    def test_ci_does_not_require_submodules_for_runtime(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        workflow = (repository_root / ".github/workflows/validate.yml").read_text(encoding="utf-8")
        self.assertNotIn("submodules: recursive", workflow)
        self.assertNotIn("Upload pinned runtime art", workflow)

    def test_ci_runs_headless_gameplay_tests(self) -> None:
        root = Path(__file__).resolve().parents[1]
        workflow = (root / ".github/workflows/validate.yml").read_text(encoding="utf-8")
        self.assertIn("--script res://tests/godot/test_runner.gd", workflow)
        self.assertTrue((root / "tests/godot/test_runner.gd").is_file())

    def test_inventory_ui_contract_exists(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        for relative in (
            "scenes/ui/hotbar_ui.tscn",
            "scenes/ui/inventory_ui.tscn",
            "scripts/ui/hotbar_ui.gd",
            "scripts/ui/inventory_ui.gd",
        ):
            self.assertTrue((repository_root / relative).is_file(), relative)
        inventory_scene = (repository_root / "scenes/ui/inventory_ui.tscn").read_text(encoding="utf-8")
        self.assertIn("columns = 5", inventory_scene)
        self.assertIn("RecipeList", inventory_scene)

    def test_runtime_loader_does_not_depend_on_vendor_project(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        library = (repository_root / "scripts/assets/open_asset_library.gd").read_text(encoding="utf-8")
        self.assertIn("res://assets/third_party/ninja-adventure", library)
        self.assertNotIn("res://vendor/ninja-adventure", library)

    def test_open_asset_loader_has_fallbacks(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        library = (repository_root / "scripts/assets/open_asset_library.gd").read_text(encoding="utf-8")
        for phrase in (
            "class_name OpenAssetLibrary",
            "const FLOOR_ATLAS",
            "const VILLAGE_ATLAS",
            "const PLAYER_SHEET",
            "func load_texture",
            "using local fallback",
        ):
            self.assertIn(phrase, library)

    def test_readme_documents_bundled_open_art(self) -> None:
        repository_root = Path(__file__).resolve().parents[1]
        readme = (repository_root / "README.md").read_text(encoding="utf-8")
        for phrase in (
            "Hearthwild 2D",
            "Ninja Adventure",
            "无需初始化 submodule",
            "640×360",
            "THIRD_PARTY_NOTICES.md",
        ):
            self.assertIn(phrase, readme)
        self.assertNotIn("--recurse-submodules", readme)
        self.assertNotIn("Sprite3D", readme)


if __name__ == "__main__":
    unittest.main()
