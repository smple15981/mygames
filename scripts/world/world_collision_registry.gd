class_name WorldCollisionRegistry
extends Node

@export_range(1.0, 128.0, 1.0) var search_step := 16.0
@export_range(1, 64, 1) var search_rings := 16

var _footprints: Dictionary = {}
var _world_rect := Rect2(Vector2.ZERO, Vector2(1280, 768))


func configure_world(rect: Rect2) -> void:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        push_warning("WorldCollisionRegistry rejected invalid world bounds")
        return
    _world_rect = rect


func world_rect() -> Rect2:
    return _world_rect


func register_rect(id: StringName, rect: Rect2) -> bool:
    if id.is_empty():
        return false
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return false
    if _footprints.has(id):
        return false
    _footprints[id] = rect
    return true


func unregister(id: StringName) -> void:
    _footprints.erase(id)


func clear() -> void:
    _footprints.clear()


func has_footprint(id: StringName) -> bool:
    return _footprints.has(id)


func footprint_count() -> int:
    return _footprints.size()


func footprints() -> Dictionary:
    return _footprints.duplicate()


func overlaps_rect(rect: Rect2) -> bool:
    for value in _footprints.values():
        var footprint := value as Rect2
        if footprint.intersects(rect, true):
            return true
    return false


func is_position_safe(position: Vector2, player_size: Vector2) -> bool:
    if player_size.x <= 0.0 or player_size.y <= 0.0:
        return false
    var footprint := Rect2(position - player_size * 0.5, player_size)
    return _world_rect.encloses(footprint) and not overlaps_rect(footprint)


func find_nearest_safe_position(
    requested: Vector2,
    player_size: Vector2,
    fallback: Vector2
) -> Vector2:
    if is_position_safe(requested, player_size):
        return requested

    for ring in range(1, search_rings + 1):
        var radius := float(ring) * search_step
        var offsets: Array[Vector2] = [
            Vector2(radius, 0.0),
            Vector2(-radius, 0.0),
            Vector2(0.0, radius),
            Vector2(0.0, -radius),
            Vector2(radius, radius),
            Vector2(-radius, radius),
            Vector2(radius, -radius),
            Vector2(-radius, -radius),
        ]
        for offset in offsets:
            var candidate := requested + offset
            if is_position_safe(candidate, player_size):
                return candidate

    if is_position_safe(fallback, player_size):
        return fallback
    var center := _world_rect.get_center()
    return center if is_position_safe(center, player_size) else requested
