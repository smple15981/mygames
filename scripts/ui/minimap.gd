class_name MiniMap
extends Control

const MAP_SIZE := Vector2(160, 160)
const COLOR_GRASS := Color("#486f43")
const COLOR_FARMSTEAD := Color("#8b6b42")
const COLOR_MEADOW := Color("#5e8a50")
const COLOR_STONEFIELD := Color("#747b78")
const COLOR_WHISPERWOOD := Color("#315d38")
const COLOR_PATH := Color("#b58a59")
const COLOR_WATER := Color("#3e86a8")
const COLOR_FARMLAND := Color("#70452f")
const COLOR_PLAYER := Color("#ffe5a3")

var config: WorldLayoutConfig
var player: Node2D
var _markers: Dictionary = {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = MAP_SIZE
    queue_redraw()


func _process(_delta: float) -> void:
    if player != null:
        queue_redraw()


func bind(layout_config: WorldLayoutConfig, player_target: Node2D) -> void:
    config = layout_config
    player = player_target
    queue_redraw()


func register_marker(
    id: StringName,
    category: WorldPropDefinition.MarkerCategory,
    world_position: Vector2
) -> bool:
    if id.is_empty() or category == WorldPropDefinition.MarkerCategory.NONE:
        return false
    if _markers.has(id):
        return false
    _markers[id] = {
        "category": int(category),
        "position": world_position,
    }
    queue_redraw()
    return true


func unregister_marker(id: StringName) -> void:
    _markers.erase(id)
    queue_redraw()


func has_marker(id: StringName) -> bool:
    return _markers.has(id)


func marker_count() -> int:
    return _markers.size()


func player_marker_position() -> Vector2:
    if config == null or player == null:
        return Vector2.ZERO
    return config.normalized_to_minimap(player.global_position, MAP_SIZE)


func marker_map_position(id: StringName) -> Vector2:
    if config == null or not _markers.has(id):
        return Vector2.ZERO
    var marker := _markers[id] as Dictionary
    return config.normalized_to_minimap(marker.get("position", Vector2.ZERO), MAP_SIZE)


func cell_rect_to_map(cell_rect: Rect2i) -> Rect2:
    if config == null:
        return Rect2()
    var world_position := Vector2(
        cell_rect.position.x * config.display_cell_size.x,
        cell_rect.position.y * config.display_cell_size.y
    )
    var world_end := Vector2(
        cell_rect.end.x * config.display_cell_size.x,
        cell_rect.end.y * config.display_cell_size.y
    )
    var map_position := config.normalized_to_minimap(world_position, MAP_SIZE)
    var map_end := config.normalized_to_minimap(world_end, MAP_SIZE)
    return Rect2(map_position, map_end - map_position)


func set_modal_dimmed(dimmed: bool) -> void:
    modulate = Color(1.0, 1.0, 1.0, 0.55 if dimmed else 1.0)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), COLOR_GRASS)
    if config == null:
        return

    _draw_cell_rect(WorldLayoutConfig.FARMSTEAD, COLOR_FARMSTEAD)
    _draw_cell_rect(WorldLayoutConfig.MEADOW, COLOR_MEADOW)
    _draw_cell_rect(WorldLayoutConfig.STONEFIELD, COLOR_STONEFIELD)
    _draw_cell_rect(WorldLayoutConfig.WHISPERWOOD, COLOR_WHISPERWOOD)

    _draw_cell_rect(Rect2i(17, 0, 3, 64), COLOR_PATH)
    _draw_cell_rect(Rect2i(0, 31, 96, 3), COLOR_PATH)
    _draw_cell_rect(Rect2i(58, 0, 4, 64), COLOR_WATER)
    _draw_cell_rect(Rect2i(58, 30, 4, 4), COLOR_PATH)
    _draw_cell_rect(Rect2i(58, 45, 4, 3), COLOR_PATH)
    _draw_cell_rect(Rect2i(8, 48, 13, 10), COLOR_FARMLAND)

    for marker_value in _markers.values():
        var marker := marker_value as Dictionary
        var category := int(marker.get("category", 0))
        var world_position := marker.get("position", Vector2.ZERO) as Vector2
        _draw_marker(
            config.normalized_to_minimap(world_position, MAP_SIZE),
            category
        )

    if player != null:
        _draw_player(player_marker_position())


func _draw_cell_rect(cell_rect: Rect2i, color: Color) -> void:
    draw_rect(cell_rect_to_map(cell_rect), color)


func _draw_marker(position: Vector2, category: int) -> void:
    var p := Vector2(
        clampf(position.x, 3.0, MAP_SIZE.x - 3.0),
        clampf(position.y, 3.0, MAP_SIZE.y - 3.0)
    )
    match category:
        WorldPropDefinition.MarkerCategory.FARMHOUSE:
            draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("#f4d06f"))
            draw_line(p + Vector2(-4, -3), p + Vector2(0, -7), Color("#f4d06f"), 2.0)
            draw_line(p + Vector2(0, -7), p + Vector2(4, -3), Color("#f4d06f"), 2.0)
        WorldPropDefinition.MarkerCategory.WORKSHOP:
            draw_colored_polygon(
                PackedVector2Array([
                    p + Vector2(0, -5),
                    p + Vector2(5, 0),
                    p + Vector2(0, 5),
                    p + Vector2(-5, 0),
                ]),
                Color("#d7b45a")
            )
        WorldPropDefinition.MarkerCategory.FARM_PLOT:
            draw_rect(Rect2(p - Vector2(3, 2), Vector2(6, 4)), Color("#8f5d35"))
        WorldPropDefinition.MarkerCategory.OBJECTIVE:
            draw_colored_polygon(
                PackedVector2Array([
                    p + Vector2(0, -5),
                    p + Vector2(4, 0),
                    p + Vector2(0, 5),
                    p + Vector2(-4, 0),
                ]),
                Color("#fff0a0")
            )


func _draw_player(position: Vector2) -> void:
    var p := Vector2(
        clampf(position.x, 4.0, MAP_SIZE.x - 4.0),
        clampf(position.y, 4.0, MAP_SIZE.y - 4.0)
    )
    draw_colored_polygon(
        PackedVector2Array([
            p + Vector2(0, -6),
            p + Vector2(5, 5),
            p,
            p + Vector2(-5, 5),
        ]),
        COLOR_PLAYER
    )
