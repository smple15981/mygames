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


static func world_direction(input_vector: Vector2) -> Vector3:
    return Vector3(input_vector.x, 0.0, input_vector.y)


static func facing_index(direction: Vector2, previous: int) -> int:
    if direction.is_zero_approx():
        return previous
    if absf(direction.x) > absf(direction.y):
        return Facing.WEST if direction.x < 0.0 else Facing.EAST
    return Facing.NORTH if direction.y < 0.0 else Facing.SOUTH
