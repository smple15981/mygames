extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []

    var tree := load("res://data/world/props/tree_small.tres") as WorldPropDefinition
    failures.append(TestAssert.truthy(tree != null, "tree definition loads"))
    if tree != null:
        failures.append(TestAssert.equal(
            tree.interaction_kind,
            InteractionTarget.Kind.HARVEST_TREE,
            "tree kind"
        ))
        failures.append(TestAssert.equal(
            tree.required_tool,
            ItemDefinition.ToolType.AXE,
            "tree tool"
        ))
        failures.append(TestAssert.equal(tree.harvest_hits, 3, "tree hits"))
        failures.append(TestAssert.equal(tree.drop_item_id, &"wood", "tree drop"))
        failures.append(TestAssert.equal(tree.drop_quantity, 3, "tree drop quantity"))

    var cluster := load("res://data/world/props/tree_cluster.tres") as WorldPropDefinition
    failures.append(TestAssert.truthy(cluster != null, "tree cluster definition loads"))
    if cluster != null:
        failures.append(TestAssert.equal(cluster.harvest_hits, 5, "cluster hits"))
        failures.append(TestAssert.equal(cluster.interaction_range, 48.0, "cluster range"))

    var rock := load("res://data/world/props/rock_cluster.tres") as WorldPropDefinition
    failures.append(TestAssert.truthy(rock != null, "rock definition loads"))
    if rock != null:
        failures.append(TestAssert.equal(
            rock.interaction_kind,
            InteractionTarget.Kind.HARVEST_ROCK,
            "rock kind"
        ))
        failures.append(TestAssert.equal(
            rock.required_tool,
            ItemDefinition.ToolType.PICKAXE,
            "rock tool"
        ))
        failures.append(TestAssert.equal(rock.harvest_hits, 4, "rock hits"))
        failures.append(TestAssert.equal(rock.drop_item_id, &"stone", "rock drop"))

    var target := InteractionTarget.new()
    target.target_rect = Rect2(-12, -20, 24, 20)
    target.position = Vector2(100, 120)
    failures.append(TestAssert.equal(
        target.world_target_rect(),
        Rect2(88, 100, 24, 20),
        "world target rect"
    ))

    var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color.WHITE)
    var texture := ImageTexture.create_from_image(image)
    var parent := Node2D.new()
    var registry := WorldCollisionRegistry.new()
    registry.configure_world(Rect2(0, 0, 640, 360))
    var prop := WorldPropFactory.spawn_atlas_prop(
        parent,
        texture,
        Rect2i(0, 0, 16, 16),
        tree,
        &"interactive_tree",
        Vector2(120, 160),
        registry
    )
    failures.append(TestAssert.truthy(prop != null, "interactive prop spawns"))
    if prop != null:
        failures.append(TestAssert.truthy(
            prop.has_node("InteractionTarget"),
            "prop has interaction target"
        ))
        failures.append(TestAssert.truthy(
            prop.has_node("Highlight"),
            "prop has highlight"
        ))
        var spawned_target := prop.get_node("InteractionTarget") as InteractionTarget
        failures.append(TestAssert.equal(
            spawned_target.collision_layer,
            4,
            "interaction target layer"
        ))
        failures.append(TestAssert.equal(spawned_target.collision_mask, 0, "interaction target mask"))

    target.free()
    parent.free()
    registry.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
