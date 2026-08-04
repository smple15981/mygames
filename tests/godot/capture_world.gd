extends SceneTree

const OUTPUT_PATH := "res://artifacts/world-validation.png"


func _init() -> void:
    call_deferred("_capture_world")


func _capture_world() -> void:
    root.size = Vector2i(1280, 720)
    var packed := load("res://scenes/world/prototype_world.tscn") as PackedScene
    if packed == null:
        push_error("Unable to load prototype world for screenshot")
        quit(1)
        return

    var world := packed.instantiate()
    root.add_child(world)
    for _frame in 45:
        await process_frame

    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("World screenshot viewport returned an empty image")
        quit(1)
        return

    var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
    var output_directory := output_absolute.get_base_dir()
    var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
    if directory_error != OK:
        push_error("Unable to create screenshot directory: %s" % directory_error)
        quit(1)
        return

    var save_error := image.save_png(output_absolute)
    if save_error != OK:
        push_error("Unable to save world screenshot: %s" % save_error)
        quit(1)
        return

    print("HEARTHWILD_SCREENSHOT_SAVED:%s" % OUTPUT_PATH)
    quit(0)
