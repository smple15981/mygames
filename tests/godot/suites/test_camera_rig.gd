extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var camera := CameraRig.new()
    camera.set_zoom_value(4.0)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.5, "upper clamp"))
    camera.set_zoom_value(0.1)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 0.75, "lower clamp"))
    camera.set_zoom_value(1.0)
    camera.change_zoom_steps(1)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 1.125, "one step"))
    camera.change_zoom_steps(-2)
    failures.append(TestAssert.equal(camera.target_zoom_value(), 0.875, "reverse steps"))
    var clamped := CameraRig.clamp_center_to_world(
        Vector2(-100, -100),
        Rect2(Vector2.ZERO, Vector2(3072, 2048)),
        Vector2(640, 360),
        1.0
    )
    failures.append(TestAssert.equal(clamped, Vector2(320, 180), "top-left clamp"))
    var far_clamped := CameraRig.clamp_center_to_world(
        Vector2(4000, 3000),
        Rect2(Vector2.ZERO, Vector2(3072, 2048)),
        Vector2(640, 360),
        1.0
    )
    failures.append(TestAssert.equal(far_clamped, Vector2(2752, 1868), "bottom-right clamp"))
    camera.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
