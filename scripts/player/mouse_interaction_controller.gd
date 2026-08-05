class_name MouseInteractionController
extends Node

signal target_requested(target: InteractionTarget)
signal feedback_requested(message: String)

var player: PlayerController
var inventory: InventoryModel
var path_grid: WorldPathGrid
var cursor_manager: CursorStateManager
var _hovered_target: InteractionTarget
var _input_blocked := false


func bind(
    player_node: PlayerController,
    inventory_model: InventoryModel,
    grid: WorldPathGrid,
    manager: CursorStateManager
) -> void:
    player = player_node
    inventory = inventory_model
    path_grid = grid
    cursor_manager = manager
    set_process(player != null and cursor_manager != null)


func _process(_delta: float) -> void:
    if _input_blocked or player == null or cursor_manager == null:
        return
    var next_target := _target_under_mouse()
    if next_target != _hovered_target:
        _clear_hover()
        _hovered_target = next_target

    if _hovered_target == null:
        cursor_manager.reset()
        return

    var reachable := _is_target_reachable(_hovered_target)
    var state := cursor_state_for_target(_hovered_target, reachable)
    _hovered_target.set_highlighted(true, state == CursorStateManager.State.TOOL_LOCKED)
    cursor_manager.set_state(state)


func _unhandled_input(event: InputEvent) -> void:
    if _input_blocked or _hovered_target == null:
        return
    var mouse_event := event as InputEventMouseButton
    if (
        mouse_event != null
        and mouse_event.button_index == MOUSE_BUTTON_LEFT
        and mouse_event.pressed
    ):
        handle_target_click(_hovered_target, _is_target_reachable(_hovered_target))
        get_viewport().set_input_as_handled()


func cursor_state_for_target(target: InteractionTarget, reachable: bool) -> int:
    if target == null or not target.interaction_enabled:
        return CursorStateManager.State.DEFAULT

    if target.kind in [
        InteractionTarget.Kind.HARVEST_TREE,
        InteractionTarget.Kind.HARVEST_ROCK,
    ] and selected_tool_type() != target.required_tool:
        return CursorStateManager.State.TOOL_LOCKED

    if not reachable:
        return CursorStateManager.State.UNREACHABLE

    match target.kind:
        InteractionTarget.Kind.HARVEST_TREE:
            return CursorStateManager.State.HARVEST_AXE
        InteractionTarget.Kind.HARVEST_ROCK:
            return CursorStateManager.State.HARVEST_PICKAXE
        InteractionTarget.Kind.PICKUP:
            return CursorStateManager.State.PICKUP
        InteractionTarget.Kind.INTERACT:
            return CursorStateManager.State.INTERACT
        _:
            return CursorStateManager.State.DEFAULT


func handle_target_click(target: InteractionTarget, reachable: bool) -> bool:
    if _input_blocked or target == null or not target.interaction_enabled:
        return false

    var state := cursor_state_for_target(target, reachable)
    if cursor_manager != null:
        cursor_manager.set_state(state)

    # Pickups are collected automatically by proximity. Clicking one only keeps
    # the pickup cursor visible and must not create a harvesting command.
    if target.kind == InteractionTarget.Kind.PICKUP:
        return false
    if state == CursorStateManager.State.TOOL_LOCKED:
        feedback_requested.emit(_required_tool_message(target.required_tool))
        return false
    if state == CursorStateManager.State.UNREACHABLE:
        feedback_requested.emit("无法到达")
        return false
    if state == CursorStateManager.State.DEFAULT:
        return false

    target_requested.emit(target)
    return true


func set_input_blocked(blocked: bool) -> void:
    _input_blocked = blocked
    if blocked:
        _clear_hover()
        if cursor_manager != null:
            cursor_manager.reset()


func selected_tool_type() -> ItemDefinition.ToolType:
    if inventory == null:
        return ItemDefinition.ToolType.NONE
    var stack := inventory.selected_stack()
    if stack == null or stack.is_empty():
        return ItemDefinition.ToolType.NONE
    var definition := ItemCatalog.get_item(stack.item_id)
    return (
        definition.tool_type
        if definition != null
        else ItemDefinition.ToolType.NONE
    )


func _is_target_reachable(target: InteractionTarget) -> bool:
    if target == null:
        return false
    if target.kind in [InteractionTarget.Kind.PICKUP, InteractionTarget.Kind.INTERACT]:
        return true
    if player == null or path_grid == null:
        return true
    return not path_grid.find_path(
        player.global_position,
        target.world_target_rect(),
        target.interaction_range
    ).is_empty()


func _target_under_mouse() -> InteractionTarget:
    if player == null or not player.is_inside_tree():
        return null
    var query := PhysicsPointQueryParameters2D.new()
    query.position = player.get_global_mouse_position()
    query.collision_mask = 4
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var results := player.get_world_2d().direct_space_state.intersect_point(query, 16)
    for result in results:
        var collider := result.get("collider") as InteractionTarget
        if collider != null and collider.interaction_enabled:
            return collider
    return null


func _clear_hover() -> void:
    if _hovered_target != null and is_instance_valid(_hovered_target):
        _hovered_target.set_highlighted(false)
    _hovered_target = null


func _required_tool_message(tool: ItemDefinition.ToolType) -> String:
    match tool:
        ItemDefinition.ToolType.AXE:
            return "需要石斧"
        ItemDefinition.ToolType.PICKAXE:
            return "需要石镐"
        _:
            return "需要正确工具"
