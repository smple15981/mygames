class_name WorldPropFactory
extends RefCounted

const OUTLINE_SHADER: Shader = preload("res://assets/original/ui/interaction_outline.gdshader")


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
    root.z_as_relative = true
    root.set_meta("interaction_kind", int(definition.interaction_kind))
    root.set_meta("world_instance_id", instance_id)

    var sprite := _create_atlas_sprite(
        "Visual",
        texture,
        region,
        definition.visual_scale,
        definition.visual_offset
    )
    sprite.z_index = 0
    root.add_child(sprite)

    if definition.interaction_kind != InteractionTarget.Kind.NONE:
        var highlight := _create_atlas_sprite(
            "Highlight",
            texture,
            region,
            definition.visual_scale,
            definition.visual_offset
        )
        highlight.visible = false
        highlight.z_index = -1
        var material := ShaderMaterial.new()
        material.shader = OUTLINE_SHADER
        var texture_size := Vector2(texture.get_size())
        if texture_size.x > 0.0 and texture_size.y > 0.0:
            material.set_shader_parameter(
                "pixel_size",
                Vector2(1.0 / texture_size.x, 1.0 / texture_size.y)
            )
        highlight.material = material
        root.add_child(highlight)

        var target := InteractionTarget.new()
        target.name = "InteractionTarget"
        target.kind = definition.interaction_kind
        target.required_tool = definition.required_tool
        target.interaction_range = definition.interaction_range
        target.target_rect = definition.interaction_rect
        target.highlight = highlight
        target.collision_layer = 4
        target.collision_mask = 0
        root.add_child(target)

        var interaction_shape := RectangleShape2D.new()
        interaction_shape.size = definition.interaction_rect.size
        var interaction_collision := CollisionShape2D.new()
        interaction_collision.name = "CollisionShape2D"
        interaction_collision.position = (
            definition.interaction_rect.position
            + definition.interaction_rect.size * 0.5
        )
        interaction_collision.shape = interaction_shape
        target.add_child(interaction_collision)

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

    if definition.interaction_kind in [
        InteractionTarget.Kind.HARVEST_TREE,
        InteractionTarget.Kind.HARVEST_ROCK,
    ]:
        var harvestable := HarvestableResource.new()
        harvestable.name = "HarvestableResource"
        harvestable.add_to_group("harvestables")
        root.add_child(harvestable)
        harvestable.configure(
            definition.required_tool,
            definition.harvest_hits,
            definition.drop_item_id,
            definition.drop_quantity,
            registry,
            registered_ids
        )

    root.set_meta("footprint_ids", registered_ids)
    parent.add_child(root)
    return root


static func _create_atlas_sprite(
    node_name: String,
    texture: Texture2D,
    region: Rect2i,
    visual_scale: float,
    visual_offset: Vector2
) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = node_name
    sprite.texture = texture
    sprite.region_enabled = true
    sprite.region_rect = Rect2(region)
    sprite.scale = Vector2.ONE * visual_scale
    sprite.position = visual_offset
    return sprite
