class_name WorldPickupFactory
extends RefCounted


static func spawn(
    parent: Node2D,
    item_id: StringName,
    quantity: int,
    world_position: Vector2,
    player: Node2D,
    inventory: InventoryModel
) -> WorldPickup:
    if (
        parent == null
        or item_id.is_empty()
        or quantity <= 0
        or ItemCatalog.get_item(item_id) == null
    ):
        return null

    var pickup := WorldPickup.new()
    pickup.name = "WorldPickup_%s_%d" % [item_id, parent.get_child_count()]
    pickup.position = world_position
    pickup.z_as_relative = true
    pickup.configure(item_id, quantity, player, inventory)
    parent.add_child(pickup)
    return pickup
