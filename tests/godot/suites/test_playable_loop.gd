extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var world_scene := load("res://scenes/world/prototype_world.tscn") as PackedScene
    failures.append(TestAssert.truthy(world_scene != null, "playable world scene loads"))
    if world_scene == null:
        return failures.filter(func(message: String) -> bool: return not message.is_empty())

    var scene_tree := Engine.get_main_loop() as SceneTree
    var world := world_scene.instantiate() as PrototypeWorld
    scene_tree.root.add_child(world)
    await scene_tree.process_frame
    await scene_tree.process_frame

    var inventory := world.player.get_node("Inventory") as InventoryModel
    inventory.add_item(&"branch", 8)
    inventory.add_item(&"loose_stone", 7)

    var axe_recipe := load("res://data/recipes/stone_axe.tres") as RecipeDefinition
    var pick_recipe := load("res://data/recipes/stone_pickaxe.tres") as RecipeDefinition
    var axe_result := CraftingService.craft(axe_recipe, inventory)
    var pick_result := CraftingService.craft(pick_recipe, inventory)
    failures.append(TestAssert.truthy(axe_result.ok, "craft stone axe"))
    failures.append(TestAssert.truthy(pick_result.ok, "craft stone pickaxe"))
    failures.append(TestAssert.equal(inventory.count_item(&"stone_axe"), 1, "axe enters inventory"))
    failures.append(TestAssert.equal(inventory.count_item(&"stone_pickaxe"), 1, "pickaxe enters inventory"))

    var tree_resource := world.find_first_harvestable(InteractionTarget.Kind.HARVEST_TREE)
    failures.append(TestAssert.truthy(tree_resource != null, "find harvestable tree"))
    if tree_resource != null:
        failures.append(TestAssert.truthy(
            world.force_harvest_for_test(tree_resource),
            "force tree through interaction manager"
        ))
        failures.append(TestAssert.truthy(
            inventory.count_item(&"wood") > 0,
            "tree yields wood through pickup"
        ))

    var rock_resource := world.find_first_harvestable(InteractionTarget.Kind.HARVEST_ROCK)
    failures.append(TestAssert.truthy(rock_resource != null, "find harvestable rock"))
    if rock_resource != null:
        failures.append(TestAssert.truthy(
            world.force_harvest_for_test(rock_resource),
            "force rock through interaction manager"
        ))
        failures.append(TestAssert.truthy(
            inventory.count_item(&"stone") > 0,
            "rock yields stone through pickup"
        ))

    failures.append(TestAssert.equal(
        world.get_tree().get_nodes_in_group("resource_drops").size(),
        0,
        "test helper transfers generated drops"
    ))

    world.free()
    scene_tree.paused = false
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
