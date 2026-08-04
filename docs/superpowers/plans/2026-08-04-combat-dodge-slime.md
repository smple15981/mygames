# Combat, Dodge, and Slime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add mouse-aimed three-hit melee combat, stamina-limited dodge, player health, one readable slime enemy, interruptible recovery items, and balanced defeat recovery.

**Architecture:** Pure combat math filters physics candidates into a 90° arc. Health and hurtbox components own damage deduplication. Player combat, dodge, and consumption remain sibling components under the player, while the slime uses a compact explicit state machine.

**Tech Stack:** Godot 4.3+ / GDScript, `PhysicsDirectSpaceState2D`, `Area2D`, `CharacterBody2D`, headless Godot tests.

## Global Constraints

- Use the action and inventory interfaces from the foundation plan unchanged.
- Wooden sword attacks point toward the mouse and can hit multiple enemies.
- Combo window is 0.45 seconds; the third strike is stronger and has more knockback.
- Maximum stamina is 100; dodge costs 40 and regeneration is approximately 28/second after a delay.
- Dodge direction uses movement input, falling back to mouse direction while stationary.
- The first portion of the dodge grants invulnerability.
- Ordinary slime damage must defeat a full-health player in approximately 4–6 successful hits.
- Food/bandage healing resolves only after its use animation and is cancelled by damage.
- No ranged weapons, magic, boss, elite modifiers, elemental damage, or advanced aggro system.

---

## File structure

**Create**

- `scripts/combat/combat_math.gd`
- `scripts/combat/health_component.gd`
- `scripts/combat/hurtbox.gd`
- `scripts/combat/hit_feedback.gd`
- `scripts/player/player_combat.gd`
- `scripts/player/player_dodge.gd`
- `scripts/player/player_consume.gd`
- `scripts/enemies/slime_enemy.gd`
- `scripts/enemies/slime_state_math.gd`
- `scenes/enemies/grass_slime.tscn`
- `scripts/ui/player_status_ui.gd`
- `tests/godot/suites/test_combat_math.gd`
- `tests/godot/suites/test_health_component.gd`
- `tests/godot/suites/test_player_dodge.gd`
- `tests/godot/suites/test_player_consume.gd`
- `tests/godot/suites/test_slime_state_math.gd`

**Modify**

- `scenes/player/player.tscn`
- `scripts/player/player_controller.gd`
- `scripts/player/item_user.gd`
- `scenes/world/prototype_world.tscn`
- `scripts/world/prototype_world.gd`
- `project.godot`
- `tests/godot/test_runner.gd`
- `tools/validate_project.py`

---

### Task 1: Add arc math and deduplicated health

**Files:**
- Create: `scripts/combat/combat_math.gd`
- Create: `scripts/combat/health_component.gd`
- Create: `scripts/combat/hurtbox.gd`
- Test: `tests/godot/suites/test_combat_math.gd`
- Test: `tests/godot/suites/test_health_component.gd`

**Interfaces:**
- Consumes: `ActionRequest`.
- Produces: `CombatMath.is_point_in_arc` and `HealthComponent.apply_damage`.

- [ ] **Step 1: Write failing math tests**

```gdscript
failures.append(TestAssert.truthy(
    CombatMath.is_point_in_arc(Vector2.ZERO, Vector2.RIGHT, Vector2(40, 0), 56.0, 90.0),
    "point ahead is in arc"
))
failures.append(TestAssert.truthy(
    not CombatMath.is_point_in_arc(Vector2.ZERO, Vector2.RIGHT, Vector2(-10, 0), 56.0, 90.0),
    "point behind is outside arc"
))
```

Also test the 45° edge and a point beyond range.

- [ ] **Step 2: Run and verify parse failure**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
```

- [ ] **Step 3: Implement exact arc math**

```gdscript
class_name CombatMath
extends RefCounted

static func is_point_in_arc(
    origin: Vector2,
    forward: Vector2,
    point: Vector2,
    max_range: float,
    arc_degrees: float
) -> bool:
    var offset := point - origin
    if offset.length_squared() > max_range * max_range:
        return false
    if offset.is_zero_approx():
        return true
    var minimum_dot := cos(deg_to_rad(arc_degrees * 0.5))
    return forward.normalized().dot(offset.normalized()) >= minimum_dot
```

- [ ] **Step 4: Write and implement health deduplication**

Tests assert sequence `12` damages once, repeating `12` does not, and sequence `13` does.

```gdscript
class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node)
signal died(source: Node)

@export_range(1, 999, 1) var maximum := 100
var current := 100
var invulnerable := false
var _seen_sequences: Dictionary = {}

func _ready() -> void:
    current = maximum

func apply_damage(amount: int, source: Node, sequence_id: int) -> bool:
    if amount <= 0 or invulnerable or current <= 0 or _seen_sequences.has(sequence_id):
        return false
    _seen_sequences[sequence_id] = true
    current = maxi(0, current - amount)
    damaged.emit(amount, source)
    health_changed.emit(current, maximum)
    if current == 0:
        died.emit(source)
    return true
```

Retain only the latest 64 sequence ids.

- [ ] **Step 5: Implement `Hurtbox.receive_action`**

Accept requests with `damage > 0`, delegate to `HealthComponent`, and return success only when damage was applied.

- [ ] **Step 6: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/combat tests/godot
git commit -m "feat: add melee arc and health components"
```

---

### Task 2: Implement the player three-hit combo

**Files:**
- Create: `scripts/player/player_combat.gd`
- Modify: `scripts/player/item_user.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/player_controller.gd`
- Test: `tests/godot/suites/test_combat_math.gd`

**Interfaces:**
- Consumes: wooden-sword `ActionRequest`.
- Produces: combo state and damage requests to hurtboxes.

- [ ] **Step 1: Add failing combo progression tests**

```gdscript
failures.append(TestAssert.equal(PlayerCombat.next_combo_index(-1, 0.0, 0.45), 0, "first swing"))
failures.append(TestAssert.equal(PlayerCombat.next_combo_index(0, 0.20, 0.45), 1, "second swing"))
failures.append(TestAssert.equal(PlayerCombat.next_combo_index(1, 0.60, 0.45), 0, "expired reset"))
```

- [ ] **Step 2: Implement `PlayerCombat`**

```gdscript
const COMBO_WINDOW := 0.45
const DAMAGE_MULTIPLIERS := [1.0, 1.15, 1.55]
const KNOCKBACK_MULTIPLIERS := [1.0, 1.1, 1.5]
const MOVE_SPEED_MULTIPLIERS := [0.72, 0.68, 0.58]
```

On a wooden-sword request: select combo index, query hurtboxes within 56 pixels, filter with `CombatMath`, apply multiplied damage once per target/sequence, and emit `swing_started` plus `swing_resolved`.

- [ ] **Step 3: Wire player nodes**

```text
Health (HealthComponent, maximum=100)
Hurtbox (Area2D)
PlayerCombat (PlayerCombat)
```

Connect `ItemUser.action_requested` to `PlayerCombat.handle_action`. `PlayerController` multiplies movement speed by `PlayerCombat.movement_multiplier()` during a swing.

- [ ] **Step 4: Add visual swing feedback**

Use a short-lived `Line2D`/`Polygon2D` arc rotated to aim direction. First/second swings last 0.16 seconds; third lasts 0.24 seconds. It must not own collision or damage.

- [ ] **Step 5: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add scenes/player scripts/player scripts/combat tests/godot
git commit -m "feat: add mouse-aimed three-hit sword combo"
```

---

### Task 3: Implement stamina and directional dodge

**Files:**
- Create: `scripts/player/player_dodge.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/player_controller.gd`
- Test: `tests/godot/suites/test_player_dodge.gd`

**Interfaces:**
- Consumes: movement input, aim direction, player health.
- Produces: dodge state, stamina signals, movement override, and invulnerability.

- [ ] **Step 1: Write failing stamina tests**

Test starting at 100, two successful dodges leaving 20, third rejected, delayed regeneration capped at 100, and stationary dodge using aim direction.

- [ ] **Step 2: Implement deterministic stamina logic**

```gdscript
class_name PlayerDodge
extends Node

signal stamina_changed(current: float, maximum: float)
signal dodge_started(direction: Vector2)

const MAX_STAMINA := 100.0
const DODGE_COST := 40.0
const REGEN_PER_SECOND := 28.0
const REGEN_DELAY := 0.55
const DODGE_DURATION := 0.32
const INVULNERABLE_DURATION := 0.18
const DODGE_SPEED := 285.0

var stamina := MAX_STAMINA
var remaining := 0.0
var regen_delay_remaining := 0.0
var dodge_direction := Vector2.ZERO
```

`try_start(move_direction, aim_direction) -> bool` rejects while dodging/below cost. Expose `tick(delta)` for deterministic tests.

- [ ] **Step 3: Wire movement and invulnerability**

During dodge, controller uses `dodge_direction * DODGE_SPEED`. Set health invulnerable for 0.18 seconds, then false.

- [ ] **Step 4: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/player scenes/player tests/godot
git commit -m "feat: add stamina-limited directional dodge"
```

---

### Task 4: Add the grass slime state machine

**Files:**
- Create: `scripts/enemies/slime_state_math.gd`
- Create: `scripts/enemies/slime_enemy.gd`
- Create: `scenes/enemies/grass_slime.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Test: `tests/godot/suites/test_slime_state_math.gd`

**Interfaces:**
- Consumes: player position and health.
- Produces: a damageable enemy and death signal.

- [ ] **Step 1: Write failing transition tests**

Test idle→chase on detection, chase→windup in range, windup→charge after timer, charge→recover, leash→return, and zero health→dead.

- [ ] **Step 2: Implement explicit states**

States: `idle`, `wander`, `chase`, `windup`, `charge`, `recover`, `hurt`, `return`, `dead`.

```gdscript
@export var detection_range := 150.0
@export var leash_range := 260.0
@export var attack_range := 48.0
@export var chase_speed := 52.0
@export var charge_speed := 170.0
@export var windup_time := 0.45
@export var charge_time := 0.28
@export var recover_time := 0.55
@export var contact_damage := 22
```

- [ ] **Step 3: Build the scene**

```text
GrassSlime (CharacterBody2D)
├── Shadow (Sprite2D)
├── Sprite2D
├── CollisionShape2D
├── Hurtbox (Area2D)
├── Health (HealthComponent, maximum=35)
└── AttackArea (Area2D)
```

Use an isolated runtime-generated green pixel blob only when no bundled slime art exists, so later art replacement does not touch AI.

- [ ] **Step 4: Add readable windup and control protection**

Compress Y scale to 0.75 and flash twice. Hurt state has 0.12-second control protection; valid health damage still applies.

- [ ] **Step 5: Spawn enemies**

Spawn one tutorial slime (25 health, 16 damage) and two ordinary slimes at fixed positions outside the farmhouse start area.

- [ ] **Step 6: Run and commit**

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add scenes/enemies scripts/enemies scripts/world tests/godot
git commit -m "feat: add readable grass slime enemy"
```

---

### Task 5: Add interruptible food and bandage use

**Files:**
- Create: `scripts/player/player_consume.gd`
- Modify: `scripts/combat/health_component.gd`
- Modify: `scripts/player/item_user.gd`
- Modify: `scenes/player/player.tscn`
- Test: `tests/godot/suites/test_player_consume.gd`

**Interfaces:**
- Consumes: food item, inventory, health.
- Produces: delayed healing cancelled by damage.

- [ ] **Step 1: Write failing tests**

Test radish does not heal before 0.55 seconds, then consumes one and heals 15; bandage heals 35 after 0.80 seconds; damage cancels without consuming; heal caps at maximum; a second use is rejected while active.

- [ ] **Step 2: Add healing**

```gdscript
func heal(amount: int) -> int:
    if amount <= 0 or current <= 0:
        return 0
    var before := current
    current = mini(maximum, current + amount)
    var restored := current - before
    if restored > 0:
        health_changed.emit(current, maximum)
    return restored
```

- [ ] **Step 3: Implement `PlayerConsume`**

```gdscript
class_name PlayerConsume
extends Node

signal consume_started(item_id: StringName, duration: float)
signal consume_cancelled(item_id: StringName)
signal consume_completed(item_id: StringName, healed: int)

@export var inventory_path: NodePath
@export var health_path: NodePath
var active_item_id: StringName = &""
var remaining := 0.0
@onready var inventory: InventoryModel = get_node(inventory_path)
@onready var health: HealthComponent = get_node(health_path)

func try_start(item_id: StringName) -> bool:
    if not active_item_id.is_empty():
        return false
    var item := ItemCatalog.get_item(item_id)
    if item == null or item.item_type != ItemDefinition.ItemType.FOOD:
        return false
    if inventory.count_item(item_id) <= 0 or health.current >= health.maximum:
        return false
    active_item_id = item_id
    remaining = item.consume_duration
    consume_started.emit(item_id, remaining)
    return true

func tick(delta: float) -> void:
    if active_item_id.is_empty():
        return
    remaining -= delta
    if remaining > 0.0:
        return
    var item := ItemCatalog.get_item(active_item_id)
    if inventory.remove_item(active_item_id, 1):
        consume_completed.emit(active_item_id, health.heal(item.heal_amount))
    active_item_id = &""
```

Connect damage to `cancel()`. While consuming, movement multiplier is 0.45 and attack/dodge/second consume are rejected.

- [ ] **Step 4: Set values and commit**

Radish: heal 15, 0.55s. Bandage: heal 35, 0.80s.

```bash
godot --headless --path . --script res://tests/godot/test_runner.gd
git add scripts/player scripts/combat scenes/player data/items tests/godot
git commit -m "feat: add interruptible recovery item use"
```

---

### Task 6: Add feedback, status HUD, and defeat recovery

**Files:**
- Create: `scripts/combat/hit_feedback.gd`
- Create: `scripts/ui/player_status_ui.gd`
- Modify: `scenes/world/prototype_world.tscn`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/world/prototype_world.gd`
- Test: `tests/godot/suites/test_health_component.gd`

**Interfaces:**
- Consumes: health/stamina/hit/death signals.
- Produces: live bars and `recover_player_after_defeat()`.

- [ ] **Step 1: Write a failing material-loss helper test**

Exclude key items, tools, and weapons; use seeded RNG and assert only eligible ordinary materials are selected.

- [ ] **Step 2: Implement isolated hit feedback**

Listen to `damaged` and perform a 0.06s flash, 0.035s hit pause, small camera impulse, damage number, and particles. Disabling feedback must not alter health tests.

- [ ] **Step 3: Bind health and stamina bars**

Replace static HUD values. Hide stamina after 1.5 seconds at full and show immediately on change.

- [ ] **Step 4: Implement defeat recovery**

Disable control, fade to black, move to farmhouse bed, restore 60 health and full stamina, lose 10%–20% of eligible materials gained that day, optionally advance future `TimeManager` by 120 minutes, fade in, restore control.

- [ ] **Step 5: Run release gate and commit**

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
git add scripts/combat scripts/player scripts/enemies scripts/ui scenes tests tools
git commit -m "feat: finish combat dodge slime and recovery"
```
