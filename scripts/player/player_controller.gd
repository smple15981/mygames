class_name PlayerController
extends CharacterBody2D

signal manual_input_started

@export_range(20.0, 400.0, 1.0) var move_speed: float = 120.0
@export_range(1.0, 12.0, 0.5) var animation_speed: float = 6.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var item_user: ItemUser = $ItemUser
@onready var auto_move_agent: AutoMoveAgent = $AutoMoveAgent

var facing: int = MovementMath.Facing.SOUTH
var gameplay_input_blocked := false
var _animation_time := 0.0
var _using_open_sheet := false
var _manual_was_active := false


func _ready() -> void:
    _configure_visuals()
    auto_move_agent.bind(self, null)


func _physics_process(delta: float) -> void:
    var raw_input := (
        Vector2.ZERO
        if gameplay_input_blocked
        else Input.get_vector("move_left", "move_right", "move_up", "move_down")
    )
    var manual_direction := MovementMath.normalized_input(raw_input)
    var manual_active := not manual_direction.is_zero_approx()
    if manual_active:
        if not _manual_was_active:
            manual_input_started.emit()
        auto_move_agent.cancel(&"manual_input")

    var direction := manual_direction
    if not gameplay_input_blocked and not manual_active:
        direction = auto_move_agent.next_direction(global_position, delta)
    _manual_was_active = manual_active

    velocity = direction * move_speed
    move_and_slide()

    var moving := not direction.is_zero_approx()
    facing = MovementMath.facing_index(direction, facing)
    _apply_visual_state(moving, delta)


func _unhandled_input(event: InputEvent) -> void:
    if gameplay_input_blocked:
        return
    if event is InputEventMouseButton:
        return
    if event.is_action_pressed("attack"):
        item_user.request_use(aim_direction())
        get_viewport().set_input_as_handled()


func set_gameplay_input_blocked(blocked: bool) -> void:
    gameplay_input_blocked = blocked
    if blocked:
        velocity = Vector2.ZERO
        auto_move_agent.cancel(&"modal")


func set_path_grid(grid: WorldPathGrid) -> void:
    auto_move_agent.bind(self, grid)


func aim_direction() -> Vector2:
    var mouse_world := get_global_mouse_position()
    var direction := global_position.direction_to(mouse_world)
    return direction if not direction.is_zero_approx() else Vector2.DOWN


func _configure_visuals() -> void:
    _using_open_sheet = OpenAssetLibrary.texture_exists(OpenAssetLibrary.PLAYER_SHEET)
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
        sprite.position = Vector2(0, -16)
        shadow.scale = Vector2(2, 2)
        shadow.position = Vector2(0, -2)
    else:
        sprite.hframes = 1
        sprite.vframes = 1
        sprite.scale = Vector2.ONE
        sprite.position = Vector2(0, -22)
        shadow.scale = Vector2.ONE
        shadow.position = Vector2(0, -2)


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
