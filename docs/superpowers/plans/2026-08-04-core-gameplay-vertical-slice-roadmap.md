# Core Gameplay Vertical Slice Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current movement-and-visual prototype into a 15–20 minute complete loop: gather, craft, fight, farm, sleep, grow, harvest, and save.

**Architecture:** Deliver the slice through five sequential, independently reviewable plans. Shared data and test infrastructure land first; combat, harvesting, farming/save, and tutorial integration build on stable interfaces rather than editing `PlayerController` into a monolith.

**Tech Stack:** Godot 4.3+ / GDScript, pure 2D scenes, Python 3.13 repository validation, GitHub Actions, official Godot 4.6.3 headless CI.

## Global Constraints

- Keep the project pure 2D and preserve the 640×360 base viewport, nearest-neighbor filtering, pixel snapping, and GL Compatibility renderer.
- Keep `scenes/bootstrap/main.tscn` as the configured main scene.
- Runtime assets must work in a normal clone or GitHub ZIP without submodules.
- The player inventory has exactly 20 slots; slots 0–4 are the five-slot quickbar.
- Left click always uses the currently selected quickbar item.
- Mouse position controls attack and tool direction.
- Only dodge consumes stamina; maximum stamina is 100 and a dodge costs 40.
- Single-player inventory, crafting, dialogue, and pause menus freeze world time.
- This milestone contains one enemy, one crop, basic wood/stone resources, and no multiplayer, economy, ranged combat, building, fishing, cooking, or tool upgrade tree.
- New gameplay logic must be covered by headless Godot tests; repository contracts remain covered by Python tests.
- Each phase is merged only after Python tests, the repository validator, Godot import, Godot gameplay tests, and the main-scene smoke run pass.

---

## Execution order

1. [`2026-08-04-gameplay-foundation-inventory-crafting.md`](2026-08-04-gameplay-foundation-inventory-crafting.md)
2. [`2026-08-04-combat-dodge-slime.md`](2026-08-04-combat-dodge-slime.md)
3. [`2026-08-04-harvesting-pickups.md`](2026-08-04-harvesting-pickups.md)
4. [`2026-08-04-farming-time-save.md`](2026-08-04-farming-time-save.md)
5. [`2026-08-04-tutorial-integration.md`](2026-08-04-tutorial-integration.md)

## Branch and review strategy

Each plan is implemented on a fresh branch created from the latest `main`:

```bash
git switch main
git pull --ff-only
git switch -c feat/<phase-name>
```

Each plan ends with a draft pull request. Merge only after the plan’s acceptance checks pass. The next phase starts from the merge commit, not from an unmerged feature branch.

## Cross-plan interfaces

These names are frozen across all five plans:

```gdscript
ItemCatalog.get_item(item_id: StringName) -> ItemDefinition
InventoryModel.add_item(item_id: StringName, quantity: int) -> int
InventoryModel.remove_item(item_id: StringName, quantity: int) -> bool
InventoryModel.count_item(item_id: StringName) -> int
InventoryModel.selected_stack() -> InventorySlot
CraftingService.craft(recipe: RecipeDefinition, inventory: InventoryModel) -> CraftingResult

ActionRequest.new_request(
    actor: Node2D,
    action_id: StringName,
    origin: Vector2,
    direction: Vector2,
    sequence_id: int
) -> ActionRequest
ActionResult.success(targets: Array[Node], payload: Dictionary = {}) -> ActionResult
ActionResult.failure(reason: StringName) -> ActionResult

HealthComponent.apply_damage(amount: int, source: Node, sequence_id: int) -> bool
HarvestableComponent.apply_harvest(request: ActionRequest) -> ActionResult
FarmCell.apply_action(request: ActionRequest) -> ActionResult

TimeManager.advance_minutes(minutes: int) -> void
TimeManager.sleep_to_next_day() -> void
SaveManager.save_game(reason: StringName) -> Error
SaveManager.load_game() -> Dictionary
TutorialDirector.notify_event(event_id: StringName, payload: Dictionary = {}) -> void
```

Do not rename these methods in later phases without updating all earlier tests and plan documents in the same commit.

## Final vertical-slice acceptance

- A fresh save starts empty-handed inside the farmhouse.
- The player can gather enough branches and loose stones to craft a stone axe and stone pickaxe within five minutes.
- The player can harvest wood and stone, craft a wooden sword, defeat the tutorial slime, and pick up slime gel.
- The player can craft a wooden hoe at the workbench.
- Opening the old chest grants the worn watering can and first moon-dew radish seed packet exactly once.
- The player can till, plant, water, sleep, and repeat until the crop matures after three watered-day settlements.
- The player can harvest the mature crop.
- Inventory, tutorial progress, farm state, world resources, time, player stats, and position survive save/load.
- The full loop is understandable through on-screen objectives without external instructions.
- No script errors, runtime errors, missing-resource errors, or open-art fallback warnings occur in CI.
