class_name PlayerController
extends CharacterBody2D

@export_range(20.0, 400.0, 1.0) var move_speed: float = 120.0
@export_range(1.0, 12.0, 0.5) var animation_speed: float = 6.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow

var facing: int = MovementMath.Facing.SOUTH
var _animation_time := 0.0
var _using_open_sheet := false


func _ready() -> void:
    _configure_visuals()


func _physics_process(delta: float) -> void:
    var raw_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var direction := MovementMath.normalized_input(raw_input)

    velocity = direction * move_speed
    move_and_slide()

    var moving := not direction.is_zero_approx()
    facing = MovementMath.facing_index(direction, facing)
    _apply_visual_state(moving, delta)


func _configure_visuals() -> void:
    _using_open_sheet = ResourceLoader.exists(OpenAssetLibrary.PLAYER_SHEET)
    sprite.texture = OpenAssetLibrary.load_texture(
        OpenAssetLibrary.PLAYER_SHEET,
        "res://assets/original/player/player.svg"
    )
    shadow.texture = OpenAssetLibrary.load_texture(
        OpenAssetLibrary.SHADOW_TEXTURE,
        "res://assets/original/player/shadow.svg"
    )

    if _using_open_sheet:
        sprite.hframes = 4
        sprite.vframes = 7
        sprite.scale = Vector2(2, 2)
        sprite.position = Vector2(0, -12)
        shadow.scale = Vector2(2, 2)
        shadow.position = Vector2(0, 5)
    else:
        sprite.hframes = 1
        sprite.vframes = 1
        sprite.scale = Vector2.ONE
        sprite.position = Vector2(0, -10)
        shadow.scale = Vector2.ONE
        shadow.position = Vector2(0, 16)


func _apply_visual_state(moving: bool, delta: float) -> void:
    if not _using_open_sheet:
        return
    sprite.frame_coords = Vector2i(
        _direction_column(facing),
        _animation_row(moving, delta)
    )


func _direction_column(current_facing: int) -> int:
    match current_facing:
        MovementMath.Facing.NORTH:
            return 1
        MovementMath.Facing.EAST:
            return 3
        MovementMath.Facing.WEST:
            return 2
        _:
            return 0


func _animation_row(moving: bool, delta: float) -> int:
    if not moving:
        _animation_time = 0.0
        return 0
    _animation_time = fmod(_animation_time + delta * animation_speed, 4.0)
    return int(floor(_animation_time))
