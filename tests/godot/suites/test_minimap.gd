extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var packed := load("res://scenes/ui/minimap.tscn") as PackedScene
    failures.append(TestAssert.truthy(packed != null, "minimap scene loads"))
    if packed == null:
        return failures.filter(func(message: String) -> bool: return not message.is_empty())

    var frame := packed.instantiate() as PanelContainer
    var scene_tree := Engine.get_main_loop() as SceneTree
    scene_tree.root.add_child(frame)
    var minimap := frame.get_node("Margin/MiniMap") as MiniMap
    var config := WorldLayoutConfig.new()
    var player := Node2D.new()
    scene_tree.root.add_child(player)
    minimap.bind(config, player)

    player.global_position = Vector2.ZERO
    failures.append(TestAssert.equal(minimap.player_marker_position(), Vector2.ZERO, "player map origin"))
    player.global_position = Vector2(1536, 1024)
    failures.append(TestAssert.equal(minimap.player_marker_position(), Vector2(80, 80), "player map center"))
    player.global_position = Vector2(3072, 2048)
    failures.append(TestAssert.equal(minimap.player_marker_position(), Vector2(160, 160), "player map end"))

    failures.append(TestAssert.truthy(
        minimap.register_marker(
            &"farmhouse",
            WorldPropDefinition.MarkerCategory.FARMHOUSE,
            Vector2(400, 1392)
        ),
        "register farmhouse"
    ))
    failures.append(TestAssert.truthy(minimap.has_marker(&"farmhouse"), "farmhouse marker exists"))
    failures.append(TestAssert.truthy(
        not minimap.register_marker(
            &"farmhouse",
            WorldPropDefinition.MarkerCategory.FARMHOUSE,
            Vector2.ZERO
        ),
        "duplicate marker rejected"
    ))
    minimap.unregister_marker(&"farmhouse")
    failures.append(TestAssert.truthy(not minimap.has_marker(&"farmhouse"), "farmhouse marker removed"))

    var bridge_rect := minimap.cell_rect_to_map(Rect2i(58, 30, 4, 4))
    failures.append(TestAssert.equal(bridge_rect.size.y, 10.0, "bridge minimap height"))
    failures.append(TestAssert.truthy(bridge_rect.size.x > 6.6, "bridge minimap width"))

    var world_packed := load("res://scenes/world/prototype_world.tscn") as PackedScene
    failures.append(TestAssert.truthy(world_packed != null, "world scene loads for HUD contract"))
    if world_packed != null:
        var world := world_packed.instantiate()
        scene_tree.root.add_child(world)
        failures.append(TestAssert.truthy(world.has_node("HUD/StatsHUD"), "world has stats HUD"))
        failures.append(TestAssert.truthy(world.has_node("HUD/MiniMapFrame"), "world has minimap frame"))
        world.free()

    player.free()
    frame.free()
    scene_tree.paused = false
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
