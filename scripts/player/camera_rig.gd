class_name CameraRig
extends Camera2D

const MIN_ZOOM := 0.75
const MAX_ZOOM := 1.50
const ZOOM_STEP := 0.125

@export_range(1.0, 20.0, 0.5) var zoom_lerp_speed := 10.0

var _target_zoom := 1.0
var _world_rect := Rect2(Vector2.ZERO, Vector2(1280, 768))


func _ready() -> void:
    position_smoothing_enabled = true
    position_smoothing_speed = 7.0
    zoom = Vector2.ONE * _target_zoom
    _apply_limits()


func _process(delta: float) -> void:
    var weight := 1.0 - exp(-zoom_lerp_speed * delta)
    var next := lerpf(zoom.x, _target_zoom, weight)
    zoom = Vector2.ONE * next
    global_position = clamp_center_to_world(
        global_position,
        _world_rect,
        get_viewport_rect().size,
        next
    )


func configure_world(rect: Rect2) -> void:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        push_warning("CameraRig rejected invalid world bounds")
        return
    _world_rect = rect
    _apply_limits()


func change_zoom_steps(direction: int) -> void:
    if direction == 0:
        return
    set_zoom_value(_target_zoom + float(direction) * ZOOM_STEP)


func set_zoom_value(value: float) -> void:
    _target_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)


func target_zoom_value() -> float:
    return _target_zoom


func world_rect() -> Rect2:
    return _world_rect


func _apply_limits() -> void:
    limit_left = roundi(_world_rect.position.x)
    limit_top = roundi(_world_rect.position.y)
    limit_right = roundi(_world_rect.end.x)
    limit_bottom = roundi(_world_rect.end.y)


static func clamp_center_to_world(
    target: Vector2,
    rect: Rect2,
    viewport: Vector2,
    zoom_value: float
) -> Vector2:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return target

    var half_view := viewport * 0.5 / maxf(zoom_value, 0.001)
    var minimum := rect.position + half_view
    var maximum := rect.end - half_view
    if minimum.x > maximum.x:
        minimum.x = rect.get_center().x
        maximum.x = minimum.x
    if minimum.y > maximum.y:
        minimum.y = rect.get_center().y
        maximum.y = minimum.y
    return Vector2(
        clampf(target.x, minimum.x, maximum.x),
        clampf(target.y, minimum.y, maximum.y)
    )
