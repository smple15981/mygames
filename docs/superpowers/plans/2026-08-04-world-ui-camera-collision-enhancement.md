# World, UI, Camera, and Collision Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Hearthwild 2D to a 96×64 world with reliable inventory input, bounded camera zoom, health/stamina/mana HUD, a full-map minimap, and base-only collisions that stop prop clipping while preserving top-down occlusion.

**Architecture:** Keep `PrototypeWorld` as the composition root, but move dimensions and terrain rules into `WorldLayoutConfig`, terrain/prop construction into `WorldLayout`, collision creation into `WorldPropFactory` plus `WorldCollisionRegistry`, player resources into `PlayerStats`, camera behavior into `CameraRig`, and global modal controls into `GameInputRouter` plus `PauseCoordinator`. HUD scenes observe data through signals and never become the source of truth.

**Tech Stack:** Godot 4.3+ / GDScript, Godot 4.6.3 headless CI, Python 3.13 repository tests, GitHub Actions, existing pure-2D and bundled open-art pipeline.

## Global Constraints

- Preserve the 640×360 internal viewport, nearest-neighbor filtering, 16×16 source tiles, and 2× display scale.
- The authoritative world is exactly 96×64 logical cells and 3072×2048 world pixels.
- Preserve the current `CharacterBody2D` player, 20-slot inventory, five-slot quickbar, portable crafting, and item request protocol.
- Direct mouse wheel changes camera zoom; Ctrl + mouse wheel cycles quickbar slots; number keys 1–5 still select slots.
- Camera zoom starts at 1.00, changes by 0.125, and clamps to 0.75–1.50.
- Tab is captured in `_input()` and toggles inventory before GUI focus traversal can consume it.
- Escape closes inventory before any pause-menu action.
- Inventory closing releases only the inventory pause reason.
- Solid props collide only at their bases; decorative props create no collision.
- World solids remain on collision layer 1; the player remains on layer 2 with mask 1.
- Every placed solid prop has a unique stable instance ID even when multiple instances use the same definition.
- No combat damage, enemy AI, harvesting results, farming progression, magic abilities, third-party plugins, or 3D nodes are added.
- Each task follows red → green testing and ends with an independently reviewable commit.

---

## File Map

### Create

```text
scripts/world/world_layout_config.gd
data/world/default_world_layout.tres
scripts/player/player_stats.gd
scripts/ui/stats_hud.gd
scenes/ui/stats_hud.tscn
scripts/player/camera_rig.gd
scripts/core/pause_coordinator.gd
scripts/input/game_input_router.gd
scripts/world/world_prop_definition.gd
scripts/world/world_collision_registry.gd
scripts/world/world_prop_factory.gd
data/world/props/farmhouse.tres
data/world/props/workshop.tres
data/world/props/tree_small.tres
data/world/props/tree_cluster.tres
data/world/props/rock_cluster.tres
data/world/props/fence_horizontal.tres
scripts/world/world_layout.gd
scripts/ui/minimap.gd
scenes/ui/minimap.tscn
tests/godot/suites/test_world_layout_config.gd
tests/godot/suites/test_player_stats.gd
tests/godot/suites/test_camera_rig.gd
tests/godot/suites/test_game_input_router.gd
tests/godot/suites/test_world_collisions.gd
tests/godot/suites/test_world_integration.gd
tests/godot/suites/test_minimap.gd
```

### Modify

```text
project.godot
scenes/player/player.tscn
scripts/player/player_controller.gd
scripts/ui/inventory_ui.gd
scripts/ui/hotbar_ui.gd
scenes/world/prototype_world.tscn
scripts/world/prototype_world.gd
tests/godot/test_runner.gd
tools/validate_project.py
tests/test_validate_project.py
README.md
```

---

### Task 1: Authoritative World Layout Configuration

**Files:**
- Create: `scripts/world/world_layout_config.gd`
- Create: `data/world/default_world_layout.tres`
- Create: `tests/godot/suites/test_world_layout_config.gd`
- Modify: `tests/godot/test_runner.gd`
- Modify: `tests/test_validate_project.py`

**Interfaces:**
- Produces `world_size_pixels() -> Vector2i`, `world_rect() -> Rect2`, `cell_to_world(cell) -> Vector2`, `world_to_normalized(position) -> Vector2`, `normalized_to_minimap(position, size) -> Vector2`, `is_inside_cell(cell) -> bool`, `is_bridge_cell(cell) -> bool`, and `is_water_cell(cell) -> bool`.

- [ ] **Step 1: Write the failing repository test**

Add to `tests/test_validate_project.py`:

```python
def test_world_layout_contract_exists(self) -> None:
    root = Path(__file__).resolve().parents[1]
    path = root / "scripts/world/world_layout_config.gd"
    self.assertTrue(path.is_file())
    self.assertTrue((root / "data/world/default_world_layout.tres").is_file())
    text = path.read_text(encoding="utf-8")
    self.assertIn("Vector2i(96, 64)", text)
    self.assertIn("Vector2i(32, 32)", text)
    self.assertIn("func normalized_to_minimap", text)
```

- [ ] **Step 2: Write the failing Godot suite**

Create `tests/godot/suites/test_world_layout_config.gd`:

```gdscript
extends RefCounted

static func run() -> Array[String]:
    var failures: Array[String] = []
    var config := WorldLayoutConfig.new()
    failures.append(TestAssert.equal(config.map_size_cells, Vector2i(96, 64), "map cells"))
    failures.append(TestAssert.equal(config.world_size_pixels(), Vector2i(3072, 2048), "world pixels"))
    failures.append(TestAssert.equal(config.world_to_normalized(Vector2.ZERO), Vector2.ZERO, "normalized origin"))
    failures.append(TestAssert.equal(config.world_to_normalized(Vector2(3072, 2048)), Vector2.ONE, "normalized end"))
    failures.append(TestAssert.equal(
        config.normalized_to_minimap(Vector2(1536, 1024), Vector2(160, 160)),
        Vector2(80, 80),
        "minimap center"
    ))
    failures.append(TestAssert.truthy(config.is_bridge_cell(Vector2i(59, 31)), "bridge cell"))
    failures.append(TestAssert.truthy(not config.is_water_cell(Vector2i(59, 31)), "bridge walkable"))
    failures.append(TestAssert.truthy(config.is_water_cell(Vector2i(59, 20)), "river water"))
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite in `tests/godot/test_runner.gd`.

- [ ] **Step 3: Verify the tests fail**

```bash
python -m unittest tests.test_validate_project.ProjectValidatorTests.test_world_layout_contract_exists -v
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: missing files and undefined `WorldLayoutConfig`.

- [ ] **Step 4: Implement the layout resource**

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
    return Vector2i(
        map_size_cells.x * display_cell_size.x,
        map_size_cells.y * display_cell_size.y
    )

func world_rect() -> Rect2:
    return Rect2(Vector2.ZERO, Vector2(world_size_pixels()))

func cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(
        cell.x * display_cell_size.x + display_cell_size.x * 0.5,
        cell.y * display_cell_size.y + display_cell_size.y * 0.5
    )

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
    for rows in bridge_y_ranges:
        if cell.y >= rows.x and cell.y <= rows.y:
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
```

- [ ] **Step 5: Run and commit**

```bash
python -m unittest discover -s tests -v
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world/world_layout_config.gd data/world/default_world_layout.tres tests
git commit -m "feat: add authoritative world layout configuration"
```

---

### Task 2: Player Resources and Three-Bar HUD

**Files:**
- Create: `scripts/player/player_stats.gd`
- Create: `scripts/ui/stats_hud.gd`
- Create: `scenes/ui/stats_hud.tscn`
- Create: `tests/godot/suites/test_player_stats.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Produces `PlayerStats.set_health`, `change_health`, `set_stamina`, `change_stamina`, `set_mana`, `change_mana`, `restore_all`; signals `health_changed`, `stamina_changed`, `mana_changed`; and `StatsHUD.bind(stats)`.

- [ ] **Step 1: Write the failing model and scene test**

Create `tests/godot/suites/test_player_stats.gd`:

```gdscript
extends RefCounted

static func run() -> Array[String]:
    var failures: Array[String] = []
    var stats := PlayerStats.new()
    var health_events := 0
    stats.health_changed.connect(func(_current: float, _maximum: float) -> void: health_events += 1)
    stats.set_health(130.0)
    failures.append(TestAssert.equal(stats.health, 100.0, "health upper clamp"))
    stats.change_health(-145.0)
    failures.append(TestAssert.equal(stats.health, 0.0, "health lower clamp"))
    stats.set_stamina(42.0)
    failures.append(TestAssert.equal(stats.stamina, 42.0, "stamina value"))
    stats.set_mana(-10.0)
    failures.append(TestAssert.equal(stats.mana, 0.0, "mana lower clamp"))
    stats.restore_all()
    failures.append(TestAssert.equal(stats.health, 100.0, "health restore"))
    failures.append(TestAssert.equal(stats.stamina, 100.0, "stamina restore"))
    failures.append(TestAssert.equal(stats.mana, 100.0, "mana restore"))
    failures.append(TestAssert.truthy(health_events >= 2, "health signal"))

    var packed := load("res://scenes/ui/stats_hud.tscn") as PackedScene
    failures.append(TestAssert.truthy(packed != null, "stats HUD loads"))
    if packed != null:
        var hud := packed.instantiate() as StatsHUD
        Engine.get_main_loop().root.add_child(hud)
        hud.bind(stats)
        stats.set_mana(55.0)
        var label := hud.get_node("Margin/Column/Mana/Value") as Label
        failures.append(TestAssert.equal(label.text, "55 / 100", "mana label"))
        hud.free()
    stats.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register the suite and verify it fails before implementation.

- [ ] **Step 2: Implement `PlayerStats`**

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
    _emit_all()

func set_health(value: float) -> void:
    var next := clampf(value, 0.0, max_health)
    if is_equal_approx(next, health): return
    health = next
    health_changed.emit(health, max_health)

func change_health(delta: float) -> void:
    set_health(health + delta)

func set_stamina(value: float) -> void:
    var next := clampf(value, 0.0, max_stamina)
    if is_equal_approx(next, stamina): return
    stamina = next
    stamina_changed.emit(stamina, max_stamina)

func change_stamina(delta: float) -> void:
    set_stamina(stamina + delta)

func set_mana(value: float) -> void:
    var next := clampf(value, 0.0, max_mana)
    if is_equal_approx(next, mana): return
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

Add `[node name="PlayerStats" type="Node" parent="."]` with this script to `scenes/player/player.tscn`.

- [ ] **Step 3: Create the exact HUD scene tree**

Create `scenes/ui/stats_hud.tscn` with this node contract:

```text
StatsHUD (PanelContainer, script=stats_hud.gd, size 220×92)
└── Margin (MarginContainer, 8/7/8/7 margins)
    └── Column (VBoxContainer, separation 3)
        ├── Health (HBoxContainer)
        │   ├── Name (Label, text="生命")
        │   ├── Bar (ProgressBar, minimum 112×9, red fill)
        │   └── Value (Label, text="100 / 100", minimum width 62)
        ├── Stamina (HBoxContainer; Name="体力"; gold-green fill)
        │   ├── Name
        │   ├── Bar
        │   └── Value
        ├── Mana (HBoxContainer; Name="魔力"; blue fill)
        │   ├── Name
        │   ├── Bar
        │   └── Value
        └── Area (Label, text="晨露谷地 · 初春")
```

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
@onready var area: Label = $Margin/Column/Area
var stats: PlayerStats
var targets := Vector3(100, 100, 100)

func _process(delta: float) -> void:
    var weight := 1.0 - exp(-12.0 * delta)
    health_bar.value = lerpf(health_bar.value, targets.x, weight)
    stamina_bar.value = lerpf(stamina_bar.value, targets.y, weight)
    mana_bar.value = lerpf(mana_bar.value, targets.z, weight)

func bind(model: PlayerStats) -> void:
    stats = model
    if stats == null:
        push_error("StatsHUD requires PlayerStats")
        return
    stats.health_changed.connect(_on_health)
    stats.stamina_changed.connect(_on_stamina)
    stats.mana_changed.connect(_on_mana)
    _on_health(stats.health, stats.max_health)
    _on_stamina(stats.stamina, stats.max_stamina)
    _on_mana(stats.mana, stats.max_mana)

func set_area_text(text: String) -> void:
    area.text = text

func set_modal_dimmed(dimmed: bool) -> void:
    modulate.a = 0.55 if dimmed else 1.0

func _on_health(current: float, maximum: float) -> void:
    health_bar.max_value = maximum
    targets.x = current
    health_value.text = "%d / %d" % [roundi(current), roundi(maximum)]

func _on_stamina(current: float, maximum: float) -> void:
    stamina_bar.max_value = maximum
    targets.y = current
    stamina_value.text = "%d / %d" % [roundi(current), roundi(maximum)]

func _on_mana(current: float, maximum: float) -> void:
    mana_bar.max_value = maximum
    targets.z = current
    mana_value.text = "%d / %d" % [roundi(current), roundi(maximum)]
```

- [ ] **Step 4: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
git add scripts/player/player_stats.gd scripts/ui/stats_hud.gd scenes/ui/stats_hud.tscn scenes/player/player.tscn tests/godot
git commit -m "feat: add player resources and three-bar HUD"
```

---

### Task 3: Bounded Camera Zoom

**Files:**
- Create: `scripts/player/camera_rig.gd`
- Create: `tests/godot/suites/test_camera_rig.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Produces `configure_world(rect)`, `change_zoom_steps(direction)`, `set_zoom_value(value)`, `target_zoom_value()`, and static `clamp_center_to_world(...)`.

- [ ] **Step 1: Write and run the failing camera test**

```gdscript
extends RefCounted

static func run() -> Array[String]:
    var failures: Array[String] = []
    var camera := CameraRig.new()
    camera.set_zoom_value(4.0)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.5, "upper clamp"))
    camera.set_zoom_value(0.1)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 0.75, "lower clamp"))
    camera.set_zoom_value(1.0)
    camera.change_zoom_steps(1)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.125, "one step"))
    var clamped := CameraRig.clamp_center_to_world(
        Vector2(-100, -100),
        Rect2(Vector2.ZERO, Vector2(3072, 2048)),
        Vector2(640, 360),
        1.0
    )
    failures.append(TestAssert.equal(clamped, Vector2(320, 180), "top-left clamp"))
    camera.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Expected before implementation: `CameraRig` is undefined.

- [ ] **Step 2: Implement `CameraRig`**

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
    zoom = Vector2.ONE
    _apply_limits()

func _process(delta: float) -> void:
    var weight := 1.0 - exp(-zoom_lerp_speed * delta)
    var next := lerpf(zoom.x, _target_zoom, weight)
    zoom = Vector2.ONE * next
    global_position = clamp_center_to_world(global_position, _world_rect, get_viewport_rect().size, next)

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

static func clamp_center_to_world(target: Vector2, rect: Rect2, viewport: Vector2, zoom_value: float) -> Vector2:
    var half_view := viewport * 0.5 / maxf(zoom_value, 0.001)
    var minimum := rect.position + half_view
    var maximum := rect.end - half_view
    if minimum.x > maximum.x: minimum.x = rect.get_center().x; maximum.x = minimum.x
    if minimum.y > maximum.y: minimum.y = rect.get_center().y; maximum.y = minimum.y
    return Vector2(clampf(target.x, minimum.x, maximum.x), clampf(target.y, minimum.y, maximum.y))
```

Replace the existing bare `Camera2D` scriptless node with the same `Camera2D` node named `Camera2D`, attach `camera_rig.gd`, and remove hard-coded 1280×768 limits.

- [ ] **Step 3: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
git add scripts/player/camera_rig.gd scenes/player/player.tscn tests/godot
git commit -m "feat: add bounded smooth camera zoom"
```

---

### Task 4: Reliable Tab, Escape, Pause Ownership, and Wheel Routing

**Files:**
- Create: `scripts/core/pause_coordinator.gd`
- Create: `scripts/input/game_input_router.gd`
- Create: `tests/godot/suites/test_game_input_router.gd`
- Modify: `scripts/ui/inventory_ui.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `scripts/ui/hotbar_ui.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Produces `PauseCoordinator.acquire/release/has_reason/is_paused`, `GameInputRouter.bind(...)`, and `handle_event(event) -> bool`.

- [ ] **Step 1: Write the failing input suite**

Create a test that:

```gdscript
var pause := PauseCoordinator.new()
pause.acquire(&"inventory")
pause.acquire(&"pause_menu")
pause.release(&"inventory")
failures.append(TestAssert.truthy(pause.has_reason(&"pause_menu"), "other pause retained"))

var tab := InputEventKey.new()
tab.keycode = KEY_TAB
tab.pressed = true
failures.append(TestAssert.truthy(router.handle_event(tab), "Tab handled"))
failures.append(TestAssert.truthy(inventory_ui.is_open(), "Tab opens inventory"))

var escape := InputEventKey.new()
escape.keycode = KEY_ESCAPE
escape.pressed = true
router.handle_event(escape)
failures.append(TestAssert.truthy(not inventory_ui.is_open(), "Escape closes inventory"))

var wheel := InputEventMouseButton.new()
wheel.button_index = MOUSE_BUTTON_WHEEL_UP
wheel.pressed = true
router.handle_event(wheel)
failures.append(TestAssert.equal(camera.target_zoom_value(), 1.125, "wheel zoom"))
wheel.ctrl_pressed = true
inventory.set_selected_slot(2)
router.handle_event(wheel)
failures.append(TestAssert.equal(inventory.selected_index, 1, "Ctrl-wheel quickbar"))
```

Instantiate the existing inventory scene, an `InventoryModel`, `CameraRig`, `PauseCoordinator`, and `GameInputRouter`; add them to the scene-tree root so signals and pause state work. Verify failure before implementation.

- [ ] **Step 2: Implement `PauseCoordinator`**

```gdscript
class_name PauseCoordinator
extends Node

signal pause_state_changed(paused: bool)
var _reasons: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func acquire(reason: StringName) -> void:
    if reason.is_empty(): return
    var previous := is_paused()
    _reasons[reason] = true
    _sync(previous)

func release(reason: StringName) -> void:
    var previous := is_paused()
    _reasons.erase(reason)
    _sync(previous)

func has_reason(reason: StringName) -> bool:
    return _reasons.has(reason)

func is_paused() -> bool:
    return not _reasons.is_empty()

func _sync(previous: bool) -> void:
    var current := is_paused()
    if get_tree() != null: get_tree().paused = current
    if current != previous: pause_state_changed.emit(current)
```

- [ ] **Step 3: Make `InventoryUI` state-only**

Remove its `_unhandled_input()` and all direct `get_tree().paused` assignments. Keep `process_mode = ALWAYS` and implement:

```gdscript
func is_open() -> bool:
    return visible

func set_open(opened: bool) -> void:
    if visible == opened: return
    visible = opened
    if visible:
        status_label.text = ""
        _refresh_inventory()
        _refresh_recipe_detail()
    opened_changed.emit(visible)

func open() -> void:
    if inventory != null: set_open(true)

func close() -> void:
    set_open(false)
```

The close button remains connected to `close()`.

- [ ] **Step 4: Implement `GameInputRouter`**

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

func bind(view: InventoryUI, model: InventoryModel, camera: CameraRig, pause: PauseCoordinator) -> void:
    inventory_ui = view
    inventory = model
    camera_rig = camera
    pause_coordinator = pause
    inventory_ui.opened_changed.connect(_on_inventory_opened)

func _input(event: InputEvent) -> void:
    if handle_event(event): get_viewport().set_input_as_handled()

func handle_event(event: InputEvent) -> bool:
    if event is InputEventKey and (event as InputEventKey).echo: return false
    if event.is_action_pressed("inventory") or _key_pressed(event, KEY_TAB):
        if inventory_ui == null: push_error("GameInputRouter missing InventoryUI"); return true
        inventory_ui.set_open(not inventory_ui.is_open())
        return true
    if event.is_action_pressed("pause") or _key_pressed(event, KEY_ESCAPE):
        if inventory_ui != null and inventory_ui.is_open():
            inventory_ui.set_open(false)
            return true
        return false
    if inventory_ui != null and inventory_ui.is_open(): return false
    for index in InventoryModel.QUICKBAR_SIZE:
        if event.is_action_pressed("quick_slot_%d" % (index + 1)):
            if inventory != null: inventory.set_selected_slot(index)
            return true
    if event is InputEventMouseButton and event.pressed:
        var mouse := event as InputEventMouseButton
        var direction := 1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1 if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0
        if direction == 0: return false
        if mouse.ctrl_pressed and inventory != null:
            inventory.set_selected_slot(posmod(inventory.selected_index - direction, inventory.quickbar_size))
        elif camera_rig != null:
            camera_rig.change_zoom_steps(direction)
        return true
    return false

func _on_inventory_opened(opened: bool) -> void:
    if pause_coordinator == null: return
    if opened: pause_coordinator.acquire(INVENTORY_REASON)
    else: pause_coordinator.release(INVENTORY_REASON)

func _key_pressed(event: InputEvent, key: Key) -> bool:
    return event is InputEventKey and event.pressed and (event as InputEventKey).keycode == key
```

- [ ] **Step 5: Remove conflicting player input ownership**

Delete quickbar number-key and wheel handling from `PlayerController._unhandled_input`; retain attack only. Add `gameplay_input_blocked`, `set_gameplay_input_blocked(blocked)`, and return zero movement input while blocked. Guard attack requests while blocked. Add this to `HotbarUI`:

```gdscript
func set_modal_dimmed(dimmed: bool) -> void:
    modulate.a = 0.55 if dimmed else 1.0
```

- [ ] **Step 6: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
git add scripts/core scripts/input scripts/ui/inventory_ui.gd scripts/ui/hotbar_ui.gd scripts/player/player_controller.gd tests/godot
git commit -m "fix: centralize modal input and pause ownership"
```

---

### Task 5: Prop Definitions, Unique Instance IDs, and Collision Registry

**Files:**
- Create: `scripts/world/world_prop_definition.gd`
- Create: `scripts/world/world_collision_registry.gd`
- Create: `scripts/world/world_prop_factory.gd`
- Create: `data/world/props/*.tres`
- Create: `tests/godot/suites/test_world_collisions.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- `WorldPropDefinition` describes a reusable prop type.
- Every `WorldPropFactory.spawn_atlas_prop` call also receives a unique `instance_id`.
- `WorldCollisionRegistry` stores world-space footprints by unique instance-shape ID.

- [ ] **Step 1: Write the failing collision suite**

Test all of these cases:

```gdscript
var tree := WorldPropDefinition.new()
tree.id = &"tree_small"
tree.solid = true
tree.collision_rects = [Rect2(-12, -14, 24, 14)]
failures.append(TestAssert.equal(tree.validate().size(), 0, "valid tree"))

var broken := WorldPropDefinition.new()
broken.id = &"broken"
broken.solid = true
failures.append(TestAssert.truthy(broken.validate().size() > 0, "solid needs collision"))

var registry := WorldCollisionRegistry.new()
registry.configure_world(Rect2(Vector2.ZERO, Vector2(3072, 2048)))
failures.append(TestAssert.truthy(registry.register_rect(&"tree_001:0", Rect2(90, 90, 20, 20)), "first instance"))
failures.append(TestAssert.truthy(registry.register_rect(&"tree_002:0", Rect2(130, 90, 20, 20)), "second same-type instance"))
failures.append(TestAssert.truthy(not registry.register_rect(&"tree_001:0", Rect2(0, 0, 5, 5)), "duplicate instance rejected"))
failures.append(TestAssert.truthy(not registry.is_position_safe(Vector2(100, 100), Vector2(16, 12)), "overlap unsafe"))
```

Also load `farmhouse.tres` and assert a `Rect2(-15, -31, 30, 31)` doorway does not intersect any collision rectangle.

- [ ] **Step 2: Implement `WorldPropDefinition`**

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
@export var marker_category: MarkerCategory = MarkerCategory.NONE

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if id.is_empty(): errors.append("id must not be empty")
    if visual_scale <= 0.0: errors.append("visual_scale must be positive")
    if solid and collision_rects.is_empty(): errors.append("solid prop requires collision_rects")
    for rect in collision_rects:
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            errors.append("collision rectangle sizes must be positive")
    return errors
```

- [ ] **Step 3: Implement `WorldCollisionRegistry`**

```gdscript
class_name WorldCollisionRegistry
extends Node

var _footprints: Dictionary = {}
var _world_rect := Rect2(Vector2.ZERO, Vector2(1280, 768))
@export var search_step := 16.0
@export var search_rings := 16

func configure_world(rect: Rect2) -> void:
    if rect.size.x > 0.0 and rect.size.y > 0.0: _world_rect = rect

func register_rect(id: StringName, rect: Rect2) -> bool:
    if id.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0 or _footprints.has(id): return false
    _footprints[id] = rect
    return true

func unregister(id: StringName) -> void:
    _footprints.erase(id)

func overlaps_rect(rect: Rect2) -> bool:
    for footprint in _footprints.values():
        if (footprint as Rect2).intersects(rect, true): return true
    return false

func is_position_safe(position: Vector2, player_size: Vector2) -> bool:
    var footprint := Rect2(position - player_size * 0.5, player_size)
    return _world_rect.encloses(footprint) and not overlaps_rect(footprint)

func find_nearest_safe_position(requested: Vector2, player_size: Vector2, fallback: Vector2) -> Vector2:
    if is_position_safe(requested, player_size): return requested
    for ring in range(1, search_rings + 1):
        var radius := ring * search_step
        for offset in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius), Vector2(radius, radius), Vector2(-radius, radius), Vector2(radius, -radius), Vector2(-radius, -radius)]:
            var candidate := requested + offset
            if is_position_safe(candidate, player_size): return candidate
    return fallback if is_position_safe(fallback, player_size) else _world_rect.get_center()
```

- [ ] **Step 4: Implement `WorldPropFactory` with unique instance IDs**

```gdscript
class_name WorldPropFactory
extends RefCounted

static func spawn_atlas_prop(
    parent: Node2D,
    texture: Texture2D,
    region: Rect2i,
    definition: WorldPropDefinition,
    instance_id: StringName,
    world_position: Vector2,
    registry: WorldCollisionRegistry
) -> Node2D:
    if parent == null or texture == null or definition == null or instance_id.is_empty(): return null
    if not definition.validate().is_empty() or not OpenAtlasRegions.region_fits(texture, region): return null
    var root := Node2D.new()
    root.name = String(instance_id)
    root.position = world_position
    var sprite := Sprite2D.new()
    sprite.name = "Visual"
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = Rect2(region)
    sprite.scale = Vector2.ONE * definition.visual_scale
    sprite.position = definition.visual_offset
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
            collision.position = rect.position + rect.size * 0.5
            collision.shape = shape
            body.add_child(collision)
            if registry != null:
                registry.register_rect(StringName("%s:%d" % [instance_id, index]), Rect2(world_position + rect.position, rect.size))
    parent.add_child(root)
    return root
```

- [ ] **Step 5: Create exact prop resources**

Use these values:

```text
farmhouse: scale 2.0, visual_offset (0,-92), solid, rects (-56,-44,40,44), (16,-44,40,44), (-56,-44,112,12), marker FARMHOUSE
workshop: scale 2.0, visual_offset (0,-76), solid, rects (-44,-36,32,36), (12,-36,32,36), (-44,-36,88,10), marker WORKSHOP
tree_small: scale 2.0, visual_offset (0,-64), solid, rect (-12,-14,24,14)
tree_cluster: scale 2.0, visual_offset (0,-72), solid, rects (-28,-16,20,16), (8,-16,20,16)
rock_cluster: scale 1.7, visual_offset (0,-24), solid, rect (-17,-12,34,12)
fence_horizontal: scale 2.0, visual_offset (0,-16), solid, rect (-56,-8,112,12)
```

Each `.tres` contains the script, unique definition ID, display name, exact values above, and no texture path because atlas regions remain selected by `WorldLayout`.

- [ ] **Step 6: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
git add scripts/world/world_prop_definition.gd scripts/world/world_collision_registry.gd scripts/world/world_prop_factory.gd data/world/props tests/godot
git commit -m "feat: add unique base-only prop collisions"
```

---

### Task 6: Build the 96×64 World, Boundaries, Routes, and Recovery

**Files:**
- Create: `scripts/world/world_layout.gd`
- Create: `tests/godot/suites/test_world_integration.gd`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Produces `WorldLayout.build`, `spawn_position`, `world_rect`, `validate_required_routes`, and `recover_player_position`.

- [ ] **Step 1: Write the failing integration suite**

Instantiate `prototype_world.tscn` and assert:

```gdscript
var layout := world.get_node("WorldLayout") as WorldLayout
failures.append(TestAssert.equal(layout.config.map_size_cells, Vector2i(96, 64), "large layout"))
failures.append(TestAssert.equal(layout.world_rect().size, Vector2(3072, 2048), "world bounds"))
failures.append(TestAssert.equal(layout.validate_required_routes().size(), 0, "routes passable"))
var registry := world.get_node("WorldCollisionRegistry") as WorldCollisionRegistry
var player := world.get_node("Entities/Player") as CharacterBody2D
failures.append(TestAssert.truthy(registry.is_position_safe(player.position, Vector2(16, 12)), "safe spawn"))
var recovered := layout.recover_player_position(Vector2(400, 1376), Vector2(16, 12))
failures.append(TestAssert.truthy(registry.is_position_safe(recovered, Vector2(16, 12)), "safe recovery"))
```

Verify failure before scene changes.

- [ ] **Step 2: Implement deterministic terrain rules**

`WorldLayout` owns the existing runtime tile-set setup. Paint all 6144 cells. Use:

```gdscript
func terrain_for(cell: Vector2i) -> int:
    if config.is_bridge_cell(cell): return GroundTile.PATH
    if config.is_water_cell(cell): return GroundTile.WATER
    if cell.x >= 8 and cell.x <= 20 and cell.y >= 48 and cell.y <= 57: return GroundTile.SOIL
    if cell.x >= 66 and cell.y >= 20 and (cell.x + cell.y) % 4 == 0: return GroundTile.STONE
    if (cell.x >= 17 and cell.x <= 19) or (cell.y >= 31 and cell.y <= 33): return GroundTile.PATH
    return GroundTile.GRASS
```

Keep source tiles at 16 and `Ground.scale = Vector2(2,2)`.

- [ ] **Step 3: Place exact interior props with unique IDs**

```gdscript
const FARMHOUSE_CELL := Vector2i(12, 43)
const WORKSHOP_CELL := Vector2i(24, 43)
const FARM_FENCE_CELL := Vector2i(14, 50)
const TREE_CELLS := [Vector2i(5,7),Vector2i(11,8),Vector2i(18,6),Vector2i(25,10),Vector2i(33,7),Vector2i(41,11),Vector2i(49,8),Vector2i(55,14),Vector2i(7,25),Vector2i(10,31),Vector2i(84,8),Vector2i(90,15)]
const ROCK_CELLS := [Vector2i(70,27),Vector2i(76,31),Vector2i(83,25),Vector2i(88,38),Vector2i(72,48),Vector2i(84,54)]
```

Call `WorldPropFactory.spawn_atlas_prop` with instance IDs `farmhouse`, `workshop`, `farm_fence`, `tree_000`… and `rock_000`… . Never pass the reusable definition ID as the instance ID.

- [ ] **Step 4: Generate exact natural borders**

Use this deterministic boundary generator:

```gdscript
func boundary_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for x in range(0, config.map_size_cells.x, 2):
        cells.append(Vector2i(x, 1))
        cells.append(Vector2i(x, config.map_size_cells.y - 2))
    for y in range(3, config.map_size_cells.y - 3, 2):
        cells.append(Vector2i(1, y))
        cells.append(Vector2i(config.map_size_cells.x - 2, y))
    return cells
```

Spawn alternating `tree_small` and `rock_cluster` definitions with IDs `boundary_000` onward. The border is entirely closed; no road exits leave the prototype map. The two-cell inset keeps sprites visible without exposing a bare cutoff.

- [ ] **Step 5: Build river visuals and collision without bridge seams**

River columns are 58–61. Create water visual segments and matching static collision rectangles for rows `0–29`, `34–44`, and `48–63`. Each segment position and size is computed from `display_cell_size`; bridge rows `30–33` and `45–47` receive path tiles and no river collision. Register collision IDs `river_0`, `river_1`, `river_2`.

- [ ] **Step 6: Validate routes and recover invalid positions**

Required checkpoints:

```gdscript
const ROUTE_CELLS := [Vector2i(16,46),Vector2i(18,32),Vector2i(40,32),Vector2i(59,31),Vector2i(72,31),Vector2i(42,18)]
```

`validate_required_routes()` checks a 16×12 player footprint at every checkpoint and returns messages for blocked points. `recover_player_position(requested,size)` calls the registry’s nearest-safe search and uses `spawn_position()` as fallback. Add a breadth-first test over four-neighbor cells from spawn to every route checkpoint; water cells and registry-overlapped cells are blocked. The test fails if any checkpoint cannot be reached.

- [ ] **Step 7: Refactor the world composition**

Add scene nodes:

```text
WorldCollisionRegistry (Node)
WorldLayout (Node2D; config=default_world_layout.tres; paths to Ground and Entities)
PauseCoordinator (Node)
GameInputRouter (Node)
```

`PrototypeWorld._ready()` order:

```gdscript
world_layout.build()
player.position = world_layout.spawn_position()
camera_rig.configure_world(world_layout.world_rect())
_bind_player_ui()
_bind_global_input()
```

Move hard-coded map painting, prop construction, and river blocker code out of `PrototypeWorld`. Keep `Entities.y_sort_enabled = true`; prop roots and player roots remain positioned at physical feet/base coordinates.

- [ ] **Step 8: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
timeout 20s godot --headless --path . --quit-after 8
git add scripts/world/world_layout.gd scripts/world/prototype_world.gd scenes/world/prototype_world.tscn tests/godot
git commit -m "feat: expand prototype world and physical boundaries"
```

---

### Task 7: Full-Map Minimap and HUD Composition

**Files:**
- Create: `scripts/ui/minimap.gd`
- Create: `scenes/ui/minimap.tscn`
- Create: `tests/godot/suites/test_minimap.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Produces `MiniMap.bind`, `register_marker`, `unregister_marker`, `has_marker`, `player_marker_position`, and `set_modal_dimmed`.

- [ ] **Step 1: Write the failing minimap test**

Instantiate the minimap scene and a separate root-level player node. Assert player positions `(0,0)`, `(1536,1024)`, and `(3072,2048)` map to `(0,0)`, `(80,80)`, and `(160,160)`. Register and unregister `farmhouse`. Verify failure before implementation.

- [ ] **Step 2: Implement the minimap data model**

Use a 160×160 custom `Control`. Store markers as:

```gdscript
_markers[id] = {"category": category, "position": world_position}
```

Reject empty or duplicate IDs. Clamp marker output with explicit `clampf` calls. `player_marker_position()` uses `layout.normalized_to_minimap(player.global_position, Vector2(160,160))`.

- [ ] **Step 3: Draw every required layer in this exact order**

Inside `_draw()`:

```text
1. grass background #486f43
2. farmstead rectangle #8b6b42
3. meadow rectangle #5e8a50
4. stonefield rectangle #747b78
5. whisperwood rectangle #315d38
6. vertical road cells x=17..19, color #b58a59
7. horizontal road cells y=31..33, color #b58a59
8. river x=58..61, color #3e86a8
9. bridge rectangles y=30..33 and y=45..47, color #b58a59, drawn over river
10. farmland x=8..20 and y=48..57, color #70452f
11. registered markers
12. player marker #ffe5a3
```

Convert cell rectangles to minimap rectangles through `WorldLayoutConfig`, not hard-coded pixel ratios.

- [ ] **Step 4: Create the exact scene contract**

```text
MiniMapFrame (PanelContainer, top-right anchors, outer size 168×168)
└── Margin (4-pixel margins)
    └── MiniMap (Control, script=minimap.gd, minimum size 160×160)
```

Use the existing dark translucent panel and gold border visual language.

- [ ] **Step 5: Compose the final HUD**

Remove the old health-only `StatusPanel`. Instance `StatsHUD` at `(12,12)`, `MiniMapFrame` at upper-right offsets `(-180,12,-12,180)`, retain bottom-center `HotbarUI`, and retain modal `InventoryUI`. Update the hint to `WASD移动 · 左键使用 · 滚轮缩放 · Ctrl+滚轮切换 · Tab背包` and hide it after six seconds.

Bind:

```gdscript
stats_hud.bind(player.get_node("PlayerStats") as PlayerStats)
minimap.bind(world_layout.config, player)
minimap.register_marker(&"farmhouse", WorldPropDefinition.MarkerCategory.FARMHOUSE, world_layout.config.cell_to_world(Vector2i(12,43)))
minimap.register_marker(&"workshop", WorldPropDefinition.MarkerCategory.WORKSHOP, world_layout.config.cell_to_world(Vector2i(24,43)))
inventory_ui.opened_changed.connect(_on_inventory_opened_changed)
```

Modal callback:

```gdscript
player.set_gameplay_input_blocked(opened)
hotbar_ui.set_modal_dimmed(opened)
stats_hud.set_modal_dimmed(opened)
minimap.set_modal_dimmed(opened)
```

- [ ] **Step 6: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --import
timeout 20s godot --headless --path . --quit-after 8
git add scripts/ui/minimap.gd scenes/ui/minimap.tscn scenes/world/prototype_world.tscn scripts/world/prototype_world.gd tests/godot
git commit -m "feat: add minimap and expanded HUD composition"
```

---

### Task 8: Repository Validation, Documentation, and Final Gate

**Files:**
- Modify: `tools/validate_project.py`
- Modify: `tests/test_validate_project.py`
- Modify: `README.md`
- Modify: `.github/workflows/validate.yml` only when the existing steps do not already run every suite.

- [ ] **Step 1: Add failing repository contracts**

Create `WORLD_ENHANCEMENT_FILES` in `tools/validate_project.py` containing every new production file and scene. Add Python tests requiring the tuple and these exact tokens:

```text
WorldLayoutConfig: Vector2i(96, 64), Vector2i(32, 32)
CameraRig: MIN_ZOOM := 0.75, MAX_ZOOM := 1.50, ZOOM_STEP := 0.125
GameInputRouter: func _input, KEY_TAB, ctrl_pressed, change_zoom_steps
World scene: WorldCollisionRegistry, WorldLayout, PauseCoordinator, GameInputRouter, stats_hud.tscn, minimap.tscn
WorldPropFactory: instance_id and "%s:%d"
```

Run Python tests and confirm red before updating the validator.

- [ ] **Step 2: Update the validator and README**

README documents:

```text
96×64 logical world / 3072×2048 pixels
Tab inventory toggle
Escape closes inventory first
Mouse wheel camera zoom
Ctrl + mouse wheel quickbar cycle
1–5 direct quickbar selection
Upper-left health/stamina/mana HUD
Upper-right full-map minimap
Base-only collisions for houses, tree trunks, rocks, fences, and river segments
```

State that combat damage, enemy AI, harvesting, farming growth, and magic abilities remain inactive.

- [ ] **Step 3: Run the complete automated gate on the final tree**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
godot --headless --path . --import
timeout 60s godot --headless --path . --script res://tests/godot/test_runner.gd
timeout 20s godot --headless --path . --quit-after 8
```

Every command must exit `0`; any `SCRIPT ERROR`, missing resource, invalid node path, collision validation error, or timeout fails the phase.

- [ ] **Step 4: Run the graphical acceptance checklist**

Record each result in the PR description:

```text
[ ] Travel works between farmstead, meadow, whisperwood, and stonefield.
[ ] Normal paths do not expose a bare rectangular map edge.
[ ] Tab opens and closes inventory repeatedly.
[ ] Escape closes inventory first.
[ ] Direct wheel zoom is smooth and stays within 0.75–1.50.
[ ] Ctrl-wheel and 1–5 select quickbar slots.
[ ] Inventory-open wheel input does not zoom the world.
[ ] Health, stamina, and mana remain readable at 640×360.
[ ] Minimap shows roads, river, bridges, farm, regions, markers, and player position.
[ ] House walls, tree trunks, rocks, fences, and river segments are solid.
[ ] Tree canopies and roofs occlude correctly without becoming full-image collisions.
[ ] Farmhouse doorway and required routes remain passable.
[ ] Spawn and invalid-position recovery never place the player inside collision.
[ ] Existing inventory, hotbar, item requests, and crafting do not regress.
```

- [ ] **Step 5: Commit and open the phase PR**

```bash
git add tools tests README.md .github/workflows/validate.yml
git commit -m "test: validate world UI camera and collision enhancement"
git push -u origin feat/world-ui-camera-collision-enhancement
```

Open a PR against `main` titled `feat: expand world HUD camera and collisions`. The PR is ready only when all automated gates pass and the graphical checklist is recorded.