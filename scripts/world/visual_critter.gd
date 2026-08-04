class_name VisualCritter
extends Sprite2D

@export_range(1.0, 12.0, 0.5) var animation_speed := 4.0

var _animation_time := 0.0
var _base_y := 0.0


func _ready() -> void:
    _base_y = position.y


func _process(delta: float) -> void:
    if hframes < 4 or vframes < 4:
        return
    _animation_time += delta * animation_speed
    frame_coords = Vector2i(0, int(floor(_animation_time)) % 4)
    position.y = _base_y + roundf(sin(_animation_time * 0.5))
