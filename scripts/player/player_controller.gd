class_name PlayerController
extends CharacterBody2D

@export_range(20.0, 400.0, 1.0) var move_speed: float = 120.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing: int = MovementMath.Facing.SOUTH


func _ready() -> void:
    sprite.play("idle_down")


func _physics_process(_delta: float) -> void:
    var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var direction := MovementMath.normalized_input(raw_input)

    velocity = direction * move_speed
    move_and_slide()

    var moving := not direction.is_zero_approx()
    facing = MovementMath.facing_index(direction, facing)
    _apply_visual_state(direction, moving)


func _apply_visual_state(direction: Vector2, moving: bool) -> void:
    if absf(direction.x) > 0.01:
        sprite.flip_h = direction.x < 0.0
    sprite.play(MovementMath.animation_name(facing, moving))
