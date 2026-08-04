extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var root := Engine.get_main_loop().root

    var pause := PauseCoordinator.new()
    root.add_child(pause)
    pause.acquire(&"inventory")
    pause.acquire(&"pause_menu")
    pause.release(&"inventory")
    failures.append(TestAssert.truthy(pause.has_reason(&"pause_menu"), "other pause retained"))
    failures.append(TestAssert.truthy(pause.is_paused(), "remaining reason keeps pause"))
    pause.release(&"pause_menu")

    var packed := load("res://scenes/ui/inventory_ui.tscn") as PackedScene
    failures.append(TestAssert.truthy(packed != null, "inventory scene loads for router"))
    if packed == null:
        pause.free()
        return failures.filter(func(message: String) -> bool: return not message.is_empty())

    var inventory := InventoryModel.new()
    inventory.name = "Inventory"
    root.add_child(inventory)
    var inventory_ui := packed.instantiate() as InventoryUI
    root.add_child(inventory_ui)
    inventory_ui.bind(inventory)
    var camera := CameraRig.new()
    root.add_child(camera)
    var router := GameInputRouter.new()
    root.add_child(router)
    router.bind(inventory_ui, inventory, camera, pause)

    var tab := InputEventKey.new()
    tab.keycode = KEY_TAB
    tab.pressed = true
    failures.append(TestAssert.truthy(router.handle_event(tab), "Tab handled"))
    failures.append(TestAssert.truthy(inventory_ui.is_open(), "Tab opens inventory"))
    failures.append(TestAssert.truthy(pause.has_reason(&"inventory"), "inventory owns pause"))

    var escape := InputEventKey.new()
    escape.keycode = KEY_ESCAPE
    escape.pressed = true
    failures.append(TestAssert.truthy(router.handle_event(escape), "Escape handled while inventory open"))
    failures.append(TestAssert.truthy(not inventory_ui.is_open(), "Escape closes inventory"))
    failures.append(TestAssert.truthy(not pause.has_reason(&"inventory"), "inventory pause released"))

    var wheel := InputEventMouseButton.new()
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel.pressed = true
    failures.append(TestAssert.truthy(router.handle_event(wheel), "wheel handled"))
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.125, "wheel zoom"))

    wheel.ctrl_pressed = true
    inventory.set_selected_slot(2)
    failures.append(TestAssert.truthy(router.handle_event(wheel), "Ctrl-wheel handled"))
    failures.append(TestAssert.equal(inventory.selected_index, 1, "Ctrl-wheel quickbar"))

    var slot_five := InputEventKey.new()
    slot_five.keycode = KEY_5
    slot_five.pressed = true
    failures.append(TestAssert.truthy(router.handle_event(slot_five), "number key handled"))
    failures.append(TestAssert.equal(inventory.selected_index, 4, "number key quickbar"))

    router.free()
    camera.free()
    inventory_ui.free()
    inventory.free()
    pause.free()
    root.get_tree().paused = false
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
