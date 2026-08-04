class_name FloatingMotes
extends Node2D

@export var field_size := Vector2(360, 220)
@export var mote_count := 22
@export var mote_color := Color(1.0, 0.86, 0.48, 0.7)

var _points: Array[Vector2] = []
var _time := 0.0


func _ready() -> void:
    var random := RandomNumberGenerator.new()
    random.seed = 15981
    for _index in mote_count:
        _points.append(
            Vector2(
                random.randf_range(0.0, field_size.x),
                random.randf_range(0.0, field_size.y)
            )
        )


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _draw() -> void:
    for index in _points.size():
        var point := _points[index]
        var lift := fmod(_time * (5.0 + float(index % 4)) + point.y, field_size.y)
        var sway := sin(_time * 1.2 + float(index)) * 3.0
        var draw_position := Vector2(point.x + sway, field_size.y - lift)
        var draw_color := mote_color
        draw_color.a = 0.35 + float(index % 3) * 0.15
        draw_rect(Rect2(draw_position.round(), Vector2(2, 2)), draw_color)
