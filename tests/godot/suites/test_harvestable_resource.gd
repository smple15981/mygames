extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var registry := WorldCollisionRegistry.new()
    registry.configure_world(Rect2(0, 0, 640, 360))
    registry.register_rect(&"tree:0", Rect2(90, 90, 20, 12))

    var resource := HarvestableResource.new()
    resource.configure(
        ItemDefinition.ToolType.AXE,
        3,
        &"wood",
        3,
        registry,
        [&"tree:0"]
    )

    var hit_values: Array[int] = []
    var drops: Array[Dictionary] = []
    resource.hit.connect(func(remaining: int): hit_values.append(remaining))
    resource.depleted.connect(
        func(item_id: StringName, quantity: int, position: Vector2):
            drops.append({
                "item_id": item_id,
                "quantity": quantity,
                "position": position,
            })
    )

    failures.append(TestAssert.truthy(
        not resource.apply_hit(ItemDefinition.ToolType.PICKAXE, 1),
        "wrong tool rejected"
    ))
    failures.append(TestAssert.equal(resource.current_hits(), 3, "wrong tool preserves health"))
    failures.append(TestAssert.truthy(
        not resource.apply_hit(ItemDefinition.ToolType.AXE, 0),
        "zero damage rejected"
    ))

    failures.append(TestAssert.truthy(
        resource.apply_hit(ItemDefinition.ToolType.AXE, 1),
        "first axe hit accepted"
    ))
    resource.apply_hit(ItemDefinition.ToolType.AXE, 1)
    resource.apply_hit(ItemDefinition.ToolType.AXE, 1)
    failures.append(TestAssert.equal(hit_values, [2, 1, 0], "hit sequence"))
    failures.append(TestAssert.truthy(resource.is_depleted(), "resource depletes"))
    failures.append(TestAssert.equal(resource.current_hits(), 0, "depleted health zero"))
    failures.append(TestAssert.truthy(
        not registry.has_footprint(&"tree:0"),
        "depletion removes footprint"
    ))
    failures.append(TestAssert.equal(drops.size(), 1, "depletion emitted once"))
    if drops.size() == 1:
        failures.append(TestAssert.equal(drops[0]["item_id"], &"wood", "drop item"))
        failures.append(TestAssert.equal(drops[0]["quantity"], 3, "drop quantity"))

    failures.append(TestAssert.truthy(
        not resource.apply_hit(ItemDefinition.ToolType.AXE, 1),
        "depleted resource rejects later hits"
    ))
    failures.append(TestAssert.equal(drops.size(), 1, "later hits do not duplicate drops"))

    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    var texture := ImageTexture.create_from_image(image)
    var parent := Node2D.new()
    var tree := load("res://data/world/props/tree_small.tres") as WorldPropDefinition
    var prop := WorldPropFactory.spawn_atlas_prop(
        parent,
        texture,
        Rect2i(0, 0, 16, 16),
        tree,
        &"factory_tree",
        Vector2(240, 180),
        registry
    )
    failures.append(TestAssert.truthy(prop != null, "harvestable prop spawns"))
    if prop != null:
        failures.append(TestAssert.truthy(
            prop.has_node("HarvestableResource"),
            "factory attaches harvest component"
        ))
        var component := prop.get_node("HarvestableResource") as HarvestableResource
        failures.append(TestAssert.equal(component.current_hits(), 3, "factory harvest hits"))
        failures.append(TestAssert.truthy(
            component.can_harvest(ItemDefinition.ToolType.AXE),
            "factory accepts configured tool"
        ))

    resource.free()
    parent.free()
    registry.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
