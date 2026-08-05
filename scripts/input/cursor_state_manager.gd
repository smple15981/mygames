class_name CursorStateManager
extends Node

enum State {
    DEFAULT,
    HARVEST_AXE,
    HARVEST_PICKAXE,
    PICKUP,
    INTERACT,
    UNREACHABLE,
    TOOL_LOCKED,
}

const RESOURCE_PATHS := {
    State.DEFAULT: "res://assets/original/ui/cursors/default.svg",
    State.HARVEST_AXE: "res://assets/original/ui/cursors/axe.svg",
    State.HARVEST_PICKAXE: "res://assets/original/ui/cursors/pickaxe.svg",
    State.PICKUP: "res://assets/original/ui/cursors/pickup.svg",
    State.INTERACT: "res://assets/original/ui/cursors/interact.svg",
    State.UNREACHABLE: "res://assets/original/ui/cursors/unreachable.svg",
    State.TOOL_LOCKED: "res://assets/original/ui/cursors/tool_locked.svg",
}

const HOTSPOTS := {
    State.DEFAULT: Vector2(1, 1),
    State.HARVEST_AXE: Vector2(4, 20),
    State.HARVEST_PICKAXE: Vector2(4, 20),
    State.PICKUP: Vector2(10, 10),
    State.INTERACT: Vector2(12, 12),
    State.UNREACHABLE: Vector2(12, 12),
    State.TOOL_LOCKED: Vector2(12, 12),
}

var _current_state := State.DEFAULT
var _applied_state := -1
var _textures: Dictionary = {}


func _ready() -> void:
    _apply_state()


func set_state(state: int) -> void:
    _current_state = state if RESOURCE_PATHS.has(state) else State.DEFAULT
    if is_inside_tree():
        _apply_state()


func reset() -> void:
    set_state(State.DEFAULT)


func current_state() -> int:
    return _current_state


func resource_path_for_state(state: int) -> String:
    return str(RESOURCE_PATHS.get(state, RESOURCE_PATHS[State.DEFAULT]))


func hotspot_for_state(state: int) -> Vector2:
    return HOTSPOTS.get(state, HOTSPOTS[State.DEFAULT]) as Vector2


func _apply_state() -> void:
    if _applied_state == _current_state:
        return
    var texture := _texture_for_state(_current_state)
    if texture == null:
        return
    Input.set_custom_mouse_cursor(
        texture,
        Input.CURSOR_ARROW,
        hotspot_for_state(_current_state)
    )
    _applied_state = _current_state


func _texture_for_state(state: int) -> Texture2D:
    if _textures.has(state):
        return _textures[state] as Texture2D
    var texture := load(resource_path_for_state(state)) as Texture2D
    if texture != null:
        _textures[state] = texture
    return texture
