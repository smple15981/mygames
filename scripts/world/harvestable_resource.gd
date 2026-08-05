class_name HarvestableResource
extends Node

signal hit(remaining_hits: int)
signal depleted(item_id: StringName, quantity: int, world_position: Vector2)

var required_tool: ItemDefinition.ToolType = ItemDefinition.ToolType.NONE
var maximum_hits := 1
var _current_hits := 1
var drop_item_id: StringName
var drop_quantity := 1
var registry: WorldCollisionRegistry
var footprint_ids: Array[StringName] = []
var _depleted := false


func configure(
    tool: ItemDefinition.ToolType,
    hits: int,
    item_id: StringName,
    quantity: int,
    collision_registry: WorldCollisionRegistry,
    ids: Array[StringName]
) -> void:
    required_tool = tool
    maximum_hits = maxi(1, hits)
    _current_hits = maximum_hits
    drop_item_id = item_id
    drop_quantity = maxi(1, quantity)
    registry = collision_registry
    footprint_ids = ids.duplicate()
    _depleted = false


func can_harvest(tool_type: ItemDefinition.ToolType) -> bool:
    return not _depleted and tool_type == required_tool


func apply_hit(tool_type: ItemDefinition.ToolType, damage := 1) -> bool:
    if not can_harvest(tool_type) or damage <= 0:
        return false
    _current_hits = maxi(0, _current_hits - damage)
    hit.emit(_current_hits)
    if _current_hits == 0:
        _deplete()
    return true


func current_hits() -> int:
    return _current_hits


func is_depleted() -> bool:
    return _depleted


func _deplete() -> void:
    if _depleted:
        return
    _depleted = true

    if registry != null:
        registry.unregister_many(footprint_ids)

    var root := get_parent() as Node2D
    var world_position := Vector2.ZERO
    if root != null:
        world_position = root.global_position
        var solid := root.get_node_or_null("Solid") as StaticBody2D
        if solid != null:
            solid.collision_layer = 0
            solid.collision_mask = 0
            for child in solid.get_children():
                var collision := child as CollisionShape2D
                if collision != null:
                    collision.set_deferred("disabled", true)
        var target := root.get_node_or_null("InteractionTarget") as InteractionTarget
        if target != null:
            target.set_interaction_enabled(false)

    depleted.emit(drop_item_id, drop_quantity, world_position)
    if root != null:
        root.call_deferred("queue_free")
