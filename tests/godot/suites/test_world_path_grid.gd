extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var config := WorldLayoutConfig.new()
    config.map_size_cells = Vector2i(12, 8)
    config.display_cell_size = Vector2i(32, 32)
    config.river_x_range = Vector2i(99, 100)

    var registry := WorldCollisionRegistry.new()
    registry.configure_world(config.world_rect())
    registry.register_rect(&"wall", Rect2(128, 0, 32, 192))

    var grid := WorldPathGrid.new()
    grid.configure(config, registry)
    var target_rect := Rect2(224, 64, 24, 24)
    var path := grid.find_path(Vector2(80, 80), target_rect, 36.0)

    failures.append(TestAssert.truthy(path.size() > 2, "path exists around blocker"))
    if not path.is_empty():
        failures.append(TestAssert.truthy(
            path[path.size() - 1].distance_to(target_rect.get_center()) <= 68.0,
            "path ends in interaction range"
        ))

    registry.register_rect(&"sealed", Rect2(192, 32, 96, 128))
    failures.append(TestAssert.equal(
        grid.find_path(Vector2(80, 80), target_rect, 36.0).size(),
        0,
        "sealed target unreachable"
    ))

    registry.unregister(&"sealed")
    failures.append(TestAssert.truthy(
        grid.find_path(Vector2(80, 80), target_rect, 36.0).size() > 0,
        "unregister reopens path"
    ))

    failures.append(TestAssert.equal(
        grid.world_to_cell(Vector2(80, 80)),
        Vector2i(2, 2),
        "world to cell"
    ))
    failures.append(TestAssert.equal(
        grid.cell_to_world(Vector2i(2, 2)),
        Vector2(80, 80),
        "cell to world"
    ))

    registry.free()
    grid.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
