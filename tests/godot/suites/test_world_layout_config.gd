extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var config := WorldLayoutConfig.new()
    failures.append(TestAssert.equal(config.map_size_cells, Vector2i(96, 64), "map cells"))
    failures.append(TestAssert.equal(config.world_size_pixels(), Vector2i(3072, 2048), "world pixels"))
    failures.append(TestAssert.equal(config.world_to_normalized(Vector2.ZERO), Vector2.ZERO, "normalized origin"))
    failures.append(TestAssert.equal(
        config.world_to_normalized(Vector2(3072, 2048)),
        Vector2.ONE,
        "normalized end"
    ))
    failures.append(TestAssert.equal(
        config.normalized_to_minimap(Vector2(1536, 1024), Vector2(160, 160)),
        Vector2(80, 80),
        "minimap center"
    ))
    failures.append(TestAssert.truthy(config.is_bridge_cell(Vector2i(59, 31)), "bridge cell"))
    failures.append(TestAssert.truthy(not config.is_water_cell(Vector2i(59, 31)), "bridge walkable"))
    failures.append(TestAssert.truthy(config.is_water_cell(Vector2i(59, 20)), "river water"))
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
