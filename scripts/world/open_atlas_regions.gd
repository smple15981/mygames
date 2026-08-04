class_name OpenAtlasRegions
extends RefCounted

const SOURCE_TILE_SIZE := Vector2i(16, 16)

# Compact runtime floor atlas. Tiles are copied from the pinned Ninja Adventure pack.
const GRASS_TILES: Array[Vector2i] = [
    Vector2i(0, 0),
    Vector2i(1, 0),
    Vector2i(2, 0),
    Vector2i(3, 0),
]
const PATH_TILE := Vector2i(4, 0)
const SOIL_TILE := Vector2i(5, 0)
const STONE_TILE := Vector2i(6, 0)

# Compact runtime village atlas regions (pixel coordinates).
const TREE_CLUSTER := Rect2i(0, 0, 64, 64)
const TREE_SMALL := Rect2i(64, 0, 32, 48)
const ROCK_CLUSTER := Rect2i(96, 0, 48, 32)
const HOUSE_LARGE := Rect2i(0, 64, 80, 96)
const HOUSE_SMALL := Rect2i(80, 64, 64, 80)
const FENCE_STRIP := Rect2i(144, 64, 64, 32)


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
