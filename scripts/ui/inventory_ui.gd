class_name InventoryUI
extends PanelContainer

signal opened_changed(opened: bool)

const PORTABLE_RECIPE_PATHS := [
    "res://data/recipes/stone_axe.tres",
    "res://data/recipes/stone_pickaxe.tres",
    "res://data/recipes/wooden_sword.tres",
    "res://data/recipes/torch.tres",
]

@onready var item_grid: GridContainer = $Margin/Column/Main/InventoryColumn/ItemGrid
@onready var recipe_list: ItemList = $Margin/Column/Main/RecipeColumn/RecipeList
@onready var recipe_detail: Label = $Margin/Column/Main/RecipeColumn/RecipeDetail
@onready var craft_button: Button = $Margin/Column/Main/RecipeColumn/CraftButton
@onready var status_label: Label = $Margin/Column/Main/RecipeColumn/Status
@onready var close_button: Button = $Margin/Column/Header/CloseButton

var inventory: InventoryModel
var recipes: Array[RecipeDefinition] = []
var selected_recipe: RecipeDefinition


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    _build_inventory_grid()
    _load_recipes()
    close_button.pressed.connect(close)
    craft_button.pressed.connect(_on_craft_pressed)
    recipe_list.item_selected.connect(_on_recipe_selected)


func bind(model: InventoryModel) -> void:
    if inventory != null:
        var refresh_callable := Callable(self, "_refresh_inventory")
        var selected_callable := Callable(self, "_on_selected_slot_changed")
        if inventory.changed.is_connected(refresh_callable):
            inventory.changed.disconnect(refresh_callable)
        if inventory.selected_changed.is_connected(selected_callable):
            inventory.selected_changed.disconnect(selected_callable)

    inventory = model
    if inventory != null:
        inventory.changed.connect(_refresh_inventory)
        inventory.selected_changed.connect(_on_selected_slot_changed)
    _refresh_inventory()
    _refresh_recipe_detail()


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("inventory"):
        return
    if visible:
        close()
    else:
        open()
    get_viewport().set_input_as_handled()


func open() -> void:
    if inventory == null or visible:
        return
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    visible = true
    status_label.text = ""
    _refresh_inventory()
    _refresh_recipe_detail()
    get_tree().paused = true
    opened_changed.emit(true)


func close() -> void:
    if not visible:
        return
    get_tree().paused = false
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    opened_changed.emit(false)


func _exit_tree() -> void:
    if visible and get_tree() != null:
        get_tree().paused = false


func _build_inventory_grid() -> void:
    if item_grid.get_child_count() == InventoryModel.CAPACITY:
        return
    for child in item_grid.get_children():
        child.queue_free()
    for index in InventoryModel.CAPACITY:
        var button := Button.new()
        button.name = "Slot%d" % index
        button.custom_minimum_size = Vector2(50, 43)
        button.focus_mode = Control.FOCUS_NONE
        button.expand_icon = true
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_theme_font_size_override("font_size", 10)
        item_grid.add_child(button)


func _load_recipes() -> void:
    recipes.clear()
    recipe_list.clear()
    for path in PORTABLE_RECIPE_PATHS:
        var recipe := load(path) as RecipeDefinition
        if recipe == null:
            push_error("Unable to load recipe: %s" % path)
            continue
        recipes.append(recipe)
        var definition := ItemCatalog.get_item(recipe.output_item_id)
        recipe_list.add_item(
            recipe.display_name,
            definition.icon if definition != null else null
        )
    if not recipes.is_empty():
        recipe_list.select(0)
        _on_recipe_selected(0)


func _on_selected_slot_changed(_index: int) -> void:
    _refresh_inventory()


func _refresh_inventory() -> void:
    if not is_node_ready():
        return
    _build_inventory_grid()
    for index in InventoryModel.CAPACITY:
        var button := item_grid.get_child(index) as Button
        if inventory == null:
            button.icon = null
            button.text = ""
            button.tooltip_text = ""
            continue

        var slot := inventory.slots[index]
        button.modulate = (
            Color("#ffe5a3")
            if index == inventory.selected_index
            else Color.WHITE
        )
        if slot.is_empty():
            button.icon = null
            button.text = str(index + 1) if index < InventoryModel.QUICKBAR_SIZE else ""
            button.tooltip_text = "空"
            continue

        var definition := ItemCatalog.get_item(slot.item_id)
        button.icon = definition.icon if definition != null else null
        button.text = str(slot.quantity) if slot.quantity > 1 else ""
        button.tooltip_text = definition.display_name if definition != null else String(slot.item_id)
    _refresh_recipe_detail()


func _on_recipe_selected(index: int) -> void:
    if index < 0 or index >= recipes.size():
        selected_recipe = null
    else:
        selected_recipe = recipes[index]
    status_label.text = ""
    _refresh_recipe_detail()


func _refresh_recipe_detail() -> void:
    if not is_node_ready():
        return
    if selected_recipe == null:
        recipe_detail.text = "选择一个配方"
        craft_button.disabled = true
        return

    var lines := PackedStringArray([selected_recipe.display_name, "需要："])
    var can_craft := inventory != null
    for raw_item_id in selected_recipe.ingredients:
        var item_id := StringName(str(raw_item_id))
        var required := int(selected_recipe.ingredients[raw_item_id])
        var owned := inventory.count_item(item_id) if inventory != null else 0
        var definition := ItemCatalog.get_item(item_id)
        var display_name := definition.display_name if definition != null else String(item_id)
        lines.append("%s  %d/%d" % [display_name, owned, required])
        if owned < required:
            can_craft = false
    recipe_detail.text = "\n".join(lines)
    craft_button.disabled = not can_craft


func _on_craft_pressed() -> void:
    if inventory == null or selected_recipe == null:
        return
    var result := CraftingService.craft(selected_recipe, inventory)
    if result.ok:
        status_label.text = (
            "成品等待领取"
            if result.output_pending
            else "制作完成"
        )
    else:
        match result.reason:
            &"missing_materials":
                status_label.text = "材料不足"
            &"inventory_full":
                status_label.text = "背包已满"
            _:
                status_label.text = "无法制作"
    _refresh_inventory()
