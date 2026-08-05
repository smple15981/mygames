class_name WorldPropDefinition
extends Resource

enum MarkerCategory {
    NONE,
    FARMHOUSE,
    WORKSHOP,
    FARM_PLOT,
    OBJECTIVE,
}

@export var id: StringName
@export var display_name := ""
@export_range(0.1, 8.0, 0.1) var visual_scale := 2.0
@export var visual_offset := Vector2.ZERO
@export var solid := false
@export var collision_rects: Array[Rect2] = []
@export var marker_category: MarkerCategory = MarkerCategory.NONE
@export var interaction_kind: InteractionTarget.Kind = InteractionTarget.Kind.NONE
@export var interaction_rect := Rect2()
@export var required_tool: ItemDefinition.ToolType = ItemDefinition.ToolType.NONE
@export_range(0, 99, 1) var harvest_hits := 0
@export var drop_item_id: StringName
@export_range(0, 99, 1) var drop_quantity := 0
@export_range(16.0, 96.0, 1.0) var interaction_range := 44.0


func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if id.is_empty():
        errors.append("id must not be empty")
    if visual_scale <= 0.0:
        errors.append("visual_scale must be positive")
    if solid and collision_rects.is_empty():
        errors.append("solid prop requires collision_rects")
    for rect in collision_rects:
        if rect.size.x <= 0.0 or rect.size.y <= 0.0:
            errors.append("collision rectangle sizes must be positive")

    if interaction_kind != InteractionTarget.Kind.NONE:
        if interaction_rect.size.x <= 0.0 or interaction_rect.size.y <= 0.0:
            errors.append("interactive prop requires interaction_rect")

    if interaction_kind in [
        InteractionTarget.Kind.HARVEST_TREE,
        InteractionTarget.Kind.HARVEST_ROCK,
    ]:
        if required_tool == ItemDefinition.ToolType.NONE or harvest_hits <= 0:
            errors.append("harvestable prop requires tool and positive hits")
        if drop_item_id.is_empty() or drop_quantity <= 0:
            errors.append("harvestable prop requires a positive drop")
    return errors
