class_name ActionResult
extends RefCounted

var ok := false
var reason: StringName = &""
var targets: Array[Node] = []
var payload: Dictionary = {}


static func success(hit_targets: Array[Node], data: Dictionary = {}) -> ActionResult:
    var result := ActionResult.new()
    result.ok = true
    result.targets = hit_targets
    result.payload = data
    return result


static func failure(failure_reason: StringName) -> ActionResult:
    var result := ActionResult.new()
    result.reason = failure_reason
    return result
