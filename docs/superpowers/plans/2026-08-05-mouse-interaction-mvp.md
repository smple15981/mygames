# Mouse Interaction Harvesting MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保留现有 WASD、大地图、相机、小地图、三状态栏、快捷栏、背包和随身制作的基础上，完成“拾取枝条/碎石 → 制作石斧/石镐 → 鼠标点击资源 → A* 自动靠近 → 持续采集 → 掉落并自动拾取”的最小可玩闭环，并修复残余穿模与遮挡问题。

**Architecture:** 使用 `WorldCollisionRegistry` 作为世界实体占用的唯一来源，新增 `WorldPathGrid` 将占用矩形映射到 32×32 A* 网格。玩家侧由 `AutoMoveAgent` 提供自动移动方向，`MouseInteractionController` 负责悬停、点击和取消，`HarvestableResource` 与 `WorldPickup` 分别负责采集和掉落；所有实体继续由现有 `WorldPropFactory` 与 `PrototypeWorld` 组合。

**Tech Stack:** Godot 4.6.3、GDScript、`AStarGrid2D`、`CharacterBody2D.move_and_slide()`、现有 `InventoryModel`/`CraftingService`、Python `unittest`、Godot 自制无头测试运行器、GitHub Actions。

## Global Constraints

- 操控固定为 WASD 手动移动 + 鼠标世界交互，不实现点击地面移动。
- 背包或暂停模态状态优先于全部世界输入；无模态状态时 WASD 立即取消自动靠近和持续采集。
- 枝条和碎石靠近后自动吸附拾取；背包满时地面物不删除。
- 点击资源一次后持续采集到耗尽；点击新目标、WASD、背包、暂停、目标失效或路径失败均取消。
- 树木必须使用石斧，岩石必须使用石镐；本阶段不允许徒手采集。
- 石斧配方保持 `branch ×3 + loose_stone ×2`；石镐保持 `branch ×3 + loose_stone ×3`。
- 出生区固定提供枝条 ×8、碎石 ×7、可采集小树 ×3、可采集岩石 ×3。
- 不实现工具耐久、复杂战斗、敌人 AI、多人、昼夜、完整种植、任务和剧情。
- 不回退现有 96×64 世界、小地图、状态栏、镜头缩放、Tab 背包、Ctrl+滚轮快捷栏、数字键 1–5。
- 世界物理层为 1，玩家层为 2，交互目标层为 4，拾取触发层为 8。
- 所有可 Y 排序实体的根节点必须位于脚底/接地底部中心，视觉只向上偏移。
- 旧计划 `docs/superpowers/plans/2026-08-04-harvesting-pickups.md` 不作为本轮实现依据；与本计划冲突时以本计划和 2026-08-05 设计规格为准。

---

## File Structure

### Create

- `scripts/world/world_path_grid.gd` — 32×32 A* 网格、占用同步、目标周边终点选择。
- `scripts/world/interaction_target.gd` — 可悬停/点击目标的统一 Area2D 接口。
- `scripts/world/harvestable_resource.gd` — 工具校验、采集生命值、耗尽与碰撞注销。
- `scripts/world/world_pickup.gd` — 吸附、背包转移和溢出保留。
- `scripts/world/world_pickup_factory.gd` — 生成枝条、碎石、木材和石头地面实体。
- `scripts/world/world_interaction_manager.gd` — 目标查询、采集循环、掉落生成、反馈消息。
- `scripts/player/auto_move_agent.gd` — 路径跟随、抵达、重规划和取消。
- `scripts/player/mouse_interaction_controller.gd` — 鼠标悬停、左键指令、WASD/模态取消。
- `scripts/input/cursor_state_manager.gd` — 状态型自定义鼠标光标。
- `scripts/ui/action_feedback.gd` — “需要石斧”“无法到达”“背包已满”短提示。
- `assets/original/ui/cursors/default.svg`
- `assets/original/ui/cursors/axe.svg`
- `assets/original/ui/cursors/pickaxe.svg`
- `assets/original/ui/cursors/pickup.svg`
- `assets/original/ui/cursors/interact.svg`
- `assets/original/ui/cursors/unreachable.svg`
- `assets/original/ui/cursors/tool_locked.svg`
- `assets/original/ui/interaction_outline.gdshader`
- `tests/godot/suites/test_world_path_grid.gd`
- `tests/godot/suites/test_interaction_target.gd`
- `tests/godot/suites/test_harvestable_resource.gd`
- `tests/godot/suites/test_world_pickup.gd`
- `tests/godot/suites/test_auto_move_agent.gd`
- `tests/godot/suites/test_mouse_interaction.gd`
- `tests/godot/suites/test_playable_loop.gd`

### Modify

- `scripts/world/world_collision_registry.gd`
- `scripts/world/world_prop_definition.gd`
- `scripts/world/world_prop_factory.gd`
- `scripts/world/world_layout.gd`
- `scripts/world/prototype_world.gd`
- `scripts/player/player_controller.gd`
- `scripts/input/game_input_router.gd`
- `scripts/ui/inventory_ui.gd`
- `scenes/player/player.tscn`
- `scenes/world/prototype_world.tscn`
- `data/world/props/tree_small.tres`
- `data/world/props/tree_cluster.tres`
- `data/world/props/rock_cluster.tres`
- `data/world/props/farmhouse.tres`
- `data/world/props/workshop.tres`
- `data/world/props/fence_horizontal.tres`
- `tests/godot/suites/test_world_collisions.gd`
- `tests/godot/suites/test_world_integration.gd`
- `tests/godot/suites/test_game_input_router.gd`
- `tests/godot/test_runner.gd`
- `tests/godot/capture_world.gd`
- `tests/test_validate_project.py`
- `tools/validate_project.py`
- `README.md`

---

## Execution Setup

实施时先使用 `superpowers:using-git-worktrees`。从 `design/mouse-interaction-mvp` 最新提交创建隔离分支：

```bash
git fetch origin
git worktree add .worktrees/mouse-interaction-mvp -b feat/mouse-interaction-mvp origin/design/mouse-interaction-mvp
cd .worktrees/mouse-interaction-mvp
python -m unittest discover -s tests -v
python tools/validate_project.py .
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
```

预期：基线 Python、验证器、Godot 导入和 11 个现有 Godot suite 全部通过后才开始 Task 1。

---

### Task 1: Make collision footprints observable and removable

**Files:**
- Modify: `scripts/world/world_collision_registry.gd`
- Modify: `tests/godot/suites/test_world_collisions.gd`

**Interfaces:**
- Consumes: existing `register_rect(id, rect)`, `unregister(id)`, `footprints()`.
- Produces: `signal footprint_registered(id: StringName, rect: Rect2)`, `signal footprint_unregistered(id: StringName, rect: Rect2)`, `signal footprints_cleared`, `footprint(id) -> Rect2`, `unregister_many(ids: Array[StringName]) -> void`.

- [ ] **Step 1: Write failing registry event tests**

Append to `test_world_collisions.gd`:

```gdscript
var events: Array[String] = []
registry.footprint_registered.connect(func(id: StringName, _rect: Rect2): events.append("add:%s" % id))
registry.footprint_unregistered.connect(func(id: StringName, _rect: Rect2): events.append("remove:%s" % id))
failures.append(TestAssert.truthy(
    registry.register_rect(&"dynamic_tree:0", Rect2(240, 240, 20, 12)),
    "dynamic footprint registers"
))
failures.append(TestAssert.equal(
    registry.footprint(&"dynamic_tree:0"),
    Rect2(240, 240, 20, 12),
    "footprint query"
))
registry.unregister_many([&"dynamic_tree:0"])
failures.append(TestAssert.equal(events, ["add:dynamic_tree:0", "remove:dynamic_tree:0"], "registry events"))
```

- [ ] **Step 2: Run the suite and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: parse failure or assertion failure because signals, `footprint()` and `unregister_many()` do not exist.

- [ ] **Step 3: Implement observable registry mutations**

Add at the top of `world_collision_registry.gd`:

```gdscript
signal footprint_registered(id: StringName, rect: Rect2)
signal footprint_unregistered(id: StringName, rect: Rect2)
signal footprints_cleared
```

Use these implementations:

```gdscript
func register_rect(id: StringName, rect: Rect2) -> bool:
    if id.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0 or _footprints.has(id):
        return false
    _footprints[id] = rect
    footprint_registered.emit(id, rect)
    return true

func footprint(id: StringName) -> Rect2:
    return _footprints.get(id, Rect2()) as Rect2

func unregister(id: StringName) -> void:
    if not _footprints.has(id):
        return
    var rect := _footprints[id] as Rect2
    _footprints.erase(id)
    footprint_unregistered.emit(id, rect)

func unregister_many(ids: Array[StringName]) -> void:
    for id in ids:
        unregister(id)

func clear() -> void:
    if _footprints.is_empty():
        return
    _footprints.clear()
    footprints_cleared.emit()
```

- [ ] **Step 4: Run tests**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: all suites pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/world_collision_registry.gd tests/godot/suites/test_world_collisions.gd
git commit -m "feat: expose dynamic world footprints"
```

---

### Task 2: Build the 32×32 A* world path grid

**Files:**
- Create: `scripts/world/world_path_grid.gd`
- Create: `tests/godot/suites/test_world_path_grid.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `WorldLayoutConfig`, `WorldCollisionRegistry.footprints()` and footprint signals.
- Produces: `configure(config, registry)`, `world_to_cell(position)`, `cell_to_world(cell)`, `is_cell_walkable(cell)`, `find_path(start_world, target_rect, interaction_range) -> PackedVector2Array`.

- [ ] **Step 1: Write failing path tests**

Create `test_world_path_grid.gd`:

```gdscript
extends RefCounted

static func run() -> Array[String]:
    var failures: Array[String] = []
    var config := WorldLayoutConfig.new()
    config.map_size_cells = Vector2i(12, 8)
    config.display_cell_size = Vector2i(32, 32)
    config.river_x_range = Vector2i(99, 100)
    var registry := WorldCollisionRegistry.new()
    registry.configure_world(config.world_rect())
    registry.register_rect(&"wall", Rect2(128, 0, 32, 192))
    var grid := WorldPathGrid.new()
    grid.configure(config, registry)

    var path := grid.find_path(Vector2(80, 80), Rect2(224, 64, 24, 24), 36.0)
    failures.append(TestAssert.truthy(path.size() > 2, "path exists around blocker"))
    failures.append(TestAssert.truthy(
        path[path.size() - 1].distance_to(Rect2(224, 64, 24, 24).get_center()) <= 68.0,
        "path ends in interaction range"
    ))

    registry.register_rect(&"sealed", Rect2(192, 32, 96, 128))
    failures.append(TestAssert.equal(
        grid.find_path(Vector2(80, 80), Rect2(224, 64, 24, 24), 36.0).size(),
        0,
        "sealed target unreachable"
    ))

    registry.unregister(&"sealed")
    failures.append(TestAssert.truthy(
        grid.find_path(Vector2(80, 80), Rect2(224, 64, 24, 24), 36.0).size() > 0,
        "unregister reopens path"
    ))
    registry.free()
    grid.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
```

Register it in `test_runner.gd` after `test_world_collisions.gd`.

- [ ] **Step 2: Run and verify failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Expected: preload failure for `world_path_grid.gd` or missing `WorldPathGrid`.

- [ ] **Step 3: Implement path grid configuration and occupancy counts**

Create `world_path_grid.gd` with this public shape:

```gdscript
class_name WorldPathGrid
extends Node

const PLAYER_FOOTPRINT := Vector2(16, 12)

var config: WorldLayoutConfig
var registry: WorldCollisionRegistry
var astar := AStarGrid2D.new()
var _footprint_cells: Dictionary = {}
var _occupancy_counts: Dictionary = {}

func configure(layout_config: WorldLayoutConfig, collision_registry: WorldCollisionRegistry) -> void:
    config = layout_config
    registry = collision_registry
    astar.region = Rect2i(Vector2i.ZERO, config.map_size_cells)
    astar.cell_size = Vector2(config.display_cell_size)
    astar.offset = Vector2(config.display_cell_size) * 0.5
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    astar.update()
    _rebuild_occupancy()
    registry.footprint_registered.connect(_on_footprint_registered)
    registry.footprint_unregistered.connect(_on_footprint_unregistered)
    registry.footprints_cleared.connect(_rebuild_occupancy)
```

Implement `_cells_for_rect(rect)` by converting the expanded rect `rect.grow_individual(8, 6, 8, 6)` to clamped cell bounds. Maintain per-cell counts so removing one overlapping footprint never opens a cell still occupied by another footprint.

- [ ] **Step 4: Implement target-ring path selection**

Use this method contract:

```gdscript
func find_path(start_world: Vector2, target_rect: Rect2, interaction_range: float) -> PackedVector2Array:
    var start := world_to_cell(start_world)
    if not is_cell_walkable(start):
        return PackedVector2Array()
    var best := PackedVector2Array()
    var best_length := INF
    for candidate in _candidate_cells(target_rect, interaction_range):
        if not is_cell_walkable(candidate):
            continue
        var candidate_path := astar.get_point_path(start, candidate)
        if candidate_path.is_empty():
            continue
        var length := _path_length(candidate_path)
        if length < best_length:
            best = candidate_path
            best_length = length
    return best
```

`_candidate_cells()` must return cells whose center is outside the target rect and within `interaction_range + half cell diagonal` of the rect.

- [ ] **Step 5: Run tests and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world/world_path_grid.gd tests/godot/suites/test_world_path_grid.gd tests/godot/test_runner.gd
git commit -m "feat: add world A star path grid"
```

---

### Task 3: Add interaction targets and harvest metadata to world props

**Files:**
- Create: `scripts/world/interaction_target.gd`
- Create: `assets/original/ui/interaction_outline.gdshader`
- Create: `tests/godot/suites/test_interaction_target.gd`
- Modify: `scripts/world/world_prop_definition.gd`
- Modify: `scripts/world/world_prop_factory.gd`
- Modify: `data/world/props/tree_small.tres`
- Modify: `data/world/props/tree_cluster.tres`
- Modify: `data/world/props/rock_cluster.tres`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `ItemDefinition.ToolType`, prop collision rectangles, generated root/visual nodes.
- Produces: `InteractionTarget.kind`, `required_tool`, `interaction_range`, `world_target_rect()`, `set_highlighted(enabled, locked)`.

- [ ] **Step 1: Write failing definition and target tests**

Create `test_interaction_target.gd` covering:

```gdscript
var tree := load("res://data/world/props/tree_small.tres") as WorldPropDefinition
failures.append(TestAssert.equal(tree.interaction_kind, InteractionTarget.Kind.HARVEST_TREE, "tree kind"))
failures.append(TestAssert.equal(tree.required_tool, ItemDefinition.ToolType.AXE, "tree tool"))
failures.append(TestAssert.equal(tree.harvest_hits, 3, "tree hits"))
failures.append(TestAssert.equal(tree.drop_item_id, &"wood", "tree drop"))

var target := InteractionTarget.new()
target.target_rect = Rect2(-12, -20, 24, 20)
target.position = Vector2(100, 120)
failures.append(TestAssert.equal(target.world_target_rect(), Rect2(88, 100, 24, 20), "world target rect"))
```

- [ ] **Step 2: Extend `WorldPropDefinition`**

Add exports:

```gdscript
@export var interaction_kind: InteractionTarget.Kind = InteractionTarget.Kind.NONE
@export var interaction_rect := Rect2()
@export var required_tool: ItemDefinition.ToolType = ItemDefinition.ToolType.NONE
@export_range(0, 99, 1) var harvest_hits := 0
@export var drop_item_id: StringName
@export_range(0, 99, 1) var drop_quantity := 0
@export_range(16.0, 96.0, 1.0) var interaction_range := 44.0
```

Validation rules:

```gdscript
if interaction_kind != InteractionTarget.Kind.NONE:
    if interaction_rect.size.x <= 0.0 or interaction_rect.size.y <= 0.0:
        errors.append("interactive prop requires interaction_rect")
if interaction_kind in [InteractionTarget.Kind.HARVEST_TREE, InteractionTarget.Kind.HARVEST_ROCK]:
    if required_tool == ItemDefinition.ToolType.NONE or harvest_hits <= 0:
        errors.append("harvestable prop requires tool and positive hits")
    if drop_item_id.is_empty() or drop_quantity <= 0:
        errors.append("harvestable prop requires a positive drop")
```

- [ ] **Step 3: Implement `InteractionTarget` and outline**

Public API:

```gdscript
class_name InteractionTarget
extends Area2D

enum Kind { NONE, HARVEST_TREE, HARVEST_ROCK, PICKUP, INTERACT }

@export var kind: Kind = Kind.NONE
@export var required_tool: ItemDefinition.ToolType = ItemDefinition.ToolType.NONE
@export var interaction_range := 44.0
var target_rect := Rect2()
var highlight: Sprite2D

func world_target_rect() -> Rect2:
    return Rect2(global_position + target_rect.position, target_rect.size)

func set_highlighted(enabled: bool, locked := false) -> void:
    if highlight == null:
        return
    highlight.visible = enabled
    if highlight.material is ShaderMaterial:
        (highlight.material as ShaderMaterial).set_shader_parameter(
            "outline_color",
            Color("#8d9497") if locked else Color("#ffd86a")
        )
```

The shader must sample the four direct neighboring texels and draw only outside the source alpha. Use `outline_color` and `pixel_size` uniforms.

- [ ] **Step 4: Attach interaction nodes in `WorldPropFactory`**

After creating `Visual`, duplicate it as `Highlight`, assign the shader material, hide it, then create an `InteractionTarget` with collision layer 4 and mask 0. Use `definition.interaction_rect` for its `RectangleShape2D`. Keep physical `Solid` on layer 1.

Set exact prop values:

```text
tree_small: HARVEST_TREE, AXE, 3 hits, wood ×3, range 44, interaction Rect2(-28,-96,56,96)
tree_cluster: HARVEST_TREE, AXE, 5 hits, wood ×5, range 48, interaction Rect2(-48,-112,96,112)
rock_cluster: HARVEST_ROCK, PICKAXE, 4 hits, stone ×4, range 44, interaction Rect2(-30,-48,60,48)
```

- [ ] **Step 5: Run tests and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world assets/original/ui/interaction_outline.gdshader data/world/props tests/godot
git commit -m "feat: add interactive world prop targets"
```

---

### Task 4: Implement tool-gated harvest depletion and dynamic obstacle removal

**Files:**
- Create: `scripts/world/harvestable_resource.gd`
- Create: `tests/godot/suites/test_harvestable_resource.gd`
- Modify: `scripts/world/world_prop_factory.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `InteractionTarget`, `WorldCollisionRegistry`, generated `Solid` and footprint ids.
- Produces: `can_harvest(tool_type)`, `apply_hit(tool_type, damage) -> bool`, `signal hit`, `signal depleted(item_id, quantity, position)`.

- [ ] **Step 1: Write failing harvest tests**

Create tests for wrong tool, correct tool, repeated hits, single depletion emission, and collision removal:

```gdscript
var registry := WorldCollisionRegistry.new()
registry.configure_world(Rect2(0, 0, 640, 360))
registry.register_rect(&"tree:0", Rect2(90, 90, 20, 12))
var resource := HarvestableResource.new()
resource.configure(
    ItemDefinition.ToolType.AXE,
    3,
    &"wood",
    3,
    registry,
    [&"tree:0"]
)
failures.append(TestAssert.truthy(
    not resource.apply_hit(ItemDefinition.ToolType.PICKAXE, 1),
    "wrong tool rejected"
))
failures.append(TestAssert.equal(resource.current_hits(), 3, "wrong tool preserves health"))
resource.apply_hit(ItemDefinition.ToolType.AXE, 1)
resource.apply_hit(ItemDefinition.ToolType.AXE, 1)
resource.apply_hit(ItemDefinition.ToolType.AXE, 1)
failures.append(TestAssert.truthy(resource.is_depleted(), "resource depletes"))
failures.append(TestAssert.truthy(not registry.has_footprint(&"tree:0"), "depletion removes footprint"))
```

- [ ] **Step 2: Implement `HarvestableResource`**

Use this class shape:

```gdscript
class_name HarvestableResource
extends Node

signal hit(remaining_hits: int)
signal depleted(item_id: StringName, quantity: int, world_position: Vector2)

var required_tool: ItemDefinition.ToolType
var maximum_hits := 1
var _current_hits := 1
var drop_item_id: StringName
var drop_quantity := 1
var registry: WorldCollisionRegistry
var footprint_ids: Array[StringName] = []
var _depleted := false

func configure(tool, hits: int, item_id: StringName, quantity: int, collision_registry, ids: Array[StringName]) -> void:
    required_tool = tool
    maximum_hits = maxi(1, hits)
    _current_hits = maximum_hits
    drop_item_id = item_id
    drop_quantity = maxi(1, quantity)
    registry = collision_registry
    footprint_ids = ids.duplicate()

func apply_hit(tool_type: ItemDefinition.ToolType, damage := 1) -> bool:
    if _depleted or tool_type != required_tool or damage <= 0:
        return false
    _current_hits = maxi(0, _current_hits - damage)
    hit.emit(_current_hits)
    if _current_hits == 0:
        _deplete()
    return true
```

`_deplete()` must set `_depleted` before emitting, unregister all footprint ids, disable `Solid`, disable `InteractionTarget`, emit drop data, then queue-free the prop root after one frame.

- [ ] **Step 3: Attach the component in `WorldPropFactory`**

Keep the footprint ids created while adding solid shapes. For harvestable definitions, add child `HarvestableResource`, call `configure(...)`, and store root metadata:

```gdscript
root.set_meta("interaction_kind", int(definition.interaction_kind))
root.set_meta("world_instance_id", instance_id)
```

- [ ] **Step 4: Run tests and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world/world_prop_factory.gd scripts/world/harvestable_resource.gd tests/godot
git commit -m "feat: add tool gated resource depletion"
```

---

### Task 5: Add inventory-safe world pickups and starter materials

**Files:**
- Create: `scripts/world/world_pickup.gd`
- Create: `scripts/world/world_pickup_factory.gd`
- Create: `tests/godot/suites/test_world_pickup.gd`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `InventoryModel.add_item`, `ItemCatalog`, player world position.
- Produces: `WorldPickup.configure(item_id, quantity, player, inventory)`, `try_transfer() -> int`, factory `spawn(...)`.

- [ ] **Step 1: Write failing pickup tests**

Cover full transfer, partial transfer and full-inventory retention:

```gdscript
var inventory := InventoryModel.new()
var pickup := WorldPickup.new()
pickup.configure(&"wood", 3, null, inventory)
failures.append(TestAssert.equal(pickup.try_transfer(), 0, "all wood transferred"))
failures.append(TestAssert.equal(inventory.count_item(&"wood"), 3, "inventory receives wood"))

var full_inventory := InventoryModel.new()
for index in InventoryModel.CAPACITY:
    full_inventory.slots[index].item_id = &"stone_axe"
    full_inventory.slots[index].quantity = 1
var blocked := WorldPickup.new()
blocked.configure(&"wood", 2, null, full_inventory)
failures.append(TestAssert.equal(blocked.try_transfer(), 2, "full inventory retains pickup"))
```

- [ ] **Step 2: Implement `WorldPickup`**

Use `Node2D` with child `Sprite2D`, `Label`, and `Area2D`. Physics behavior:

```gdscript
@export var attract_radius := 30.0
@export var collect_radius := 8.0
@export var attract_speed := 150.0

func _physics_process(delta: float) -> void:
    if player == null or inventory == null or quantity <= 0:
        return
    var distance := global_position.distance_to(player.global_position)
    if distance <= collect_radius:
        try_transfer()
    elif distance <= attract_radius:
        global_position = global_position.move_toward(player.global_position, attract_speed * delta)

func try_transfer() -> int:
    quantity = inventory.add_item(item_id, quantity)
    if quantity == 0:
        queue_free()
    else:
        _refresh_label()
    return quantity
```

Collision layer must be 8 and mask 0; it must never block the player.

- [ ] **Step 3: Implement the pickup factory**

`WorldPickupFactory.spawn(parent, item_id, quantity, world_position, player, inventory) -> WorldPickup` creates the sprite using the item icon, otherwise a deterministic colored circle fallback. It adds the node to `Entities` and sets its global position.

- [ ] **Step 4: Spawn fixed starter materials**

In `PrototypeWorld`, add:

```gdscript
const STARTER_BRANCH_CELLS: Array[Vector2i] = [
    Vector2i(14, 45), Vector2i(15, 45), Vector2i(16, 45), Vector2i(17, 45),
    Vector2i(14, 46), Vector2i(15, 46), Vector2i(16, 46), Vector2i(17, 46),
]
const STARTER_STONE_CELLS: Array[Vector2i] = [
    Vector2i(19, 44), Vector2i(20, 44), Vector2i(21, 44), Vector2i(19, 45),
    Vector2i(20, 45), Vector2i(21, 45), Vector2i(20, 46),
]
```

Spawn one `branch` or `loose_stone` per cell after player/inventory binding. Before spawning, pass each position through `world_layout.recover_player_position(position, Vector2(8, 8))` to avoid material inside an obstacle.

- [ ] **Step 5: Run tests and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world/world_pickup.gd scripts/world/world_pickup_factory.gd scripts/world/prototype_world.gd tests/godot
git commit -m "feat: add starter pickups and auto collection"
```

---

### Task 6: Add path-following auto movement with instant WASD override

**Files:**
- Create: `scripts/player/auto_move_agent.gd`
- Create: `tests/godot/suites/test_auto_move_agent.gd`
- Modify: `scripts/player/player_controller.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: `WorldPathGrid.find_path`, target rect/range, player position.
- Produces: `request_move(target, target_rect, range) -> bool`, `next_direction(actor_position, delta) -> Vector2`, `cancel(reason)`, `signal arrived(target)`, `signal cancelled(reason)`.

- [ ] **Step 1: Write failing auto-move tests**

Test waypoint advancement, arrival and manual cancellation:

```gdscript
var agent := AutoMoveAgent.new()
agent.set_path_for_test(PackedVector2Array([Vector2(32, 0), Vector2(64, 0)]))
failures.append(TestAssert.equal(agent.next_direction(Vector2.ZERO, 0.016), Vector2.RIGHT, "moves toward first point"))
agent.next_direction(Vector2(33, 0), 0.016)
failures.append(TestAssert.equal(agent.next_direction(Vector2(33, 0), 0.016), Vector2.RIGHT, "advances waypoint"))
agent.cancel(&"manual_input")
failures.append(TestAssert.equal(agent.next_direction(Vector2(33, 0), 0.016), Vector2.ZERO, "cancel stops movement"))
```

- [ ] **Step 2: Implement `AutoMoveAgent`**

Use waypoint tolerance 6 px, stuck threshold 0.75 s, movement epsilon 1 px, max replans 2. `request_move()` stores target/rect/range and calls the path grid. `next_direction()` advances waypoints and emits `arrived` when the final point is reached. When stuck, re-run `find_path()`; after two failures emit `cancelled(&"unreachable")`.

Public test hook:

```gdscript
func set_path_for_test(points: PackedVector2Array) -> void:
    _path = points
    _path_index = 0
```

- [ ] **Step 3: Integrate with `PlayerController`**

Add `@onready var auto_move_agent: AutoMoveAgent = $AutoMoveAgent`. Replace direction selection with:

```gdscript
var manual_input := (
    Vector2.ZERO
    if gameplay_input_blocked
    else Input.get_vector("move_left", "move_right", "move_up", "move_down")
)
var direction := MovementMath.normalized_input(manual_input)
if not direction.is_zero_approx():
    auto_move_agent.cancel(&"manual_input")
elif not gameplay_input_blocked:
    direction = auto_move_agent.next_direction(global_position, delta)
```

`set_gameplay_input_blocked(true)` must cancel with `&"modal"`.

- [ ] **Step 4: Fix the player foot anchor in the scene and visual code**

Set `CollisionShape2D.position = Vector2(0, -6)`, `Shadow.position = Vector2(0, -2)`. For open sheet use `Sprite2D.position = Vector2(0, -16)`; fallback uses `Vector2(0, -22)`. Root global position now denotes feet/contact point.

- [ ] **Step 5: Run tests and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/player scenes/player tests/godot
git commit -m "feat: add cancelable auto movement"
```

---

### Task 7: Add state cursors, hover selection and mouse command routing

**Files:**
- Create: `scripts/input/cursor_state_manager.gd`
- Create: `scripts/player/mouse_interaction_controller.gd`
- Create: `assets/original/ui/cursors/default.svg`
- Create: `assets/original/ui/cursors/axe.svg`
- Create: `assets/original/ui/cursors/pickaxe.svg`
- Create: `assets/original/ui/cursors/pickup.svg`
- Create: `assets/original/ui/cursors/interact.svg`
- Create: `assets/original/ui/cursors/unreachable.svg`
- Create: `assets/original/ui/cursors/tool_locked.svg`
- Create: `tests/godot/suites/test_mouse_interaction.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `tests/godot/test_runner.gd`

**Interfaces:**
- Consumes: selected inventory item, physics point query mask 4, `WorldPathGrid`, `AutoMoveAgent`.
- Produces: cursor enum/state mapping, `resolve_state(target)`, `handle_world_click(target)`, `signal target_requested(target)` and `signal feedback_requested(message)`.

- [ ] **Step 1: Write failing cursor decision tests**

Cover tree+axe, tree without axe, rock+pickaxe, unreachable target, no target:

```gdscript
var controller := MouseInteractionController.new()
var inventory := InventoryModel.new()
controller.inventory = inventory
var tree := InteractionTarget.new()
tree.kind = InteractionTarget.Kind.HARVEST_TREE
tree.required_tool = ItemDefinition.ToolType.AXE
failures.append(TestAssert.equal(
    controller.resolve_cursor_state(tree, false),
    CursorStateManager.State.TOOL_LOCKED,
    "tree locked without axe"
))
inventory.add_item(&"stone_axe", 1)
failures.append(TestAssert.equal(
    controller.resolve_cursor_state(tree, false),
    CursorStateManager.State.HARVEST_AXE,
    "tree axe cursor"
))
failures.append(TestAssert.equal(
    controller.resolve_cursor_state(tree, true),
    CursorStateManager.State.UNREACHABLE,
    "unreachable overrides tool"
))
```

- [ ] **Step 2: Create seven original SVG cursor assets**

Use 24×24 viewboxes, hard pixel-aligned paths, no gradients, no external fonts. Hotspots:

```text
default (1,1), axe (4,20), pickaxe (4,20), pickup (10,10), interact (12,12), unreachable (12,12), tool_locked (12,12)
```

- [ ] **Step 3: Implement `CursorStateManager`**

```gdscript
class_name CursorStateManager
extends Node

enum State { DEFAULT, HARVEST_AXE, HARVEST_PICKAXE, PICKUP, INTERACT, UNREACHABLE, TOOL_LOCKED }

const CURSORS := {
    State.DEFAULT: ["res://assets/original/ui/cursors/default.svg", Vector2(1, 1)],
    State.HARVEST_AXE: ["res://assets/original/ui/cursors/axe.svg", Vector2(4, 20)],
    State.HARVEST_PICKAXE: ["res://assets/original/ui/cursors/pickaxe.svg", Vector2(4, 20)],
    State.PICKUP: ["res://assets/original/ui/cursors/pickup.svg", Vector2(10, 10)],
    State.INTERACT: ["res://assets/original/ui/cursors/interact.svg", Vector2(12, 12)],
    State.UNREACHABLE: ["res://assets/original/ui/cursors/unreachable.svg", Vector2(12, 12)],
    State.TOOL_LOCKED: ["res://assets/original/ui/cursors/tool_locked.svg", Vector2(12, 12)],
}
```

`set_state()` loads once into a cache and calls `Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)` only when state changes.

- [ ] **Step 4: Implement mouse target query and click routing**

`MouseInteractionController._physics_process()` performs `PhysicsPointQueryParameters2D` against collision mask 4 at `get_global_mouse_position()`, picks the first enabled `InteractionTarget`, updates highlight and cursor. Tool matching uses the selected slot’s `ItemDefinition.tool_type`.

On left click:

```gdscript
func handle_world_click(target: InteractionTarget) -> bool:
    if gameplay_blocked or target == null:
        return false
    var unreachable := path_grid.find_path(
        player.global_position,
        target.world_target_rect(),
        target.interaction_range
    ).is_empty()
    var state := resolve_cursor_state(target, unreachable)
    if state == CursorStateManager.State.TOOL_LOCKED:
        feedback_requested.emit("需要石斧" if target.required_tool == ItemDefinition.ToolType.AXE else "需要石镐")
        return true
    if state == CursorStateManager.State.UNREACHABLE:
        feedback_requested.emit("无法到达")
        return true
    target_requested.emit(target)
    return true
```

- [ ] **Step 5: Run tests and commit**

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/input scripts/player assets/original/ui/cursors scenes/player tests/godot
git commit -m "feat: add mouse interaction cursors"
```

---

### Task 8: Orchestrate continuous harvesting, drops and modal cancellation

**Files:**
- Create: `scripts/world/world_interaction_manager.gd`
- Create: `scripts/ui/action_feedback.gd`
- Modify: `scripts/world/prototype_world.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/input/game_input_router.gd`
- Modify: `tests/godot/suites/test_game_input_router.gd`
- Modify: `tests/godot/suites/test_world_integration.gd`

**Interfaces:**
- Consumes: `MouseInteractionController.target_requested`, `AutoMoveAgent.arrived`, `HarvestableResource`, selected tool cooldown, `WorldPickupFactory`.
- Produces: one active target, repeated hit timer, drop spawn, `cancel_active(reason)`, feedback UI.

- [ ] **Step 1: Add failing integration tests**

In `test_world_integration.gd`, instantiate `prototype_world.tscn`, await two frames, assert these nodes exist:

```gdscript
failures.append(TestAssert.truthy(world.has_node("WorldPathGrid"), "world path grid exists"))
failures.append(TestAssert.truthy(world.has_node("WorldInteractionManager"), "interaction manager exists"))
failures.append(TestAssert.truthy(world.has_node("CursorStateManager"), "cursor manager exists"))
failures.append(TestAssert.truthy(world.has_node("HUD/ActionFeedback"), "feedback label exists"))
failures.append(TestAssert.equal(
    world.get_tree().get_nodes_in_group("starter_pickups").size(),
    15,
    "starter pickups spawned"
))
```

In `test_game_input_router.gd`, bind an interaction manager stub and assert opening inventory calls cancellation before pause acquisition.

- [ ] **Step 2: Implement `WorldInteractionManager`**

Required state:

```gdscript
class_name WorldInteractionManager
extends Node

var player: PlayerController
var inventory: InventoryModel
var path_grid: WorldPathGrid
var auto_move: AutoMoveAgent
var mouse_controller: MouseInteractionController
var entities: Node2D
var active_target: InteractionTarget
var _harvest_cooldown := 0.0

func bind(player_node, model, grid, mouse, entity_root) -> void:
```

When target requested, cancel old target, call `auto_move.request_move(...)`, and wait for arrival. On arrival, verify target and tool again. `_process(delta)` repeatedly calls `HarvestableResource.apply_hit()` according to selected tool `use_cooldown`, minimum 0.2 s. On `depleted`, spawn the declared drop at the resource root position and clear active target.

- [ ] **Step 3: Implement hit feedback and short messages**

On `HarvestableResource.hit`, tween the visual `position.x` by ±2 px for 0.08 s and modulate to white for one frame. `ActionFeedback.show_message(text)` shows a HUD label for 1.4 s, then fades it over 0.25 s. It must not pause the game or capture mouse input.

- [ ] **Step 4: Bind world nodes and modal cancellation**

Add `WorldPathGrid`, `WorldInteractionManager`, `CursorStateManager`, and `HUD/ActionFeedback` to `prototype_world.tscn`. In `PrototypeWorld._ready()`:

```gdscript
world_path_grid.configure(world_layout.config, collision_registry)
mouse_controller.bind(player, player_inventory, world_path_grid, cursor_state_manager)
world_interaction_manager.bind(player, player_inventory, world_path_grid, mouse_controller, entities)
```

In `_on_inventory_opened(true)`, call `world_interaction_manager.cancel_active(&"inventory")` and `cursor_state_manager.set_state(CursorStateManager.State.DEFAULT)` before blocking player input.

- [ ] **Step 5: Run tests and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add scripts/world scripts/ui scripts/input scripts/world/prototype_world.gd scenes/world tests/godot
git commit -m "feat: connect mouse harvesting gameplay loop"
```

---

### Task 9: Calibrate base collisions and Y sorting to remove residual clipping

**Files:**
- Modify: `data/world/props/tree_small.tres`
- Modify: `data/world/props/tree_cluster.tres`
- Modify: `data/world/props/rock_cluster.tres`
- Modify: `data/world/props/farmhouse.tres`
- Modify: `data/world/props/workshop.tres`
- Modify: `data/world/props/fence_horizontal.tres`
- Modify: `scripts/world/world_prop_factory.gd`
- Modify: `scripts/world/world_layout.gd`
- Modify: `tests/godot/suites/test_world_collisions.gd`
- Modify: `tests/godot/suites/test_world_path_grid.gd`

**Interfaces:**
- Consumes: foot-anchor convention, shared registry/path data.
- Produces: precise base footprints, open doors, open bridges, non-solid decorations, dynamic resource unblocking.

- [ ] **Step 1: Add exact collision-contract tests**

Assertions:

```gdscript
failures.append(TestAssert.equal(tree_small.collision_rects, [Rect2(-10, -12, 20, 12)], "small tree trunk base"))
failures.append(TestAssert.equal(tree_cluster.collision_rects, [Rect2(-25, -14, 16, 14), Rect2(9, -14, 16, 14)], "tree cluster trunks"))
failures.append(TestAssert.equal(rock.collision_rects, [Rect2(-16, -10, 32, 10)], "rock base"))
failures.append(TestAssert.equal(fence.collision_rects, [Rect2(-56, -6, 112, 8)], "fence base"))
```

Keep farmhouse doorway `Rect2(-15,-31,30,31)` and workshop doorway `Rect2(-11,-27,22,27)` free of collision.

- [ ] **Step 2: Apply exact collision rectangles**

Use the values above. Keep farmhouse side walls and top wall:

```text
Rect2(-56,-44,40,44), Rect2(16,-44,40,44), Rect2(-56,-44,112,12)
```

Keep workshop side walls and top wall:

```text
Rect2(-44,-36,33,36), Rect2(11,-36,33,36), Rect2(-44,-36,88,10)
```

- [ ] **Step 3: Enforce foot-anchor sorting**

`WorldPropFactory` must set every generated root `position = world_position` and never offset the root for visual alignment. Only `Visual`, `Highlight`, interaction collision and physical shapes receive local offsets. Set `root.z_as_relative = true`, `Visual.z_index = 0`, `Highlight.z_index = -1`.

- [ ] **Step 4: Verify river/bridge parity between path and physics**

Add path tests for both bridge cells from `WorldLayoutConfig.bridge_rects`. For every bridge center, assert `WorldPathGrid.is_cell_walkable()` is true. For one water cell immediately beside each bridge, assert false. `WorldLayout._build_river_collisions()` must derive segments from config bridge rows rather than hard-coded visual assumptions.

- [ ] **Step 5: Run tests and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add data/world/props scripts/world tests/godot
git commit -m "fix: align world prop collisions and sorting"
```

---

### Task 10: Prove the complete playable loop and prevent regressions

**Files:**
- Create: `tests/godot/suites/test_playable_loop.gd`
- Modify: `tests/godot/test_runner.gd`
- Modify: `tests/godot/capture_world.gd`
- Modify: `tests/test_validate_project.py`
- Modify: `tools/validate_project.py`
- Modify: `README.md`
- Modify: `.github/workflows/validate.yml` only when a new capture path is required.

**Interfaces:**
- Consumes: all implemented systems.
- Produces: deterministic end-to-end regression, screenshot artifact, documented controls and phase status.

- [ ] **Step 1: Write the deterministic playable-loop test**

The test must instantiate the world and execute logic without synthetic keyboard timing:

```gdscript
var world_scene := load("res://scenes/world/prototype_world.tscn") as PackedScene
var world := world_scene.instantiate() as PrototypeWorld
root.add_child(world)
await root.get_tree().process_frame
await root.get_tree().process_frame

var inventory := world.player.get_node("Inventory") as InventoryModel
inventory.add_item(&"branch", 8)
inventory.add_item(&"loose_stone", 7)
var axe_recipe := load("res://data/recipes/stone_axe.tres") as RecipeDefinition
var pick_recipe := load("res://data/recipes/stone_pickaxe.tres") as RecipeDefinition
failures.append(TestAssert.truthy(CraftingService.craft(axe_recipe, inventory).ok, "craft stone axe"))
failures.append(TestAssert.truthy(CraftingService.craft(pick_recipe, inventory).ok, "craft stone pickaxe"))

var tree_resource := world.find_first_harvestable(InteractionTarget.Kind.HARVEST_TREE)
world.force_harvest_for_test(tree_resource)
failures.append(TestAssert.truthy(inventory.count_item(&"wood") > 0, "tree yields wood"))
var rock_resource := world.find_first_harvestable(InteractionTarget.Kind.HARVEST_ROCK)
world.force_harvest_for_test(rock_resource)
failures.append(TestAssert.truthy(inventory.count_item(&"stone") > 0, "rock yields stone"))
```

Add explicit test helpers to `PrototypeWorld` only under normal public methods with deterministic names; they must call the same harvest manager path, not mutate inventory directly.

- [ ] **Step 2: Extend repository validation**

`tools/validate_project.py` must require these files/classes and reject any world interaction Area2D using collision layer 1 or player mask. `tests/test_validate_project.py` adds one passing fixture assertion and one failure assertion for a pickup configured as solid.

- [ ] **Step 3: Update capture script for visual acceptance**

`capture_world.gd` must wait for world build, position the player near a tree and rock in the starter area, leave the inventory closed, and save `artifacts/world-validation.png`. Ensure the screenshot shows:

```text
left HUD, right minimap, bottom quickbar, player, starter pickups, one tree, one rock, and unobstructed ground around the player
```

Do not automate a mouse hover in screenshot capture; cursor state is covered by logic tests and manual review.

- [ ] **Step 4: Update README**

Document controls:

```text
WASD/方向键：移动并立即取消自动行动
鼠标悬停：显示采集、拾取、交互、锁定或不可达光标
鼠标左键：选择资源，自动绕障碍靠近并持续采集
Tab：打开/关闭背包和随身制作，同时取消世界行动
滚轮：镜头缩放
Ctrl+滚轮：快捷栏切换
数字键 1–5：直接选择快捷栏
```

State that the first playable loop is now available and list what remains out of scope.

- [ ] **Step 5: Run the complete local gate**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
xvfb-run -a godot --audio-driver Dummy --path . --script res://tests/godot/capture_world.gd
test -s artifacts/world-validation.png
```

Expected: all commands exit 0, no `SCRIPT ERROR:` or leading `ERROR:` in logs, screenshot exists and is non-empty.

- [ ] **Step 6: Commit**

```bash
git add tests tools README.md .github/workflows/validate.yml
git commit -m "test: verify mouse harvesting MVP"
```

---

### Task 11: Open the draft PR and verify CI evidence

**Files:**
- No product files unless CI reveals a reproducible failure.

**Interfaces:**
- Consumes: feature branch commits and GitHub Actions.
- Produces: draft PR with exact validation evidence.

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/mouse-interaction-mvp
```

- [ ] **Step 2: Open a draft PR to `main`**

PR title:

```text
feat: add mouse-driven harvesting MVP
```

PR body must include:

```markdown
## Playable loop
- starter branch/stone auto-pickup
- stone axe and pickaxe crafting
- mouse hover state cursors
- A* auto-approach with WASD cancellation
- continuous tree/rock harvesting
- world drops and auto-pickup
- base collision and Y-sort fixes

## Validation
- Python unittest
- repository validator
- Godot 4.6.3 import
- Godot gameplay suites
- main-scene smoke
- graphical screenshot artifact
```

- [ ] **Step 3: Inspect every failed CI step before changing code**

For each failure, use `superpowers:systematic-debugging`: capture the exact log, identify the first causal error, reproduce with the matching local command, add or tighten a failing test, apply the smallest fix, and rerun the full affected gate.

- [ ] **Step 4: Verify final CI and artifact**

Confirm all checks green and download `world-validation`. Inspect that HUD does not overlap, player is not visually inside tree/rock bases, starter pickups are visible, doors/bridge paths remain open, and no bare map edge appears in the initial view.

- [ ] **Step 5: Request code review**

Invoke `superpowers:requesting-code-review` after all checks pass. Address only evidence-backed issues, rerun the complete gate, and keep the PR draft until review findings are resolved.

---

## Plan Self-Review

- Spec coverage: mouse hover/cursors, A* approach, WASD cancellation, continuous harvesting, correct-tool checks, starter materials, pickups, crafting reuse, collisions, Y sorting, modal cancellation, tests, smoke and screenshot all map to Tasks 1–11.
- Scope: no combat, multiplayer, day/night, farming expansion, durability, questing or click-to-move task is present.
- Type consistency: `InteractionTarget.Kind`, `CursorStateManager.State`, `WorldPathGrid.find_path`, `AutoMoveAgent.request_move`, `HarvestableResource.apply_hit`, and `WorldPickup.try_transfer` use the same names throughout.
- Placeholder scan: the plan contains no unresolved implementation markers; exact files, values, commands and public interfaces are specified.
