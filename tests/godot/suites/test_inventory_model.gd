extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var inventory := InventoryModel.new()
    failures.append(TestAssert.equal(inventory.slots.size(), 20, "slot count"))
    failures.append(TestAssert.equal(inventory.quickbar_size, 5, "quickbar size"))

    var remainder := inventory.add_item(&"branch", 120)
    failures.append(TestAssert.equal(remainder, 0, "branch add remainder"))
    failures.append(TestAssert.equal(inventory.count_item(&"branch"), 120, "branch count"))
    failures.append(TestAssert.equal(inventory.slots[0].quantity, 99, "first stack capped"))
    failures.append(TestAssert.equal(inventory.slots[1].quantity, 21, "second stack remainder"))

    failures.append(TestAssert.truthy(
        inventory.remove_item(&"branch", 20),
        "remove available items"
    ))
    failures.append(TestAssert.equal(inventory.count_item(&"branch"), 100, "count after remove"))

    var before_failed_remove := inventory.serialize()
    failures.append(TestAssert.truthy(
        not inventory.remove_item(&"branch", 101),
        "reject unavailable remove"
    ))
    failures.append(TestAssert.equal(
        inventory.serialize(),
        before_failed_remove,
        "failed remove is atomic"
    ))

    inventory.set_selected_slot(4)
    failures.append(TestAssert.equal(inventory.selected_index, 4, "selected slot"))
    inventory.set_selected_slot(20)
    failures.append(TestAssert.equal(inventory.selected_index, 4, "invalid selection ignored"))

    var round_trip := InventoryModel.new()
    round_trip.deserialize(inventory.serialize())
    failures.append(TestAssert.equal(round_trip.count_item(&"branch"), 100, "round-trip count"))
    failures.append(TestAssert.equal(round_trip.selected_index, 4, "round-trip selection"))

    var full := InventoryModel.new()
    failures.append(TestAssert.equal(full.add_item(&"stone_axe", 20), 0, "fill with tools"))
    failures.append(TestAssert.equal(full.add_item(&"wood", 1), 1, "full inventory remainder"))

    inventory.free()
    round_trip.free()
    full.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
