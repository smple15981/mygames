from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.validate_mouse_interaction import (
    MOUSE_INTERACTION_FILES,
    validate_mouse_interaction,
)


class MouseInteractionValidatorTests(unittest.TestCase):
    def test_mouse_interaction_mvp_files_exist(self) -> None:
        root = Path(__file__).resolve().parents[1]
        errors = validate_mouse_interaction(root)
        self.assertEqual(errors, [])
        for relative in MOUSE_INTERACTION_FILES:
            self.assertTrue((root / relative).is_file(), relative)

    def test_correct_pickup_area_is_not_reported_as_solid(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/test_pickup.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text(
                '[node name="PickupArea" type="Area2D"]\n'
                'collision_layer = 8\n'
                'collision_mask = 0\n',
                encoding="utf-8",
            )
            errors = validate_mouse_interaction(root)
        self.assertNotIn(
            "scenes/test_pickup.tscn PickupArea must use collision layer 8 and mask 0",
            errors,
        )

    def test_pickup_area_rejects_world_solid_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/test_pickup.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text(
                '[node name="PickupArea" type="Area2D"]\n'
                'collision_layer = 1\n'
                'collision_mask = 2\n',
                encoding="utf-8",
            )
            errors = validate_mouse_interaction(root)
        self.assertIn(
            "scenes/test_pickup.tscn PickupArea must use collision layer 8 and mask 0",
            errors,
        )

    def test_interaction_target_rejects_world_solid_layer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scene = root / "scenes/test_target.tscn"
            scene.parent.mkdir(parents=True)
            scene.write_text(
                '[node name="InteractionTarget" type="Area2D"]\n'
                'collision_layer = 1\n'
                'collision_mask = 2\n',
                encoding="utf-8",
            )
            errors = validate_mouse_interaction(root)
        self.assertIn(
            "scenes/test_target.tscn InteractionTarget must use collision layer 4 and mask 0",
            errors,
        )


if __name__ == "__main__":
    unittest.main()
