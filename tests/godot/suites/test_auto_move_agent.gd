extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var agent := AutoMoveAgent.new()
    var arrivals := [0]
    var cancellations: Array[StringName] = []
    agent.arrived.connect(func(): arrivals[0] += 1)
    agent.cancelled.connect(func(reason: StringName): cancellations.append(reason))

    agent.set_path_for_test(
        PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(64, 0)]),
        Vector2(0, 0)
    )
    failures.append(TestAssert.truthy(agent.is_active(), "test path activates agent"))
    failures.append(TestAssert.equal(
        agent.next_direction(Vector2(0, 0), 0.1),
        Vector2.RIGHT,
        "agent follows first segment"
    ))
    failures.append(TestAssert.equal(
        agent.next_direction(Vector2(32, 0), 0.1),
        Vector2.RIGHT,
        "agent advances path point"
    ))
    failures.append(TestAssert.equal(
        agent.next_direction(Vector2(64, 0), 0.1),
        Vector2.ZERO,
        "agent stops on arrival"
    ))
    failures.append(TestAssert.equal(arrivals[0], 1, "arrival emitted once"))
    failures.append(TestAssert.truthy(not agent.is_active(), "arrival clears path"))

    agent.set_path_for_test(
        PackedVector2Array([Vector2(0, 0), Vector2(32, 0)]),
        Vector2(0, 0)
    )
    agent.cancel(&"manual_input")
    failures.append(TestAssert.equal(cancellations, [&"manual_input"], "manual cancel reason"))
    failures.append(TestAssert.equal(
        agent.next_direction(Vector2(0, 0), 0.1),
        Vector2.ZERO,
        "cancelled agent has no direction"
    ))

    var player_scene := load("res://scenes/player/player.tscn") as PackedScene
    var player := player_scene.instantiate() as PlayerController
    failures.append(TestAssert.truthy(player.has_node("AutoMoveAgent"), "player has auto move agent"))
    var collision := player.get_node("CollisionShape2D") as CollisionShape2D
    failures.append(TestAssert.equal(collision.position, Vector2(0, -6), "player collision foot anchor"))
    failures.append(TestAssert.equal(
        (collision.shape as RectangleShape2D).size,
        Vector2(16, 12),
        "player collision size"
    ))

    player.free()
    agent.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
