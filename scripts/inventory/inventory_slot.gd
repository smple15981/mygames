class_name InventorySlot
extends Resource

@export var item_id: StringName = &""
@export_range(0, 999, 1) var quantity := 0


func is_empty() -> bool:
    return item_id.is_empty() or quantity <= 0


func clear() -> void:
    item_id = &""
    quantity = 0


func duplicate_slot() -> InventorySlot:
    var copy := InventorySlot.new()
    copy.item_id = item_id
    copy.quantity = quantity
    return copy
