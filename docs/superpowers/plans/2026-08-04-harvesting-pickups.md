# Harvesting and Pickups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make empty-handed gathering, tool harvesting, world drops, auto-pickup, and anti-softlock resource spawning fully playable.

**Architecture:** `HarvestableComponent` validates tool requests and owns durability. A reusable loot table produces item stacks, while a pickup scene transfers stacks into the existing inventory without deleting overflow. World resource nodes register stable ids for later save/day-refresh systems.

**Tech Stack:** Godot 4.3+ / GDScript, existing inventory and action protocol, pure 2D physics/scenes, headless tests.

## Global Constraints

- Empty hands may gather only branches and loose stones at low efficiency.
- Stone axe harvests trees; stone pickaxe harvests ordinary rocks.
- Wrong tools and insufficient tool levels must not reduce durability.
- Full inventory leaves pickups in the world.
- Tutorial resource guarantees must prevent the player from becoming unable to craft first tools.
- Do not add copper, iron, rare ores, stumps, tool upgrades, or large procedural generation.

---

## File structure

**Create**

- `scripts/loot/loot_entry.gd`, `scripts/loot/loot_table.gd`
- `scripts/world/pickup.gd`, `scenes/world/pickup.tscn`
- `scripts/world/harvestable_component.gd`
- `scripts/world/resource_node.gd`
- `scenes/world/resources/tree_resource.tscn`
- `scenes/world/resources/loose_stone_resource.tscn`
- `scenes/world/resources/rock_resource.tscn`
- `scripts/player/tool_action_router.gd`
- `scripts/world/resource_spawn_manager.gd`
- `tests/godot/suites/test_loot_table.gd`
- `tests/godot/suites/test_harvestable_component.gd`
- `tests/godot/suites/test_pickup_transfer.gd`
- `tests/godot/suites/test_resource_spawn_manager.gd`

**Modify**

- `scenes/player/player.tscn`
- `scripts/player/item_user.gd`
- `scenes/world/prototype_world.tscn`
- `scripts/world/prototype_world.gd`
- `scripts/enemies/slime_enemy.gd`
- `tests/godot/test_runner.gd`
- `tools/validate_project.py`

---

### Task 1: Add deterministic loot tables and inventory-safe pickups

**Files:**
- Create: `scripts/loot/loot_entry.gd`
- Create: `scripts/loot/loot_table.gd`
- Create: `scripts/world/pickup.gd`
- Create: `scenes/world/pickup.tscn`
- Test: `tests/godot/suites/test_loot_table.gd`
- Test: `tests/godot/suites/test_pickup_transfer.gd`

**Interfaces:**
- Consumes: `InventoryModel.add_item`.
- Produces: `LootTable.roll(rng) -> Array[Dictionary]` and `Pickup.try_transfer(inventory) -> int`.

- [ ] **Step 1: Write failing loot tests**

Use a seeded RNG. Guaranteed entries must return exact ids/quantities; a zero-chance entry must never appear.

- [ ] **Step 2: Implement loot resources**

```gdscript
class_name LootEntry
extends Resource

@export var item_id: StringName
@export_range(1, 99, 1) var minimum := 1
@export_range(1, 99, 1) var maximum := 1
@export_range(0.0, 1.0, 0.01) var chance := 1.0
```

```gdscript
class_name LootTable
extends Resource

@export var entries: Array[LootEntry] = []

func roll(rng: RandomNumberGenerator) -> Array[Dictionary]:
    var drops: Array[Dictionary] = []
    for entry in entries:
        if rng.randf() <= entry.chance:
            drops.append({
                "item_id": entry.item_id,
                "quantity": rng.randi_range(entry.minimum, entry.maximum),
            })
    return drops
```

- [ ] **Step 3: Write failing pickup overflow tests**

Give an inventory room for two wood and a pickup containing five. Assert three remain. Fill the inventory and assert the pickup remains unchanged.

- [ ] **Step 4: Implement `Pickup`**

Scene nodes: `Area2D`, `CollisionShape2D`, `Sprite2D`, `Label`. After a 0.35-second bounce lock, attract inside 72 pixels. Transfer only the accepted amount and free only when quantity reaches zero.

```gdscript
func try_transfer(inventory: InventoryModel) -> int:
    quantity = inventory.add_item(item_id, quantity)
    if quantity == 0:
        queue_free()
    else:
        _refresh_label()
    return quantity
```

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/loot scripts/world/pickup.gd scenes/world/pickup.tscn tests/godot
git commit -m "feat: add deterministic loot and safe pickups"
```

---

### Task 2: Implement reusable harvest durability and tool validation

**Files:**
- Create: `scripts/world/harvestable_component.gd`
- Create: `scripts/player/tool_action_router.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/item_user.gd`
- Test: `tests/godot/suites/test_harvestable_component.gd`

**Interfaces:**
- Consumes: `ActionRequest` and `LootTable`.
- Produces: `HarvestableComponent.apply_harvest`.

- [ ] **Step 1: Write failing validation tests**

Cover correct tool, wrong tool, insufficient level, duplicate sequence, final-hit drops, unarmed tree branch taps, and unarmed loose-stone depletion.

- [ ] **Step 2: Implement `HarvestableComponent`**

```gdscript
class_name HarvestableComponent
extends Node

signal durability_changed(current: int, maximum: int)
signal depleted(drops: Array[Dictionary])

@export var accepted_tool: ItemDefinition.ToolType
@export_range(0, 10, 1) var required_level := 0
@export_range(1, 999, 1) var maximum_durability := 3
@export var allow_unarmed := false
@export var unarmed_item_id: StringName = &""
@export var unarmed_yield_every_hits := 3
@export var loot_table: LootTable

var durability := 3
var _unarmed_hits := 0
var _seen_sequences: Dictionary = {}
```

`apply_harvest` validates type and level before mutation. Unarmed tree hits grant one branch every third valid hit without depleting the tree; loose-stone nodes allow normal unarmed depletion.

- [ ] **Step 3: Implement `ToolActionRouter`**

For axe, pickaxe, and unarmed requests: gather candidates within item range, filter by a 75° forward cone, select nearest valid `HarvestableComponent`, call `apply_harvest`, emit `harvest_resolved`. Wrong target returns `wrong_target` without durability change.

- [ ] **Step 4: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world/harvestable_component.gd scripts/player/tool_action_router.gd scenes/player/player.tscn tests/godot
git commit -m "feat: add tool-gated harvesting"
```

---

### Task 3: Build tree, loose-stone, and rock resource scenes

**Files:**
- Create: `scripts/world/resource_node.gd`
- Create: `scenes/world/resources/tree_resource.tscn`
- Create: `scenes/world/resources/loose_stone_resource.tscn`
- Create: `scenes/world/resources/rock_resource.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Test: `tests/godot/suites/test_harvestable_component.gd`

**Interfaces:**
- Consumes: harvesting and pickup systems.
- Produces: stable `world_id`, serialized state, and `reset_for_new_day` hook.

- [ ] **Step 1: Add a failing state round-trip test**

Deplete a resource, serialize it, restore into a new instance, and assert active/depleted state and durability match.

- [ ] **Step 2: Implement `ResourceNode`**

```gdscript
class_name ResourceNode
extends StaticBody2D

signal state_changed(world_id: StringName)

@export var world_id: StringName
@export var refresh_chance := 0.5
@export var pickup_scene: PackedScene
var depleted := false

func serialize_state() -> Dictionary:
    return {"world_id": String(world_id), "depleted": depleted}

func restore_state(data: Dictionary) -> void:
    depleted = bool(data.get("depleted", false))
    visible = not depleted
    collision_layer = 0 if depleted else 1
```

On depletion, spawn one pickup per rolled stack, hide/disable the resource, and emit state change.

- [ ] **Step 3: Configure exact resource values**

- Tree: axe level 1, durability 5, wood 3–5 plus branch 1–2; unarmed branch every three hits.
- Loose stone: unarmed allowed, durability 1, loose stone 1–2.
- Rock: pickaxe level 1, durability 4, stone 2–4.

Use existing open-atlas regions where available. Keep nondesignated decorative props decorative.

- [ ] **Step 4: Add isolated hit feedback**

Tree shake/leaf particles. Rock crack state at 50% and stone particles. Feedback listens to durability signals and cannot change outcomes.

- [ ] **Step 5: Import/smoke and commit**

```bash
godot --headless --path . --import
godot --headless --path . --quit-after 8
git add scripts/world/resource_node.gd scenes/world/resources scripts/world/prototype_world.gd tests/godot
git commit -m "feat: add harvestable world resource scenes"
```

---

### Task 4: Add ground resource spawning and anti-softlock guarantees

**Files:**
- Create: `scripts/world/resource_spawn_manager.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Test: `tests/godot/suites/test_resource_spawn_manager.gd`

**Interfaces:**
- Consumes: inventory counts and resource scenes.
- Produces: deterministic daily spawn lists and guaranteed starter resources.

- [ ] **Step 1: Write failing guarantee tests**

With empty inventory/no active loose resources, require at least six branches and five loose stones in tutorial zone. With stone axe and pickaxe present, no starter guarantee is needed.

- [ ] **Step 2: Implement seeded spawn planning**

```gdscript
class_name ResourceSpawnManager
extends Node

@export var tutorial_rect := Rect2(360, 240, 320, 260)
@export var branch_minimum_before_tools := 6
@export var loose_stone_minimum_before_tools := 5

func plan_daily_spawns(
    day: int,
    inventory: InventoryModel,
    active_counts: Dictionary
) -> Array[Dictionary]:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("hearthwild-day-%d" % day)
    return _build_plan(rng, inventory, active_counts)
```

Use fixed candidate positions so tests and saves remain stable.

- [ ] **Step 3: Instantiate stable nodes**

Create `ResourceSpawns` under `Entities`; ids follow `branch_ground_03`, `loose_stone_04`, `tree_07`, `rock_02`.

- [ ] **Step 4: Add daily refresh hook**

```gdscript
func refresh_for_day(day: int, inventory: InventoryModel) -> void:
```

The time phase calls it; until then world `_ready()` calls day 1 once.

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world/resource_spawn_manager.gd scenes/world scripts/world/prototype_world.gd tests/godot
git commit -m "feat: guarantee starter resource spawns"
```

---

### Task 5: Connect slime/resource drops and complete gathering progression

**Files:**
- Modify: `scripts/enemies/slime_enemy.gd`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `scripts/ui/inventory_ui.gd`
- Modify: `tools/validate_project.py`
- Test: `tests/godot/suites/test_pickup_transfer.gd`
- Test: `tests/test_validate_project.py`

**Interfaces:**
- Consumes: loot, pickups, inventory, combat death.
- Produces: all first-slice material pickups in normal play.

- [ ] **Step 1: Add slime loot tests**

Normal slime always produces at least one gel with seeded RNG. Tutorial slime produces exactly the one guaranteed gel required for the hoe path.

- [ ] **Step 2: Emit pickups on death**

Normal: gel 1–2 guaranteed, moon-dew seed chance 0.12. Tutorial: gel 1 guaranteed and no random seed dependency.

- [ ] **Step 3: Add wild grass clumps**

Use `HarvestableComponent`, unarmed action, durability 1, grass drop. They are ordinary refreshable resources.

- [ ] **Step 4: Verify the progression in editor**

Start empty → gather branches/loose stone → craft axe/pickaxe → harvest wood/stone → craft sword → defeat tutorial slime → confirm gel. Target under 12 active minutes before farming exists. Record measured time in PR body.

- [ ] **Step 5: Run phase gate and commit**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add scripts scenes tests tools
git commit -m "feat: complete harvesting and pickup loop"
```
