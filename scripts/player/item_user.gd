class_name ItemUser
extends Node

signal action_requested(request: ActionRequest)

@export var inventory_path: NodePath

var inventory: InventoryModel
var _sequence_id := 0
var _cooldown_remaining := 0.0


func _ready() -> void:
    _resolve_inventory()


func _process(delta: float) -> void:
    _cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)


func set_inventory(model: InventoryModel) -> void:
    inventory = model


func request_use(direction: Vector2) -> void:
    if _cooldown_remaining > 0.0:
        return
    if _resolve_inventory() == null:
        push_warning("ItemUser has no inventory")
        return

    var actor := get_parent() as Node2D
    if actor == null:
        push_warning("ItemUser parent must be Node2D")
        return

    var slot := inventory.selected_stack()
    _sequence_id += 1
    var request := ActionRequest.new_request(
        actor,
        &"use_item",
        actor.global_position,
        direction,
        _sequence_id
    )

    if not slot.is_empty():
        request.item_id = slot.item_id
        var item := ItemCatalog.get_item(slot.item_id)
        if item == null:
            push_warning("Selected item is missing from catalog: %s" % slot.item_id)
            return
        request.range = item.use_range
        request.arc_degrees = item.arc_degrees
        request.tool_type = item.tool_type
        request.tool_level = item.tool_level
        request.damage = item.base_damage
        _cooldown_remaining = item.use_cooldown
    else:
        request.item_id = &"unarmed"
        request.range = 32.0
        _cooldown_remaining = 0.35

    action_requested.emit(request)


func _resolve_inventory() -> InventoryModel:
    if inventory != null:
        return inventory
    if inventory_path.is_empty() or not has_node(inventory_path):
        return null
    inventory = get_node(inventory_path) as InventoryModel
    return inventory
