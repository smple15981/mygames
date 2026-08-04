class_name CraftingService
extends RefCounted


static func craft(recipe: RecipeDefinition, inventory: InventoryModel) -> CraftingResult:
    if recipe == null or inventory == null:
        return CraftingResult.failure(&"invalid_request")
    if ItemCatalog.get_item(recipe.output_item_id) == null or recipe.output_quantity <= 0:
        return CraftingResult.failure(&"invalid_recipe")

    for raw_item_id in recipe.ingredients:
        var item_id := StringName(str(raw_item_id))
        var required := int(recipe.ingredients[raw_item_id])
        if required <= 0 or ItemCatalog.get_item(item_id) == null:
            return CraftingResult.failure(&"invalid_recipe")
        if inventory.count_item(item_id) < required:
            return CraftingResult.failure(&"missing_materials")

    var simulated := InventoryModel.new()
    simulated.deserialize(inventory.serialize())
    for raw_item_id in recipe.ingredients:
        var item_id := StringName(str(raw_item_id))
        var required := int(recipe.ingredients[raw_item_id])
        if not simulated.remove_item(item_id, required):
            simulated.free()
            return CraftingResult.failure(&"missing_materials")

    var simulated_remainder := simulated.add_item(
        recipe.output_item_id,
        recipe.output_quantity
    )
    simulated.free()
    if simulated_remainder > 0 and not recipe.key_recipe:
        return CraftingResult.failure(&"inventory_full")

    for raw_item_id in recipe.ingredients:
        var item_id := StringName(str(raw_item_id))
        var required := int(recipe.ingredients[raw_item_id])
        var removed := inventory.remove_item(item_id, required)
        assert(removed)

    var real_remainder := inventory.add_item(
        recipe.output_item_id,
        recipe.output_quantity
    )
    return CraftingResult.success(
        recipe.output_item_id,
        real_remainder if real_remainder > 0 else recipe.output_quantity,
        real_remainder > 0
    )
