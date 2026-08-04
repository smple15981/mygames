extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var actor := Node2D.new()
    var request := ActionRequest.new_request(
        actor,
        &"use_item",
        Vector2(10, 20),
        Vector2.RIGHT,
        7
    )
    failures.append(TestAssert.equal(request.sequence_id, 7, "request sequence"))
    failures.append(TestAssert.equal(request.direction, Vector2.RIGHT, "request direction"))

    var fallback_direction := ActionRequest.new_request(
        actor,
        &"use_item",
        Vector2.ZERO,
        Vector2.ZERO,
        8
    )
    failures.append(TestAssert.equal(
        fallback_direction.direction,
        Vector2.DOWN,
        "zero aim fallback"
    ))

    var result := ActionResult.failure(&"no_target")
    failures.append(TestAssert.truthy(not result.ok, "failure result"))
    failures.append(TestAssert.equal(result.reason, &"no_target", "failure reason"))

    var success := ActionResult.success([actor], {"amount": 1})
    failures.append(TestAssert.truthy(success.ok, "success result"))
    failures.append(TestAssert.equal(success.targets.size(), 1, "success targets"))
    failures.append(TestAssert.equal(success.payload.get("amount"), 1, "success payload"))

    var sword := ItemCatalog.get_item(&"wooden_sword")
    failures.append(TestAssert.truthy(sword != null, "wooden sword catalog entry"))
    if sword != null:
        failures.append(TestAssert.equal(sword.base_damage, 12, "wooden sword damage"))
        failures.append(TestAssert.equal(sword.arc_degrees, 90.0, "wooden sword arc"))

    var test_parent := Node2D.new()
    var inventory := InventoryModel.new()
    inventory.name = "Inventory"
    test_parent.add_child(inventory)
    var item_user := ItemUser.new()
    test_parent.add_child(item_user)
    item_user.set_inventory(inventory)
    inventory.add_item(&"wooden_sword", 1)
    var emitted: Array[ActionRequest] = []
    item_user.action_requested.connect(
        func(emitted_request: ActionRequest) -> void:
            emitted.append(emitted_request)
    )
    item_user.request_use(Vector2.RIGHT)
    failures.append(TestAssert.equal(emitted.size(), 1, "item use emitted"))
    if not emitted.is_empty():
        failures.append(TestAssert.equal(emitted[0].item_id, &"wooden_sword", "item use id"))
        failures.append(TestAssert.truthy(emitted[0].sequence_id > 0, "item use sequence"))
        failures.append(TestAssert.equal(emitted[0].direction, Vector2.RIGHT, "item use direction"))

    actor.free()
    test_parent.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
