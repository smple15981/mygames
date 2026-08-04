class_name CraftingResult
extends RefCounted

var ok := false
var reason: StringName = &""
var output_pending := false
var output_item_id: StringName = &""
var output_quantity := 0


static func success(
    item_id: StringName,
    quantity: int,
    pending: bool = false
) -> CraftingResult:
    var result := CraftingResult.new()
    result.ok = true
    result.output_pending = pending
    result.output_item_id = item_id
    result.output_quantity = quantity
    return result


static func failure(failure_reason: StringName) -> CraftingResult:
    var result := CraftingResult.new()
    result.reason = failure_reason
    return result
