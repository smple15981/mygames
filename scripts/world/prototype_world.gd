class_name PrototypeWorld
extends Node2D

const VisualCritterScript := preload("res://scripts/world/visual_critter.gd")
const STARTER_BRANCH_CELLS: Array[Vector2i] = [
    Vector2i(14, 45), Vector2i(15, 45), Vector2i(16, 45), Vector2i(17, 45),
    Vector2i(14, 46), Vector2i(15, 46), Vector2i(16, 46), Vector2i(17, 46),
]
const STARTER_STONE_CELLS: Array[Vector2i] = [
    Vector2i(19, 44), Vector2i(20, 44), Vector2i(21, 44),
    Vector2i(19, 45), Vector2i(20, 45), Vector2i(21, 45),
    Vector2i(20, 46),
]

@onready var world_layout: WorldLayout = $WorldLayout
@onready var collision_registry: WorldCollisionRegistry = $WorldCollisionRegistry
@onready var world_path_grid: WorldPathGrid = $WorldPathGrid
@onready var interaction_manager: WorldInteractionManager = $WorldInteractionManager
@onready var cursor_manager: CursorStateManager = $CursorStateManager
@onready var pause_coordinator: PauseCoordinator = $PauseCoordinator
@onready var input_router: GameInputRouter = $GameInputRouter
@onready var entities: Node2D = $Entities
@onready var player: PlayerController = $Entities/Player
@onready var mouse_controller: MouseInteractionController = $Entities/Player/MouseInteractionController
@onready var camera_rig: CameraRig = $Entities/Player/Camera2D
@onready var hotbar_ui: HotbarUI = $HUD/HotbarUI
@onready var inventory_ui: InventoryUI = $HUD/InventoryUI
@onready var stats_hud: StatsHUD = $HUD/StatsHUD
@onready var minimap: MiniMap = $HUD/MiniMapFrame/Margin/MiniMap
@onready var action_feedback: ActionFeedback = $HUD/ActionFeedback
@onready var hint_panel: Control = $HUD/HintPanel
@onready var hint_timer: Timer = $HintTimer

var _starters_spawned := false


func _ready() -> void:
    world_layout.build()
    world_path_grid.configure(world_layout.config, collision_registry)
    player.position = world_layout.spawn_position()
    player.position = world_layout.recover_player_position(player.position, Vector2(16, 12))
    player.set_path_grid(world_path_grid)
    camera_rig.configure_world(world_layout.world_rect())
    _bind_player_ui()
    _bind_world_interaction()
    _bind_global_input()
    _bind_hint_timer()
    _spawn_starter_pickups()
    _spawn_critter()

    var route_errors := world_layout.validate_required_routes()
    for route_error in route_errors:
        push_warning(route_error)


func _bind_player_ui() -> void:
    var player_inventory := player.get_node("Inventory") as InventoryModel
    var player_stats := player.get_node("PlayerStats") as PlayerStats
    hotbar_ui.bind(player_inventory)
    inventory_ui.bind(player_inventory)
    stats_hud.bind(player_stats)
    minimap.bind(world_layout.config, player)

    var marker_entries := world_layout.marker_entries()
    for marker_id in marker_entries:
        var marker := marker_entries[marker_id] as Dictionary
        minimap.register_marker(
            StringName(marker_id),
            int(marker.get("category", 0)),
            marker.get("position", Vector2.ZERO) as Vector2
        )


func _bind_world_interaction() -> void:
    var player_inventory := player.get_node("Inventory") as InventoryModel
    mouse_controller.bind(
        player,
        player_inventory,
        world_path_grid,
        cursor_manager
    )
    interaction_manager.bind(
        player,
        player_inventory,
        world_path_grid,
        mouse_controller,
        entities,
        action_feedback
    )


func _bind_global_input() -> void:
    var player_inventory := player.get_node("Inventory") as InventoryModel
    input_router.bind(
        inventory_ui,
        player_inventory,
        camera_rig,
        pause_coordinator
    )
    if not inventory_ui.opened_changed.is_connected(_on_inventory_opened):
        inventory_ui.opened_changed.connect(_on_inventory_opened)
    _on_inventory_opened(inventory_ui.is_open())


func _bind_hint_timer() -> void:
    if not hint_timer.timeout.is_connected(_on_hint_timeout):
        hint_timer.timeout.connect(_on_hint_timeout)


func _on_inventory_opened(opened: bool) -> void:
    player.set_gameplay_input_blocked(opened)
    mouse_controller.set_input_blocked(opened)
    interaction_manager.set_input_blocked(opened)
    hotbar_ui.set_modal_dimmed(opened)
    stats_hud.set_modal_dimmed(opened)
    minimap.set_modal_dimmed(opened)


func _on_hint_timeout() -> void:
    hint_panel.hide()


func _spawn_starter_pickups() -> void:
    if _starters_spawned:
        return
    _starters_spawned = true
    var player_inventory := player.get_node("Inventory") as InventoryModel
    for cell in STARTER_BRANCH_CELLS:
        var pickup := WorldPickupFactory.spawn(
            entities,
            &"branch",
            1,
            world_layout.config.cell_to_world(cell),
            player,
            player_inventory
        )
        _configure_starter_pickup(pickup)
    for cell in STARTER_STONE_CELLS:
        var pickup := WorldPickupFactory.spawn(
            entities,
            &"loose_stone",
            1,
            world_layout.config.cell_to_world(cell),
            player,
            player_inventory
        )
        _configure_starter_pickup(pickup)


func _configure_starter_pickup(pickup: WorldPickup) -> void:
    if pickup == null:
        return
    pickup.add_to_group("starter_pickups")
    if not pickup.pickup_blocked.is_connected(_on_pickup_blocked):
        pickup.pickup_blocked.connect(_on_pickup_blocked)


func _on_pickup_blocked(_item_id: StringName) -> void:
    action_feedback.show_message("背包已满")


func find_first_harvestable(kind: int) -> HarvestableResource:
    for node in get_tree().get_nodes_in_group("harvestables"):
        var resource := node as HarvestableResource
        if (
            resource == null
            or resource.is_depleted()
            or not entities.is_ancestor_of(resource)
        ):
            continue
        var root := resource.get_parent()
        var target := root.get_node_or_null("InteractionTarget") as InteractionTarget
        if target != null and target.kind == kind:
            return resource
    return null


func force_harvest_for_test(resource: HarvestableResource) -> bool:
    if resource == null or resource.is_depleted():
        return false
    var root := resource.get_parent()
    var target := root.get_node_or_null("InteractionTarget") as InteractionTarget
    if target == null:
        return false

    var player_inventory := player.get_node("Inventory") as InventoryModel
    if not _select_tool_for_test(player_inventory, target.required_tool):
        return false

    var path := world_path_grid.find_path(
        player.global_position,
        target.world_target_rect(),
        target.interaction_range
    )
    if path.is_empty():
        return false
    player.global_position = path[path.size() - 1]
    player.velocity = Vector2.ZERO

    if not interaction_manager.begin_interaction(target):
        return false
    if not interaction_manager.complete_current_harvest_for_test():
        return false

    var transferred := false
    for node in get_tree().get_nodes_in_group("resource_drops"):
        var pickup := node as WorldPickup
        if pickup == null or not entities.is_ancestor_of(pickup):
            continue
        if pickup.try_transfer() == 0:
            transferred = true
    return transferred


func _select_tool_for_test(
    player_inventory: InventoryModel,
    tool: ItemDefinition.ToolType
) -> bool:
    for index in player_inventory.quickbar_size:
        var stack := player_inventory.slots[index]
        if stack.is_empty():
            continue
        var definition := ItemCatalog.get_item(stack.item_id)
        if definition != null and definition.tool_type == tool:
            player_inventory.set_selected_slot(index)
            return true
    return false


func _spawn_critter() -> void:
    var using_open_sheet := OpenAssetLibrary.texture_exists(OpenAssetLibrary.PIG_SHEET)
    var texture := OpenAssetLibrary.load_texture(
        OpenAssetLibrary.PIG_SHEET,
        "res://assets/original/world/slime.svg"
    )
    if texture == null:
        return

    var critter := Sprite2D.new()
    critter.name = "PigCritter" if using_open_sheet else "SlimeFallback"
    critter.position = world_layout.config.cell_to_world(Vector2i(50, 29))
    critter.texture = texture
    if using_open_sheet:
        critter.hframes = 2
        critter.vframes = 1
        critter.scale = Vector2(2, 2)
        critter.set_script(VisualCritterScript)
    entities.add_child(critter)
