class_name GameInputRouter
extends Node

const INVENTORY_REASON := &"inventory"

var inventory_ui: InventoryUI
var inventory: InventoryModel
var camera_rig: CameraRig
var pause_coordinator: PauseCoordinator


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func bind(
    view: InventoryUI,
    model: InventoryModel,
    camera: CameraRig,
    pause: PauseCoordinator
) -> void:
    if inventory_ui != null and inventory_ui.opened_changed.is_connected(_on_inventory_opened):
        inventory_ui.opened_changed.disconnect(_on_inventory_opened)
    if pause_coordinator != null:
        pause_coordinator.release(INVENTORY_REASON)

    inventory_ui = view
    inventory = model
    camera_rig = camera
    pause_coordinator = pause

    if inventory_ui != null:
        inventory_ui.opened_changed.connect(_on_inventory_opened)
        _on_inventory_opened(inventory_ui.is_open())


func _input(event: InputEvent) -> void:
    if handle_event(event) and get_viewport() != null:
        get_viewport().set_input_as_handled()


func handle_event(event: InputEvent) -> bool:
    if event == null:
        return false
    if event is InputEventKey and (event as InputEventKey).echo:
        return false

    if event.is_action_pressed("inventory") or _key_pressed(event, KEY_TAB):
        if inventory_ui == null:
            push_error("GameInputRouter missing InventoryUI")
            return true
        inventory_ui.set_open(not inventory_ui.is_open())
        return true

    if event.is_action_pressed("pause") or _key_pressed(event, KEY_ESCAPE):
        if inventory_ui != null and inventory_ui.is_open():
            inventory_ui.set_open(false)
            return true
        return false

    if inventory_ui != null and inventory_ui.is_open():
        return false

    var direct_slot := _number_key_index(event)
    if direct_slot >= 0:
        if inventory != null:
            inventory.set_selected_slot(direct_slot)
        return true

    for index in InventoryModel.QUICKBAR_SIZE:
        if event.is_action_pressed("quick_slot_%d" % (index + 1)):
            if inventory != null:
                inventory.set_selected_slot(index)
            return true

    if event is InputEventMouseButton and event.pressed:
        var mouse := event as InputEventMouseButton
        var direction := 0
        if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
            direction = 1
        elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            direction = -1
        if direction == 0:
            return false

        if mouse.ctrl_pressed and inventory != null:
            inventory.set_selected_slot(
                posmod(inventory.selected_index - direction, inventory.quickbar_size)
            )
        elif camera_rig != null:
            camera_rig.change_zoom_steps(direction)
        return true

    return false


func _on_inventory_opened(opened: bool) -> void:
    if pause_coordinator == null:
        return
    if opened:
        pause_coordinator.acquire(INVENTORY_REASON)
    else:
        pause_coordinator.release(INVENTORY_REASON)


func _key_pressed(event: InputEvent, key: Key) -> bool:
    if not event is InputEventKey:
        return false
    var keyboard := event as InputEventKey
    return (
        keyboard.pressed
        and (keyboard.keycode == key or keyboard.physical_keycode == key)
    )


func _number_key_index(event: InputEvent) -> int:
    if not event is InputEventKey:
        return -1
    var keyboard := event as InputEventKey
    if not keyboard.pressed:
        return -1
    var code := keyboard.keycode if keyboard.keycode != 0 else keyboard.physical_keycode
    match code:
        KEY_1:
            return 0
        KEY_2:
            return 1
        KEY_3:
            return 2
        KEY_4:
            return 3
        KEY_5:
            return 4
        _:
            return -1
