class_name WorldLayout
extends Node2D

signal world_built

enum GroundTile {
    GRASS,
    PATH,
    SOIL,
    WATER,
    STONE,
}

const SOURCE_TILE_SIZE := Vector2i(16, 16)
const DISPLAY_SCALE := 2.0
const OPEN_SOURCE_ID := 0
const FALLBACK_SOURCE_ID := 1
const WATER_SOURCE_ID := 2

const FARMHOUSE_CELL := Vector2i(12, 43)
const WORKSHOP_CELL := Vector2i(24, 43)
const FARM_FENCE_CELL := Vector2i(14, 50)
const TREE_CELLS: Array[Vector2i] = [
    Vector2i(5, 7),
    Vector2i(11, 8),
    Vector2i(18, 6),
    Vector2i(25, 10),
    Vector2i(33, 7),
    Vector2i(41, 11),
    Vector2i(49, 8),
    Vector2i(55, 14),
    Vector2i(7, 25),
    Vector2i(10, 31),
    Vector2i(84, 8),
    Vector2i(90, 15),
]
const ROCK_CELLS: Array[Vector2i] = [
    Vector2i(70, 27),
    Vector2i(76, 31),
    Vector2i(83, 25),
    Vector2i(88, 38),
    Vector2i(72, 48),
    Vector2i(84, 54),
]
const ROUTE_CELLS: Array[Vector2i] = [
    Vector2i(16, 46),
    Vector2i(18, 32),
    Vector2i(40, 32),
    Vector2i(59, 31),
    Vector2i(72, 31),
    Vector2i(42, 18),
]

const FARMHOUSE_PATH := "res://data/world/props/farmhouse.tres"
const WORKSHOP_PATH := "res://data/world/props/workshop.tres"
const TREE_SMALL_PATH := "res://data/world/props/tree_small.tres"
const TREE_CLUSTER_PATH := "res://data/world/props/tree_cluster.tres"
const ROCK_CLUSTER_PATH := "res://data/world/props/rock_cluster.tres"
const FENCE_HORIZONTAL_PATH := "res://data/world/props/fence_horizontal.tres"

@export var config: WorldLayoutConfig
@export var ground_path := NodePath("../Ground")
@export var entities_path := NodePath("../Entities")
@export var registry_path := NodePath("../WorldCollisionRegistry")

var ground: TileMapLayer
var entities: Node2D
var registry: WorldCollisionRegistry
var _using_open_floor := false
var _open_floor_coordinates: Dictionary = {}
var _definitions: Dictionary = {}
var _markers: Dictionary = {}
var _built := false


func _ready() -> void:
    _resolve_nodes()


func build() -> void:
    _resolve_nodes()
    if config == null:
        config = load("res://data/world/default_world_layout.tres") as WorldLayoutConfig
    if config == null or ground == null or entities == null or registry == null:
        push_error("WorldLayout is missing required configuration or scene nodes")
        return

    _clear_generated()
    registry.configure_world(config.world_rect())
    _load_definitions()
    _configure_runtime_tileset()
    _paint_map()
    _build_edge_collisions()
    _build_river_collisions()
    _build_visual_props()
    _built = true
    world_built.emit()


func is_built() -> bool:
    return _built


func world_rect() -> Rect2:
    return config.world_rect() if config != null else Rect2()


func spawn_position() -> Vector2:
    return config.cell_to_world(config.player_spawn_cell) if config != null else Vector2.ZERO


func marker_entries() -> Dictionary:
    return _markers.duplicate(true)


func boundary_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    if config == null:
        return cells
    for x in range(0, config.map_size_cells.x, 2):
        cells.append(Vector2i(x, 1))
        cells.append(Vector2i(x, config.map_size_cells.y - 2))
    for y in range(3, config.map_size_cells.y - 3, 2):
        cells.append(Vector2i(1, y))
        cells.append(Vector2i(config.map_size_cells.x - 2, y))
    return cells


func terrain_for(cell: Vector2i) -> int:
    if config.is_bridge_cell(cell):
        return GroundTile.PATH
    if config.is_water_cell(cell):
        return GroundTile.WATER
    if cell.x >= 8 and cell.x <= 20 and cell.y >= 48 and cell.y <= 57:
        return GroundTile.SOIL
    if cell.x >= 66 and cell.y >= 20 and (cell.x + cell.y) % 4 == 0:
        return GroundTile.STONE
    if (cell.x >= 17 and cell.x <= 19) or (cell.y >= 31 and cell.y <= 33):
        return GroundTile.PATH
    return GroundTile.GRASS


func validate_required_routes() -> PackedStringArray:
    var errors := PackedStringArray()
    if config == null or registry == null:
        errors.append("world layout is not configured")
        return errors

    var player_size := Vector2(16, 12)
    var start := config.player_spawn_cell
    for checkpoint in ROUTE_CELLS:
        if not is_cell_walkable(checkpoint, player_size):
            errors.append("route checkpoint blocked: %s" % checkpoint)
            continue
        if not _path_exists(start, checkpoint, player_size):
            errors.append("route checkpoint unreachable: %s" % checkpoint)
    return errors


func is_cell_walkable(cell: Vector2i, player_size := Vector2(16, 12)) -> bool:
    if config == null or registry == null:
        return false
    if not config.is_inside_cell(cell) or config.is_water_cell(cell):
        return false
    return registry.is_position_safe(config.cell_to_world(cell), player_size)


func recover_player_position(requested: Vector2, player_size: Vector2) -> Vector2:
    if registry == null:
        return spawn_position()
    return registry.find_nearest_safe_position(
        requested,
        player_size,
        spawn_position()
    )


func _resolve_nodes() -> void:
    ground = get_node_or_null(ground_path) as TileMapLayer
    entities = get_node_or_null(entities_path) as Node2D
    registry = get_node_or_null(registry_path) as WorldCollisionRegistry


func _clear_generated() -> void:
    _built = false
    _markers.clear()
    if ground != null:
        ground.clear()
    if registry != null:
        registry.clear()
    if entities != null:
        for child in entities.get_children():
            if child.has_meta("world_generated"):
                child.free()
    for child in get_children():
        if child.has_meta("world_generated"):
            child.free()


func _load_definitions() -> void:
    _definitions = {
        &"farmhouse": load(FARMHOUSE_PATH) as WorldPropDefinition,
        &"workshop": load(WORKSHOP_PATH) as WorldPropDefinition,
        &"tree_small": load(TREE_SMALL_PATH) as WorldPropDefinition,
        &"tree_cluster": load(TREE_CLUSTER_PATH) as WorldPropDefinition,
        &"rock_cluster": load(ROCK_CLUSTER_PATH) as WorldPropDefinition,
        &"fence_horizontal": load(FENCE_HORIZONTAL_PATH) as WorldPropDefinition,
    }
    for definition_id in _definitions:
        var definition := _definitions[definition_id] as WorldPropDefinition
        if definition == null or not definition.validate().is_empty():
            push_error("Unable to load valid world prop definition: %s" % definition_id)


func _configure_runtime_tileset() -> void:
    _using_open_floor = false
    _open_floor_coordinates.clear()
    var floor_texture := OpenAssetLibrary.load_texture(OpenAssetLibrary.FLOOR_ATLAS)
    if floor_texture != null:
        _using_open_floor = _configure_open_tileset(floor_texture)
    if not _using_open_floor:
        _configure_fallback_tileset()
    ground.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)


func _configure_open_tileset(texture: Texture2D) -> bool:
    var atlas := TileSetAtlasSource.new()
    atlas.texture = texture
    atlas.texture_region_size = SOURCE_TILE_SIZE
    for coordinate in OpenAtlasRegions.all_floor_tiles():
        var region := Rect2i(coordinate * SOURCE_TILE_SIZE, SOURCE_TILE_SIZE)
        if not OpenAtlasRegions.region_fits(texture, region):
            push_warning("Open floor tile is outside the atlas: %s" % coordinate)
            return false
        atlas.create_tile(coordinate)

    var tile_set := TileSet.new()
    tile_set.tile_size = SOURCE_TILE_SIZE
    tile_set.add_source(atlas, OPEN_SOURCE_ID)
    _add_water_source(tile_set)
    ground.tile_set = tile_set
    _open_floor_coordinates = {
        GroundTile.PATH: OpenAtlasRegions.PATH_TILE,
        GroundTile.SOIL: OpenAtlasRegions.SOIL_TILE,
        GroundTile.STONE: OpenAtlasRegions.STONE_TILE,
    }
    return true


func _add_water_source(tile_set: TileSet) -> void:
    var image := Image.create(SOURCE_TILE_SIZE.x, SOURCE_TILE_SIZE.y, false, Image.FORMAT_RGBA8)
    for y in SOURCE_TILE_SIZE.y:
        for x in SOURCE_TILE_SIZE.x:
            var color := Color("#347da0")
            if (x + y * 2) % 7 == 0:
                color = Color("#4594b2")
            elif (x * 3 + y) % 11 == 0:
                color = Color("#286b91")
            image.set_pixel(x, y, color)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = ImageTexture.create_from_image(image)
    atlas.texture_region_size = SOURCE_TILE_SIZE
    atlas.create_tile(Vector2i.ZERO)
    tile_set.add_source(atlas, WATER_SOURCE_ID)


func _configure_fallback_tileset() -> void:
    var image := Image.create(
        SOURCE_TILE_SIZE.x * 5,
        SOURCE_TILE_SIZE.y,
        false,
        Image.FORMAT_RGBA8
    )
    var colors: Array[Color] = [
        Color("#4f8a4b"),
        Color("#a77a4e"),
        Color("#70452f"),
        Color("#347da0"),
        Color("#6f7774"),
    ]
    for tile_index in colors.size():
        for y in SOURCE_TILE_SIZE.y:
            for x in SOURCE_TILE_SIZE.x:
                var color := colors[tile_index]
                if (x + y + tile_index) % 7 == 0:
                    color = color.lightened(0.07)
                image.set_pixel(tile_index * SOURCE_TILE_SIZE.x + x, y, color)

    var atlas := TileSetAtlasSource.new()
    atlas.texture = ImageTexture.create_from_image(image)
    atlas.texture_region_size = SOURCE_TILE_SIZE
    for tile_index in colors.size():
        atlas.create_tile(Vector2i(tile_index, 0))
    var tile_set := TileSet.new()
    tile_set.tile_size = SOURCE_TILE_SIZE
    tile_set.add_source(atlas, FALLBACK_SOURCE_ID)
    ground.tile_set = tile_set


func _paint_map() -> void:
    for y in config.map_size_cells.y:
        for x in config.map_size_cells.x:
            var cell := Vector2i(x, y)
            _set_ground_cell(cell, terrain_for(cell))


func _set_ground_cell(cell: Vector2i, tile: int) -> void:
    if _using_open_floor:
        if tile == GroundTile.WATER:
            ground.set_cell(cell, WATER_SOURCE_ID, Vector2i.ZERO, 0)
        else:
            ground.set_cell(cell, OPEN_SOURCE_ID, _open_coordinate_for(tile, cell), 0)
        return
    ground.set_cell(cell, FALLBACK_SOURCE_ID, Vector2i(tile, 0), 0)


func _open_coordinate_for(tile: int, cell: Vector2i) -> Vector2i:
    if tile == GroundTile.GRASS:
        var index := absi(cell.x * 31 + cell.y * 17) % OpenAtlasRegions.GRASS_TILES.size()
        return OpenAtlasRegions.GRASS_TILES[index]
    return _open_floor_coordinates.get(tile, OpenAtlasRegions.GRASS_TILES[0]) as Vector2i


func _build_visual_props() -> void:
    var village_texture := OpenAssetLibrary.load_texture(OpenAssetLibrary.VILLAGE_ATLAS)
    if village_texture == null:
        _build_fallback_props()
        return

    _spawn_atlas_definition(
        &"farmhouse",
        &"farmhouse",
        FARMHOUSE_CELL,
        village_texture,
        OpenAtlasRegions.HOUSE_LARGE
    )
    _spawn_atlas_definition(
        &"workshop",
        &"workshop",
        WORKSHOP_CELL,
        village_texture,
        OpenAtlasRegions.HOUSE_SMALL
    )
    _spawn_atlas_definition(
        &"fence_horizontal",
        &"farm_fence",
        FARM_FENCE_CELL,
        village_texture,
        OpenAtlasRegions.FENCE_STRIP
    )

    for index in TREE_CELLS.size():
        var definition_id := &"tree_cluster" if index % 3 == 0 else &"tree_small"
        var region := OpenAtlasRegions.TREE_CLUSTER if index % 3 == 0 else OpenAtlasRegions.TREE_SMALL
        _spawn_atlas_definition(
            definition_id,
            StringName("tree_%03d" % index),
            TREE_CELLS[index],
            village_texture,
            region
        )

    for index in ROCK_CELLS.size():
        _spawn_atlas_definition(
            &"rock_cluster",
            StringName("rock_%03d" % index),
            ROCK_CELLS[index],
            village_texture,
            OpenAtlasRegions.ROCK_CLUSTER
        )

    var border := boundary_cells()
    for index in border.size():
        var use_rock := index % 5 == 0
        _spawn_atlas_definition(
            &"rock_cluster" if use_rock else &"tree_small",
            StringName("boundary_%03d" % index),
            border[index],
            village_texture,
            OpenAtlasRegions.ROCK_CLUSTER if use_rock else OpenAtlasRegions.TREE_SMALL
        )


func _spawn_atlas_definition(
    definition_id: StringName,
    instance_id: StringName,
    cell: Vector2i,
    texture: Texture2D,
    region: Rect2i
) -> void:
    var definition := _definitions.get(definition_id) as WorldPropDefinition
    if definition == null:
        push_error("Missing world prop definition: %s" % definition_id)
        return
    var position := config.cell_to_world(cell)
    var root := WorldPropFactory.spawn_atlas_prop(
        entities,
        texture,
        region,
        definition,
        instance_id,
        position,
        registry
    )
    if root == null:
        push_warning("Unable to spawn world prop instance: %s" % instance_id)
        return
    root.set_meta("world_generated", true)
    if definition.marker_category != WorldPropDefinition.MarkerCategory.NONE:
        _markers[instance_id] = {
            "category": int(definition.marker_category),
            "position": position,
        }


func _build_fallback_props() -> void:
    _spawn_fallback_definition(
        &"farmhouse",
        &"farmhouse",
        FARMHOUSE_CELL,
        "res://assets/original/world/house.svg"
    )
    _spawn_fallback_definition(
        &"workshop",
        &"workshop",
        WORKSHOP_CELL,
        "res://assets/original/world/house.svg"
    )
    for index in TREE_CELLS.size():
        _spawn_fallback_definition(
            &"tree_small",
            StringName("tree_%03d" % index),
            TREE_CELLS[index],
            "res://assets/original/world/tree.svg"
        )
    for index in ROCK_CELLS.size():
        _spawn_fallback_definition(
            &"rock_cluster",
            StringName("rock_%03d" % index),
            ROCK_CELLS[index],
            "res://assets/original/world/rock.svg"
        )


func _spawn_fallback_definition(
    definition_id: StringName,
    instance_id: StringName,
    cell: Vector2i,
    texture_path: String
) -> void:
    var definition := _definitions.get(definition_id) as WorldPropDefinition
    var texture := OpenAssetLibrary.load_texture(texture_path)
    if definition == null or texture == null:
        return
    var position := config.cell_to_world(cell)
    var root := Node2D.new()
    root.name = String(instance_id)
    root.position = position
    root.set_meta("world_generated", true)

    var sprite := Sprite2D.new()
    sprite.name = "Visual"
    sprite.texture = texture
    sprite.position = definition.visual_offset
    root.add_child(sprite)

    if definition.solid:
        var body := StaticBody2D.new()
        body.name = "Solid"
        body.collision_layer = 1
        body.collision_mask = 2
        root.add_child(body)
        for index in definition.collision_rects.size():
            var rect := definition.collision_rects[index]
            var shape := RectangleShape2D.new()
            shape.size = rect.size
            var collision := CollisionShape2D.new()
            collision.position = rect.position + rect.size * 0.5
            collision.shape = shape
            body.add_child(collision)
            registry.register_rect(
                StringName("%s:%d" % [instance_id, index]),
                Rect2(position + rect.position, rect.size)
            )
    entities.add_child(root)
    if definition.marker_category != WorldPropDefinition.MarkerCategory.NONE:
        _markers[instance_id] = {
            "category": int(definition.marker_category),
            "position": position,
        }


func _build_edge_collisions() -> void:
    var size := Vector2(config.world_size_pixels())
    var thickness := float(config.display_cell_size.x * 2)
    _create_registered_blocker(&"world_edge_top", Rect2(0, 0, size.x, thickness))
    _create_registered_blocker(
        &"world_edge_bottom",
        Rect2(0, size.y - thickness, size.x, thickness)
    )
    _create_registered_blocker(
        &"world_edge_left",
        Rect2(0, thickness, thickness, size.y - thickness * 2.0)
    )
    _create_registered_blocker(
        &"world_edge_right",
        Rect2(size.x - thickness, thickness, thickness, size.y - thickness * 2.0)
    )


func _build_river_collisions() -> void:
    var cell_size := Vector2(config.display_cell_size)
    var x := float(config.river_x_range.x) * cell_size.x
    var width := float(config.river_x_range.y - config.river_x_range.x + 1) * cell_size.x
    var segments: Array[Vector2i] = [
        Vector2i(0, 29),
        Vector2i(34, 44),
        Vector2i(48, 63),
    ]
    for index in segments.size():
        var rows := segments[index]
        var y := float(rows.x) * cell_size.y
        var height := float(rows.y - rows.x + 1) * cell_size.y
        _create_registered_blocker(
            StringName("river_%d" % index),
            Rect2(x, y, width, height)
        )


func _create_registered_blocker(id: StringName, rect: Rect2) -> void:
    if not registry.register_rect(id, rect):
        push_warning("Unable to register world blocker: %s" % id)
        return
    var body := StaticBody2D.new()
    body.name = String(id)
    body.position = rect.get_center()
    body.collision_layer = 1
    body.collision_mask = 2
    body.set_meta("world_generated", true)
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    var collision := CollisionShape2D.new()
    collision.shape = shape
    body.add_child(collision)
    add_child(body)


func _path_exists(start: Vector2i, target: Vector2i, player_size: Vector2) -> bool:
    if start == target:
        return true
    if not is_cell_walkable(start, player_size) or not is_cell_walkable(target, player_size):
        return false

    var queue: Array[Vector2i] = [start]
    var visited: Dictionary = {}
    visited[start] = true
    var cursor := 0
    var directions: Array[Vector2i] = [
        Vector2i.RIGHT,
        Vector2i.LEFT,
        Vector2i.DOWN,
        Vector2i.UP,
    ]
    while cursor < queue.size():
        var current := queue[cursor]
        cursor += 1
        for direction in directions:
            var next := current + direction
            if visited.has(next) or not is_cell_walkable(next, player_size):
                continue
            if next == target:
                return true
            visited[next] = true
            queue.append(next)
    return false
