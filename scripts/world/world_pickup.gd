class_name WorldPickup
extends Node2D

signal collected(item_id: StringName, quantity: int)
signal pickup_blocked(item_id: StringName)

const OUTLINE_SHADER: Shader = preload("res://assets/original/ui/interaction_outline.gdshader")

@export_range(8.0, 96.0, 1.0) var attract_range := 30.0
@export_range(2.0, 32.0, 1.0) var collect_range := 8.0
@export_range(16.0, 400.0, 1.0) var attract_speed := 150.0
@export_range(0.0, 2.0, 0.05) var pickup_delay := 0.35

var item_id: StringName
var quantity := 0
var player: Node2D
var inventory: InventoryModel
var _blocked_reported := false
var _collected := false
var _quantity_label: Label
var _highlight: Sprite2D


func configure(
    pickup_item_id: StringName,
    pickup_quantity: int,
    player_node: Node2D,
    inventory_model: InventoryModel
) -> void:
    _disconnect_inventory()
    item_id = pickup_item_id
    quantity = maxi(1, pickup_quantity)
    player = player_node
    inventory = inventory_model
    _blocked_reported = false
    _collected = false
    if inventory != null and not inventory.changed.is_connected(_on_inventory_changed):
        inventory.changed.connect(_on_inventory_changed)
    _ensure_nodes()
    _refresh_visual()


func _exit_tree() -> void:
    _disconnect_inventory()


func _physics_process(delta: float) -> void:
    if _collected or player == null or inventory == null or not is_instance_valid(player):
        return
    if pickup_delay > 0.0:
        pickup_delay = maxf(0.0, pickup_delay - delta)
        return

    var distance := global_position.distance_to(player.global_position)
    if distance <= collect_range:
        try_transfer()
        return
    if distance <= attract_range and not _blocked_reported:
        global_position = global_position.move_toward(
            player.global_position,
            attract_speed * delta
        )


func try_transfer() -> int:
    if _collected or inventory == null or quantity <= 0:
        return quantity

    var before := quantity
    quantity = inventory.add_item(item_id, quantity)
    var accepted := before - quantity
    if accepted > 0:
        _blocked_reported = false

    if quantity == 0:
        _collected = true
        collected.emit(item_id, accepted)
        if is_inside_tree():
            queue_free()
    else:
        _refresh_visual()
        if not _blocked_reported:
            _blocked_reported = true
            pickup_blocked.emit(item_id)
    return quantity


func _ensure_nodes() -> void:
    if has_node("PickupArea") and has_node("InteractionTarget"):
        return

    var sprite := Sprite2D.new()
    sprite.name = "Visual"
    sprite.scale = Vector2(0.72, 0.72)
    sprite.position = Vector2(0, -5)
    add_child(sprite)

    _highlight = Sprite2D.new()
    _highlight.name = "Highlight"
    _highlight.scale = sprite.scale
    _highlight.position = sprite.position
    _highlight.visible = false
    _highlight.z_index = -1
    var outline_material := ShaderMaterial.new()
    outline_material.shader = OUTLINE_SHADER
    _highlight.material = outline_material
    add_child(_highlight)

    _quantity_label = Label.new()
    _quantity_label.name = "Quantity"
    _quantity_label.position = Vector2(6, 2)
    _quantity_label.z_index = 2
    _quantity_label.add_theme_font_size_override("font_size", 10)
    add_child(_quantity_label)

    var interaction_target := InteractionTarget.new()
    interaction_target.name = "InteractionTarget"
    interaction_target.kind = InteractionTarget.Kind.PICKUP
    interaction_target.interaction_range = attract_range
    interaction_target.target_rect = Rect2(-10, -16, 20, 20)
    interaction_target.highlight = _highlight
    interaction_target.collision_layer = 4
    interaction_target.collision_mask = 0
    add_child(interaction_target)

    var interaction_shape := CircleShape2D.new()
    interaction_shape.radius = 10.0
    var interaction_collision := CollisionShape2D.new()
    interaction_collision.name = "CollisionShape2D"
    interaction_collision.position = Vector2(0, -5)
    interaction_collision.shape = interaction_shape
    interaction_target.add_child(interaction_collision)

    var area := Area2D.new()
    area.name = "PickupArea"
    area.collision_layer = 8
    area.collision_mask = 0
    area.monitoring = false
    add_child(area)

    var shape := CircleShape2D.new()
    shape.radius = 8.0
    var collision := CollisionShape2D.new()
    collision.name = "CollisionShape2D"
    collision.shape = shape
    area.add_child(collision)


func _refresh_visual() -> void:
    _ensure_nodes()
    var definition := ItemCatalog.get_item(item_id)
    var texture := definition.icon if definition != null else null
    var sprite := get_node("Visual") as Sprite2D
    sprite.texture = texture
    _highlight = get_node("Highlight") as Sprite2D
    _highlight.texture = texture
    var material := _highlight.material as ShaderMaterial
    if material != null and texture != null:
        var texture_size := Vector2(texture.get_size())
        if texture_size.x > 0.0 and texture_size.y > 0.0:
            material.set_shader_parameter(
                "pixel_size",
                Vector2(1.0 / texture_size.x, 1.0 / texture_size.y)
            )
    _quantity_label = get_node("Quantity") as Label
    _quantity_label.text = str(quantity) if quantity > 1 else ""


func _on_inventory_changed() -> void:
    _blocked_reported = false


func _disconnect_inventory() -> void:
    if inventory != null and inventory.changed.is_connected(_on_inventory_changed):
        inventory.changed.disconnect(_on_inventory_changed)
