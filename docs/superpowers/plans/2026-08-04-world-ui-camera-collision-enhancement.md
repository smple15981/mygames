# World, UI, Camera, and Collision Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Hearthwild 2D to a 96×64 world with reliable modal input, bounded camera zoom, three player-resource bars, a full-map minimap, and base-only collisions that stop prop clipping while preserving top-down occlusion.

**Architecture:** Introduce small Godot components around the current prototype instead of replacing the project: an authoritative `WorldLayoutConfig`, a collision registry and prop factory, a `PlayerStats` component, a `CameraRig`, a `PauseCoordinator` plus `GameInputRouter`, and focused HUD scenes. `PrototypeWorld` remains the composition root and delegates map painting, prop construction, camera limits, minimap binding, and UI binding to these components.

**Tech Stack:** Godot 4.3+ / GDScript, Godot 4.6.3 headless CI, Python 3.13 repository tests, GitHub Actions, existing pure-2D and bundled open-art pipeline.

## Global Constraints

- Preserve the 640×360 internal viewport and nearest-neighbor pixel rendering.
- Preserve 16×16 source tiles displayed at 2× scale as 32×32 logical cells.
- The authoritative map size is exactly 96×64 cells, or 3072×2048 world pixels.
- Preserve the current `CharacterBody2D` player, 20-slot inventory, five-slot quickbar, portable crafting, and item request protocol.
- Direct mouse wheel changes camera zoom; Ctrl + mouse wheel cycles quickbar slots; number keys 1–5 still select slots.
- Camera zoom is clamped to 0.75–1.50, starts at 1.00, and changes in 0.125 steps.
- Tab opens and closes inventory before GUI focus traversal can consume the key.
- Escape closes inventory before any pause-menu action.
- Inventory pause ownership must not clear another active pause reason.
- Solid props collide only at their physical bases; decorative props create no collision.
- World solids remain on collision layer 1; the player remains on layer 2 with mask 1.
- No combat damage, enemy AI, harvesting results, farming progression, magic abilities, third-party plugins, or 3D nodes are added.
- Every task uses failing tests first, then the smallest implementation, then focused and full verification.

---

## File Structure

### Create

- `scripts/world/world_layout_config.gd` — authoritative dimensions, terrain regions, routes, spawn, water, and minimap coordinate conversion.
- `data/world/default_world_layout.tres` — default 96×64 layout resource.
- `scripts/player/player_stats.gd` — health, stamina, mana, clamping, and signals.
- `scripts/ui/stats_hud.gd`, `scenes/ui/stats_hud.tscn` — compact three-bar upper-left HUD.
- `scripts/player/camera_rig.gd` — smooth bounded camera zoom and pure clamp helpers.
- `scripts/core/pause_coordinator.gd` — reason-based single-player pause ownership.
- `scripts/input/game_input_router.gd` — Tab, Escape, camera wheel, Ctrl-wheel, and number-key routing.
- `scripts/world/world_prop_definition.gd` — data model for visual and base-collision footprints.
- `scripts/world/world_collision_registry.gd` — solid footprint tracking, overlap tests, spawn validation, and safe-position recovery.
- `scripts/world/world_prop_factory.gd` — creates visuals, collision bodies, and Y-sort roots from prop definitions.
- `data/world/props/farmhouse.tres`
- `data/world/props/workshop.tres`
- `data/world/props/tree_small.tres`
- `data/world/props/tree_cluster.tres`
- `data/world/props/rock_cluster.tres`
- `data/world/props/fence_horizontal.tres`
- `scripts/world/world_layout.gd` — paints terrain and constructs configured regions, props, and water blockers.
- `scripts/ui/minimap.gd`, `scenes/ui/minimap.tscn` — data-drawn full-map minimap and stable markers.
- `tests/godot/suites/test_world_layout_config.gd`
- `tests/godot/suites/test_player_stats.gd`
- `tests/godot/suites/test_camera_rig.gd`
- `tests/godot/suites/test_game_input_router.gd`
- `tests/godot/suites/test_world_collisions.gd`
- `tests/godot/suites/test_minimap.gd`
- `tests/godot/suites/test_world_integration.gd`

### Modify

- `project.godot` — keep existing actions and add no conflicting wheel actions.
- `scenes/player/player.tscn` — attach `PlayerStats` and replace the bare camera with `CameraRig`.
- `scripts/player/player_controller.gd` — remove quickbar wheel ownership and block movement/item use while modal UI owns input.
- `scripts/ui/inventory_ui.gd` — expose modal state without directly owning Tab or the whole pause flag.
- `scripts/ui/hotbar_ui.gd` — support dimming while modal inventory is open.
- `scenes/world/prototype_world.tscn` — compose layout, router, pause coordinator, stats HUD, minimap, and updated world nodes.
- `scripts/world/prototype_world.gd` — delegate world generation and bind all components.
- `tests/godot/test_runner.gd` — register all new suites.
- `tools/validate_project.py`, `tests/test_validate_project.py` — require the new architecture and scene wiring.
- `README.md` — document the enlarged world, controls, HUD, minimap, and collision behavior.

---

### Task 1: Add the Authoritative World Layout Configuration

**Files:**
- Create: `scripts/world/world_layout_config.gd`
- Create: `data/world/default_world_layout.tres`
- Create: `tests/godot/suites/test_world_layout_config.gd`
- Modify: `tests/godot/test_runner.gd`
- Modify: `tools/validate_project.py`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Consumes: Godot `Resource`, `Vector2i`, `Rect2i`, and `Vector2`.
- Produces: `WorldLayoutConfig.world_size_pixels() -> Vector2i`, `world_rect() -> Rect2`, `cell_to_world(cell: Vector2i) -> Vector2`, `world_to_normalized(position: Vector2) -> Vector2`, `normalized_to_minimap(position: Vector2, minimap_size: Vector2) -> Vector2`, `is_inside_cell(cell: Vector2i) -> bool`, `is_water_cell(cell: Vector2i) -> bool`, and `is_bridge_cell(cell: Vector2i) -> bool`.

- [ ] **Step 1: Add failing repository-contract assertions**

Add the following required paths to `tests/test_validate_project.py` and assert the plan constants are present:

```python
def test_world_layout_contract_exists(self) -> None:
    root = Path(__file__).resolve().parents[1]
    layout = root / "scripts/world/world_layout_config.gd"
    resource = root / "data/world/default_world_layout.tres"
    self.assertTrue(layout.is_file())
    self.assertTrue(resource.is_file())
    text = layout.read_text(encoding="utf-8")
    self.assertIn("Vector2i(96, 64)", text)
    self.assertIn("Vector2i(32, 32)", text)
    self.assertIn("func world_to_normalized", text)
```

- [ ] **Step 2: Add the failing Godot layout suite**

Create `tests/godot/suites/test_world_layout_config.gd`:

```gdscript
extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var layout := WorldLayoutConfig.new()
    failures.append(TestAssert.equal(layout.map_size_cells, Vector2i(96, 64), "map cells"))
    failures.append(TestAssert.equal(layout.world_size_pixels(), Vector2i(3072, 2048), "world pixels"))
    failures.append(TestAssert.equal(layout.world_to_normalized(Vector2.ZERO), Vector2.ZERO, "origin normalized"))
    failures.append(TestAssert.equal(
        layout.world_to_normalized(Vector2(3072, 2048)),
        Vector2.ONE,
        "far corner normalized"
    ))
    failures.append(TestAssert.equal(
        layout.normalized_to_minimap(Vector2(1536, 1024), Vector2(160, 160)),
        Vector2(80, 80),
        "center minimap"
    ))
    failures.append(TestAssert.truthy(layout.is_bridge_cell(Vector2i(59, 31)), "main bridge cell"))
    failures.append(TestAssert.truthy(not layout.is_water_cell(Vector2i(59, 31)), "bridge is walkable"))
    failures.append(TestAssert.truthy(layout.is_water_cell(Vector2i(59, 20)), "river cell"))
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register this suite in `tests/godot/test_runner.gd`.

- [ ] **Step 3: Run the focused tests and verify failure**

Run:

```bash
python -m unittest tests.test_validate_project.ProjectValidatorTests.test_world_layout_contract_exists -v
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: the Python test fails because the files do not exist; Godot fails because `WorldLayoutConfig` is undefined.

- [ ] **Step 4: Implement `WorldLayoutConfig`**

Create `scripts/world/world_layout_config.gd`:

```gdscript
class_name WorldLayoutConfig
extends Resource

@export var map_size_cells := Vector2i(96, 64)
@export var display_cell_size := Vector2i(32, 32)
@export var player_spawn_cell := Vector2i(16, 46)
@export var river_x_range := Vector2i(58, 61)
@export var bridge_y_ranges: Array[Vector2i] = [Vector2i(30, 33), Vector2i(45, 47)]

const FARMSTEAD := Rect2i(4, 36, 28, 24)
const MEADOW := Rect2i(24, 18, 42, 32)
const STONEFIELD := Rect2i(66, 20, 26, 39)
const WHISPERWOOD := Rect2i(6, 3, 70, 21)


func world_size_pixels() -> Vector2i:
    return map_size_cells * display_cell_size


func world_rect() -> Rect2:
    return Rect2(Vector2.ZERO, Vector2(world_size_pixels()))


func cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(cell * display_cell_size) + Vector2(display_cell_size) * 0.5


func world_to_normalized(position: Vector2) -> Vector2:
    var size := Vector2(world_size_pixels())
    if size.x <= 0.0 or size.y <= 0.0:
        push_warning("WorldLayoutConfig has invalid world size")
        return Vector2.ZERO
    return Vector2(
        clampf(position.x / size.x, 0.0, 1.0),
        clampf(position.y / size.y, 0.0, 1.0)
    )


func normalized_to_minimap(position: Vector2, minimap_size: Vector2) -> Vector2:
    return world_to_normalized(position) * minimap_size


func is_inside_cell(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < map_size_cells.x and cell.y < map_size_cells.y


func is_bridge_cell(cell: Vector2i) -> bool:
    if cell.x < river_x_range.x or cell.x > river_x_range.y:
        return false
    for y_range in bridge_y_ranges:
        if cell.y >= y_range.x and cell.y <= y_range.y:
            return true
    return false


func is_water_cell(cell: Vector2i) -> bool:
    return (
        is_inside_cell(cell)
        and cell.x >= river_x_range.x
        and cell.x <= river_x_range.y
        and not is_bridge_cell(cell)
    )
```

Create `data/world/default_world_layout.tres`:

```ini
[gd_resource type="Resource" script_class="WorldLayoutConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/world/world_layout_config.gd" id="1"]

[resource]
script = ExtResource("1")
map_size_cells = Vector2i(96, 64)
display_cell_size = Vector2i(32, 32)
player_spawn_cell = Vector2i(16, 46)
river_x_range = Vector2i(58, 61)
bridge_y_ranges = Array[Vector2i]([Vector2i(30, 33), Vector2i(45, 47)])
```

Add the new files to `GAMEPLAY_FOUNDATION_FILES` or a new `WORLD_ENHANCEMENT_FILES` tuple in `tools/validate_project.py`.

- [ ] **Step 5: Run focused and full tests**

Run:

```bash
python -m unittest tests.test_validate_project.ProjectValidatorTests.test_world_layout_contract_exists -v
godot --headless --path . --script res://tests/godot/test_runner.gd
python -m unittest discover -s tests -v
python tools/validate_project.py .
```

Expected: all commands exit `0`.

- [ ] **Step 6: Commit**

```bash
git add scripts/world/world_layout_config.gd data/world/default_world_layout.tres tests tools
git commit -m "feat: add authoritative world layout configuration"
```

---

### Task 2: Add Player Stats and the Three-Bar HUD

**Files:**
- Create: `scripts/player/player_stats.gd`
- Create: `scripts/ui/stats_hud.gd`
- Create: `scenes/ui/stats_hud.tscn`
- Create: `tests/godot/suites/test_player_stats.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: player scene and Godot signals.
- Produces: `PlayerStats.set_health(value: float)`, `change_health(delta: float)`, `set_stamina(value: float)`, `change_stamina(delta: float)`, `set_mana(value: float)`, `change_mana(delta: float)`, `restore_all()`, and signals `health_changed(current, maximum)`, `stamina_changed(current, maximum)`, `mana_changed(current, maximum)`; `StatsHUD.bind(stats: PlayerStats)`.

- [ ] **Step 1: Write failing player-stat tests**

Create `tests/godot/suites/test_player_stats.gd`:

```gdscript
extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var stats := PlayerStats.new()
    var health_events: Array[Vector2] = []
    stats.health_changed.connect(func(current: float, maximum: float) -> void:
        health_events.append(Vector2(current, maximum))
    )
    stats.set_health(130.0)
    failures.append(TestAssert.equal(stats.health, 100.0, "health upper clamp"))
    stats.change_health(-145.0)
    failures.append(TestAssert.equal(stats.health, 0.0, "health lower clamp"))
    stats.set_stamina(42.0)
    failures.append(TestAssert.equal(stats.stamina, 42.0, "stamina mutation"))
    stats.set_mana(-10.0)
    failures.append(TestAssert.equal(stats.mana, 0.0, "mana lower clamp"))
    stats.restore_all()
    failures.append(TestAssert.equal(stats.health, 100.0, "health restore"))
    failures.append(TestAssert.equal(stats.stamina, 100.0, "stamina restore"))
    failures.append(TestAssert.equal(stats.mana, 100.0, "mana restore"))
    failures.append(TestAssert.truthy(health_events.size() >= 2, "health signal emitted"))
    stats.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite.

- [ ] **Step 2: Run and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: parse failure because `PlayerStats` is undefined.

- [ ] **Step 3: Implement `PlayerStats`**

Create `scripts/player/player_stats.gd`:

```gdscript
class_name PlayerStats
extends Node

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)

@export_range(1.0, 999.0, 1.0) var max_health := 100.0
@export_range(1.0, 999.0, 1.0) var max_stamina := 100.0
@export_range(1.0, 999.0, 1.0) var max_mana := 100.0

var health := 100.0
var stamina := 100.0
var mana := 100.0
var invulnerable := false
var stamina_regeneration_enabled := true
var mana_regeneration_enabled := true


func _ready() -> void:
    health = clampf(health, 0.0, max_health)
    stamina = clampf(stamina, 0.0, max_stamina)
    mana = clampf(mana, 0.0, max_mana)
    _emit_all()


func set_health(value: float) -> void:
    var next := clampf(value, 0.0, max_health)
    if is_equal_approx(next, health):
        return
    health = next
    health_changed.emit(health, max_health)


func change_health(delta: float) -> void:
    set_health(health + delta)


func set_stamina(value: float) -> void:
    var next := clampf(value, 0.0, max_stamina)
    if is_equal_approx(next, stamina):
        return
    stamina = next
    stamina_changed.emit(stamina, max_stamina)


func change_stamina(delta: float) -> void:
    set_stamina(stamina + delta)


func set_mana(value: float) -> void:
    var next := clampf(value, 0.0, max_mana)
    if is_equal_approx(next, mana):
        return
    mana = next
    mana_changed.emit(mana, max_mana)


func change_mana(delta: float) -> void:
    set_mana(mana + delta)


func restore_all() -> void:
    set_health(max_health)
    set_stamina(max_stamina)
    set_mana(max_mana)


func _emit_all() -> void:
    health_changed.emit(health, max_health)
    stamina_changed.emit(stamina, max_stamina)
    mana_changed.emit(mana, max_mana)
```

Add a `PlayerStats` child to `scenes/player/player.tscn`.

- [ ] **Step 4: Build `StatsHUD`**

Create `scripts/ui/stats_hud.gd`:

```gdscript
class_name StatsHUD
extends PanelContainer

@onready var health_bar: ProgressBar = $Margin/Column/Health/Bar
@onready var health_value: Label = $Margin/Column/Health/Value
@onready var stamina_bar: ProgressBar = $Margin/Column/Stamina/Bar
@onready var stamina_value: Label = $Margin/Column/Stamina/Value
@onready var mana_bar: ProgressBar = $Margin/Column/Mana/Bar
@onready var mana_value: Label = $Margin/Column/Mana/Value
@onready var area_label: Label = $Margin/Column/Area

var stats: PlayerStats
var _health_target := 100.0
var _stamina_target := 100.0
var _mana_target := 100.0


func _process(delta: float) -> void:
    var weight := 1.0 - exp(-12.0 * delta)
    health_bar.value = lerpf(health_bar.value, _health_target, weight)
    stamina_bar.value = lerpf(stamina_bar.value, _stamina_target, weight)
    mana_bar.value = lerpf(mana_bar.value, _mana_target, weight)


func bind(model: PlayerStats) -> void:
    stats = model
    if stats == null:
        push_error("StatsHUD requires PlayerStats")
        return
    stats.health_changed.connect(_on_health_changed)
    stats.stamina_changed.connect(_on_stamina_changed)
    stats.mana_changed.connect(_on_mana_changed)
    _on_health_changed(stats.health, stats.max_health)
    _on_stamina_changed(stats.stamina, stats.max_stamina)
    _on_mana_changed(stats.mana, stats.max_mana)


func set_area_text(value: String) -> void:
    area_label.text = value


func set_modal_dimmed(dimmed: bool) -> void:
    modulate = Color(1, 1, 1, 0.55 if dimmed else 1.0)


func _on_health_changed(current: float, maximum: float) -> void:
    health_bar.max_value = maximum
    _health_target = current
    health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_stamina_changed(current: float, maximum: float) -> void:
    stamina_bar.max_value = maximum
    _stamina_target = current
    stamina_value.text = "%d / %d" % [roundi(current), roundi(maximum)]


func _on_mana_changed(current: float, maximum: float) -> void:
    mana_bar.max_value = maximum
    _mana_target = current
    mana_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
```

Build `scenes/ui/stats_hud.tscn` as a 220-pixel-wide `PanelContainer` with a `Margin/Column` tree, three `HBoxContainer` rows named `Health`, `Stamina`, and `Mana`, each containing a 112×9 `ProgressBar` named `Bar` and a right-aligned `Label` named `Value`. Add `Margin/Column/Area` with text `晨露谷地 · 初春`. Use red, warm-gold/green, and blue fill styles respectively.

- [ ] **Step 5: Add a scene test for HUD binding**

Extend `test_player_stats.gd` after the model assertions:

```gdscript
var packed := load("res://scenes/ui/stats_hud.tscn") as PackedScene
failures.append(TestAssert.truthy(packed != null, "stats HUD scene loads"))
if packed != null:
    var hud := packed.instantiate() as StatsHUD
    Engine.get_main_loop().root.add_child(hud)
    var hud_stats := PlayerStats.new()
    hud.add_child(hud_stats)
    hud.bind(hud_stats)
    hud_stats.set_mana(55.0)
    var value := hud.get_node("Margin/Column/Mana/Value") as Label
    failures.append(TestAssert.equal(value.text, "55 / 100", "mana HUD value"))
    hud.free()
```

- [ ] **Step 6: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
git add scripts/player/player_stats.gd scripts/ui/stats_hud.gd scenes/ui/stats_hud.tscn scenes/player/player.tscn tests/godot
git commit -m "feat: add player resources and three-bar HUD"
```

---

### Task 3: Add the Bounded Smooth Camera Rig

**Files:**
- Create: `scripts/player/camera_rig.gd`
- Create: `tests/godot/suites/test_camera_rig.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `WorldLayoutConfig.world_rect()` and viewport size.
- Produces: `CameraRig.configure_world(rect: Rect2)`, `change_zoom_steps(direction: int)`, `set_zoom_value(value: float)`, `target_zoom_value() -> float`, and static `clamp_center_to_world(target, world_rect, viewport_size, zoom_value) -> Vector2`.

- [ ] **Step 1: Write failing camera tests**

Create `tests/godot/suites/test_camera_rig.gd`:

```gdscript
extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var camera := CameraRig.new()
    camera.set_zoom_value(4.0)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.5, "zoom upper clamp"))
    camera.set_zoom_value(0.1)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 0.75, "zoom lower clamp"))
    camera.set_zoom_value(1.0)
    camera.change_zoom_steps(1)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.125, "zoom in step"))
    camera.change_zoom_steps(-2)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 0.875, "zoom out steps"))
    var world := Rect2(Vector2.ZERO, Vector2(3072, 2048))
    var clamped := CameraRig.clamp_center_to_world(
        Vector2(-100, -100), world, Vector2(640, 360), 1.0
    )
    failures.append(TestAssert.equal(clamped, Vector2(320, 180), "top-left camera clamp"))
    camera.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite.

- [ ] **Step 2: Run and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: `CameraRig` is undefined.

- [ ] **Step 3: Implement the camera rig**

Create `scripts/player/camera_rig.gd`:

```gdscript
class_name CameraRig
extends Camera2D

const MIN_ZOOM := 0.75
const MAX_ZOOM := 1.50
const ZOOM_STEP := 0.125

@export_range(1.0, 20.0, 0.5) var zoom_lerp_speed := 10.0
var _target_zoom := 1.0
var _world_rect := Rect2(Vector2.ZERO, Vector2(1280, 768))


func _ready() -> void:
    position_smoothing_enabled = true
    position_smoothing_speed = 7.0
    zoom = Vector2.ONE * _target_zoom
    _apply_limits()


func _process(delta: float) -> void:
    var weight := 1.0 - exp(-zoom_lerp_speed * delta)
    var next := lerpf(zoom.x, _target_zoom, weight)
    zoom = Vector2.ONE * next
    global_position = clamp_center_to_world(
        global_position,
        _world_rect,
        get_viewport_rect().size,
        next
    )


func configure_world(rect: Rect2) -> void:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        push_warning("CameraRig rejected invalid world bounds")
        return
    _world_rect = rect
    _apply_limits()


func change_zoom_steps(direction: int) -> void:
    set_zoom_value(_target_zoom + float(direction) * ZOOM_STEP)


func set_zoom_value(value: float) -> void:
    _target_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)


func target_zoom_value() -> float:
    return _target_zoom


func _apply_limits() -> void:
    limit_left = roundi(_world_rect.position.x)
    limit_top = roundi(_world_rect.position.y)
    limit_right = roundi(_world_rect.end.x)
    limit_bottom = roundi(_world_rect.end.y)


static func clamp_center_to_world(
    target: Vector2,
    world_rect: Rect2,
    viewport_size: Vector2,
    zoom_value: float
) -> Vector2:
    var safe_zoom := maxf(zoom_value, 0.001)
    var half_view := viewport_size * 0.5 / safe_zoom
    var minimum := world_rect.position + half_view
    var maximum := world_rect.end - half_view
    if minimum.x > maximum.x:
        minimum.x = world_rect.get_center().x
        maximum.x = minimum.x
    if minimum.y > maximum.y:
        minimum.y = world_rect.get_center().y
        maximum.y = minimum.y
    return Vector2(
        clampf(target.x, minimum.x, maximum.x),
        clampf(target.y, minimum.y, maximum.y)
    )
```

Replace the existing `Camera2D` node in `scenes/player/player.tscn` with the same node name and attach `camera_rig.gd`; remove hard-coded `limit_right = 1280` and `limit_bottom = 768`.

- [ ] **Step 4: Run focused and scene tests**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
```

Expected: both exit `0` with no script errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/camera_rig.gd scenes/player/player.tscn tests/godot
git commit -m "feat: add bounded smooth camera zoom"
```

---

### Task 4: Centralize Modal Pause and Global Input Routing

**Files:**
- Create: `scripts/core/pause_coordinator.gd`
- Create: `scripts/input/game_input_router.gd`
- Create: `tests/godot/suites/test_game_input_router.gd`
- Modify: `scripts/ui/inventory_ui.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `scripts/ui/hotbar_ui.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `InventoryUI`, `InventoryModel`, `CameraRig`, and the scene tree.
- Produces: `PauseCoordinator.acquire(reason: StringName)`, `release(reason)`, `has_reason(reason)`, `is_paused()`, `GameInputRouter.bind(inventory_ui, inventory, camera, pause_coordinator)`, and `handle_event(event: InputEvent) -> bool`.

- [ ] **Step 1: Write failing pause and input tests**

Create `tests/godot/suites/test_game_input_router.gd`:

```gdscript
extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var root := Node.new()
    Engine.get_main_loop().root.add_child(root)
    var pause := PauseCoordinator.new()
    root.add_child(pause)
    pause.acquire(&"inventory")
    pause.acquire(&"pause_menu")
    pause.release(&"inventory")
    failures.append(TestAssert.truthy(pause.has_reason(&"pause_menu"), "other pause reason retained"))
    failures.append(TestAssert.truthy(pause.is_paused(), "tree remains paused"))
    pause.release(&"pause_menu")
    failures.append(TestAssert.truthy(not pause.is_paused(), "all pause reasons released"))

    var packed := load("res://scenes/ui/inventory_ui.tscn") as PackedScene
    var inventory_ui := packed.instantiate() as InventoryUI
    root.add_child(inventory_ui)
    var inventory := InventoryModel.new()
    root.add_child(inventory)
    inventory_ui.bind(inventory)
    var camera := CameraRig.new()
    root.add_child(camera)
    var router := GameInputRouter.new()
    root.add_child(router)
    router.bind(inventory_ui, inventory, camera, pause)

    var tab := InputEventKey.new()
    tab.keycode = KEY_TAB
    tab.pressed = true
    failures.append(TestAssert.truthy(router.handle_event(tab), "Tab handled"))
    failures.append(TestAssert.truthy(inventory_ui.is_open(), "Tab opens inventory"))
    failures.append(TestAssert.truthy(pause.has_reason(&"inventory"), "inventory pause acquired"))

    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    failures.append(TestAssert.truthy(router.handle_event(escape), "Escape handled"))
    failures.append(TestAssert.truthy(not inventory_ui.is_open(), "Escape closes inventory first"))

    var wheel := InputEventMouseButton.new()
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel.pressed = true
    router.handle_event(wheel)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.125, "wheel zooms camera"))

    inventory.set_selected_slot(2)
    wheel.ctrl_pressed = true
    router.handle_event(wheel)
    failures.append(TestAssert.equal(inventory.selected_index, 1, "Ctrl-wheel cycles hotbar"))
    root.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite.

- [ ] **Step 2: Run and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: parse failures because the coordinator and router do not exist.

- [ ] **Step 3: Implement reason-based pause ownership**

Create `scripts/core/pause_coordinator.gd`:

```gdscript
class_name PauseCoordinator
extends Node

signal pause_state_changed(paused: bool)

var _reasons: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func acquire(reason: StringName) -> void:
    if reason.is_empty():
        push_warning("PauseCoordinator rejected an empty reason")
        return
    var was_paused := is_paused()
    _reasons[reason] = true
    _sync_tree(was_paused)


func release(reason: StringName) -> void:
    var was_paused := is_paused()
    _reasons.erase(reason)
    _sync_tree(was_paused)


func has_reason(reason: StringName) -> bool:
    return _reasons.has(reason)


func is_paused() -> bool:
    return not _reasons.is_empty()


func _sync_tree(previous: bool) -> void:
    var current := is_paused()
    if get_tree() != null:
        get_tree().paused = current
    if current != previous:
        pause_state_changed.emit(current)
```

- [ ] **Step 4: Refactor `InventoryUI` into an explicit modal view**

In `scripts/ui/inventory_ui.gd`:

- remove `_unhandled_input`;
- remove direct assignments to `get_tree().paused`;
- keep `process_mode = Node.PROCESS_MODE_ALWAYS`;
- replace `open()` and `close()` with state-only methods:

```gdscript
func is_open() -> bool:
    return visible


func set_open(opened: bool) -> void:
    if opened == visible:
        return
    visible = opened
    if visible:
        status_label.text = ""
        _refresh_inventory()
        _refresh_recipe_detail()
    opened_changed.emit(visible)


func open() -> void:
    if inventory != null:
        set_open(true)


func close() -> void:
    set_open(false)
```

Keep the close button connected to `close()`; the router listens to `opened_changed` and releases pause when the button closes the view.

- [ ] **Step 5: Implement `GameInputRouter`**

Create `scripts/input/game_input_router.gd`:

```gdscript
class_name GameInputRouter
extends Node

const INVENTORY_REASON := &"inventory"

var inventory_ui: InventoryUI
var inventory: InventoryModel
var camera_rig: CameraRig
var pause_coordinator: PauseCoordinator


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func bind(
    inventory_view: InventoryUI,
    inventory_model: InventoryModel,
    camera: CameraRig,
    pause_owner: PauseCoordinator
) -> void:
    inventory_ui = inventory_view
    inventory = inventory_model
    camera_rig = camera
    pause_coordinator = pause_owner
    if inventory_ui != null:
        inventory_ui.opened_changed.connect(_on_inventory_opened_changed)


func _input(event: InputEvent) -> void:
    if handle_event(event):
        get_viewport().set_input_as_handled()


func handle_event(event: InputEvent) -> bool:
    if event is InputEventKey and (event as InputEventKey).echo:
        return false

    if event.is_action_pressed("inventory") or _is_key_press(event, KEY_TAB):
        if inventory_ui == null:
            push_error("GameInputRouter has no InventoryUI")
            return true
        inventory_ui.set_open(not inventory_ui.is_open())
        return true

    if event.is_action_pressed("pause") or _is_key_press(event, KEY_ESCAPE):
        if inventory_ui != null and inventory_ui.is_open():
            inventory_ui.set_open(false)
            return true
        return false

    if inventory_ui != null and inventory_ui.is_open():
        return false

    for index in InventoryModel.QUICKBAR_SIZE:
        if event.is_action_pressed("quick_slot_%d" % (index + 1)):
            if inventory != null:
                inventory.set_selected_slot(index)
            return true

    if event is InputEventMouseButton and event.pressed:
        var mouse := event as InputEventMouseButton
        var direction := 0
        if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
            direction = 1
        elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            direction = -1
        if direction == 0:
            return false
        if mouse.ctrl_pressed:
            if inventory != null:
                inventory.set_selected_slot(posmod(
                    inventory.selected_index - direction,
                    inventory.quickbar_size
                ))
        elif camera_rig != null:
            camera_rig.change_zoom_steps(direction)
        return true
    return false


func _on_inventory_opened_changed(opened: bool) -> void:
    if pause_coordinator == null:
        return
    if opened:
        pause_coordinator.acquire(INVENTORY_REASON)
    else:
        pause_coordinator.release(INVENTORY_REASON)


func _is_key_press(event: InputEvent, key: Key) -> bool:
    return event is InputEventKey and event.pressed and (event as InputEventKey).keycode == key
```

- [ ] **Step 6: Remove conflicting input ownership from player and add modal blocking**

In `scripts/player/player_controller.gd`:

- remove number-key and mouse-wheel handling from `_unhandled_input`;
- keep only the attack action;
- add `var gameplay_input_blocked := false` and:

```gdscript
func set_gameplay_input_blocked(blocked: bool) -> void:
    gameplay_input_blocked = blocked


func _physics_process(delta: float) -> void:
    var raw_input := Vector2.ZERO if gameplay_input_blocked else Input.get_vector(
        "move_left", "move_right", "move_up", "move_down"
    )
    var direction := MovementMath.normalized_input(raw_input)
    velocity = direction * move_speed
    move_and_slide()
    var moving := not direction.is_zero_approx()
    facing = MovementMath.facing_index(direction, facing)
    _apply_visual_state(moving, delta)
```

Guard the attack request with `if not gameplay_input_blocked`.

Add `set_modal_dimmed(dimmed: bool)` to `HotbarUI`:

```gdscript
func set_modal_dimmed(dimmed: bool) -> void:
    modulate = Color(1, 1, 1, 0.55 if dimmed else 1.0)
```

The world binding task connects `InventoryUI.opened_changed` to player blocking and HUD dimming.

- [ ] **Step 7: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
git add scripts/core scripts/input scripts/ui/inventory_ui.gd scripts/ui/hotbar_ui.gd scripts/player/player_controller.gd tests/godot
git commit -m "fix: centralize inventory pause and global input routing"
```

---

### Task 5: Define Base-Only Prop Collisions and Safe-Position Recovery

**Files:**
- Create: `scripts/world/world_prop_definition.gd`
- Create: `scripts/world/world_collision_registry.gd`
- Create: `scripts/world/world_prop_factory.gd`
- Create: `data/world/props/*.tres`
- Create: `tests/godot/suites/test_world_collisions.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: textures, atlas regions, `WorldLayoutConfig`, and a parent `Node2D`.
- Produces: `WorldPropDefinition.validate() -> PackedStringArray`, `WorldCollisionRegistry.register_rect(id, rect)`, `unregister(id)`, `overlaps_rect(rect)`, `is_position_safe(position, player_size)`, `find_nearest_safe_position(position, player_size, fallback)`, and `WorldPropFactory.spawn_atlas_prop(...) -> Node2D`.

- [ ] **Step 1: Write failing collision tests**

Create `tests/godot/suites/test_world_collisions.gd`:

```gdscript
extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var solid := WorldPropDefinition.new()
    solid.id = &"tree_test"
    solid.solid = true
    solid.collision_rects = [Rect2(-12, -14, 24, 14)]
    failures.append(TestAssert.equal(solid.validate().size(), 0, "valid solid definition"))

    var decorative := WorldPropDefinition.new()
    decorative.id = &"flower_test"
    decorative.solid = false
    decorative.collision_rects = []
    failures.append(TestAssert.equal(decorative.validate().size(), 0, "valid decorative definition"))

    var invalid := WorldPropDefinition.new()
    invalid.id = &"broken"
    invalid.solid = true
    invalid.collision_rects = []
    failures.append(TestAssert.truthy(invalid.validate().size() > 0, "solid requires footprint"))

    var registry := WorldCollisionRegistry.new()
    registry.register_rect(&"tree", Rect2(90, 90, 20, 20))
    failures.append(TestAssert.truthy(
        registry.overlaps_rect(Rect2(95, 95, 10, 10)),
        "overlap detected"
    ))
    failures.append(TestAssert.truthy(
        not registry.is_position_safe(Vector2(100, 100), Vector2(16, 12)),
        "unsafe center rejected"
    ))
    var recovered := registry.find_nearest_safe_position(
        Vector2(100, 100), Vector2(16, 12), Vector2(32, 32)
    )
    failures.append(TestAssert.truthy(
        registry.is_position_safe(recovered, Vector2(16, 12)),
        "recovery is safe"
    ))
    registry.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite.

- [ ] **Step 2: Run and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: the three world collision classes are undefined.

- [ ] **Step 3: Implement the prop definition**

Create `scripts/world/world_prop_definition.gd`:

```gdscript
class_name WorldPropDefinition
extends Resource

enum MarkerCategory { NONE, FARMHOUSE, WORKSHOP, FARM_PLOT, OBJECTIVE }

@export var id: StringName
@export var display_name := ""
@export var visual_scale := 2.0
@export var visual_offset := Vector2.ZERO
@export var solid := false
@export var collision_rects: Array[Rect2] = []
@export var y_sort_origin_offset := Vector2.ZERO
@export var marker_category: MarkerCategory = MarkerCategory.NONE


func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if id.is_empty():
        errors.append("id must not be empty")
    if visual_scale <= 0.0:
        errors.append("visual_scale must be positive")
    if solid and collision_rects.is_empty():
        errors.append("solid prop requires collision_rects")
    for rect in collision_rects:
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            errors.append("collision rectangle sizes must be positive")
    return errors
```

- [ ] **Step 4: Implement the collision registry**

Create `scripts/world/world_collision_registry.gd`:

```gdscript
class_name WorldCollisionRegistry
extends Node

var _footprints: Dictionary = {}
@export var search_step := 16.0
@export var search_rings := 12


func register_rect(id: StringName, rect: Rect2) -> bool:
    if id.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
        push_warning("WorldCollisionRegistry rejected invalid footprint")
        return false
    if _footprints.has(id):
        push_warning("Duplicate collision id: %s" % id)
        return false
    _footprints[id] = rect
    return true


func unregister(id: StringName) -> void:
    _footprints.erase(id)


func overlaps_rect(rect: Rect2) -> bool:
    for footprint in _footprints.values():
        if (footprint as Rect2).intersects(rect, true):
            return true
    return false


func is_position_safe(position: Vector2, player_size: Vector2) -> bool:
    return not overlaps_rect(Rect2(position - player_size * 0.5, player_size))


func find_nearest_safe_position(
    requested: Vector2,
    player_size: Vector2,
    fallback: Vector2
) -> Vector2:
    if is_position_safe(requested, player_size):
        return requested
    for ring in range(1, search_rings + 1):
        var radius := float(ring) * search_step
        var candidates := [
            requested + Vector2(radius, 0),
            requested + Vector2(-radius, 0),
            requested + Vector2(0, radius),
            requested + Vector2(0, -radius),
            requested + Vector2(radius, radius),
            requested + Vector2(-radius, radius),
            requested + Vector2(radius, -radius),
            requested + Vector2(-radius, -radius),
        ]
        for candidate in candidates:
            if is_position_safe(candidate, player_size):
                return candidate
    return fallback if is_position_safe(fallback, player_size) else Vector2.ZERO
```

- [ ] **Step 5: Implement the prop factory**

Create `scripts/world/world_prop_factory.gd`:

```gdscript
class_name WorldPropFactory
extends RefCounted


static func spawn_atlas_prop(
    parent: Node2D,
    texture: Texture2D,
    region: Rect2i,
    definition: WorldPropDefinition,
    world_position: Vector2,
    registry: WorldCollisionRegistry
) -> Node2D:
    if parent == null or texture == null or definition == null:
        push_error("WorldPropFactory received an invalid request")
        return null
    var errors := definition.validate()
    if not errors.is_empty():
        push_error("Invalid prop %s: %s" % [definition.id, ", ".join(errors)])
        return null
    if not OpenAtlasRegions.region_fits(texture, region):
        push_error("Prop atlas region is outside the texture: %s" % definition.id)
        return null

    var root := Node2D.new()
    root.name = String(definition.id)
    root.position = world_position + definition.y_sort_origin_offset

    var sprite := Sprite2D.new()
    sprite.name = "Visual"
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = Rect2(region)
    sprite.scale = Vector2.ONE * definition.visual_scale
    sprite.position = definition.visual_offset - definition.y_sort_origin_offset
    root.add_child(sprite)

    if definition.solid:
        var body := StaticBody2D.new()
        body.name = "Solid"
        body.collision_layer = 1
        body.collision_mask = 2
        root.add_child(body)
        for index in definition.collision_rects.size():
            var rect := definition.collision_rects[index]
            var shape := RectangleShape2D.new()
            shape.size = rect.size
            var collision := CollisionShape2D.new()
            collision.name = "Collision%d" % index
            collision.position = rect.position + rect.size * 0.5 - definition.y_sort_origin_offset
            collision.shape = shape
            body.add_child(collision)
            if registry != null:
                registry.register_rect(
                    StringName("%s:%d" % [definition.id, index]),
                    Rect2(world_position + rect.position, rect.size)
                )
    parent.add_child(root)
    return root
```

- [ ] **Step 6: Create exact base-collision resources**

Create resources using these footprints relative to each prop's base position:

```ini
# farmhouse.tres
solid = true
collision_rects = Array[Rect2]([
    Rect2(-56, -44, 40, 44),
    Rect2(16, -44, 40, 44),
    Rect2(-56, -44, 112, 12)
])
marker_category = 1

# workshop.tres
solid = true
collision_rects = Array[Rect2]([
    Rect2(-44, -36, 32, 36),
    Rect2(12, -36, 32, 36),
    Rect2(-44, -36, 88, 10)
])
marker_category = 2

# tree_small.tres
solid = true
collision_rects = Array[Rect2]([Rect2(-12, -14, 24, 14)])

# tree_cluster.tres
solid = true
collision_rects = Array[Rect2]([
    Rect2(-28, -16, 20, 16),
    Rect2(8, -16, 20, 16)
])

# rock_cluster.tres
solid = true
collision_rects = Array[Rect2]([Rect2(-17, -12, 34, 12)])

# fence_horizontal.tres
solid = true
collision_rects = Array[Rect2]([Rect2(-56, -8, 112, 12)])
```

Set each resource's `id`, `display_name`, visual scale, visual offset, and Y-sort origin so the root position is the physical base. Keep grass, flowers, tiny stones, and ground debris as unregistered decorative visuals.

- [ ] **Step 7: Extend tests for the real resources and doorway gap**

Add to `test_world_collisions.gd`:

```gdscript
var house := load("res://data/world/props/farmhouse.tres") as WorldPropDefinition
failures.append(TestAssert.equal(house.validate().size(), 0, "farmhouse definition valid"))
var doorway := Rect2(-15, -31, 30, 31)
var doorway_blocked := false
for rect in house.collision_rects:
    doorway_blocked = doorway_blocked or rect.intersects(doorway, true)
failures.append(TestAssert.truthy(not doorway_blocked, "farmhouse doorway remains open"))
```

- [ ] **Step 8: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
git add scripts/world/world_prop_definition.gd scripts/world/world_collision_registry.gd scripts/world/world_prop_factory.gd data/world/props tests/godot
git commit -m "feat: add base-only world prop collisions"
```

---

### Task 6: Expand and Rebuild the Prototype World at 96×64

**Files:**
- Create: `scripts/world/world_layout.gd`
- Create: `tests/godot/suites/test_world_integration.gd`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scenes/player/player.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `WorldLayoutConfig`, `WorldPropFactory`, `WorldCollisionRegistry`, `OpenAssetLibrary`, and `OpenAtlasRegions`.
- Produces: `WorldLayout.build()`, `spawn_position() -> Vector2`, `world_rect() -> Rect2`, `validate_required_routes() -> PackedStringArray`, and `recover_player_position(requested, player_size) -> Vector2`.

- [ ] **Step 1: Write failing world integration tests**

Create `tests/godot/suites/test_world_integration.gd`:

```gdscript
extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var scene := load("res://scenes/world/prototype_world.tscn") as PackedScene
    failures.append(TestAssert.truthy(scene != null, "world scene loads"))
    if scene == null:
        return failures.filter(func(message: String) -> bool: return not message.is_empty())
    var world := scene.instantiate() as PrototypeWorld
    Engine.get_main_loop().root.add_child(world)
    var layout := world.get_node("WorldLayout") as WorldLayout
    failures.append(TestAssert.equal(layout.config.map_size_cells, Vector2i(96, 64), "world uses large layout"))
    failures.append(TestAssert.equal(layout.world_rect().size, Vector2(3072, 2048), "world bounds"))
    failures.append(TestAssert.equal(layout.validate_required_routes().size(), 0, "required routes passable"))
    var player := world.get_node("Entities/Player") as CharacterBody2D
    var registry := world.get_node("WorldCollisionRegistry") as WorldCollisionRegistry
    failures.append(TestAssert.truthy(
        registry.is_position_safe(player.position, Vector2(16, 12)),
        "spawn is collision free"
    ))
    var recovered := layout.recover_player_position(Vector2(250, 190), Vector2(16, 12))
    failures.append(TestAssert.truthy(
        registry.is_position_safe(recovered, Vector2(16, 12)),
        "invalid loaded position recovers"
    ))
    world.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite.

- [ ] **Step 2: Run and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: `WorldLayout` and the new scene nodes are missing.

- [ ] **Step 3: Implement `WorldLayout` terrain painting**

Create `scripts/world/world_layout.gd` with exported node paths for `Ground`, `Entities`, `WorldCollisionRegistry`, and a `WorldLayoutConfig` resource. Reuse the current runtime `TileSetAtlasSource` setup. The terrain selector must follow these exact rules:

```gdscript
func _terrain_for(cell: Vector2i) -> int:
    if config.is_water_cell(cell):
        return GroundTile.WATER
    if cell.y >= 36 and cell.y <= 59 and cell.x >= 4 and cell.x <= 31:
        if cell.x >= 8 and cell.x <= 20 and cell.y >= 48 and cell.y <= 57:
            return GroundTile.SOIL
    if cell.x >= 66 and cell.y >= 20:
        return GroundTile.STONE if (cell.x + cell.y) % 4 == 0 else GroundTile.GRASS
    if cell.x in range(17, 20) or cell.y in range(31, 34):
        return GroundTile.PATH
    if config.is_bridge_cell(cell):
        return GroundTile.PATH
    return GroundTile.GRASS
```

Paint every cell from `(0, 0)` through `(95, 63)`. Keep source tile size 16 and display scale 2.0.

- [ ] **Step 4: Add exact region props and natural boundaries**

Use these base positions, converted from cells through `config.cell_to_world`:

```gdscript
const FARMHOUSE_CELL := Vector2i(12, 43)
const WORKSHOP_CELL := Vector2i(24, 43)
const FARM_FENCE_CELL := Vector2i(14, 50)
const TREE_CELLS := [
    Vector2i(5, 7), Vector2i(11, 8), Vector2i(18, 6), Vector2i(25, 10),
    Vector2i(33, 7), Vector2i(41, 11), Vector2i(49, 8), Vector2i(55, 14),
    Vector2i(7, 25), Vector2i(10, 31), Vector2i(84, 8), Vector2i(90, 15),
    Vector2i(4, 61), Vector2i(20, 62), Vector2i(45, 62), Vector2i(76, 61),
]
const ROCK_CELLS := [
    Vector2i(70, 27), Vector2i(76, 31), Vector2i(83, 25),
    Vector2i(88, 38), Vector2i(72, 48), Vector2i(84, 54),
]
```

Create additional tree and rock boundary placements around the outer two cell rings, leaving two-cell openings only where roads intentionally meet the edge. Register all solid footprints through `WorldPropFactory`.

- [ ] **Step 5: Build continuous water blockers with bridge gaps**

For river columns 58–61, create three continuous collision rectangles that cover rows `0–29`, `34–44`, and `48–63`. Each rectangle is exactly four cells wide and aligned to 32-pixel cell boundaries:

```gdscript
func _build_river_blockers() -> void:
    var segments := [Vector2i(0, 29), Vector2i(34, 44), Vector2i(48, 63)]
    for index in segments.size():
        var rows := segments[index]
        var position := Vector2(
            config.river_x_range.x * config.display_cell_size.x,
            rows.x * config.display_cell_size.y
        )
        var size := Vector2(
            (config.river_x_range.y - config.river_x_range.x + 1) * config.display_cell_size.x,
            (rows.y - rows.x + 1) * config.display_cell_size.y
        )
        _spawn_static_rect(StringName("river:%d" % index), Rect2(position, size))
```

The visual water layer and collision rectangles must use the same config values.

- [ ] **Step 6: Add route validation and recovery**

Represent required route checkpoints as cells:

```gdscript
const ROUTE_CELLS := [
    Vector2i(16, 46),
    Vector2i(18, 32),
    Vector2i(40, 32),
    Vector2i(59, 31),
    Vector2i(72, 31),
    Vector2i(42, 18),
]
```

Implement `validate_required_routes()` by checking each checkpoint footprint with the registry and returning a message for every blocked checkpoint. Implement recovery as:

```gdscript
func recover_player_position(requested: Vector2, player_size: Vector2) -> Vector2:
    return collision_registry.find_nearest_safe_position(
        requested,
        player_size,
        spawn_position()
    )
```

- [ ] **Step 7: Refactor `PrototypeWorld` into the composition root**

`PrototypeWorld._ready()` must perform this order:

```gdscript
func _ready() -> void:
    world_layout.build()
    player.position = world_layout.spawn_position()
    camera_rig.configure_world(world_layout.world_rect())
    _bind_player_ui()
    _bind_global_input()
```

Move tile painting, prop placement, river collision creation, and hard-coded map-size constants out of `prototype_world.gd`. Keep visual atmosphere creation that belongs to the scene, but update water and mote field sizes to the 3072×2048 world where appropriate.

Add nodes to `prototype_world.tscn`:

```text
WorldCollisionRegistry (Node)
WorldLayout (Node2D)
PauseCoordinator (Node)
GameInputRouter (Node)
```

Ensure `Entities` retains `y_sort_enabled = true`. Set prop roots at their base positions so the existing Y-sort container compares player feet with prop bases.

- [ ] **Step 8: Update player collision and verify base alignment**

Keep the player collision shape at `Vector2(16, 12)` and its center at the feet. Set the player scene root `y_sort_origin = 11` when supported by the current Godot `CanvasItem`; otherwise keep the root position at the feet and visual sprite offset upward. Do not enlarge the collision to the sprite or shadow dimensions.

- [ ] **Step 9: Run integration and smoke tests**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
godot --headless --path . --quit-after 8
```

Expected: large-world, route, spawn, collision-recovery, import, and main-scene checks all pass.

- [ ] **Step 10: Commit**

```bash
git add scripts/world/world_layout.gd scripts/world/prototype_world.gd scenes/world/prototype_world.tscn scenes/player/player.tscn tests/godot
git commit -m "feat: expand prototype world and rebuild physical boundaries"
```

---

### Task 7: Add the Full-Map Minimap and Final HUD Composition

**Files:**
- Create: `scripts/ui/minimap.gd`
- Create: `scenes/ui/minimap.tscn`
- Create: `tests/godot/suites/test_minimap.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `scripts/ui/hotbar_ui.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `WorldLayoutConfig`, player `Node2D`, and stable marker IDs.
- Produces: `MiniMap.bind(layout, player)`, `register_marker(id, category, world_position)`, `unregister_marker(id)`, `marker_position(id) -> Vector2`, and `set_modal_dimmed(dimmed)`.

- [ ] **Step 1: Write failing minimap tests**

Create `tests/godot/suites/test_minimap.gd`:

```gdscript
extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var packed := load("res://scenes/ui/minimap.tscn") as PackedScene
    failures.append(TestAssert.truthy(packed != null, "minimap scene loads"))
    if packed == null:
        return failures.filter(func(message: String) -> bool: return not message.is_empty())
    var minimap := packed.instantiate() as MiniMap
    Engine.get_main_loop().root.add_child(minimap)
    var layout := WorldLayoutConfig.new()
    var player := Node2D.new()
    minimap.add_child(player)
    minimap.bind(layout, player)
    player.position = Vector2.ZERO
    failures.append(TestAssert.equal(minimap.player_marker_position(), Vector2.ZERO, "player origin marker"))
    player.position = Vector2(3072, 2048)
    failures.append(TestAssert.equal(minimap.player_marker_position(), Vector2(160, 160), "player far marker"))
    minimap.register_marker(&"farmhouse", WorldPropDefinition.MarkerCategory.FARMHOUSE, Vector2(384, 1376))
    failures.append(TestAssert.truthy(minimap.has_marker(&"farmhouse"), "farmhouse marker registered"))
    minimap.unregister_marker(&"farmhouse")
    failures.append(TestAssert.truthy(not minimap.has_marker(&"farmhouse"), "marker unregistered"))
    minimap.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite.

- [ ] **Step 2: Run and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: minimap scene and `MiniMap` class are missing.

- [ ] **Step 3: Implement the data-drawn minimap**

Create `scripts/ui/minimap.gd`:

```gdscript
class_name MiniMap
extends Control

const MAP_SIZE := Vector2(160, 160)

var layout: WorldLayoutConfig
var player: Node2D
var _markers: Dictionary = {}


func _ready() -> void:
    custom_minimum_size = MAP_SIZE
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()


func _process(_delta: float) -> void:
    queue_redraw()


func bind(config: WorldLayoutConfig, player_node: Node2D) -> void:
    layout = config
    player = player_node
    queue_redraw()


func register_marker(id: StringName, category: int, world_position: Vector2) -> void:
    if id.is_empty() or _markers.has(id):
        push_warning("MiniMap rejected duplicate or empty marker id: %s" % id)
        return
    _markers[id] = {"category": category, "position": world_position}
    queue_redraw()


func unregister_marker(id: StringName) -> void:
    _markers.erase(id)
    queue_redraw()


func has_marker(id: StringName) -> bool:
    return _markers.has(id)


func player_marker_position() -> Vector2:
    if layout == null or player == null:
        return Vector2.ZERO
    return layout.normalized_to_minimap(player.global_position, MAP_SIZE)


func set_modal_dimmed(dimmed: bool) -> void:
    modulate = Color(1, 1, 1, 0.55 if dimmed else 1.0)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("#486f43"), true)
    if layout == null:
        return
    _draw_region(WorldLayoutConfig.FARMSTEAD, Color("#8b6b42"))
    _draw_region(WorldLayoutConfig.MEADOW, Color("#5e8a50"))
    _draw_region(WorldLayoutConfig.STONEFIELD, Color("#747b78"))
    _draw_region(WorldLayoutConfig.WHISPERWOOD, Color("#315d38"))
    _draw_river()
    for marker in _markers.values():
        _draw_marker(marker)
    draw_circle(player_marker_position().clamp(Vector2.ZERO, MAP_SIZE), 3.0, Color("#ffe5a3"))


func _draw_region(region: Rect2i, color: Color) -> void:
    var top_left := layout.normalized_to_minimap(
        Vector2(region.position * layout.display_cell_size), MAP_SIZE
    )
    var bottom_right := layout.normalized_to_minimap(
        Vector2(region.end * layout.display_cell_size), MAP_SIZE
    )
    draw_rect(Rect2(top_left, bottom_right - top_left), color, true)


func _draw_river() -> void:
    var start := layout.normalized_to_minimap(
        Vector2(layout.river_x_range.x * layout.display_cell_size.x, 0), MAP_SIZE
    )
    var end := layout.normalized_to_minimap(
        Vector2((layout.river_x_range.y + 1) * layout.display_cell_size.x, layout.world_size_pixels().y),
        MAP_SIZE
    )
    draw_rect(Rect2(start, end - start), Color("#3e86a8"), true)


func _draw_marker(marker: Dictionary) -> void:
    var position := layout.normalized_to_minimap(marker["position"], MAP_SIZE)
    var category := int(marker["category"])
    var color := Color("#f4d06f") if category == WorldPropDefinition.MarkerCategory.OBJECTIVE else Color.WHITE
    draw_circle(position, 2.5, color)
```

Create `scenes/ui/minimap.tscn` as a `PanelContainer` anchored to the upper-right with a 168×168 outer size, 4-pixel margin, dark translucent background, and a child `MiniMap` control.

- [ ] **Step 4: Replace the old status panel and compose HUD**

In `prototype_world.tscn`:

- remove the old `StatusPanel` health-only tree;
- instance `StatsHUD` at `(12, 12)`;
- instance `MiniMap` with right/top anchors and offsets `-180, 12, -12, 180`;
- keep `HotbarUI` at bottom center;
- keep `InventoryUI` as a modal overlay;
- reduce `HintPanel` width and default visibility.

Add a small auto-hide timer to `PrototypeWorld` or a focused hint script: show the controls hint for six seconds on first world entry, then fade or hide it. The displayed text becomes `WASD移动 · 左键使用 · 滚轮缩放 · Ctrl+滚轮切换 · Tab背包`.

- [ ] **Step 5: Bind stats, minimap, markers, and modal dimming**

In `PrototypeWorld._bind_player_ui()`:

```gdscript
func _bind_player_ui() -> void:
    hotbar_ui.bind(player.inventory)
    inventory_ui.bind(player.inventory)
    stats_hud.bind(player.get_node("PlayerStats") as PlayerStats)
    stats_hud.set_area_text("晨露谷地 · 初春")
    minimap.bind(world_layout.config, player)
    minimap.register_marker(
        &"farmhouse",
        WorldPropDefinition.MarkerCategory.FARMHOUSE,
        world_layout.config.cell_to_world(Vector2i(12, 43))
    )
    minimap.register_marker(
        &"workshop",
        WorldPropDefinition.MarkerCategory.WORKSHOP,
        world_layout.config.cell_to_world(Vector2i(24, 43))
    )
    inventory_ui.opened_changed.connect(_on_inventory_opened_changed)
```

Implement:

```gdscript
func _on_inventory_opened_changed(opened: bool) -> void:
    player.set_gameplay_input_blocked(opened)
    hotbar_ui.set_modal_dimmed(opened)
    stats_hud.set_modal_dimmed(opened)
    minimap.set_modal_dimmed(opened)
```

- [ ] **Step 6: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
godot --headless --path . --quit-after 8
git add scripts/ui/minimap.gd scenes/ui/minimap.tscn scenes/world/prototype_world.tscn scripts/world/prototype_world.gd scripts/ui/hotbar_ui.gd tests/godot
git commit -m "feat: add minimap and compose expanded HUD"
```

---

### Task 8: Strengthen Validation, Documentation, and Final Acceptance

**Files:**
- Modify: `tools/validate_project.py`
- Modify: `tests/test_validate_project.py`
- Modify: `.github/workflows/validate.yml` only if additional test timeout or log checks are required.
- Modify: `README.md`
- Test: all Python and Godot suites.

**Interfaces:**
- Consumes: all phase components and scenes.
- Produces: repository-level guarantees that the new architecture, dimensions, input ownership, HUD, minimap, and collision files remain wired and loadable.

- [ ] **Step 1: Add failing repository contracts for every new component**

Add a `WORLD_ENHANCEMENT_FILES` tuple to `tools/validate_project.py` containing every file created by Tasks 1–7. Extend `validate_repository()` with exact checks:

```python
WORLD_ENHANCEMENT_FILES = (
    "scripts/world/world_layout_config.gd",
    "data/world/default_world_layout.tres",
    "scripts/player/player_stats.gd",
    "scripts/player/camera_rig.gd",
    "scripts/core/pause_coordinator.gd",
    "scripts/input/game_input_router.gd",
    "scripts/world/world_prop_definition.gd",
    "scripts/world/world_collision_registry.gd",
    "scripts/world/world_prop_factory.gd",
    "scripts/world/world_layout.gd",
    "scripts/ui/stats_hud.gd",
    "scenes/ui/stats_hud.tscn",
    "scripts/ui/minimap.gd",
    "scenes/ui/minimap.tscn",
)
```

Require these tokens:

```python
_require_tokens(errors, layout_text, ("Vector2i(96, 64)", "Vector2i(32, 32)", "func world_size_pixels"), "world layout")
_require_tokens(errors, camera_text, ("MIN_ZOOM := 0.75", "MAX_ZOOM := 1.50", "ZOOM_STEP := 0.125"), "camera rig")
_require_tokens(errors, router_text, ("func _input", "KEY_TAB", "ctrl_pressed", "change_zoom_steps"), "game input router")
_require_tokens(errors, world_scene_text, ("WorldCollisionRegistry", "WorldLayout", "PauseCoordinator", "GameInputRouter", "stats_hud.tscn", "minimap.tscn"), "world scene")
```

Add matching Python unit tests that fail when one file or token is removed.

- [ ] **Step 2: Run the new Python tests and verify the expected failure before validator changes**

```bash
python -m unittest discover -s tests -v
```

Expected: new contract tests fail until the validator and required-file lists are updated.

- [ ] **Step 3: Update README with exact current behavior**

Document:

```text
World: 96×64 logical cells / 3072×2048 pixels
Tab: open or close inventory
Escape: close inventory before pause
Mouse wheel: camera zoom
Ctrl + mouse wheel: quickbar cycle
1–5: direct quickbar selection
Upper-left HUD: health, stamina, mana
Upper-right HUD: full-map minimap
Collision: physical bases only, with tree canopies and roofs remaining visual occluders
```

State clearly that combat damage, enemy AI, harvesting, farming growth, and magic abilities are not active yet.

- [ ] **Step 4: Run the complete phase gate on the final tree**

Run exactly:

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
godot --headless --path . --import
timeout 60s godot --headless --path . --script res://tests/godot/test_runner.gd
timeout 20s godot --headless --path . --quit-after 8
```

Expected:

- Python reports zero failures;
- repository validator exits `0`;
- compileall exits `0`;
- Godot import reports no `SCRIPT ERROR` or missing resource;
- all headless suites finish before timeout and report zero failures;
- main scene starts and exits without runtime errors.

- [ ] **Step 5: Manually verify the acceptance checklist in a graphical Godot run**

Verify each item once and record the result in the PR description:

```text
[ ] Player can travel between farmstead, meadow, forest, and stonefield.
[ ] Bare rectangular map edges are not visible from normal paths.
[ ] Tab opens and closes inventory every time.
[ ] Escape closes inventory first.
[ ] Direct wheel zoom is smooth and remains within 0.75–1.50.
[ ] Ctrl-wheel and 1–5 change quickbar selection.
[ ] Inventory-open wheel input does not zoom the world.
[ ] Health, stamina, and mana bars are visible and readable at 640×360.
[ ] Minimap player marker tracks all four map corners correctly.
[ ] Player cannot walk through house walls, tree trunks, rocks, fences, or river segments.
[ ] Player can walk visually behind tree canopies and roof overlays.
[ ] Farmhouse doorway and main roads remain passable.
[ ] No spawn or save-position recovery places the player inside collision.
[ ] Existing inventory, hotbar, item requests, and crafting still work.
```

- [ ] **Step 6: Commit and open the phase PR**

```bash
git add tools tests .github/workflows/validate.yml README.md
git commit -m "test: validate world UI camera and collision enhancement"
git push -u origin feat/world-ui-camera-collision-enhancement
```

Open a PR against `main` titled:

```text
feat: expand world HUD camera and collisions
```

PR acceptance: all automated gates pass, the graphical checklist is recorded, and no combat, harvesting, farming, or magic scope has leaked into the phase.
