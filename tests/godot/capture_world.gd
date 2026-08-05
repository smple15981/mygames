extends SceneTree

const OUTPUT_PATH := "res://artifacts/world-validation.png"
const PICKUP_OFFSETS: Array[Vector2] = [
    Vector2(-72, 38),
    Vector2(-38, 54),
    Vector2(0, 46),
    Vector2(38, 54),
    Vector2(72, 38),
    Vector2(0, 76),
]


func _init() -> void:
    call_deferred("_capture_world")


func _capture_world() -> void:
    root.size = Vector2i(1280, 720)
    var packed := load("res://scenes/world/prototype_world.tscn") as PackedScene
    if packed == null:
        push_error("Unable to load prototype world for screenshot")
        quit(1)
        return

    var world := packed.instantiate() as PrototypeWorld
    root.add_child(world)
    for _frame in 12:
        await process_frame

    _stage_mouse_interaction_view(world)
    for _frame in 60:
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
    world.cursor_manager.release_cursor()
    quit(0)


func _stage_mouse_interaction_view(world: PrototypeWorld) -> void:
    world.inventory_ui.close()
    world.camera_rig.set_zoom_value(CameraRig.MIN_ZOOM)

    var pair := _closest_resource_pair(world)
    if pair.size() == 2:
        var tree_root := pair[0].get_parent() as Node2D
        var rock_root := pair[1].get_parent() as Node2D
        var requested := (tree_root.global_position + rock_root.global_position) * 0.5
        world.player.global_position = world.world_layout.recover_player_position(
            requested,
            Vector2(16, 12)
        )
        world.player.velocity = Vector2.ZERO

    var starter_pickups := world.get_tree().get_nodes_in_group("starter_pickups")
    for index in starter_pickups.size():
        var pickup := starter_pickups[index] as WorldPickup
        if pickup == null or not world.entities.is_ancestor_of(pickup):
            continue
        pickup.pickup_delay = 999.0
        if index < PICKUP_OFFSETS.size():
            pickup.global_position = world.player.global_position + PICKUP_OFFSETS[index]

    world.action_feedback.show_message("左键点击资源：自动靠近并持续采集")


func _closest_resource_pair(world: PrototypeWorld) -> Array[HarvestableResource]:
    var trees: Array[HarvestableResource] = []
    var rocks: Array[HarvestableResource] = []
    for node in world.get_tree().get_nodes_in_group("harvestables"):
        var resource := node as HarvestableResource
        if (
            resource == null
            or resource.is_depleted()
            or not world.entities.is_ancestor_of(resource)
        ):
            continue
        var target := resource.get_parent().get_node_or_null("InteractionTarget") as InteractionTarget
        if target == null:
            continue
        if target.kind == InteractionTarget.Kind.HARVEST_TREE:
            trees.append(resource)
        elif target.kind == InteractionTarget.Kind.HARVEST_ROCK:
            rocks.append(resource)

    var best: Array[HarvestableResource] = []
    var best_distance := INF
    for tree in trees:
        var tree_root := tree.get_parent() as Node2D
        for rock in rocks:
            var rock_root := rock.get_parent() as Node2D
            var distance := tree_root.global_position.distance_to(rock_root.global_position)
            if distance < best_distance:
                best_distance = distance
                best = [tree, rock]
    return best
