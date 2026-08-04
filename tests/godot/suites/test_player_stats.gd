extends RefCounted


static func run() -> Array[String]:
    var failures: Array[String] = []
    var stats := PlayerStats.new()
    var health_events: Array[Vector2] = []
    stats.health_changed.connect(
        func(current: float, maximum: float) -> void:
            health_events.append(Vector2(current, maximum))
    )

    stats.set_health(130.0)
    failures.append(TestAssert.equal(stats.health, 100.0, "health upper clamp"))
    stats.change_health(-145.0)
    failures.append(TestAssert.equal(stats.health, 0.0, "health lower clamp"))
    stats.set_stamina(42.0)
    failures.append(TestAssert.equal(stats.stamina, 42.0, "stamina value"))
    stats.set_mana(-10.0)
    failures.append(TestAssert.equal(stats.mana, 0.0, "mana lower clamp"))
    stats.restore_all()
    failures.append(TestAssert.equal(stats.health, 100.0, "health restore"))
    failures.append(TestAssert.equal(stats.stamina, 100.0, "stamina restore"))
    failures.append(TestAssert.equal(stats.mana, 100.0, "mana restore"))
    failures.append(TestAssert.truthy(health_events.size() >= 2, "health signal"))

    var packed := load("res://scenes/ui/stats_hud.tscn") as PackedScene
    failures.append(TestAssert.truthy(packed != null, "stats HUD loads"))
    if packed != null:
        var hud := packed.instantiate() as StatsHUD
        Engine.get_main_loop().root.add_child(hud)
        hud.bind(stats)
        stats.set_mana(55.0)
        var label := hud.get_node("Margin/Column/Mana/Value") as Label
        failures.append(TestAssert.equal(label.text, "55 / 100", "mana label"))
        hud.free()

    stats.free()
    return failures.filter(func(message: String) -> bool: return not message.is_empty())
