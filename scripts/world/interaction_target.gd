class_name InteractionTarget
extends Area2D

enum Kind {
    NONE,
    HARVEST_TREE,
    HARVEST_ROCK,
    PICKUP,
    INTERACT,
}

@export var kind: Kind = Kind.NONE
@export var required_tool: ItemDefinition.ToolType = ItemDefinition.ToolType.NONE
@export_range(16.0, 96.0, 1.0) var interaction_range := 44.0

var target_rect := Rect2()
var highlight: Sprite2D
var interaction_enabled := true


func world_target_rect() -> Rect2:
    return Rect2(global_position + target_rect.position, target_rect.size)


func set_highlighted(enabled: bool, locked := false) -> void:
    if highlight == null:
        return
    highlight.visible = enabled and interaction_enabled
    var shader_material := highlight.material as ShaderMaterial
    if shader_material != null:
        shader_material.set_shader_parameter(
            "outline_color",
            Color("#8d9497") if locked else Color("#ffd86a")
        )


func set_interaction_enabled(enabled: bool) -> void:
    interaction_enabled = enabled
    collision_layer = 4 if enabled else 0
    monitoring = enabled
    monitorable = enabled
    if not enabled:
        set_highlighted(false)
