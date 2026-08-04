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
    var player := world.get_node_or_null("Entities/Player") as CharacterBody2D
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

    world.free()
    scene_tree.paused = false
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
