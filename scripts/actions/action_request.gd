class_name ActionRequest
extends RefCounted

var actor: Node2D
var action_id: StringName
var origin: Vector2
var direction: Vector2
var sequence_id: int
var item_id: StringName = &""
var damage: int = 0
var range: float = 0.0
var arc_degrees: float = 0.0
var tool_type: int = 0
var tool_level: int = 0
var strength: int = 0


static func new_request(
    source: Node2D,
    requested_action: StringName,
    world_origin: Vector2,
    aim_direction: Vector2,
    requested_sequence: int
) -> ActionRequest:
    var request := ActionRequest.new()
    request.actor = source
    request.action_id = requested_action
    request.origin = world_origin
    request.direction = (
        aim_direction.normalized()
        if not aim_direction.is_zero_approx()
        else Vector2.DOWN
    )
    request.sequence_id = requested_sequence
    return request
