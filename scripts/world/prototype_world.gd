class_name PrototypeWorld
extends Node2D

const TILE_SIZE := Vector2i(32, 32)
const MAP_SIZE := Vector2i(40, 24)

enum GroundTile {
    GRASS,
    PATH,
    SOIL,
    WATER,
    STONE,
}

@onready var ground: TileMapLayer = $Ground


func _ready() -> void:
    _configure_runtime_tileset()
    _paint_map()


func _configure_runtime_tileset() -> void:
    var image := Image.create(TILE_SIZE.x * 5, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
    var colors := [
        Color("#4f8a4b"),
        Color("#a77a4e"),
        Color("#70452f"),
        Color("#3c86a8"),
        Color("#6f7774"),
    ]

    for tile_index in colors.size():
        for y in TILE_SIZE.y:
            for x in TILE_SIZE.x:
                var color: Color = colors[tile_index]
                if (x + y) % 7 == 0:
                    color = color.lightened(0.06)
                image.set_pixel(tile_index * TILE_SIZE.x + x, y, color)

    var texture := ImageTexture.create_from_image(image)
    var atlas := TileSetAtlasSource.new()
    atlas.texture = texture
    atlas.texture_region_size = TILE_SIZE

    for tile_index in colors.size():
        atlas.create_tile(Vector2i(tile_index, 0))

    var tile_set := TileSet.new()
    tile_set.tile_size = TILE_SIZE
    tile_set.add_source(atlas, 0)
    ground.tile_set = tile_set


func _paint_map() -> void:
    for y in MAP_SIZE.y:
        for x in MAP_SIZE.x:
            var tile := GroundTile.GRASS

            if x >= 18 and x <= 22:
                tile = GroundTile.PATH
            if x >= 30 and x <= 33:
                tile = GroundTile.WATER
            if x >= 4 and x <= 11 and y >= 5 and y <= 10:
                tile = GroundTile.SOIL
            if x >= 35 and y <= 7:
                tile = GroundTile.STONE

            ground.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0), 0)
