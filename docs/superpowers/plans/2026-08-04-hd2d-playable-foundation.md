# HD-2D Playable Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot 4.x project that opens into a fixed-camera HD-2D prototype where a Sprite3D player can move around a small 3D farm/forest blockout, with one verified CC0 visual asset and automated repository validation.

**Architecture:** The first slice keeps behavior small and isolated. `PlayerController` owns movement and facing, `PrototypeWorld` owns only blockout scene decoration, and project validation is implemented as a standalone Python tool so the repository can be checked even when the Godot editor is unavailable. Third-party files live under a dedicated source directory with their own license record.

**Tech Stack:** Godot 4.x, GDScript, Godot text scenes/resources, Python 3.11+ validation, GitHub Actions.

## Global Constraints

- Engine: Godot 4.x.
- Language: GDScript.
- Camera: fixed orthographic three-quarter view; no player-controlled rotation.
- Visuals: 3D environment plus camera-facing 2D character/VFX.
- Base viewport: 960×540 with nearest-neighbor sampling for 2D art.
- First delivery is single-player and contains no procedural world, multiplayer, farming simulation, inventory, or combat implementation.
- Third-party assets must have a verified open license and remain isolated under `assets/third_party/<source>/<pack>/`.
- The project must remain openable without third-party downloads by providing original placeholders.

---

## File Map

- `project.godot`: engine configuration, input actions, viewport and main scene.
- `scenes/bootstrap/main.tscn`: application root and world instance.
- `scenes/world/prototype_world.tscn`: fixed camera, lighting, blockout terrain and player instance.
- `scenes/player/player.tscn`: CharacterBody3D, collision, Sprite3D visual and shadow.
- `scripts/player/movement_math.gd`: pure movement/facing helpers.
- `scripts/player/player_controller.gd`: input, velocity, movement and sprite orientation.
- `assets/original/player/player.svg`: original pixel-style player placeholder.
- `assets/third_party/kenney/starter-kit-3d-platformer/particle.png`: CC0 Kenney particle used in the world marker.
- `assets/third_party/kenney/starter-kit-3d-platformer/LICENSE.md`: source license statement.
- `tools/validate_project.py`: deterministic project/scene/license validator.
- `tests/test_validate_project.py`: unit tests for the validator.
- `.github/workflows/validate.yml`: CI that runs the Python validation suite.
- `README.md`: setup, controls, architecture and asset provenance.
- `THIRD_PARTY_NOTICES.md`: exact imported asset record.

### Task 1: Validator and repository contract

**Files:**
- Create: `tools/validate_project.py`
- Create: `tests/test_validate_project.py`

**Interfaces:**
- Produces: `validate_repository(root: pathlib.Path) -> list[str]`, where an empty list means valid.
- Produces CLI exit code `0` on success and `1` with one error per line on failure.

- [ ] **Step 1: Write the failing test**

```python
def test_missing_project_file_is_reported(tmp_path):
    errors = validate_repository(tmp_path)
    assert "missing required file: project.godot" in errors
```

- [ ] **Step 2: Run the test and verify RED**

Run: `python -m unittest tests.test_validate_project -v`
Expected: import failure because `tools.validate_project` does not exist.

- [ ] **Step 3: Implement the minimal validator**

The validator must check the exact required file list, verify `project.godot` contains the configured main scene and display size, verify each `.tscn` external resource path exists, verify `THIRD_PARTY_NOTICES.md` names each file under `assets/third_party`, and reject `TODO`/`TBD` in committed project files.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `python -m unittest tests.test_validate_project -v`
Expected: all validator tests pass.

- [ ] **Step 5: Commit**

```bash
git add tools/validate_project.py tests/test_validate_project.py
git commit -m "test: add project repository validator"
```

### Task 2: Godot project and bootstrap scene

**Files:**
- Create: `project.godot`
- Create: `scenes/bootstrap/main.tscn`
- Create: `scenes/world/prototype_world.tscn`

**Interfaces:**
- Produces main scene `res://scenes/bootstrap/main.tscn`.
- Produces input actions `move_left`, `move_right`, `move_up`, `move_down`, `interact`, `attack`, `dodge`, `pause`.

- [ ] **Step 1: Add a failing validator test**

Create a fixture project without `run/main_scene` and assert the validator reports `project.godot missing run/main_scene`.

- [ ] **Step 2: Run the targeted test and verify RED**

Run: `python -m unittest tests.test_validate_project.ProjectValidatorTests.test_project_requires_main_scene -v`
Expected: failure until the validator/project contract is complete.

- [ ] **Step 3: Add the Godot configuration and scenes**

Set 960×540, stretch mode `canvas_items`, nearest texture filtering, Forward+ rendering, and the exact input actions. Build a 24×18 meter grass ground, dirt path, water plane, farm plots, trees and rocks from primitive meshes. Add a fixed orthographic camera at `(10, 12, 10)` looking at the center and a directional light.

- [ ] **Step 4: Validate**

Run: `python tools/validate_project.py .`
Expected: remaining errors refer only to files scheduled in later tasks.

- [ ] **Step 5: Commit**

```bash
git add project.godot scenes/bootstrap/main.tscn scenes/world/prototype_world.tscn
git commit -m "feat: add HD-2D world scaffold"
```

### Task 3: Player movement and HD-2D presentation

**Files:**
- Create: `scripts/player/movement_math.gd`
- Create: `scripts/player/player_controller.gd`
- Create: `scenes/player/player.tscn`
- Create: `assets/original/player/player.svg`

**Interfaces:**
- `MovementMath.normalized_input(raw: Vector2) -> Vector2`
- `MovementMath.world_direction(input_vector: Vector2) -> Vector3`
- `MovementMath.facing_index(direction: Vector2, previous: int) -> int`
- `PlayerController` export `move_speed: float = 4.5`.

- [ ] **Step 1: Add a failing source-contract test**

Assert that the required methods and `CharacterBody3D` scene root are present and that the player scene references `player.svg` through `Sprite3D`.

- [ ] **Step 2: Run the test and verify RED**

Run: `python -m unittest tests.test_validate_project.ProjectValidatorTests.test_player_contract -v`
Expected: required player files are missing.

- [ ] **Step 3: Implement the minimal player**

Read four movement actions with `Input.get_vector`, convert Y input to the negative Z world axis, normalize diagonals, set `velocity.x/z`, call `move_and_slide`, and retain the last non-zero facing index. Use a camera-facing Sprite3D with nearest-filtered original SVG texture and a flattened dark quad shadow.

- [ ] **Step 4: Run all tests**

Run: `python -m unittest discover -s tests -v`
Expected: all tests pass or only asset-license checks remain.

- [ ] **Step 5: Commit**

```bash
git add scripts/player scenes/player assets/original/player
git commit -m "feat: add movable Sprite3D player"
```

### Task 4: Verified CC0 asset integration

**Files:**
- Create: `assets/third_party/kenney/starter-kit-3d-platformer/particle.png`
- Create: `assets/third_party/kenney/starter-kit-3d-platformer/LICENSE.md`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `THIRD_PARTY_NOTICES.md`

**Interfaces:**
- The particle texture is shown by a small Sprite3D marker near the cave/forest transition.
- The notices record author, upstream repository, exact path, upstream commit reference, license and usage.

- [ ] **Step 1: Add a failing license test**

Create a third-party file in the test fixture without its name in `THIRD_PARTY_NOTICES.md` and assert the validator reports an unregistered asset.

- [ ] **Step 2: Run the test and verify RED**

Run: `python -m unittest tests.test_validate_project.ProjectValidatorTests.test_third_party_assets_must_be_registered -v`
Expected: failure before license validation exists.

- [ ] **Step 3: Import the asset and license record**

Use `sprites/particle.png` from `KenneyNL/Starter-Kit-3D-Platformer`, whose README states included 2D/3D/audio assets are CC0. Preserve a local license/source note and register the imported file in `THIRD_PARTY_NOTICES.md`.

- [ ] **Step 4: Run all tests**

Run: `python -m unittest discover -s tests -v && python tools/validate_project.py .`
Expected: all checks pass.

- [ ] **Step 5: Commit**

```bash
git add assets/third_party scenes/world/prototype_world.tscn THIRD_PARTY_NOTICES.md
git commit -m "assets: add verified Kenney CC0 particle"
```

### Task 5: Documentation and CI

**Files:**
- Modify: `README.md`
- Create: `.github/workflows/validate.yml`

**Interfaces:**
- Documents Godot version floor, controls, current scope, folder ownership and asset policy.
- CI runs `python -m unittest discover -s tests -v` and `python tools/validate_project.py .` on pushes and pull requests.

- [ ] **Step 1: Add a failing documentation test**

Assert README contains `Godot 4`, `WASD`, `HD-2D`, and `THIRD_PARTY_NOTICES.md`.

- [ ] **Step 2: Run the test and verify RED**

Run: `python -m unittest tests.test_validate_project.ProjectValidatorTests.test_readme_documents_bootstrap -v`
Expected: failure against the baseline README.

- [ ] **Step 3: Write documentation and workflow**

Include opening instructions, controls, what is implemented, what is deliberately not implemented, how to run validation, and how third-party assets are accepted.

- [ ] **Step 4: Final verification**

Run:

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
git diff --check
git status -sb
```

Expected: tests pass, validator prints success, no whitespace errors, and only intended files are changed.

- [ ] **Step 5: Commit**

```bash
git add README.md .github/workflows/validate.yml tests/test_validate_project.py
git commit -m "docs: explain and validate playable foundation"
```
