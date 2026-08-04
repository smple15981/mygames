extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []

    var tree := WorldPropDefinition.new()
    tree.id = &"tree_small"
    tree.solid = true
    tree.collision_rects = [Rect2(-12, -14, 24, 14)]
    failures.append(TestAssert.equal(tree.validate().size(), 0, "valid tree"))

    var decorative := WorldPropDefinition.new()
    decorative.id = &"flowers"
    decorative.solid = false
    failures.append(TestAssert.equal(decorative.validate().size(), 0, "decorative needs no collision"))

    var broken := WorldPropDefinition.new()
    broken.id = &"broken"
    broken.solid = true
    failures.append(TestAssert.truthy(broken.validate().size() > 0, "solid needs collision"))

    var registry := WorldCollisionRegistry.new()
    registry.configure_world(Rect2(Vector2.ZERO, Vector2(3072, 2048)))
    failures.append(TestAssert.truthy(
        registry.register_rect(&"tree_001:0", Rect2(90, 90, 20, 20)),
        "first instance"
    ))
    failures.append(TestAssert.truthy(
        registry.register_rect(&"tree_002:0", Rect2(130, 90, 20, 20)),
        "second same-type instance"
    ))
    failures.append(TestAssert.truthy(
        not registry.register_rect(&"tree_001:0", Rect2(0, 0, 5, 5)),
        "duplicate instance rejected"
    ))
    failures.append(TestAssert.truthy(
        not registry.is_position_safe(Vector2(100, 100), Vector2(16, 12)),
        "overlap unsafe"
    ))
    failures.append(TestAssert.truthy(
        registry.is_position_safe(Vector2(200, 200), Vector2(16, 12)),
        "clear position safe"
    ))
    var recovered := registry.find_nearest_safe_position(
        Vector2(100, 100),
        Vector2(16, 12),
        Vector2(200, 200)
    )
    failures.append(TestAssert.truthy(
        registry.is_position_safe(recovered, Vector2(16, 12)),
        "unsafe position recovers"
    ))

    var farmhouse := load("res://data/world/props/farmhouse.tres") as WorldPropDefinition
    failures.append(TestAssert.truthy(farmhouse != null, "farmhouse definition loads"))
    if farmhouse != null:
        failures.append(TestAssert.equal(farmhouse.validate().size(), 0, "farmhouse definition valid"))
        var doorway := Rect2(-15, -31, 30, 31)
        for collision_rect in farmhouse.collision_rects:
            failures.append(TestAssert.truthy(
                not collision_rect.intersects(doorway, true),
                "farmhouse doorway remains open"
            ))

    var parent := Node2D.new()
    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    var texture := ImageTexture.create_from_image(image)
    var factory_registry := WorldCollisionRegistry.new()
    factory_registry.configure_world(Rect2(Vector2.ZERO, Vector2(3072, 2048)))
    var prop := WorldPropFactory.spawn_atlas_prop(
        parent,
        texture,
        Rect2i(0, 0, 16, 16),
        tree,
        &"tree_factory_001",
        Vector2(300, 300),
        factory_registry
    )
    failures.append(TestAssert.truthy(prop != null, "factory creates solid prop"))
    if prop != null:
        failures.append(TestAssert.truthy(prop.has_node("Solid"), "solid prop has body"))
        failures.append(TestAssert.truthy(
            not factory_registry.is_position_safe(Vector2(300, 293), Vector2(16, 12)),
            "factory registers base footprint"
        ))

    parent.free()
    registry.free()
    factory_registry.free()
    tree.free()
    decorative.free()
    broken.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
