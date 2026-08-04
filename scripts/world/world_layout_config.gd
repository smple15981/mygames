class_name WorldLayoutConfig
extends Resource

@export var map_size_cells := Vector2i(96, 64)
@export var display_cell_size := Vector2i(32, 32)
@export var player_spawn_cell := Vector2i(16, 46)
@export var river_x_range := Vector2i(58, 61)
@export var bridge_y_ranges: Array[Vector2i] = [Vector2i(30, 33), Vector2i(45, 47)]

const FARMSTEAD := Rect2i(4, 36, 28, 24)
const MEADOW := Rect2i(24, 18, 42, 32)
const STONEFIELD := Rect2i(66, 20, 26, 39)
const WHISPERWOOD := Rect2i(6, 3, 70, 21)


func world_size_pixels() -> Vector2i:
    return Vector2i(
        map_size_cells.x * display_cell_size.x,
        map_size_cells.y * display_cell_size.y
    )


func world_rect() -> Rect2:
    return Rect2(Vector2.ZERO, Vector2(world_size_pixels()))


func cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(
        cell.x * display_cell_size.x + display_cell_size.x * 0.5,
        cell.y * display_cell_size.y + display_cell_size.y * 0.5
    )


func world_to_normalized(position: Vector2) -> Vector2:
    var size := Vector2(world_size_pixels())
    if size.x <= 0.0 or size.y <= 0.0:
        push_warning("WorldLayoutConfig has invalid world size")
        return Vector2.ZERO
    return Vector2(
        clampf(position.x / size.x, 0.0, 1.0),
        clampf(position.y / size.y, 0.0, 1.0)
    )


func normalized_to_minimap(position: Vector2, minimap_size: Vector2) -> Vector2:
    return world_to_normalized(position) * minimap_size


func is_inside_cell(cell: Vector2i) -> bool:
    return (
        cell.x >= 0
        and cell.y >= 0
        and cell.x < map_size_cells.x
        and cell.y < map_size_cells.y
    )


func is_bridge_cell(cell: Vector2i) -> bool:
    if cell.x < river_x_range.x or cell.x > river_x_range.y:
        return false
    for rows in bridge_y_ranges:
        if cell.y >= rows.x and cell.y <= rows.y:
            return true
    return false


func is_water_cell(cell: Vector2i) -> bool:
    return (
        is_inside_cell(cell)
        and cell.x >= river_x_range.x
        and cell.x <= river_x_range.y
        and not is_bridge_cell(cell)
    )
