class_name MovementMath
extends RefCounted


enum Facing {
    NORTH,
    EAST,
    SOUTH,
    WEST,
}


static func normalized_input(raw: Vector2) -> Vector2:
    return raw.limit_length(1.0)


static func facing_index(direction: Vector2, previous: int) -> int:
    if direction.is_zero_approx():
        return previous
    if absf(direction.x) > absf(direction.y):
        return Facing.WEST if direction.x < 0.0 else Facing.EAST
    return Facing.NORTH if direction.y < 0.0 else Facing.SOUTH


static func animation_name(facing: int, moving: bool) -> StringName:
    var prefix := "walk_" if moving else "idle_"
    match facing:
        Facing.NORTH:
            return StringName(prefix + "up")
        Facing.EAST, Facing.WEST:
            return StringName(prefix + "side")
        _:
            return StringName(prefix + "down")
