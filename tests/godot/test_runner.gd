extends SceneTree

const SUITES := [
    preload("res://tests/godot/suites/test_action_protocol.gd"),
    preload("res://tests/godot/suites/test_inventory_model.gd"),
    preload("res://tests/godot/suites/test_crafting_service.gd"),
]


func _init() -> void:
    var failures: Array[String] = []
    for suite in SUITES:
        failures.append_array(suite.run())
    for failure in failures:
        push_error(failure)
    quit(0 if failures.is_empty() else 1)
