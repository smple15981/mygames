class_name AutoMoveAgent
extends Node

signal arrived
signal cancelled(reason: StringName)

@export_range(1.0, 24.0, 0.5) var waypoint_tolerance := 6.0
@export_range(0.1, 3.0, 0.05) var stuck_timeout := 0.75
@export_range(0.1, 8.0, 0.1) var movement_epsilon := 1.0
@export_range(0, 8, 1) var maximum_replans := 2

var actor: Node2D
var path_grid: WorldPathGrid
var target: InteractionTarget
var _path := PackedVector2Array()
var _path_index := 0
var _active := false
var _last_position := Vector2.ZERO
var _stuck_elapsed := 0.0
var _replans := 0


func bind(actor_node: Node2D, grid: WorldPathGrid) -> void:
    actor = actor_node
    path_grid = grid


func request_move(interaction_target: InteractionTarget) -> bool:
    if (
        actor == null
        or path_grid == null
        or interaction_target == null
        or not is_instance_valid(interaction_target)
    ):
        return false
    var candidate := path_grid.find_path(
        actor.global_position,
        interaction_target.world_target_rect(),
        interaction_target.interaction_range
    )
    if candidate.is_empty():
        cancel(&"unreachable")
        return false
    target = interaction_target
    _start_path(candidate, actor.global_position, true)
    return true


func set_path_for_test(path: PackedVector2Array, current_position: Vector2) -> void:
    target = null
    _start_path(path, current_position, true)


func next_direction(current_position: Vector2, delta: float) -> Vector2:
    if not _active:
        return Vector2.ZERO

    _advance_reached_waypoints(current_position)
    if not _active:
        return Vector2.ZERO

    if current_position.distance_to(_last_position) <= movement_epsilon:
        _stuck_elapsed += delta
    else:
        _last_position = current_position
        _stuck_elapsed = 0.0

    if _stuck_elapsed >= stuck_timeout:
        if not _try_replan(current_position):
            cancel(&"stuck")
            return Vector2.ZERO

    var waypoint := _path[_path_index]
    var direction := current_position.direction_to(waypoint)
    return direction if not direction.is_zero_approx() else Vector2.ZERO


func cancel(reason: StringName = &"cancelled") -> void:
    if not _active:
        return
    _active = false
    _path.clear()
    _path_index = 0
    _stuck_elapsed = 0.0
    target = null
    cancelled.emit(reason)


func is_active() -> bool:
    return _active


func current_path() -> PackedVector2Array:
    return _path.duplicate()


func _start_path(
    path: PackedVector2Array,
    current_position: Vector2,
    reset_replans: bool
) -> void:
    _path = path.duplicate()
    _path_index = 0
    _active = not _path.is_empty()
    _last_position = current_position
    _stuck_elapsed = 0.0
    if reset_replans:
        _replans = 0
    if _active:
        _advance_reached_waypoints(current_position)


func _advance_reached_waypoints(current_position: Vector2) -> void:
    while _path_index < _path.size():
        if current_position.distance_to(_path[_path_index]) > waypoint_tolerance:
            break
        _path_index += 1

    if _path_index >= _path.size():
        _active = false
        _path.clear()
        _path_index = 0
        _stuck_elapsed = 0.0
        target = null
        arrived.emit()


func _try_replan(current_position: Vector2) -> bool:
    if (
        target == null
        or not is_instance_valid(target)
        or path_grid == null
        or _replans >= maximum_replans
    ):
        return false
    _replans += 1
    var replacement := path_grid.find_path(
        current_position,
        target.world_target_rect(),
        target.interaction_range
    )
    if replacement.is_empty():
        return false
    _start_path(replacement, current_position, false)
    return true
