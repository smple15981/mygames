class_name PrototypeWorld
extends Node2D

const SOURCE_TILE_SIZE := Vector2i(16, 16)
const DISPLAY_SCALE := 2.0
const MAP_SIZE := Vector2i(40, 24)
const OPEN_SOURCE_ID := 0
const FALLBACK_SOURCE_ID := 1
const VisualCritterScript := preload("res://scripts/world/visual_critter.gd")

enum GroundTile {
    GRASS,
    PATH,
    SOIL,
    WATER,
    STONE,
}

@onready var ground: TileMapLayer = $Ground
@onready var entities: Node2D = $Entities

var _using_open_floor := false
var _open_floor_coordinates: Dictionary = {}


func _ready() -> void:
    _configure_runtime_tileset()
    _paint_map()
    _build_props()
    _build_world_collisions()


func _configure_runtime_tileset() -> void:
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
    ground.tile_set = tile_set

    _open_floor_coordinates = {
        GroundTile.PATH: OpenAtlasRegions.PATH_TILE,
        GroundTile.SOIL: OpenAtlasRegions.SOIL_TILE,
        GroundTile.STONE: OpenAtlasRegions.STONE_TILE,
    }
    return true


func _configure_fallback_tileset() -> void:
    var image := Image.create(
        SOURCE_TILE_SIZE.x * 5,
        SOURCE_TILE_SIZE.y,
        false,
        Image.FORMAT_RGBA8
    )
    var colors := [
        Color("#4f8a4b"),
        Color("#a77a4e"),
        Color("#70452f"),
        Color("#3c86a8"),
        Color("#6f7774"),
    ]

    for tile_index in colors.size():
        for y in SOURCE_TILE_SIZE.y:
            for x in SOURCE_TILE_SIZE.x:
                var color: Color = colors[tile_index]
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
    for y in MAP_SIZE.y:
        for x in MAP_SIZE.x:
            var tile := GroundTile.GRASS

            if x >= 18 and x <= 22:
                tile = GroundTile.PATH
            if x >= 4 and x <= 11 and y >= 5 and y <= 10:
                tile = GroundTile.SOIL
            if x >= 35 and y <= 7:
                tile = GroundTile.STONE
            if x >= 30 and x <= 33:
                tile = GroundTile.WATER

            _set_ground_cell(Vector2i(x, y), tile)


func _set_ground_cell(cell: Vector2i, tile: int) -> void:
    if _using_open_floor:
        ground.set_cell(cell, OPEN_SOURCE_ID, _open_coordinate_for(tile, cell), 0)
        return
    ground.set_cell(cell, FALLBACK_SOURCE_ID, Vector2i(tile, 0), 0)


func _open_coordinate_for(tile: int, cell: Vector2i) -> Vector2i:
    if tile == GroundTile.GRASS or tile == GroundTile.WATER:
        var index := abs(cell.x * 31 + cell.y * 17) % OpenAtlasRegions.GRASS_TILES.size()
        return OpenAtlasRegions.GRASS_TILES[index]
    var coordinate: Vector2i = _open_floor_coordinates.get(
        tile,
        OpenAtlasRegions.GRASS_TILES[0]
    )
    return coordinate


func _build_props() -> void:
    var village_texture := OpenAssetLibrary.load_texture(OpenAssetLibrary.VILLAGE_ATLAS)
    if village_texture != null:
        _build_open_props(village_texture)
    else:
        _build_fallback_props()
    _spawn_critter()


func _build_open_props(texture: Texture2D) -> void:
    _spawn_atlas_prop(
        "FarmHouse",
        texture,
        OpenAtlasRegions.HOUSE_LARGE,
        Vector2(250, 190),
        2.0,
        Vector2(112, 46)
    )
    _spawn_atlas_prop(
        "Workshop",
        texture,
        OpenAtlasRegions.HOUSE_SMALL,
        Vector2(650, 180),
        2.0,
        Vector2(88, 38)
    )

    var trees := [
        Vector2(100, 220),
        Vector2(92, 520),
        Vector2(430, 92),
        Vector2(770, 230),
        Vector2(835, 430),
        Vector2(910, 560),
        Vector2(1180, 480),
        Vector2(1200, 680),
    ]
    for index in trees.size():
        var region := (
            OpenAtlasRegions.TREE_CLUSTER
            if index % 3 == 0
            else OpenAtlasRegions.TREE_SMALL
        )
        _spawn_atlas_prop(
            "Tree%02d" % index,
            texture,
            region,
            trees[index],
            2.0,
            Vector2(28, 18)
        )

    var rocks := [Vector2(1090, 150), Vector2(1150, 210), Vector2(1120, 620)]
    for index in rocks.size():
        _spawn_atlas_prop(
            "Rock%02d" % index,
            texture,
            OpenAtlasRegions.ROCK_CLUSTER,
            rocks[index],
            1.7,
            Vector2(34, 20)
        )

    _spawn_atlas_prop(
        "FarmFence",
        texture,
        OpenAtlasRegions.FENCE_STRIP,
        Vector2(255, 350),
        2.0,
        Vector2(112, 16)
    )


func _spawn_atlas_prop(
    node_name: String,
    texture: Texture2D,
    region: Rect2i,
    world_position: Vector2,
    scale_factor: float,
    collision_size: Vector2
) -> Node2D:
    if not OpenAtlasRegions.region_fits(texture, region):
        push_warning("Skipping atlas prop with invalid region: %s" % node_name)
        return null

    var root: Node2D
    if collision_size.is_zero_approx():
        root = Node2D.new()
    else:
        var body := StaticBody2D.new()
        body.collision_layer = 1
        body.collision_mask = 2
        root = body

    root.name = node_name
    root.position = world_position

    var sprite := Sprite2D.new()
    sprite.name = "Sprite2D"
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = Rect2(region)
    sprite.scale = Vector2.ONE * scale_factor
    sprite.position = Vector2(0, -float(region.size.y) * scale_factor * 0.5)
    root.add_child(sprite)

    if root is StaticBody2D:
        var shape := RectangleShape2D.new()
        shape.size = collision_size
        var collision := CollisionShape2D.new()
        collision.name = "CollisionShape2D"
        collision.position = Vector2(0, -collision_size.y * 0.5)
        collision.shape = shape
        root.add_child(collision)

    entities.add_child(root)
    return root


func _build_fallback_props() -> void:
    _spawn_fallback_prop(
        "FarmHouse",
        "res://assets/original/world/house.svg",
        Vector2(245, 170),
        Vector2(0, -40),
        Vector2(96, 54)
    )
    _spawn_fallback_prop(
        "TreeA",
        "res://assets/original/world/tree.svg",
        Vector2(110, 190),
        Vector2(0, -40),
        Vector2(30, 22)
    )
    _spawn_fallback_prop(
        "TreeB",
        "res://assets/original/world/tree.svg",
        Vector2(770, 220),
        Vector2(0, -40),
        Vector2(30, 22)
    )
    _spawn_fallback_prop(
        "TreeC",
        "res://assets/original/world/tree.svg",
        Vector2(890, 430),
        Vector2(0, -40),
        Vector2(30, 22)
    )
    _spawn_fallback_prop(
        "RockA",
        "res://assets/original/world/rock.svg",
        Vector2(1110, 150),
        Vector2(0, -12),
        Vector2(30, 24)
    )


func _spawn_fallback_prop(
    node_name: String,
    texture_path: String,
    world_position: Vector2,
    visual_offset: Vector2,
    collision_size: Vector2
) -> void:
    var texture := OpenAssetLibrary.load_texture(texture_path)
    if texture == null:
        return

    var body := StaticBody2D.new()
    body.name = node_name
    body.position = world_position
    body.collision_layer = 1

    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.position = visual_offset
    body.add_child(sprite)

    var shape := RectangleShape2D.new()
    shape.size = collision_size
    var collision := CollisionShape2D.new()
    collision.shape = shape
    body.add_child(collision)
    entities.add_child(body)


func _spawn_critter() -> void:
    var using_open_sheet := ResourceLoader.exists(OpenAssetLibrary.PIG_SHEET)
    var texture := OpenAssetLibrary.load_texture(
        OpenAssetLibrary.PIG_SHEET,
        "res://assets/original/world/slime.svg"
    )
    if texture == null:
        return

    var critter := Sprite2D.new()
    critter.name = "PigCritter" if using_open_sheet else "SlimeFallback"
    critter.position = Vector2(850, 330)
    critter.texture = texture
    if using_open_sheet:
        critter.hframes = 2
        critter.vframes = 1
        critter.scale = Vector2(2, 2)
        critter.set_script(VisualCritterScript)
    entities.add_child(critter)


func _build_world_collisions() -> void:
    var river_blocker := StaticBody2D.new()
    river_blocker.name = "RiverBlocker"
    river_blocker.position = Vector2(1024, 384)
    river_blocker.collision_layer = 1

    var river_shape := RectangleShape2D.new()
    river_shape.size = Vector2(118, 768)
    var river_collision := CollisionShape2D.new()
    river_collision.shape = river_shape
    river_blocker.add_child(river_collision)
    add_child(river_blocker)
