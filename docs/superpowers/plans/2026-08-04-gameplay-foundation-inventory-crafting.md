# Gameplay Foundation, Inventory, and Crafting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish stable gameplay data, action, inventory, quickbar, crafting, and headless-test foundations without changing the existing world loop.

**Architecture:** Resource-backed item and recipe definitions feed a pure inventory model. A small `ItemUser` component emits typed action requests, while UI scenes observe inventory signals. Headless Godot tests exercise gameplay models independently of the rendered world.

**Tech Stack:** Godot 4.3+ / GDScript Resources and Nodes, Python repository tests, GitHub Actions, Godot 4.6.3 headless runner.

## Global Constraints

- Preserve the current pure 2D world, 640×360 viewport, and existing open-art loading.
- Inventory capacity is exactly 20; slots 0–4 are the quickbar.
- Tools and key items occupy one slot; stackable materials use each item’s `max_stack`.
- Left click uses the selected quickbar item; no combat or harvesting effect is implemented in this phase.
- Do not add third-party plugins.
- All model behavior must run in headless Godot without loading the main scene.

---

## File structure

**Create**

- `scripts/actions/action_request.gd`, `scripts/actions/action_result.gd`
- `scripts/items/item_definition.gd`, `scripts/items/item_catalog.gd`
- `scripts/inventory/inventory_slot.gd`, `scripts/inventory/inventory_model.gd`
- `scripts/crafting/recipe_definition.gd`, `scripts/crafting/crafting_result.gd`, `scripts/crafting/crafting_service.gd`
- `scripts/player/item_user.gd`
- `scripts/ui/hotbar_ui.gd`, `scenes/ui/hotbar_ui.tscn`
- `scripts/ui/inventory_ui.gd`, `scenes/ui/inventory_ui.tscn`
- `data/items/*.tres`, `data/recipes/*.tres`, `assets/original/items/*.svg`
- `tests/godot/test_runner.gd`, `tests/godot/test_assert.gd`
- `tests/godot/suites/test_action_protocol.gd`
- `tests/godot/suites/test_inventory_model.gd`
- `tests/godot/suites/test_crafting_service.gd`

**Modify**

- `project.godot`
- `scenes/player/player.tscn`
- `scenes/world/prototype_world.tscn`
- `scripts/player/player_controller.gd`
- `scripts/world/prototype_world.gd`
- `.github/workflows/validate.yml`
- `tools/validate_project.py`, `tests/test_validate_project.py`

---

### Task 1: Add the headless Godot gameplay-test harness

**Files:**
- Create: `tests/godot/test_assert.gd`
- Create: `tests/godot/test_runner.gd`
- Create: `tests/godot/suites/test_action_protocol.gd`
- Modify: `.github/workflows/validate.yml`
- Modify: `tools/validate_project.py`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Consumes: official Godot binary already installed by CI.
- Produces: each suite exposes `static func run() -> Array[String]`; runner exits `0` on no failures and `1` otherwise.

- [ ] **Step 1: Write the failing repository-contract test**

```python
def test_ci_runs_headless_gameplay_tests(self) -> None:
    root = Path(__file__).resolve().parents[1]
    workflow = (root / ".github/workflows/validate.yml").read_text(encoding="utf-8")
    self.assertIn("--script res://tests/godot/test_runner.gd", workflow)
    self.assertTrue((root / "tests/godot/test_runner.gd").is_file())
```

- [ ] **Step 2: Run the test and verify the expected failure**

```bash
python -m unittest tests.test_validate_project.ProjectValidatorTests.test_ci_runs_headless_gameplay_tests -v
```

Expected: FAIL because the runner does not exist and the workflow lacks the command.

- [ ] **Step 3: Implement assertions and the runner**

```gdscript
class_name TestAssert
extends RefCounted

static func equal(actual: Variant, expected: Variant, label: String) -> String:
    if actual == expected:
        return ""
    return "%s: expected %s, got %s" % [label, expected, actual]

static func truthy(value: bool, label: String) -> String:
    return "" if value else "%s: expected true" % label
```

```gdscript
extends SceneTree

const SUITES := [
    preload("res://tests/godot/suites/test_action_protocol.gd"),
]

func _init() -> void:
    var failures: Array[String] = []
    for suite in SUITES:
        failures.append_array(suite.run())
    for failure in failures:
        push_error(failure)
    quit(0 if failures.is_empty() else 1)
```

Add after Godot import:

```yaml
      - name: Run headless gameplay tests
        run: ./Godot_v4.6.3-stable_linux.x86_64 --headless --path . --script res://tests/godot/test_runner.gd
```

Add `tests/godot/test_runner.gd` to `REQUIRED_FILES`.

- [ ] **Step 4: Run all validation**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
./Godot_v4.6.3-stable_linux.x86_64 --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: all commands exit `0`.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/validate.yml tools/validate_project.py tests
git commit -m "test: add headless gameplay test harness"
```

---

### Task 2: Define the action protocol and item resources

**Files:**
- Create: `scripts/actions/action_request.gd`
- Create: `scripts/actions/action_result.gd`
- Create: `scripts/items/item_definition.gd`
- Create: `scripts/items/item_catalog.gd`
- Create: `data/items/*.tres`
- Create: `assets/original/items/*.svg`
- Modify: `project.godot`
- Test: `tests/godot/suites/test_action_protocol.gd`

**Interfaces:**
- Consumes: `TestAssert`.
- Produces: `ActionRequest`, `ActionResult`, `ItemDefinition`, and autoload `ItemCatalog`.

- [ ] **Step 1: Write failing action-protocol tests**

```gdscript
extends RefCounted

static func run() -> Array[String]:
    var failures: Array[String] = []
    var actor := Node2D.new()
    var request := ActionRequest.new_request(
        actor, &"use_item", Vector2(10, 20), Vector2.RIGHT, 7
    )
    failures.append(TestAssert.equal(request.sequence_id, 7, "request sequence"))
    failures.append(TestAssert.equal(request.direction, Vector2.RIGHT, "request direction"))
    var result := ActionResult.failure(&"no_target")
    failures.append(TestAssert.truthy(not result.ok, "failure result"))
    failures.append(TestAssert.equal(result.reason, &"no_target", "failure reason"))
    actor.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

- [ ] **Step 2: Run and verify parse failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: `ActionRequest` and `ActionResult` are undefined.

- [ ] **Step 3: Implement the protocol**

```gdscript
class_name ActionRequest
extends RefCounted

var actor: Node2D
var action_id: StringName
var origin: Vector2
var direction: Vector2
var sequence_id: int
var item_id: StringName = &""
var damage := 0
var range := 0.0
var arc_degrees := 0.0
var tool_type := 0
var tool_level := 0
var strength := 0

static func new_request(
    source: Node2D,
    requested_action: StringName,
    world_origin: Vector2,
    aim_direction: Vector2,
    requested_sequence: int
) -> ActionRequest:
    var request := ActionRequest.new()
    request.actor = source
    request.action_id = requested_action
    request.origin = world_origin
    request.direction = aim_direction.normalized() if not aim_direction.is_zero_approx() else Vector2.DOWN
    request.sequence_id = requested_sequence
    return request
```

```gdscript
class_name ActionResult
extends RefCounted

var ok := false
var reason: StringName = &""
var targets: Array[Node] = []
var payload: Dictionary = {}

static func success(hit_targets: Array[Node], data: Dictionary = {}) -> ActionResult:
    var result := ActionResult.new()
    result.ok = true
    result.targets = hit_targets
    result.payload = data
    return result

static func failure(failure_reason: StringName) -> ActionResult:
    var result := ActionResult.new()
    result.reason = failure_reason
    return result
```

- [ ] **Step 4: Implement item definitions and catalog**

```gdscript
class_name ItemDefinition
extends Resource

enum ItemType { MATERIAL, WEAPON, TOOL, SEED, FOOD, KEY_ITEM }
enum ToolType { NONE, AXE, PICKAXE, HOE, WATERING_CAN }

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MATERIAL
@export_range(1, 999, 1) var max_stack := 99
@export_range(0.0, 5.0, 0.05) var use_cooldown := 0.25
@export var tool_type: ToolType = ToolType.NONE
@export_range(0, 10, 1) var tool_level := 0
@export_range(0, 100, 1) var base_damage := 0
@export_range(0, 100, 1) var heal_amount := 0
@export_range(0.0, 3.0, 0.05) var consume_duration := 0.55
@export_range(0.0, 128.0, 1.0) var use_range := 48.0
@export_range(0.0, 180.0, 1.0) var arc_degrees := 0.0
@export var key_item := false
```

`ItemCatalog` preloads all `.tres` definitions and exposes:

```gdscript
func get_item(item_id: StringName) -> ItemDefinition:
    return _items.get(item_id) as ItemDefinition

func has_item(item_id: StringName) -> bool:
    return _items.has(item_id)
```

Register `ItemCatalog="*res://scripts/items/item_catalog.gd"`. Use exact ids: `branch`, `loose_stone`, `wood`, `stone`, `grass`, `slime_gel`, `stone_axe`, `stone_pickaxe`, `wooden_sword`, `wooden_hoe`, `worn_watering_can`, `moon_dew_seed`, `moon_dew_radish`, `torch`, `simple_bandage`.

- [ ] **Step 5: Run import/tests and commit**

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
git add project.godot scripts/actions scripts/items data/items assets/original/items tests/godot
git commit -m "feat: define gameplay actions and item catalog"
```

---

### Task 3: Implement the 20-slot inventory model

**Files:**
- Create: `scripts/inventory/inventory_slot.gd`
- Create: `scripts/inventory/inventory_model.gd`
- Test: `tests/godot/suites/test_inventory_model.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `ItemCatalog.get_item`.
- Produces: `add_item`, `remove_item`, `count_item`, `set_selected_slot`, `selected_stack`, `serialize`, and `deserialize`.

- [ ] **Step 1: Write failing inventory tests**

Test exactly 20 slots, five quickbar slots, stack splitting, preflight-safe removal, full-inventory remainder, valid selection, and ignored invalid selection.

```gdscript
var inventory := InventoryModel.new()
failures.append(TestAssert.equal(inventory.slots.size(), 20, "slot count"))
failures.append(TestAssert.equal(inventory.quickbar_size, 5, "quickbar size"))
var remainder := inventory.add_item(&"branch", 120)
failures.append(TestAssert.equal(remainder, 0, "branch remainder"))
failures.append(TestAssert.equal(inventory.count_item(&"branch"), 120, "branch count"))
failures.append(TestAssert.truthy(inventory.remove_item(&"branch", 20), "remove available"))
failures.append(TestAssert.equal(inventory.count_item(&"branch"), 100, "count after remove"))
```

- [ ] **Step 2: Run and verify parse failure**

- [ ] **Step 3: Implement `InventorySlot`**

```gdscript
class_name InventorySlot
extends Resource

@export var item_id: StringName = &""
@export_range(0, 999, 1) var quantity := 0

func is_empty() -> bool:
    return item_id.is_empty() or quantity <= 0

func clear() -> void:
    item_id = &""
    quantity = 0
```

- [ ] **Step 4: Implement `InventoryModel`**

```gdscript
class_name InventoryModel
extends Node

signal changed
signal selected_changed(index: int)

const CAPACITY := 20
const QUICKBAR_SIZE := 5
var slots: Array[InventorySlot] = []
var selected_index := 0
var quickbar_size := QUICKBAR_SIZE

func _init() -> void:
    for _index in CAPACITY:
        slots.append(InventorySlot.new())

func add_item(item_id: StringName, quantity: int) -> int:
    var definition := ItemCatalog.get_item(item_id)
    if definition == null or quantity <= 0:
        return quantity
    var remaining := quantity
    if definition.max_stack > 1:
        for slot in slots:
            if slot.item_id == item_id and slot.quantity < definition.max_stack:
                var moved := mini(remaining, definition.max_stack - slot.quantity)
                slot.quantity += moved
                remaining -= moved
                if remaining == 0:
                    changed.emit()
                    return 0
    for slot in slots:
        if slot.is_empty():
            slot.item_id = item_id
            slot.quantity = mini(remaining, definition.max_stack)
            remaining -= slot.quantity
            if remaining == 0:
                changed.emit()
                return 0
    changed.emit()
    return remaining
```

`remove_item` counts first and performs no mutation if the quantity is unavailable. `serialize` returns 20 dictionaries plus `selected_index`; `deserialize` validates every item id through `ItemCatalog`.

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/inventory tests/godot
git commit -m "feat: add stack-safe inventory model"
```

---

### Task 4: Implement atomic crafting

**Files:**
- Create: `scripts/crafting/recipe_definition.gd`
- Create: `scripts/crafting/crafting_result.gd`
- Create: `scripts/crafting/crafting_service.gd`
- Create: `data/recipes/*.tres`
- Test: `tests/godot/suites/test_crafting_service.gd`

**Interfaces:**
- Consumes: `InventoryModel` and `ItemCatalog`.
- Produces: `CraftingService.craft`.

- [ ] **Step 1: Write failing transaction tests**

Test success, missing materials with no mutation, full inventory with no mutation, and key output becoming `output_pending` rather than disappearing.

- [ ] **Step 2: Implement resources**

```gdscript
class_name RecipeDefinition
extends Resource

enum Station { PORTABLE, WORKBENCH }
@export var id: StringName
@export var display_name: String
@export var station: Station = Station.PORTABLE
@export var ingredients: Dictionary = {}
@export var output_item_id: StringName
@export_range(1, 99, 1) var output_quantity := 1
@export var key_recipe := false
```

```gdscript
class_name CraftingResult
extends RefCounted
var ok := false
var reason: StringName = &""
var output_pending := false
```

- [ ] **Step 3: Implement preflight-first crafting**

```gdscript
static func craft(recipe: RecipeDefinition, inventory: InventoryModel) -> CraftingResult:
    for item_id in recipe.ingredients:
        if inventory.count_item(item_id) < int(recipe.ingredients[item_id]):
            return _failure(&"missing_materials")
    var simulated := InventoryModel.new()
    simulated.deserialize(inventory.serialize())
    var remainder := simulated.add_item(recipe.output_item_id, recipe.output_quantity)
    if remainder > 0 and not recipe.key_recipe:
        return _failure(&"inventory_full")
    for item_id in recipe.ingredients:
        assert(inventory.remove_item(item_id, int(recipe.ingredients[item_id])))
    var real_remainder := inventory.add_item(recipe.output_item_id, recipe.output_quantity)
    var result := CraftingResult.new()
    result.ok = true
    result.output_pending = real_remainder > 0
    return result
```

- [ ] **Step 4: Create exact recipes**

Portable: stone axe (`branch×3`, `loose_stone×2`), stone pickaxe (`branch×3`, `loose_stone×3`), wooden sword (`wood×4`, `loose_stone×1`), torch (`wood×1`, `slime_gel×1`). Workbench: wooden hoe (`wood×5`, `stone×2`, `slime_gel×1`) and simple bandage (`grass×3`, `slime_gel×1`).

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/crafting data/recipes tests/godot
git commit -m "feat: add atomic crafting transactions"
```

---

### Task 5: Wire player inventory, quickbar input, and item requests

**Files:**
- Create: `scripts/player/item_user.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/player_controller.gd`
- Modify: `project.godot`
- Test: `tests/godot/suites/test_action_protocol.gd`

**Interfaces:**
- Consumes: inventory and item data.
- Produces: `ItemUser.action_requested(request)`.

- [ ] **Step 1: Add a failing emitted-request test**

Add a wooden sword to selected slot, call `request_use(Vector2.RIGHT)`, and assert item id, direction, range, damage, and nonzero sequence.

- [ ] **Step 2: Implement `ItemUser`**

```gdscript
class_name ItemUser
extends Node

signal action_requested(request: ActionRequest)
@export var inventory_path: NodePath
var _sequence_id := 0
var _cooldown_remaining := 0.0
@onready var inventory: InventoryModel = get_node(inventory_path)

func _process(delta: float) -> void:
    _cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)

func request_use(direction: Vector2) -> void:
    if _cooldown_remaining > 0.0:
        return
    var slot := inventory.selected_stack()
    _sequence_id += 1
    var request := ActionRequest.new_request(
        get_parent() as Node2D,
        &"use_item",
        (get_parent() as Node2D).global_position,
        direction,
        _sequence_id
    )
    if slot.is_empty():
        request.item_id = &"unarmed"
        request.range = 32.0
        _cooldown_remaining = 0.35
    else:
        request.item_id = slot.item_id
        var item := ItemCatalog.get_item(slot.item_id)
        request.range = item.use_range
        request.arc_degrees = item.arc_degrees
        request.tool_type = item.tool_type
        request.tool_level = item.tool_level
        request.damage = item.base_damage
        _cooldown_remaining = item.use_cooldown
    action_requested.emit(request)
```

- [ ] **Step 3: Add player nodes and inputs**

Add `Inventory` and `ItemUser` children. Add `inventory` and `quick_slot_1` through `quick_slot_5`. Handle wheel selection in `_unhandled_input`.

```gdscript
func aim_direction() -> Vector2:
    var direction := global_position.direction_to(get_global_mouse_position())
    return direction if not direction.is_zero_approx() else Vector2.DOWN
```

- [ ] **Step 4: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add project.godot scenes/player scripts/player tests/godot
git commit -m "feat: wire inventory selection and item use"
```

---

### Task 6: Add quickbar and inventory/crafting UI

**Files:**
- Create: `scripts/ui/hotbar_ui.gd`, `scenes/ui/hotbar_ui.tscn`
- Create: `scripts/ui/inventory_ui.gd`, `scenes/ui/inventory_ui.tscn`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Consumes: inventory signals and portable recipes.
- Produces: visible five-slot hotbar and 20-slot Tab inventory; `opened_changed(opened)`.

- [ ] **Step 1: Add failing UI contract assertions**

Require both scenes/scripts through the Python test and validator, then run to confirm failure.

- [ ] **Step 2: Build `HotbarUI`**

Use an `HBoxContainer` with exactly five slot panels. `bind(model)` connects `changed` and `selected_changed`, then updates icon, quantity, and selected border directly from `model.slots[index]`.

- [ ] **Step 3: Build `InventoryUI`**

Use a 5×4 `GridContainer`, portable recipe list, detail panel, craft button, and close button. In this phase opening pauses the tree and the UI processes while paused; the time-system phase replaces direct pause ownership with `TimeManager` reasons.

- [ ] **Step 4: Bind to the world**

```gdscript
var player_inventory: InventoryModel = $Entities/Player/Inventory
$HUD/HotbarUI.bind(player_inventory)
$HUD/InventoryUI.bind(player_inventory)
```

Center the hotbar at the bottom and inventory panel in the 640×360 viewport.

- [ ] **Step 5: Run the phase gate**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
```

- [ ] **Step 6: Commit and open the phase PR**

```bash
git add scenes/ui scripts/ui scenes/world scripts/world tests tools
git commit -m "feat: add quickbar inventory and portable crafting UI"
```

PR acceptance: inventory, quickbar, crafting models, and UI are complete; item use emits requests but does not yet apply combat, harvesting, or farming effects.
