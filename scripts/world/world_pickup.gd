class_name WorldPickup
extends Node2D

signal collected(item_id: StringName, quantity: int)
signal pickup_blocked(item_id: StringName)

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


func configure(
    pickup_item_id: StringName,
    pickup_quantity: int,
    player_node: Node2D,
    inventory_model: InventoryModel
) -> void:
    item_id = pickup_item_id
    quantity = maxi(1, pickup_quantity)
    player = player_node
    inventory = inventory_model
    _ensure_nodes()
    _refresh_visual()


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
    if has_node("PickupArea"):
        return

    var sprite := Sprite2D.new()
    sprite.name = "Visual"
    sprite.scale = Vector2(0.72, 0.72)
    sprite.position = Vector2(0, -5)
    add_child(sprite)

    _quantity_label = Label.new()
    _quantity_label.name = "Quantity"
    _quantity_label.position = Vector2(6, 2)
    _quantity_label.z_index = 2
    _quantity_label.add_theme_font_size_override("font_size", 10)
    add_child(_quantity_label)

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
    var sprite := get_node("Visual") as Sprite2D
    sprite.texture = definition.icon if definition != null else null
    _quantity_label = get_node("Quantity") as Label
    _quantity_label.text = str(quantity) if quantity > 1 else ""
