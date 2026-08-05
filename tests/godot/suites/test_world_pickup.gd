extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []

    var inventory := InventoryModel.new()
    var pickup := WorldPickup.new()
    pickup.configure(&"wood", 3, null, inventory)
    failures.append(TestAssert.equal(pickup.try_transfer(), 0, "all wood transferred"))
    failures.append(TestAssert.equal(inventory.count_item(&"wood"), 3, "inventory receives wood"))

    var partial_inventory := InventoryModel.new()
    for index in InventoryModel.CAPACITY - 1:
        partial_inventory.slots[index].item_id = &"stone_axe"
        partial_inventory.slots[index].quantity = 1
    partial_inventory.slots[InventoryModel.CAPACITY - 1].item_id = &"wood"
    partial_inventory.slots[InventoryModel.CAPACITY - 1].quantity = 98
    var partial := WorldPickup.new()
    partial.configure(&"wood", 3, null, partial_inventory)
    failures.append(TestAssert.equal(partial.try_transfer(), 2, "partial transfer keeps overflow"))
    failures.append(TestAssert.equal(partial_inventory.count_item(&"wood"), 99, "partial stack fills"))
    failures.append(TestAssert.equal(partial.quantity, 2, "pickup stores remainder"))

    var full_inventory := InventoryModel.new()
    for index in InventoryModel.CAPACITY:
        full_inventory.slots[index].item_id = &"stone_axe"
        full_inventory.slots[index].quantity = 1
    var blocked := WorldPickup.new()
    blocked.configure(&"wood", 2, null, full_inventory)
    failures.append(TestAssert.equal(blocked.try_transfer(), 2, "full inventory retains pickup"))
    failures.append(TestAssert.equal(blocked.quantity, 2, "blocked pickup quantity unchanged"))

    var parent := Node2D.new()
    var spawned := WorldPickupFactory.spawn(
        parent,
        &"branch",
        1,
        Vector2(80, 96),
        null,
        inventory
    )
    failures.append(TestAssert.truthy(spawned != null, "factory spawns pickup"))
    if spawned != null:
        failures.append(TestAssert.equal(spawned.position, Vector2(80, 96), "pickup position"))
        failures.append(TestAssert.truthy(spawned.has_node("PickupArea"), "pickup area exists"))
        var area := spawned.get_node("PickupArea") as Area2D
        failures.append(TestAssert.equal(area.collision_layer, 8, "pickup layer"))
        failures.append(TestAssert.equal(area.collision_mask, 0, "pickup mask"))

    var world_scene := load("res://scenes/world/prototype_world.tscn") as PackedScene
    var root := (Engine.get_main_loop() as SceneTree).root
    var world := world_scene.instantiate() as PrototypeWorld
    root.add_child(world)
    await root.get_tree().process_frame
    await root.get_tree().process_frame
    failures.append(TestAssert.equal(
        world.get_tree().get_nodes_in_group("starter_pickups").size(),
        15,
        "starter pickup count"
    ))
    world.free()

    pickup.free()
    partial.free()
    blocked.free()
    parent.free()
    inventory.free()
    partial_inventory.free()
    full_inventory.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
