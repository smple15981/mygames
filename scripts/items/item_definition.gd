class_name ItemDefinition
extends Resource

enum ItemType { MATERIAL, WEAPON, TOOL, SEED, FOOD, KEY_ITEM }
enum ToolType { NONE, AXE, PICKAXE, HOE, WATERING_CAN }

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MATERIAL
@export_range(1, 999, 1) var max_stack := 99
@export_range(0.0, 5.0, 0.05) var use_cooldown := 0.25
@export var tool_type: ToolType = ToolType.NONE
@export_range(0, 10, 1) var tool_level := 0
@export_range(0, 100, 1) var base_damage := 0
@export_range(0, 100, 1) var heal_amount := 0
@export_range(0.0, 3.0, 0.05) var consume_duration := 0.55
@export_range(0.0, 128.0, 1.0) var use_range := 48.0
@export_range(0.0, 180.0, 1.0) var arc_degrees := 0.0
@export var key_item := false
