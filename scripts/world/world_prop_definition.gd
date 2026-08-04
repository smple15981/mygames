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
    return errors
