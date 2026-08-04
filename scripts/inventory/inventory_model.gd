class_name InventoryModel
extends Node

signal changed
signal selected_changed(index: int)

const CAPACITY := 20
const QUICKBAR_SIZE := 5

var slots: Array[InventorySlot] = []
var selected_index := 0
var quickbar_size := QUICKBAR_SIZE


func _init() -> void:
    _reset_slots()


func _reset_slots() -> void:
    slots.clear()
    for _index in CAPACITY:
        slots.append(InventorySlot.new())


func add_item(item_id: StringName, quantity: int) -> int:
    var definition := ItemCatalog.get_item(item_id)
    if definition == null or quantity <= 0:
        return quantity

    var remaining := quantity
    if definition.max_stack > 1:
        for slot in slots:
            if slot.item_id == item_id and slot.quantity < definition.max_stack:
                var moved := mini(remaining, definition.max_stack - slot.quantity)
                slot.quantity += moved
                remaining -= moved
                if remaining == 0:
                    changed.emit()
                    return 0

    for slot in slots:
        if not slot.is_empty():
            continue
        slot.item_id = item_id
        slot.quantity = mini(remaining, definition.max_stack)
        remaining -= slot.quantity
        if remaining == 0:
            changed.emit()
            return 0

    if remaining != quantity:
        changed.emit()
    return remaining


func count_item(item_id: StringName) -> int:
    var total := 0
    for slot in slots:
        if slot.item_id == item_id and not slot.is_empty():
            total += slot.quantity
    return total


func remove_item(item_id: StringName, quantity: int) -> bool:
    if quantity <= 0:
        return false
    if count_item(item_id) < quantity:
        return false

    var remaining := quantity
    for slot in slots:
        if slot.item_id != item_id or slot.is_empty():
            continue
        var removed := mini(slot.quantity, remaining)
        slot.quantity -= removed
        remaining -= removed
        if slot.quantity <= 0:
            slot.clear()
        if remaining == 0:
            changed.emit()
            return true
    return false


func set_selected_slot(index: int) -> void:
    if index < 0 or index >= quickbar_size or index == selected_index:
        return
    selected_index = index
    selected_changed.emit(selected_index)


func selected_stack() -> InventorySlot:
    return slots[selected_index]


func serialize() -> Dictionary:
    var serialized_slots: Array[Dictionary] = []
    for slot in slots:
        serialized_slots.append({
            "item_id": String(slot.item_id),
            "quantity": slot.quantity,
        })
    return {
        "selected_index": selected_index,
        "slots": serialized_slots,
    }


func deserialize(data: Dictionary) -> void:
    _reset_slots()
    var serialized_slots: Array = data.get("slots", [])
    var limit := mini(serialized_slots.size(), CAPACITY)
    for index in limit:
        var raw_slot: Variant = serialized_slots[index]
        if not raw_slot is Dictionary:
            continue
        var slot_data := raw_slot as Dictionary
        var item_id := StringName(str(slot_data.get("item_id", "")))
        var quantity := maxi(0, int(slot_data.get("quantity", 0)))
        var definition := ItemCatalog.get_item(item_id)
        if definition == null or quantity <= 0:
            continue
        slots[index].item_id = item_id
        slots[index].quantity = mini(quantity, definition.max_stack)

    var restored_index := int(data.get("selected_index", 0))
    selected_index = clampi(restored_index, 0, quickbar_size - 1)
    changed.emit()
    selected_changed.emit(selected_index)
