extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []

    var cursor := CursorStateManager.new()
    failures.append(TestAssert.equal(
        cursor.hotspot_for_state(CursorStateManager.State.DEFAULT),
        Vector2(1, 1),
        "default cursor hotspot"
    ))
    failures.append(TestAssert.equal(
        cursor.hotspot_for_state(CursorStateManager.State.HARVEST_AXE),
        Vector2(4, 20),
        "axe cursor hotspot"
    ))
    failures.append(TestAssert.equal(
        cursor.hotspot_for_state(CursorStateManager.State.HARVEST_PICKAXE),
        Vector2(4, 20),
        "pickaxe cursor hotspot"
    ))
    failures.append(TestAssert.equal(
        cursor.hotspot_for_state(CursorStateManager.State.PICKUP),
        Vector2(10, 10),
        "pickup cursor hotspot"
    ))
    failures.append(TestAssert.equal(
        cursor.hotspot_for_state(CursorStateManager.State.INTERACT),
        Vector2(12, 12),
        "interact cursor hotspot"
    ))
    failures.append(TestAssert.equal(
        cursor.hotspot_for_state(CursorStateManager.State.UNREACHABLE),
        Vector2(12, 12),
        "unreachable cursor hotspot"
    ))
    failures.append(TestAssert.equal(
        cursor.hotspot_for_state(CursorStateManager.State.TOOL_LOCKED),
        Vector2(12, 12),
        "locked cursor hotspot"
    ))

    for state in CursorStateManager.State.values():
        failures.append(TestAssert.truthy(
            ResourceLoader.exists(cursor.resource_path_for_state(state)),
            "cursor resource exists for state %d" % state
        ))

    var controller := MouseInteractionController.new()
    var inventory := InventoryModel.new()
    controller.bind(null, inventory, null, cursor)

    var tree := InteractionTarget.new()
    tree.kind = InteractionTarget.Kind.HARVEST_TREE
    tree.required_tool = ItemDefinition.ToolType.AXE
    failures.append(TestAssert.equal(
        controller.cursor_state_for_target(tree, true),
        CursorStateManager.State.TOOL_LOCKED,
        "tree without axe locked"
    ))

    inventory.add_item(&"stone_axe", 1)
    failures.append(TestAssert.equal(
        controller.cursor_state_for_target(tree, true),
        CursorStateManager.State.HARVEST_AXE,
        "tree with axe cursor"
    ))
    failures.append(TestAssert.equal(
        controller.cursor_state_for_target(tree, false),
        CursorStateManager.State.UNREACHABLE,
        "unreachable tree cursor"
    ))

    var rock := InteractionTarget.new()
    rock.kind = InteractionTarget.Kind.HARVEST_ROCK
    rock.required_tool = ItemDefinition.ToolType.PICKAXE
    failures.append(TestAssert.equal(
        controller.cursor_state_for_target(rock, true),
        CursorStateManager.State.TOOL_LOCKED,
        "rock with axe locked"
    ))

    inventory.remove_item(&"stone_axe", 1)
    inventory.add_item(&"stone_pickaxe", 1)
    failures.append(TestAssert.equal(
        controller.cursor_state_for_target(rock, true),
        CursorStateManager.State.HARVEST_PICKAXE,
        "rock with pickaxe cursor"
    ))

    var pickup := InteractionTarget.new()
    pickup.kind = InteractionTarget.Kind.PICKUP
    failures.append(TestAssert.equal(
        controller.cursor_state_for_target(pickup, true),
        CursorStateManager.State.PICKUP,
        "pickup cursor"
    ))

    var interact := InteractionTarget.new()
    interact.kind = InteractionTarget.Kind.INTERACT
    failures.append(TestAssert.equal(
        controller.cursor_state_for_target(interact, true),
        CursorStateManager.State.INTERACT,
        "interact cursor"
    ))

    var requested: Array[InteractionTarget] = []
    var feedback: Array[String] = []
    controller.target_requested.connect(func(target: InteractionTarget): requested.append(target))
    controller.feedback_requested.connect(func(message: String): feedback.append(message))

    failures.append(TestAssert.truthy(
        controller.handle_target_click(rock, true),
        "valid target click accepted"
    ))
    failures.append(TestAssert.equal(requested, [rock], "valid target emitted"))

    inventory.remove_item(&"stone_pickaxe", 1)
    failures.append(TestAssert.truthy(
        not controller.handle_target_click(rock, true),
        "locked target click rejected"
    ))
    failures.append(TestAssert.equal(feedback[-1], "需要石镐", "pickaxe feedback"))

    inventory.add_item(&"stone_axe", 1)
    failures.append(TestAssert.truthy(
        not controller.handle_target_click(tree, false),
        "unreachable target click rejected"
    ))
    failures.append(TestAssert.equal(feedback[-1], "无法到达", "unreachable feedback"))

    controller.set_input_blocked(true)
    failures.append(TestAssert.truthy(
        not controller.handle_target_click(tree, true),
        "modal state blocks target click"
    ))
    failures.append(TestAssert.equal(cursor.current_state(), CursorStateManager.State.DEFAULT, "modal cursor reset"))

    tree.free()
    rock.free()
    pickup.free()
    interact.free()
    inventory.free()
    controller.free()
    cursor.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
