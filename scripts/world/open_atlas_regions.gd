class_name OpenAtlasRegions
extends RefCounted

const SOURCE_TILE_SIZE := Vector2i(16, 16)

# Ninja Adventure floor atlas coordinates. Each coordinate addresses one 16×16 tile.
const GRASS_TILES: Array[Vector2i] = [
    Vector2i(1, 7),
    Vector2i(2, 7),
    Vector2i(3, 7),
    Vector2i(4, 7),
]
const PATH_TILE := Vector2i(6, 9)
const SOIL_TILE := Vector2i(8, 9)
const STONE_TILE := Vector2i(13, 14)

# Ninja Adventure abandoned-village atlas regions (pixel coordinates).
const TREE_CLUSTER := Rect2i(0, 64, 64, 64)
const TREE_SMALL := Rect2i(64, 64, 32, 48)
const ROCK_CLUSTER := Rect2i(64, 16, 48, 32)
const HOUSE_LARGE := Rect2i(176, 96, 80, 96)
const HOUSE_SMALL := Rect2i(256, 112, 64, 80)
const FENCE_STRIP := Rect2i(256, 160, 64, 32)


static func all_floor_tiles() -> Array[Vector2i]:
    var result: Array[Vector2i] = GRASS_TILES.duplicate()
    result.append(PATH_TILE)
    result.append(SOIL_TILE)
    result.append(STONE_TILE)
    return result


static func region_fits(texture: Texture2D, region: Rect2i) -> bool:
    if texture == null:
        return false
    var size := texture.get_size()
    return region.position.x >= 0 and region.position.y >= 0 \
        and region.end.x <= int(size.x) and region.end.y <= int(size.y)
