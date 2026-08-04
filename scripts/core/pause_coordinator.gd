class_name PauseCoordinator
extends Node

signal pause_state_changed(paused: bool)

var _reasons: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _apply_pause_state()


func acquire(reason: StringName) -> void:
    if reason.is_empty():
        return
    var previous := is_paused()
    _reasons[reason] = true
    _sync(previous)


func release(reason: StringName) -> void:
    var previous := is_paused()
    _reasons.erase(reason)
    _sync(previous)


func clear() -> void:
    var previous := is_paused()
    _reasons.clear()
    _sync(previous)


func has_reason(reason: StringName) -> bool:
    return _reasons.has(reason)


func is_paused() -> bool:
    return not _reasons.is_empty()


func reasons() -> Array[StringName]:
    var result: Array[StringName] = []
    for reason in _reasons.keys():
        result.append(StringName(reason))
    return result


func _sync(previous: bool) -> void:
    var current := is_paused()
    _apply_pause_state()
    if current != previous:
        pause_state_changed.emit(current)


func _apply_pause_state() -> void:
    if get_tree() != null:
        get_tree().paused = is_paused()


func _exit_tree() -> void:
    _reasons.clear()
    if get_tree() != null:
        get_tree().paused = false
