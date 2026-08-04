# Tutorial and Vertical-Slice Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect all implemented systems into a clear empty-handed tutorial that ends with harvesting the first mature crop.

**Architecture:** Interactable world objects publish typed tutorial events. `TutorialDirector` advances a non-blocking objective state machine and never directly grants progression except through the old chest’s one-time reward. A final acceptance suite validates the full loop as state transitions.

**Tech Stack:** Godot 4.3+ / GDScript, existing gameplay modules, CanvasLayer UI, procedural audio cues, versioned save system, Python and headless Godot CI.

## Global Constraints

- A fresh game starts empty-handed.
- Objectives guide but do not lock unrelated controls.
- Already-completed objective conditions auto-skip after load.
- The old chest grants one worn watering can and one moon-dew seed packet exactly once.
- Wooden hoe is crafted only at the workbench.
- Critical items cannot be dropped or consumed as ingredients.
- Tutorial slime respawns while its objective is incomplete.
- The first complete loop should take approximately 15–20 minutes.
- No economy, dialogue tree, quest journal, NPC dependency, or multiplayer behavior.

---

## File structure

**Create**

- `scripts/interactions/interactable.gd`
- `scripts/interactions/interaction_detector.gd`
- `scripts/world/old_chest.gd`
- `scripts/world/workbench.gd`
- `scripts/tutorial/tutorial_director.gd`
- `scripts/tutorial/tutorial_objective.gd`
- `data/tutorial/first_day_objectives.tres`
- `scripts/ui/tutorial_ui.gd`, `scenes/ui/tutorial_ui.tscn`
- `scripts/ui/workbench_ui.gd`, `scenes/ui/workbench_ui.tscn`
- `scripts/ui/target_highlight.gd`
- `scripts/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn`
- `scripts/ui/title_menu.gd`, `scenes/ui/title_menu.tscn`
- `scripts/audio/gameplay_audio.gd`
- `scripts/bootstrap/main.gd`
- `tests/godot/suites/test_tutorial_director.gd`
- `tests/godot/suites/test_vertical_slice_acceptance.gd`

**Modify**

- `project.godot`
- `scenes/bootstrap/main.tscn`
- `scenes/player/player.tscn`
- `scripts/player/player_controller.gd`
- `scenes/world/prototype_world.tscn`
- `scripts/world/prototype_world.gd`
- `scripts/world/resource_spawn_manager.gd`
- `scripts/enemies/slime_enemy.gd`
- `scripts/save/save_manager.gd`
- `scripts/ui/inventory_ui.gd`
- `README.md`
- `tools/validate_project.py`
- `tests/test_validate_project.py`
- `tests/godot/test_runner.gd`

---

### Task 1: Add generic interaction detection

**Files:**
- Create: `scripts/interactions/interactable.gd`
- Create: `scripts/interactions/interaction_detector.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/player_controller.gd`
- Test: `tests/godot/suites/test_tutorial_director.gd`

**Interfaces:**
- Produces: `Interactable.get_prompt()`, `Interactable.interact(actor)`, and `InteractionDetector.focus_changed`.

- [ ] **Step 1: Write failing nearest-interaction tests**

Place two mock interactables in range and assert nearest inside the player’s forward 120° cone wins. Assert no focus outside 56 pixels.

- [ ] **Step 2: Implement base interactable**

```gdscript
class_name Interactable
extends Area2D

@export var prompt := "交互"
@export var enabled := true

func get_prompt() -> String:
    return prompt if enabled else ""

func interact(_actor: Node) -> bool:
    return false
```

- [ ] **Step 3: Implement detector**

Poll overlapping interactables, filter by range/cone, sort by squared distance, emit focus changes, and handle `interact`. It never identifies concrete object types.

- [ ] **Step 4: Bind contextual prompt**

Reuse the bottom hint panel for `E · <prompt>` and hide it when no focus exists or a menu is open.

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/interactions scenes/player scripts/player tests/godot
git commit -m "feat: add focused world interactions"
```

---

### Task 2: Add old chest and workbench flows

**Files:**
- Create: `scripts/world/old_chest.gd`
- Create: `scripts/world/workbench.gd`
- Create: `scripts/ui/workbench_ui.gd`
- Create: `scenes/ui/workbench_ui.tscn`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Test: `tests/godot/suites/test_vertical_slice_acceptance.gd`

**Interfaces:**
- Consumes: inventory and crafting.
- Produces: one-time chest grant and workbench-only crafting.

- [ ] **Step 1: Write failing chest idempotency tests**

First open adds `worn_watering_can×1` and `moon_dew_seed×1`; second adds nothing. A full inventory leaves rewards pending instead of deleting them.

- [ ] **Step 2: Implement `OldChest`**

```gdscript
var claimed := false
var pending_rewards := {
    &"worn_watering_can": 1,
    &"moon_dew_seed": 1,
}
```

`interact` transfers accepted quantities, retains remainder, marks claimed only when all rewards transfer, emits `old_chest_claimed`, and serializes claimed/pending state.

- [ ] **Step 3: Implement workbench and UI**

Workbench opens only wooden hoe and simple bandage recipes. Craft calls `CraftingService.craft`. Pending key output stays in a visible output slot and retries when inventory changes.

- [ ] **Step 4: Place objects**

Put the chest near the farmhouse bed and workbench beside the existing workshop prop. Give stable save ids and clear collision/prompt regions.

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world scripts/ui scenes/ui scenes/world tests/godot
git commit -m "feat: add old chest and workbench interactions"
```

---

### Task 3: Implement the non-blocking tutorial director

**Files:**
- Create: `scripts/tutorial/tutorial_objective.gd`
- Create: `scripts/tutorial/tutorial_director.gd`
- Create: `data/tutorial/first_day_objectives.tres`
- Test: `tests/godot/suites/test_tutorial_director.gd`
- Modify: `project.godot`

**Interfaces:**
- Consumes: typed gameplay events and state queries.
- Produces: current objective id/text and serialized progress.

- [ ] **Step 1: Write failing progression tests**

Use exact order:

```text
gather_starter_materials
craft_stone_tools
gather_wood_stone
craft_wooden_sword
defeat_tutorial_slime
craft_wooden_hoe
claim_watering_can
till_soil
plant_seed
water_crop
sleep_once
grow_crop
harvest_first_crop
complete
```

Out-of-order events do not skip requirements. Reconciliation after load advances through already-satisfied conditions.

- [ ] **Step 2: Implement objective Resource**

```gdscript
class_name TutorialObjective
extends Resource

@export var id: StringName
@export var text: String
@export var completion_event: StringName
@export var target_count := 1
```

- [ ] **Step 3: Implement director**

```gdscript
class_name HearthwildTutorialDirector
extends Node

signal objective_changed(id: StringName, text: String)
signal tutorial_completed

var current_index := 0
var progress := 0

func notify_event(event_id: StringName, payload: Dictionary = {}) -> void:
    var objective := objectives[current_index]
    if event_id != objective.completion_event:
        return
    progress += int(payload.get("count", 1))
    if progress >= objective.target_count:
        _advance()
```

Register as `TutorialDirector`. `reconcile(state)` repeatedly checks exact inventory/world conditions until no further objective is complete.

- [ ] **Step 4: Connect typed events**

Connect inventory counts, crafting success, tutorial slime death, chest claim, farm actions, sleep, crop maturity, and harvest. Never parse UI strings or node names.

- [ ] **Step 5: Save progress and commit**

Register a tutorial provider with `SaveableRegistry`.

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/tutorial data/tutorial project.godot tests/godot scripts/save
git commit -m "feat: add first-day tutorial state machine"
```

---

### Task 4: Build tutorial, target, audio, title, and pause presentation

**Files:**
- Create: `scripts/ui/tutorial_ui.gd`, `scenes/ui/tutorial_ui.tscn`
- Create: `scripts/ui/target_highlight.gd`
- Create: `scripts/audio/gameplay_audio.gd`
- Create: `scripts/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn`
- Create: `scripts/ui/title_menu.gd`, `scenes/ui/title_menu.tscn`
- Create: `scripts/bootstrap/main.gd`
- Modify: `scenes/bootstrap/main.tscn`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scripts/ui/inventory_ui.gd`
- Modify: `scripts/ui/player_status_ui.gd`

**Interfaces:**
- Consumes: tutorial, focus, pickup, crafting, combat, and save signals.
- Produces: objective/progress UI, target outline, procedural cues, and save-aware menu transitions.

- [ ] **Step 1: Add failing UI contract tests**

Python tests require TutorialUI, WorkbenchUI, five-slot hotbar, stamina bar, clock label, contextual prompt, pause menu, and title menu scene tokens.

- [ ] **Step 2: Implement objective panel**

Compact upper-right panel, maximum width 220 pixels. On objective change, show a short completion check animation before replacing text. No modal tutorial popups.

- [ ] **Step 3: Improve item feedback and valid-target highlighting**

Pickup shows `+quantity display_name`; craft shows output; wrong tool shows one-line reason with one-second anti-spam cooldown.

`TargetHighlight` stores a focused `CanvasItem`’s original modulate, pulses brightness from 1.0 to 1.18, and restores it on focus change. Interaction/combat/harvesting/farming routers publish valid targets; highlighting never determines success.

- [ ] **Step 4: Add procedural gameplay audio**

`GameplayAudio` owns `AudioStreamPlayer` + `AudioStreamGenerator`. Add deterministic cues for `swing`, `hit`, `pickup`, `craft`, `plant`, `water`, `objective_complete`; peak amplitude below 0.35. Audio failure suppresses sound only.

- [ ] **Step 5: Add title and pause without changing main-scene path**

Keep `project.godot` pointing at `scenes/bootstrap/main.tscn`. Structure:

```text
Main (Node, main.gd)
├── WorldRoot (Node)
└── UI (CanvasLayer)
    └── TitleMenu
```

`main.gd` exposes:

```gdscript
func start_new_game() -> void
func continue_game() -> void
func save_and_return_to_title() -> void
```

Continue is disabled without a valid save. New Game asks confirmation before deleting/replacing a save. Pause uses reason `pause_menu`, provides Resume and Save and Return to Title, saves with reason `return_to_title`, frees active world, and shows title.

- [ ] **Step 6: Verify menu focus**

Inventory, workbench, pause, and title cannot overlap. Esc closes the top gameplay panel before opening pause. Prompts/highlighting disappear while a menu is open.

- [ ] **Step 7: Run and commit**

```bash
godot --headless --path . --import
godot --headless --path . --quit-after 8
git add scripts/ui scripts/audio scripts/bootstrap scenes/ui scenes/bootstrap scenes/world tests tools
git commit -m "feat: present tutorial audio targets and menus"
```

---

### Task 5: Enforce anti-softlock recovery and world-state consistency

**Files:**
- Modify: `scripts/world/resource_spawn_manager.gd`
- Modify: `scripts/enemies/slime_enemy.gd`
- Modify: `scripts/world/old_chest.gd`
- Modify: `scripts/tutorial/tutorial_director.gd`
- Modify: `scripts/save/save_manager.gd`
- Test: `tests/godot/suites/test_vertical_slice_acceptance.gd`

**Interfaces:**
- Consumes: tutorial/save state.
- Produces: deterministic recovery from missing critical resources.

- [ ] **Step 1: Write failing recovery tests**

Cover no starter resources/tools, missing tutorial slime before objective, crafted hoe but unclaimed chest, missing key item after load, and pending workbench output after space becomes available.

- [ ] **Step 2: Implement recovery rules**

On load/day start: guarantee branches/stones until first tools exist; respawn tutorial slime while objective incomplete; preserve chest rewards; restore missing claimed key items only when save audit proves previous grant; retry pending workbench output. Never duplicate items already in inventory/pending output.

- [ ] **Step 3: Persist audit fields**

Save `granted_key_items`, pending outputs, tutorial enemy status, and guarantee state. Validate all ids with `ItemCatalog` before restoring.

- [ ] **Step 4: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/world scripts/enemies scripts/tutorial scripts/save tests/godot
git commit -m "fix: prevent first-day tutorial softlocks"
```

---

### Task 6: Add full-loop acceptance test and documentation

**Files:**
- Create: `tests/godot/suites/test_vertical_slice_acceptance.gd`
- Modify: `tests/godot/test_runner.gd`
- Modify: `tools/validate_project.py`
- Modify: `tests/test_validate_project.py`
- Modify: `README.md`
- Modify: `.github/workflows/validate.yml`

**Interfaces:**
- Consumes: all completed systems.
- Produces: one deterministic non-rendered full-loop acceptance test and release documentation.

- [ ] **Step 1: Write the acceptance scenario before final fixes**

```text
empty inventory
→ add guaranteed starter pickups
→ craft stone axe and stone pickaxe
→ harvest enough wood and stone
→ craft wooden sword
→ damage tutorial slime until death
→ transfer slime gel
→ craft wooden hoe at workbench
→ claim chest rewards
→ till, plant, water
→ settle three watered days
→ harvest radish
→ save and load
```

Assert every inventory count, objective id, crop stage, day value, and key-item count.

- [ ] **Step 2: Run and identify integration failures**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

Before final fixes, expected failure is an assertion identifying an interface mismatch, not a parse error.

- [ ] **Step 3: Fix only reported integration mismatches**

Keep frozen subsystem interfaces and avoid unrelated features.

- [ ] **Step 4: Update validator and README**

Document complete loop, controls, save/backup path, implemented systems, non-goals, normal clone/ZIP art behavior, and local test commands. Validator requires major gameplay scripts/scenes and gameplay-test CI.

- [ ] **Step 5: Run complete release gate**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 12
```

Expected: all exit `0`; no `SCRIPT ERROR`, runtime `ERROR:`, missing resource, or open-art fallback warning.

- [ ] **Step 6: Conduct one timed editor playthrough**

Delete local save and record time to first tool, sword, slime defeat, planted/watered crop, and first harvest. Target 15–20 minutes active time. Adjust quantities, durability, damage, and spawn distances only.

- [ ] **Step 7: Commit and open final PR**

```bash
git add README.md .github tools tests scripts scenes data project.godot
git commit -m "feat: complete first gameplay vertical slice"
```

PR body includes release-gate output and measured playthrough times.
