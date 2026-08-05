class_name WorldInteractionManager
extends Node

signal interaction_started(target: InteractionTarget)
signal interaction_cancelled(reason: StringName)
signal harvest_completed(item_id: StringName, quantity: int)

var player: PlayerController
var inventory: InventoryModel
var path_grid: WorldPathGrid
var mouse_controller: MouseInteractionController
var entities: Node2D
var feedback: ActionFeedback

var _current_target: InteractionTarget
var _current_resource: HarvestableResource
var _harvesting := false
var _input_blocked := false
var _cooldown_remaining := 0.0


func bind(
    player_node: PlayerController,
    inventory_model: InventoryModel,
    grid: WorldPathGrid,
    mouse: MouseInteractionController,
    entity_parent: Node2D,
    feedback_ui: ActionFeedback
) -> void:
    _disconnect_bindings()
    player = player_node
    inventory = inventory_model
    path_grid = grid
    mouse_controller = mouse
    entities = entity_parent
    feedback = feedback_ui

    if mouse_controller != null:
        mouse_controller.target_requested.connect(begin_interaction)
        mouse_controller.feedback_requested.connect(_show_feedback)
    if player != null:
        player.manual_input_started.connect(_on_manual_input_started)
        player.auto_move_agent.arrived.connect(_on_auto_move_arrived)
        player.auto_move_agent.cancelled.connect(_on_auto_move_cancelled)


func _process(delta: float) -> void:
    if _input_blocked or not _harvesting:
        return
    if not _has_valid_target():
        cancel(&"target_invalid")
        return
    if not _is_in_interaction_range(_current_target):
        cancel(&"out_of_range")
        return

    _cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
    if _cooldown_remaining > 0.0:
        return

    if not _perform_harvest_hit():
        if _harvesting:
            cancel(&"harvest_rejected")
        return

    if _harvesting:
        var item := _selected_item_definition()
        if item != null:
            _cooldown_remaining = maxf(0.05, item.use_cooldown)


func begin_interaction(target: InteractionTarget) -> bool:
    if _input_blocked or target == null or not target.interaction_enabled:
        return false
    if target.kind not in [
        InteractionTarget.Kind.HARVEST_TREE,
        InteractionTarget.Kind.HARVEST_ROCK,
    ]:
        _show_feedback("暂不可用")
        return false

    var root := target.get_parent()
    var resource := root.get_node_or_null("HarvestableResource") as HarvestableResource
    if resource == null or resource.is_depleted():
        return false

    var item := _selected_item_definition()
    if item == null or item.tool_type != target.required_tool:
        _show_feedback(_required_tool_message(target.required_tool))
        return false

    cancel(&"new_target")
    _current_target = target
    _current_resource = resource
    _connect_resource(resource)
    interaction_started.emit(target)

    if _is_in_interaction_range(target):
        _start_harvesting()
        return true

    if player == null or not player.auto_move_agent.request_move(target):
        _show_feedback("无法到达")
        cancel(&"unreachable")
        return false
    return true


func complete_current_harvest_for_test() -> bool:
    if not _harvesting or not _has_valid_target():
        return false

    var safety := 0
    while _harvesting and _has_valid_target() and safety < 100:
        if not _perform_harvest_hit():
            return false
        safety += 1

    return (
        safety > 0
        and not _harvesting
        and _current_resource == null
        and _current_target == null
    )


func cancel(reason: StringName = &"cancelled") -> void:
    var had_interaction := (
        _current_target != null
        or _current_resource != null
        or _harvesting
        or (player != null and player.auto_move_agent.is_active())
    )
    _disconnect_resource()
    _current_target = null
    _current_resource = null
    _harvesting = false
    _cooldown_remaining = 0.0
    if player != null and player.auto_move_agent.is_active():
        player.auto_move_agent.cancel(reason)
    if had_interaction:
        interaction_cancelled.emit(reason)


func set_input_blocked(blocked: bool) -> void:
    _input_blocked = blocked
    if blocked:
        cancel(&"modal")


func is_active() -> bool:
    return (
        _current_target != null
        or _harvesting
        or (player != null and player.auto_move_agent.is_active())
    )


func current_target() -> InteractionTarget:
    return _current_target


func _start_harvesting() -> void:
    if not _has_valid_target():
        cancel(&"target_invalid")
        return
    var item := _selected_item_definition()
    if item == null or not _current_resource.can_harvest(item.tool_type):
        _show_feedback(_required_tool_message(_current_target.required_tool))
        cancel(&"wrong_tool")
        return

    _harvesting = true
    _cooldown_remaining = 0.0
    if player != null:
        player.velocity = Vector2.ZERO
        var direction := player.global_position.direction_to(
            _current_target.world_target_rect().get_center()
        )
        player.facing = MovementMath.facing_index(direction, player.facing)


func _perform_harvest_hit() -> bool:
    if not _has_valid_target():
        return false
    var item := _selected_item_definition()
    if item == null or not _current_resource.can_harvest(item.tool_type):
        _show_feedback(_required_tool_message(_current_target.required_tool))
        cancel(&"tool_changed")
        return false
    return _current_resource.apply_hit(item.tool_type, 1)


func _is_in_interaction_range(target: InteractionTarget) -> bool:
    if player == null or target == null:
        return false
    var rect := target.world_target_rect()
    var closest := Vector2(
        clampf(player.global_position.x, rect.position.x, rect.end.x),
        clampf(player.global_position.y, rect.position.y, rect.end.y)
    )
    var tolerance := 0.0
    if path_grid != null and path_grid.config != null:
        tolerance = Vector2(path_grid.config.display_cell_size).length() * 0.5
    return player.global_position.distance_to(closest) <= target.interaction_range + tolerance


func _selected_item_definition() -> ItemDefinition:
    if inventory == null:
        return null
    var stack := inventory.selected_stack()
    if stack.is_empty():
        return null
    return ItemCatalog.get_item(stack.item_id)


func _has_valid_target() -> bool:
    return (
        _current_target != null
        and is_instance_valid(_current_target)
        and _current_target.interaction_enabled
        and _current_resource != null
        and is_instance_valid(_current_resource)
        and not _current_resource.is_depleted()
    )


func _connect_resource(resource: HarvestableResource) -> void:
    if not resource.hit.is_connected(_on_resource_hit):
        resource.hit.connect(_on_resource_hit)
    if not resource.depleted.is_connected(_on_resource_depleted):
        resource.depleted.connect(_on_resource_depleted)


func _disconnect_resource() -> void:
    if _current_resource == null or not is_instance_valid(_current_resource):
        return
    if _current_resource.hit.is_connected(_on_resource_hit):
        _current_resource.hit.disconnect(_on_resource_hit)
    if _current_resource.depleted.is_connected(_on_resource_depleted):
        _current_resource.depleted.disconnect(_on_resource_depleted)


func _on_resource_hit(_remaining_hits: int) -> void:
    if _current_target == null or not is_instance_valid(_current_target):
        return
    var root := _current_target.get_parent() as Node2D
    if root == null:
        return
    var visual := root.get_node_or_null("Visual") as Sprite2D
    if visual == null:
        return
    visual.modulate = Color(1.35, 1.35, 1.35, 1.0)
    var tween := root.create_tween()
    tween.tween_property(visual, "modulate", Color.WHITE, 0.12)


func _on_resource_depleted(
    item_id: StringName,
    quantity: int,
    world_position: Vector2
) -> void:
    var pickup := WorldPickupFactory.spawn(
        entities,
        item_id,
        quantity,
        world_position,
        player,
        inventory
    )
    if pickup != null:
        pickup.add_to_group("resource_drops")
        pickup.pickup_blocked.connect(_on_pickup_blocked)

    _disconnect_resource()
    _current_target = null
    _current_resource = null
    _harvesting = false
    _cooldown_remaining = 0.0
    harvest_completed.emit(item_id, quantity)


func _on_pickup_blocked(_item_id: StringName) -> void:
    _show_feedback("背包已满")


func _on_manual_input_started() -> void:
    cancel(&"manual_input")


func _on_auto_move_arrived() -> void:
    if _current_target != null:
        _start_harvesting()


func _on_auto_move_cancelled(reason: StringName) -> void:
    if _current_target == null and _current_resource == null and not _harvesting:
        return
    if reason in [&"unreachable", &"stuck"]:
        _show_feedback("无法到达")
    cancel(reason)


func _show_feedback(message: String) -> void:
    if feedback != null:
        feedback.show_message(message)


func _required_tool_message(tool: ItemDefinition.ToolType) -> String:
    match tool:
        ItemDefinition.ToolType.AXE:
            return "需要石斧"
        ItemDefinition.ToolType.PICKAXE:
            return "需要石镐"
        _:
            return "需要正确工具"


func _disconnect_bindings() -> void:
    cancel(&"rebind")
    if mouse_controller != null:
        if mouse_controller.target_requested.is_connected(begin_interaction):
            mouse_controller.target_requested.disconnect(begin_interaction)
        if mouse_controller.feedback_requested.is_connected(_show_feedback):
            mouse_controller.feedback_requested.disconnect(_show_feedback)
    if player != null:
        if player.manual_input_started.is_connected(_on_manual_input_started):
            player.manual_input_started.disconnect(_on_manual_input_started)
        if player.auto_move_agent.arrived.is_connected(_on_auto_move_arrived):
            player.auto_move_agent.arrived.disconnect(_on_auto_move_arrived)
        if player.auto_move_agent.cancelled.is_connected(_on_auto_move_cancelled):
            player.auto_move_agent.cancelled.disconnect(_on_auto_move_cancelled)
