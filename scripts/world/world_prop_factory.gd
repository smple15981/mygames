class_name WorldPropFactory
extends RefCounted


static func spawn_atlas_prop(
    parent: Node2D,
    texture: Texture2D,
    region: Rect2i,
    definition: WorldPropDefinition,
    instance_id: StringName,
    world_position: Vector2,
    registry: WorldCollisionRegistry
) -> Node2D:
    if parent == null or texture == null or definition == null or instance_id.is_empty():
        return null
    if not definition.validate().is_empty():
        push_warning("Invalid world prop definition: %s" % definition.id)
        return null
    if not OpenAtlasRegions.region_fits(texture, region):
        push_warning("World prop atlas region is outside texture: %s" % instance_id)
        return null

    var root := Node2D.new()
    root.name = String(instance_id)
    root.position = world_position

    var sprite := Sprite2D.new()
    sprite.name = "Visual"
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = Rect2(region)
    sprite.scale = Vector2.ONE * definition.visual_scale
    sprite.position = definition.visual_offset
    root.add_child(sprite)

    var registered_ids: Array[StringName] = []
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
            collision.name = "CollisionShape2D%d" % index
            collision.position = rect.position + rect.size * 0.5
            collision.shape = shape
            body.add_child(collision)

            if registry != null:
                var footprint_id := StringName("%s:%d" % [instance_id, index])
                var world_rect := Rect2(world_position + rect.position, rect.size)
                if not registry.register_rect(footprint_id, world_rect):
                    for registered_id in registered_ids:
                        registry.unregister(registered_id)
                    root.free()
                    push_warning("Duplicate or invalid prop footprint: %s" % footprint_id)
                    return null
                registered_ids.append(footprint_id)

    parent.add_child(root)
    return root
