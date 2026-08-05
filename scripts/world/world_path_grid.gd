class_name WorldPathGrid
extends Node

const PLAYER_FOOTPRINT := Vector2(16, 12)
const RECT_EPSILON := Vector2(0.001, 0.001)

var config: WorldLayoutConfig
var registry: WorldCollisionRegistry
var astar := AStarGrid2D.new()
var _footprint_cells: Dictionary = {}
var _occupancy_counts: Dictionary = {}


func configure(
    layout_config: WorldLayoutConfig,
    collision_registry: WorldCollisionRegistry
) -> void:
    _disconnect_registry()
    config = layout_config
    registry = collision_registry
    _footprint_cells.clear()
    _occupancy_counts.clear()
    astar = AStarGrid2D.new()

    if config == null or registry == null:
        push_warning("WorldPathGrid requires layout config and collision registry")
        return
    if config.map_size_cells.x <= 0 or config.map_size_cells.y <= 0:
        push_warning("WorldPathGrid rejected invalid map size")
        return

    astar.region = Rect2i(Vector2i.ZERO, config.map_size_cells)
    astar.cell_size = Vector2(config.display_cell_size)
    astar.offset = Vector2(config.display_cell_size) * 0.5
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    astar.update()
    _rebuild_occupancy()

    registry.footprint_registered.connect(_on_footprint_registered)
    registry.footprint_unregistered.connect(_on_footprint_unregistered)
    registry.footprints_cleared.connect(_rebuild_occupancy)


func world_to_cell(position: Vector2) -> Vector2i:
    if config == null:
        return Vector2i(-1, -1)
    return Vector2i(
        floori(position.x / float(config.display_cell_size.x)),
        floori(position.y / float(config.display_cell_size.y))
    )


func cell_to_world(cell: Vector2i) -> Vector2:
    return config.cell_to_world(cell) if config != null else Vector2.ZERO


func is_cell_walkable(cell: Vector2i) -> bool:
    return (
        config != null
        and config.is_inside_cell(cell)
        and not astar.is_point_solid(cell)
    )


func find_path(
    start_world: Vector2,
    target_rect: Rect2,
    interaction_range: float
) -> PackedVector2Array:
    var empty := PackedVector2Array()
    if config == null or registry == null or interaction_range < 0.0:
        return empty

    var start_cell := world_to_cell(start_world)
    if not is_cell_walkable(start_cell):
        return empty

    var best_ids: Array[Vector2i] = []
    var best_target_distance := INF
    for candidate in _candidate_cells(target_rect, interaction_range):
        if not is_cell_walkable(candidate):
            continue
        var ids: Array[Vector2i] = astar.get_id_path(start_cell, candidate, false)
        if ids.is_empty():
            continue
        var candidate_distance := cell_to_world(candidate).distance_to(target_rect.get_center())
        if (
            best_ids.is_empty()
            or ids.size() < best_ids.size()
            or (
                ids.size() == best_ids.size()
                and candidate_distance < best_target_distance
            )
        ):
            best_ids = ids
            best_target_distance = candidate_distance

    if best_ids.is_empty():
        return empty

    var world_path := PackedVector2Array()
    for cell in best_ids:
        world_path.append(cell_to_world(cell))
    return world_path


func _candidate_cells(target_rect: Rect2, interaction_range: float) -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    if config == null:
        return candidates

    var search_rect := target_rect.grow(interaction_range)
    var minimum := world_to_cell(search_rect.position)
    var maximum := world_to_cell(search_rect.end - RECT_EPSILON)
    minimum.x = clampi(minimum.x, 0, config.map_size_cells.x - 1)
    minimum.y = clampi(minimum.y, 0, config.map_size_cells.y - 1)
    maximum.x = clampi(maximum.x, 0, config.map_size_cells.x - 1)
    maximum.y = clampi(maximum.y, 0, config.map_size_cells.y - 1)

    for y in range(minimum.y, maximum.y + 1):
        for x in range(minimum.x, maximum.x + 1):
            var cell := Vector2i(x, y)
            var center := cell_to_world(cell)
            var closest := Vector2(
                clampf(center.x, target_rect.position.x, target_rect.end.x),
                clampf(center.y, target_rect.position.y, target_rect.end.y)
            )
            if center.distance_to(closest) <= interaction_range:
                candidates.append(cell)
    return candidates


func _rebuild_occupancy() -> void:
    if config == null:
        return

    _footprint_cells.clear()
    _occupancy_counts.clear()
    for y in config.map_size_cells.y:
        for x in config.map_size_cells.x:
            var cell := Vector2i(x, y)
            astar.set_point_solid(cell, _is_static_blocked(cell))

    if registry == null:
        return
    var current := registry.footprints()
    for raw_id in current:
        _register_footprint_cells(
            StringName(str(raw_id)),
            current[raw_id] as Rect2
        )


func _register_footprint_cells(id: StringName, rect: Rect2) -> void:
    var cells := _cells_for_rect(rect)
    _footprint_cells[id] = cells
    for cell in cells:
        var count := int(_occupancy_counts.get(cell, 0)) + 1
        _occupancy_counts[cell] = count
        astar.set_point_solid(cell, true)


func _remove_footprint_cells(id: StringName) -> void:
    if not _footprint_cells.has(id):
        return
    var cells := _footprint_cells[id] as Array[Vector2i]
    _footprint_cells.erase(id)
    for cell in cells:
        var count := maxi(0, int(_occupancy_counts.get(cell, 0)) - 1)
        if count == 0:
            _occupancy_counts.erase(cell)
            astar.set_point_solid(cell, _is_static_blocked(cell))
        else:
            _occupancy_counts[cell] = count


func _cells_for_rect(rect: Rect2) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if config == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return cells

    var expanded := rect.grow_individual(
        PLAYER_FOOTPRINT.x * 0.5,
        PLAYER_FOOTPRINT.y * 0.5,
        PLAYER_FOOTPRINT.x * 0.5,
        PLAYER_FOOTPRINT.y * 0.5
    )
    var minimum := world_to_cell(expanded.position)
    var maximum := world_to_cell(expanded.end - RECT_EPSILON)
    minimum.x = clampi(minimum.x, 0, config.map_size_cells.x - 1)
    minimum.y = clampi(minimum.y, 0, config.map_size_cells.y - 1)
    maximum.x = clampi(maximum.x, 0, config.map_size_cells.x - 1)
    maximum.y = clampi(maximum.y, 0, config.map_size_cells.y - 1)

    for y in range(minimum.y, maximum.y + 1):
        for x in range(minimum.x, maximum.x + 1):
            cells.append(Vector2i(x, y))
    return cells


func _is_static_blocked(cell: Vector2i) -> bool:
    return config != null and config.is_water_cell(cell)


func _on_footprint_registered(id: StringName, rect: Rect2) -> void:
    _remove_footprint_cells(id)
    _register_footprint_cells(id, rect)


func _on_footprint_unregistered(id: StringName, _rect: Rect2) -> void:
    _remove_footprint_cells(id)


func _disconnect_registry() -> void:
    if registry == null:
        return
    if registry.footprint_registered.is_connected(_on_footprint_registered):
        registry.footprint_registered.disconnect(_on_footprint_registered)
    if registry.footprint_unregistered.is_connected(_on_footprint_unregistered):
        registry.footprint_unregistered.disconnect(_on_footprint_unregistered)
    if registry.footprints_cleared.is_connected(_rebuild_occupancy):
        registry.footprints_cleared.disconnect(_rebuild_occupancy)
