extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var packed := load("res://scenes/world/prototype_world.tscn") as PackedScene
    failures.append(TestAssert.truthy(packed != null, "prototype world scene loads"))
    if packed == null:
        return failures.filter(func(message: String) -> bool: return not message.is_empty())

    var world := packed.instantiate() as PrototypeWorld
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(world)

    var layout := world.get_node_or_null("WorldLayout") as WorldLayout
    failures.append(TestAssert.truthy(layout != null, "world layout node exists"))
    if layout != null:
        failures.append(TestAssert.equal(
            layout.config.map_size_cells,
            Vector2i(96, 64),
            "large layout"
        ))
        failures.append(TestAssert.equal(
            layout.world_rect().size,
            Vector2(3072, 2048),
            "world bounds"
        ))
        failures.append(TestAssert.equal(
            layout.validate_required_routes().size(),
            0,
            "required routes passable"
        ))

    var registry := world.get_node_or_null("WorldCollisionRegistry") as WorldCollisionRegistry
    var player := world.get_node_or_null("Entities/Player") as PlayerController
    failures.append(TestAssert.truthy(registry != null, "collision registry exists"))
    failures.append(TestAssert.truthy(player != null, "player exists"))
    if registry != null and player != null:
        failures.append(TestAssert.truthy(
            registry.is_position_safe(player.position, Vector2(16, 12)),
            "safe spawn"
        ))
        failures.append(TestAssert.truthy(
            registry.is_position_safe(Vector2(1904, 1008), Vector2(16, 12)),
            "main bridge remains open"
        ))
        failures.append(TestAssert.truthy(
            not registry.is_position_safe(Vector2(1904, 640), Vector2(16, 12)),
            "river blocks non-bridge crossing"
        ))

    if layout != null and registry != null:
        var recovered := layout.recover_player_position(
            Vector2(400, 1376),
            Vector2(16, 12)
        )
        failures.append(TestAssert.truthy(
            registry.is_position_safe(recovered, Vector2(16, 12)),
            "safe recovery"
        ))
        failures.append(TestAssert.truthy(
            layout.boundary_cells().size() >= 150,
            "natural boundary count"
        ))

    var path_grid := world.get_node_or_null("WorldPathGrid")
    var manager := world.get_node_or_null("WorldInteractionManager")
    var cursor := world.get_node_or_null("CursorStateManager")
    var feedback := world.get_node_or_null("HUD/ActionFeedback")
    failures.append(TestAssert.truthy(path_grid != null, "world path grid exists"))
    failures.append(TestAssert.truthy(manager != null, "world interaction manager exists"))
    failures.append(TestAssert.truthy(cursor != null, "cursor state manager exists"))
    failures.append(TestAssert.truthy(feedback != null, "action feedback exists"))

    if player != null and path_grid != null and cursor != null:
        var mouse := player.get_node("MouseInteractionController") as MouseInteractionController
        failures.append(TestAssert.equal(mouse.player, player, "mouse controller player binding"))
        failures.append(TestAssert.equal(mouse.path_grid, path_grid, "mouse controller path binding"))
        failures.append(TestAssert.equal(mouse.cursor_manager, cursor, "mouse controller cursor binding"))
        failures.append(TestAssert.equal(
            player.auto_move_agent.path_grid,
            path_grid,
            "auto move path binding"
        ))

    if manager != null and player != null and path_grid != null:
        failures.append(TestAssert.equal(manager.get("player"), player, "manager player binding"))
        failures.append(TestAssert.equal(manager.get("path_grid"), path_grid, "manager path binding"))

    if feedback != null:
        feedback.call("show_message", "需要石斧")
        failures.append(TestAssert.equal(feedback.get("text"), "需要石斧", "feedback message"))
        failures.append(TestAssert.truthy(feedback.get("visible"), "feedback visible"))

    failures.append(TestAssert.equal(
        scene_tree.get_nodes_in_group("starter_pickups").size(),
        15,
        "starter materials remain available"
    ))

    var starter_resources := scene_tree.get_nodes_in_group("starter_harvestables")
    var starter_tree_count := 0
    var starter_rock_count := 0
    failures.append(TestAssert.equal(starter_resources.size(), 6, "starter harvestable count"))
    if player != null:
        for node in starter_resources:
            var resource := node as HarvestableResource
            failures.append(TestAssert.truthy(resource != null, "starter entry is harvestable"))
            if resource == null:
                continue
            var target := resource.get_parent().get_node_or_null("InteractionTarget") as InteractionTarget
            failures.append(TestAssert.truthy(target != null, "starter harvestable target exists"))
            if target == null:
                continue
            failures.append(TestAssert.truthy(
                resource.get_parent().global_position.distance_to(player.global_position) <= 256.0,
                "starter harvestable near spawn"
            ))
            if target.kind == InteractionTarget.Kind.HARVEST_TREE:
                starter_tree_count += 1
            elif target.kind == InteractionTarget.Kind.HARVEST_ROCK:
                starter_rock_count += 1
    failures.append(TestAssert.equal(starter_tree_count, 3, "three starter trees"))
    failures.append(TestAssert.equal(starter_rock_count, 3, "three starter rocks"))

    if player != null:
        var action_requests := [0]
        player.item_user.action_requested.connect(func(_request: ActionRequest): action_requests[0] += 1)
        var left_click := InputEventMouseButton.new()
        left_click.button_index = MOUSE_BUTTON_LEFT
        left_click.pressed = true
        player._unhandled_input(left_click)
        failures.append(TestAssert.equal(
            action_requests[0],
            0,
            "world left click does not also use selected item"
        ))

    world.free()
    scene_tree.paused = false
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
