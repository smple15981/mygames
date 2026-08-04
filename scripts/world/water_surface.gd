class_name WaterSurface
extends Node2D

@export var surface_size := Vector2(128, 768)
@export var base_color := Color("#2e7394")
@export var deep_color := Color("#20546f")
@export var highlight_color := Color(0.55, 0.9, 1.0, 0.65)

var _time := 0.0


func _process(delta: float) -> void:
    _time += delta
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, surface_size), deep_color)
    draw_rect(Rect2(Vector2(4, 0), surface_size - Vector2(8, 0)), base_color)

    var row_count := int(surface_size.y / 16.0)
    for row in row_count:
        var y := float(row * 16 + 8)
        var drift := roundf(sin(_time * 1.8 + row * 0.7) * 4.0)
        var start_x := -16.0 + drift
        while start_x < surface_size.x + 16.0:
            draw_line(
                Vector2(start_x, y),
                Vector2(start_x + 10.0, y),
                highlight_color,
                2.0,
                false
            )
            start_x += 32.0

    draw_line(Vector2.ZERO, Vector2(0, surface_size.y), Color("#173b52"), 3.0, false)
    draw_line(
        Vector2(surface_size.x, 0),
        surface_size,
        Color("#173b52"),
        3.0,
        false
    )
