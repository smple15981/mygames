class_name PlayerController
extends CharacterBody3D

@export_range(0.5, 12.0, 0.1) var move_speed: float = 4.5
@export_range(1.0, 50.0, 0.5) var gravity_strength: float = 20.0

@onready var sprite: Sprite3D = $Visual/Sprite3D

var facing: int = MovementMath.Facing.SOUTH


func _physics_process(delta: float) -> void:
    var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var input_vector := MovementMath.normalized_input(raw_input)
    var direction := MovementMath.world_direction(input_vector)

    velocity.x = direction.x * move_speed
    velocity.z = direction.z * move_speed
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= gravity_strength * delta

    move_and_slide()
    facing = MovementMath.facing_index(input_vector, facing)
    _apply_facing(input_vector)


func _apply_facing(input_vector: Vector2) -> void:
    if absf(input_vector.x) > 0.01:
        sprite.flip_h = input_vector.x < 0.0
