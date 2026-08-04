class_name ItemCatalog
extends RefCounted

const ITEM_PATHS := {
    &"branch": "res://data/items/branch.tres",
    &"loose_stone": "res://data/items/loose_stone.tres",
    &"wood": "res://data/items/wood.tres",
    &"stone": "res://data/items/stone.tres",
    &"grass": "res://data/items/grass.tres",
    &"slime_gel": "res://data/items/slime_gel.tres",
    &"stone_axe": "res://data/items/stone_axe.tres",
    &"stone_pickaxe": "res://data/items/stone_pickaxe.tres",
    &"wooden_sword": "res://data/items/wooden_sword.tres",
    &"wooden_hoe": "res://data/items/wooden_hoe.tres",
    &"worn_watering_can": "res://data/items/worn_watering_can.tres",
    &"moon_dew_seed": "res://data/items/moon_dew_seed.tres",
    &"moon_dew_radish": "res://data/items/moon_dew_radish.tres",
    &"torch": "res://data/items/torch.tres",
    &"simple_bandage": "res://data/items/simple_bandage.tres",
}

static var _items: Dictionary = {}


static func _ensure_loaded() -> void:
    if _items.size() == ITEM_PATHS.size():
        return
    _items.clear()
    for item_id in ITEM_PATHS:
        var definition := load(ITEM_PATHS[item_id]) as ItemDefinition
        if definition == null:
            push_error("Unable to load item definition: %s" % ITEM_PATHS[item_id])
            continue
        _items[item_id] = definition


static func get_item(item_id: StringName) -> ItemDefinition:
    _ensure_loaded()
    return _items.get(item_id) as ItemDefinition


static func has_item(item_id: StringName) -> bool:
    _ensure_loaded()
    return _items.has(item_id)


static func all_items() -> Array[ItemDefinition]:
    _ensure_loaded()
    var values: Array[ItemDefinition] = []
    for definition in _items.values():
        values.append(definition as ItemDefinition)
    return values
