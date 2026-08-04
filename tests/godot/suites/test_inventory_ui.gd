extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var packed := load("res://scenes/ui/inventory_ui.tscn") as PackedScene
    failures.append(TestAssert.truthy(packed != null, "inventory UI scene loads"))
    if packed == null:
        return failures.filter(func(message: String) -> bool: return not message.is_empty())

    var ui := packed.instantiate() as InventoryUI
    Engine.get_main_loop().root.add_child(ui)
    var grid := ui.get_node("Margin/Column/Main/InventoryColumn/ItemGrid") as GridContainer
    failures.append(TestAssert.equal(
        grid.get_child_count(),
        InventoryModel.CAPACITY,
        "inventory UI builds twenty slots"
    ))
    ui.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
