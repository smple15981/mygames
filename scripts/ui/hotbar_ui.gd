class_name HotbarUI
extends Control

const SLOT_COUNT := 5

@onready var slots_container: HBoxContainer = $Slots

var inventory: InventoryModel


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ensure_slots()
    _refresh()


func bind(model: InventoryModel) -> void:
    if inventory != null:
        var changed_callable := Callable(self, "_refresh")
        var selected_callable := Callable(self, "_on_selected_changed")
        if inventory.changed.is_connected(changed_callable):
            inventory.changed.disconnect(changed_callable)
        if inventory.selected_changed.is_connected(selected_callable):
            inventory.selected_changed.disconnect(selected_callable)

    inventory = model
    if inventory != null:
        inventory.changed.connect(_refresh)
        inventory.selected_changed.connect(_on_selected_changed)
    _refresh()


func _ensure_slots() -> void:
    if slots_container.get_child_count() == SLOT_COUNT:
        return
    for child in slots_container.get_children():
        child.queue_free()
    for index in SLOT_COUNT:
        slots_container.add_child(_create_slot(index))


func _create_slot(index: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = "Slot%d" % index
    panel.custom_minimum_size = Vector2(50, 38)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var content := Control.new()
    content.name = "Content"
    content.custom_minimum_size = Vector2(46, 34)
    panel.add_child(content)

    var icon := TextureRect.new()
    icon.name = "Icon"
    icon.offset_left = 10.0
    icon.offset_top = 2.0
    icon.offset_right = 36.0
    icon.offset_bottom = 28.0
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(icon)

    var quantity := Label.new()
    quantity.name = "Quantity"
    quantity.offset_left = 27.0
    quantity.offset_top = 19.0
    quantity.offset_right = 45.0
    quantity.offset_bottom = 34.0
    quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    quantity.add_theme_font_size_override("font_size", 11)
    quantity.add_theme_color_override("font_color", Color("#fff2c4"))
    quantity.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    quantity.add_theme_constant_override("shadow_offset_x", 1)
    quantity.add_theme_constant_override("shadow_offset_y", 1)
    quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(quantity)

    var key_label := Label.new()
    key_label.name = "Key"
    key_label.text = str(index + 1)
    key_label.offset_left = 3.0
    key_label.offset_top = 20.0
    key_label.offset_right = 15.0
    key_label.offset_bottom = 34.0
    key_label.add_theme_font_size_override("font_size", 10)
    key_label.add_theme_color_override("font_color", Color("#a9bbc0"))
    key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(key_label)
    return panel


func _on_selected_changed(_index: int) -> void:
    _refresh()


func _refresh() -> void:
    if not is_node_ready():
        return
    _ensure_slots()
    for index in SLOT_COUNT:
        var panel := slots_container.get_child(index) as PanelContainer
        var icon := panel.get_node("Content/Icon") as TextureRect
        var quantity := panel.get_node("Content/Quantity") as Label
        panel.add_theme_stylebox_override(
            "panel",
            _slot_style(inventory != null and inventory.selected_index == index)
        )

        if inventory == null:
            icon.texture = null
            quantity.text = ""
            panel.tooltip_text = ""
            continue

        var slot := inventory.slots[index]
        if slot.is_empty():
            icon.texture = null
            quantity.text = ""
            panel.tooltip_text = "空"
            continue

        var definition := ItemCatalog.get_item(slot.item_id)
        icon.texture = definition.icon if definition != null else null
        quantity.text = str(slot.quantity) if slot.quantity > 1 else ""
        panel.tooltip_text = definition.display_name if definition != null else String(slot.item_id)


func _slot_style(selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#172126") if not selected else Color("#2c2b22")
    style.border_color = Color("#405158") if not selected else Color("#d8ae55")
    style.border_width_left = 1 if not selected else 2
    style.border_width_top = 1 if not selected else 2
    style.border_width_right = 1 if not selected else 2
    style.border_width_bottom = 1 if not selected else 2
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    style.shadow_color = Color(0, 0, 0, 0.45)
    style.shadow_size = 2
    return style
