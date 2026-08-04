extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []

    var inventory := InventoryModel.new()
    inventory.add_item(&"branch", 3)
    inventory.add_item(&"loose_stone", 2)
    var axe_recipe := load("res://data/recipes/stone_axe.tres") as RecipeDefinition
    var result := CraftingService.craft(axe_recipe, inventory)
    failures.append(TestAssert.truthy(result.ok, "stone axe craft succeeds"))
    failures.append(TestAssert.equal(inventory.count_item(&"branch"), 0, "branches consumed"))
    failures.append(TestAssert.equal(inventory.count_item(&"loose_stone"), 0, "loose stones consumed"))
    failures.append(TestAssert.equal(inventory.count_item(&"stone_axe"), 1, "axe produced"))

    var missing := InventoryModel.new()
    missing.add_item(&"branch", 2)
    var missing_before := missing.serialize()
    var missing_result := CraftingService.craft(axe_recipe, missing)
    failures.append(TestAssert.truthy(not missing_result.ok, "missing craft rejected"))
    failures.append(TestAssert.equal(missing_result.reason, &"missing_materials", "missing reason"))
    failures.append(TestAssert.equal(missing.serialize(), missing_before, "missing craft atomic"))

    var full := InventoryModel.new()
    full.add_item(&"wood", 99)
    full.add_item(&"slime_gel", 99)
    full.add_item(&"stone_axe", 18)
    var full_before := full.serialize()
    var torch_recipe := load("res://data/recipes/torch.tres") as RecipeDefinition
    var full_result := CraftingService.craft(torch_recipe, full)
    failures.append(TestAssert.truthy(not full_result.ok, "normal full output rejected"))
    failures.append(TestAssert.equal(full_result.reason, &"inventory_full", "full reason"))
    failures.append(TestAssert.equal(full.serialize(), full_before, "full craft atomic"))

    var pending := InventoryModel.new()
    pending.add_item(&"wood", 99)
    pending.add_item(&"stone", 99)
    pending.add_item(&"slime_gel", 99)
    pending.add_item(&"stone_axe", 17)
    var hoe_recipe := load("res://data/recipes/wooden_hoe.tres") as RecipeDefinition
    var pending_result := CraftingService.craft(hoe_recipe, pending)
    failures.append(TestAssert.truthy(pending_result.ok, "key craft succeeds"))
    failures.append(TestAssert.truthy(pending_result.output_pending, "key output pending"))
    failures.append(TestAssert.equal(pending.count_item(&"wood"), 94, "pending wood consumed"))
    failures.append(TestAssert.equal(pending.count_item(&"stone"), 97, "pending stone consumed"))
    failures.append(TestAssert.equal(pending.count_item(&"slime_gel"), 98, "pending gel consumed"))
    failures.append(TestAssert.equal(pending.count_item(&"wooden_hoe"), 0, "pending output not lost into inventory"))

    inventory.free()
    missing.free()
    full.free()
    pending.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
