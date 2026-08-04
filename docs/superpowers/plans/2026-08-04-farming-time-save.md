# Farming, Time, and Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add continuous day/night time, menu pausing, till/plant/water/harvest actions, sleep-driven crop growth, and resilient save/load.

**Architecture:** `TimeManager` is an autoload that emits deterministic phase/day events. Farm cells own serialized crop state. `SaveManager` writes one versioned JSON snapshot atomically and keeps a backup before replacing a valid save.

**Tech Stack:** Godot 4.3+ / GDScript autoloads, JSON, `FileAccess`, `DirAccess`, CanvasModulate, existing action/inventory systems, headless tests.

## Global Constraints

- Time flows continuously while playing.
- Inventory, crafting, dialogue, and pause menus stop single-player world time.
- Night never forces unconsciousness.
- Sleeping explicitly advances to the next day and settles crops/resources.
- Moon-dew radish requires three watered-day settlements and never dies from missed watering.
- Worn watering can has unlimited water and waters one cell.
- Save on sleep, first completed planting, and return to title.
- Corrupt saves are backed up and never silently overwritten.
- Do not add seasons, weather, water capacity, multiple crops, economy, or complex calendar systems.

---

## File structure

**Create**

- `scripts/time/time_manager.gd`
- `scripts/time/day_cycle_visuals.gd`
- `scripts/farming/crop_definition.gd`
- `scripts/farming/farm_cell.gd`
- `scripts/farming/farm_grid.gd`
- `scripts/player/farming_action_router.gd`
- `data/crops/moon_dew_radish.tres`
- `scenes/world/farm_cell.tscn`
- `scripts/world/bed_interaction.gd`
- `scripts/save/save_manager.gd`
- `scripts/save/saveable_registry.gd`
- `tests/godot/suites/test_time_manager.gd`
- `tests/godot/suites/test_farm_cell.gd`
- `tests/godot/suites/test_save_manager.gd`

**Modify**

- `project.godot`
- `scenes/player/player.tscn`
- `scenes/world/prototype_world.tscn`
- `scripts/world/prototype_world.gd`
- `scripts/ui/inventory_ui.gd`
- `scripts/ui/player_status_ui.gd`
- `tests/godot/test_runner.gd`
- `.github/workflows/validate.yml`
- `tools/validate_project.py`

---

### Task 1: Add deterministic world time and menu pause ownership

**Files:**
- Create: `scripts/time/time_manager.gd`
- Test: `tests/godot/suites/test_time_manager.gd`
- Modify: `project.godot`
- Modify: `scripts/ui/inventory_ui.gd`

**Interfaces:**
- Produces: `advance_minutes`, `sleep_to_next_day`, `minute_changed`, `phase_changed`, `day_started`, `request_pause`, and `release_pause`.

- [ ] **Step 1: Write failing time tests**

Test: starts day 1 at 08:00; 60 real seconds at scale 10 advances 600 minutes only when unpaused; boundaries are day 06:00, dusk 18:00, night 21:00; sleep increments day and wakes at 06:30; pause reason reference counting prevents one menu from unpausing another.

- [ ] **Step 2: Implement `TimeManager`**

```gdscript
class_name HearthwildTimeManager
extends Node

signal minute_changed(day: int, minute_of_day: int)
signal phase_changed(phase: StringName)
signal day_started(day: int)

const MINUTES_PER_DAY := 1440
const WAKE_MINUTE := 390
@export var game_minutes_per_real_second := 10.0

var day := 1
var minute_of_day := 480
var _fractional_minutes := 0.0
var _pause_reasons: Dictionary = {}

func _process(delta: float) -> void:
    if not _pause_reasons.is_empty():
        return
    _fractional_minutes += delta * game_minutes_per_real_second
    var whole := int(floor(_fractional_minutes))
    if whole > 0:
        _fractional_minutes -= whole
        advance_minutes(whole)
```

`request_pause(reason)` increments a reason count; `release_pause(reason)` decrements/removes it. Set tree pause from whether the dictionary is empty and keep the autoload in `PROCESS_MODE_ALWAYS`. Register as `TimeManager`.

- [ ] **Step 3: Route menus through pause reasons**

Inventory uses `inventory`, workbench uses `crafting`, pause menu later uses `pause_menu`. Remove direct `get_tree().paused` writes from ordinary menu scripts.

- [ ] **Step 4: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/time project.godot scripts/ui tests/godot
git commit -m "feat: add deterministic world time and menu pausing"
```

---

### Task 2: Add day/night visual interpolation

**Files:**
- Create: `scripts/time/day_cycle_visuals.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Test: `tests/godot/suites/test_time_manager.gd`

**Interfaces:**
- Consumes: time signals.
- Produces: world tone, local-light energy, clock/day label.

- [ ] **Step 1: Write failing phase-color tests**

Expose `color_for_minute(minute)`. Assert key colors at 06:00, 12:00, 18:00, 21:00, midnight, and interpolation between keys.

- [ ] **Step 2: Implement keyframes**

```gdscript
const COLOR_KEYS := [
    {"minute": 0, "color": Color("25304a")},
    {"minute": 360, "color": Color("d5b38a")},
    {"minute": 720, "color": Color("f4f5dc")},
    {"minute": 1080, "color": Color("d58a68")},
    {"minute": 1260, "color": Color("526082")},
    {"minute": 1440, "color": Color("25304a")},
]
```

Use `Color.lerp`; night stays playable rather than black.

- [ ] **Step 3: Bind current nodes**

Drive `WorldTone.color`, `HouseLight.energy`, and a compact day/time label. Local pickup light remains local and is affected by world tone.

- [ ] **Step 4: Smoke and commit**

```bash
godot --headless --path . --quit-after 8
git add scripts/time/day_cycle_visuals.gd scenes/world tests/godot
git commit -m "feat: add continuous day night visuals"
```

---

### Task 3: Implement farm-cell and crop state

**Files:**
- Create: `scripts/farming/crop_definition.gd`
- Create: `scripts/farming/farm_cell.gd`
- Create: `scripts/farming/farm_grid.gd`
- Create: `data/crops/moon_dew_radish.tres`
- Create: `scenes/world/farm_cell.tscn`
- Test: `tests/godot/suites/test_farm_cell.gd`

**Interfaces:**
- Consumes: `ActionRequest`.
- Produces: `FarmCell.apply_action`, `settle_day`, `serialize_state`, `restore_state`.

- [ ] **Step 1: Write failing state-machine tests**

Test till; reject planting untilled; successful planting; watering; no growth when dry; maturity after three watered settlements; harvest returns produce and resets to tilled; missed watering never kills/reverses growth.

- [ ] **Step 2: Implement crop definition**

```gdscript
class_name CropDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_range(1, 30, 1) var watered_days_to_mature := 3
@export var seed_item_id: StringName
@export var harvest_item_id: StringName
@export_range(1, 99, 1) var harvest_quantity := 1
@export_range(0.0, 1.0, 0.01) var seed_return_chance := 0.25
@export var stage_colors: Array[Color]
```

- [ ] **Step 3: Implement `FarmCell`**

```gdscript
var tilled := false
var crop_id: StringName = &""
var watered_today := false
var watered_growth_days := 0
```

Supported action ids: `till`, `plant`, `water`, `harvest`. `settle_day(rng)` increments only when planted and watered, then clears the watered flag.

- [ ] **Step 4: Build a fixed tutorial grid**

Create a 4×3 grid near the farmhouse. Stable ids are `farm_x_y`. Use clear procedural pixel dirt/water overlays and four crop-stage visuals isolated from logic.

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/farming data/crops scenes/world/farm_cell.tscn tests/godot
git commit -m "feat: add farm cells and moon dew crop growth"
```

---

### Task 4: Route hoe, seed, watering, and harvest actions

**Files:**
- Create: `scripts/player/farming_action_router.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/item_user.gd`
- Modify: `scripts/farming/farm_grid.gd`
- Test: `tests/godot/suites/test_farm_cell.gd`

**Interfaces:**
- Consumes: selected item and `FarmCell`.
- Produces: left-click farming behavior and safe inventory transactions.

- [ ] **Step 1: Write failing inventory-coupled tests**

Planting removes one seed only after acceptance; rejection leaves seed untouched; harvest adds produce and reports overflow as a pickup request.

- [ ] **Step 2: Implement action mapping**

- wooden hoe → `till`
- worn watering can → `water`
- moon-dew seed → `plant`
- empty hand on mature crop → `harvest`

Select nearest cell within 48 pixels and a 75° forward cone.

- [ ] **Step 3: Make transactions rollback-safe**

For planting, preflight seed, preview cell, remove seed, commit transition. For harvest, resolve cell, add accepted output, spawn remainder as pickup.

- [ ] **Step 4: Wire and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/player scripts/farming scenes/player tests/godot
git commit -m "feat: route selected items into farming actions"
```

---

### Task 5: Add bed interaction and ordered day settlement

**Files:**
- Create: `scripts/world/bed_interaction.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `scripts/world/resource_spawn_manager.gd`
- Test: `tests/godot/suites/test_time_manager.gd`
- Test: `tests/godot/suites/test_farm_cell.gd`

**Interfaces:**
- Consumes: player interaction, farm grid, spawn manager.
- Produces: one ordered sleep transaction.

- [ ] **Step 1: Write a failing settlement-order test**

Assert order: settle farm → advance day → refresh resources → request save.

- [ ] **Step 2: Implement bed confirmation and sleep**

```gdscript
func sleep() -> void:
    TimeManager.request_pause(&"sleep_transition")
    await _fade_to_black()
    farm_grid.settle_day()
    TimeManager.sleep_to_next_day()
    resource_spawn_manager.refresh_for_day(TimeManager.day, player_inventory)
    if Engine.has_singleton("SaveManager") or has_node("/root/SaveManager"):
        SaveManager.save_game(&"sleep")
    await _fade_from_black()
    TimeManager.release_pause(&"sleep_transition")
```

`E` near bed opens confirmation. At 02:00 the player remains active; only bed ends the day.

- [ ] **Step 3: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world/bed_interaction.gd scenes/world scripts/world tests/godot
git commit -m "feat: add ordered sleep and day settlement"
```

---

### Task 6: Add versioned atomic save/load with backup recovery

**Files:**
- Create: `scripts/save/saveable_registry.gd`
- Create: `scripts/save/save_manager.gd`
- Modify: `project.godot`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `scripts/inventory/inventory_model.gd`
- Modify: `scripts/player/player_controller.gd`
- Test: `tests/godot/suites/test_save_manager.gd`

**Interfaces:**
- Consumes: inventory, player, time, farm, resource, and later tutorial providers.
- Produces: `save_game`, `load_game`, `has_valid_save`, and `delete_save`.

- [ ] **Step 1: Write failing save tests**

Use an injected temporary path. Test round trip, schema version, validated temp-before-rename, previous save becoming `.bak`, corrupt main copied to `.corrupt-<timestamp>` with backup recovery, missing save returning empty data, and future schema rejection.

- [ ] **Step 2: Implement provider registry**

```gdscript
SaveableRegistry.register_provider(&"inventory", inventory)
SaveableRegistry.register_provider(&"player", player_controller)
SaveableRegistry.register_provider(&"time", TimeManager)
SaveableRegistry.register_provider(&"farm", farm_grid)
SaveableRegistry.register_provider(&"resources", resource_spawn_manager)
```

Each provider implements `serialize_state() -> Variant` and `restore_state(data: Variant) -> void`.

- [ ] **Step 3: Implement atomic write**

```gdscript
const SAVE_PATH := "user://save_v1.json"
const TEMP_PATH := "user://save_v1.tmp"
const BACKUP_PATH := "user://save_v1.bak"
const SCHEMA_VERSION := 1
```

Write temp, reopen/parse, copy existing valid main to backup, then rename temp to main. Any failure leaves the previous main untouched.

- [ ] **Step 4: Implement load recovery**

Load main; on parse/version failure copy it to timestamped corrupt path and try backup. Unknown future schema returns a clear error and does not partially restore providers.

- [ ] **Step 5: Add save triggers**

Sleep, first successful planting, return to title. Do not save each pickup or minute.

- [ ] **Step 6: Run phase gate and commit**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add scripts/save scripts/time scripts/farming scripts/player scripts/world scenes project.godot tests tools
git commit -m "feat: add farming time and resilient saves"
```
