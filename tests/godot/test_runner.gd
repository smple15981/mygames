extends SceneTree

const SUITES := [
    preload("res://tests/godot/suites/test_action_protocol.gd"),
    preload("res://tests/godot/suites/test_inventory_model.gd"),
    preload("res://tests/godot/suites/test_crafting_service.gd"),
    preload("res://tests/godot/suites/test_inventory_ui.gd"),
    preload("res://tests/godot/suites/test_world_layout_config.gd"),
    preload("res://tests/godot/suites/test_player_stats.gd"),
    preload("res://tests/godot/suites/test_camera_rig.gd"),
    preload("res://tests/godot/suites/test_game_input_router.gd"),
    preload("res://tests/godot/suites/test_world_collisions.gd"),
]


func _init() -> void:
    call_deferred("_run_tests")


func _run_tests() -> void:
    print("HEARTHWILD_TEST_RUNNER_START")
    var failures: Array[String] = []
    for index in SUITES.size():
        print("HEARTHWILD_SUITE_START:%d" % index)
        failures.append_array(SUITES[index].run())
        print("HEARTHWILD_SUITE_DONE:%d" % index)
    for failure in failures:
        push_error(failure)
    print("HEARTHWILD_TEST_RUNNER_QUIT:%d" % failures.size())
    quit(0 if failures.is_empty() else 1)
