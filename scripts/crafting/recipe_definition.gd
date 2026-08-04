class_name RecipeDefinition
extends Resource

enum Station { PORTABLE, WORKBENCH }

@export var id: StringName
@export var display_name: String
@export var station: Station = Station.PORTABLE
@export var ingredients: Dictionary = {}
@export var output_item_id: StringName
@export_range(1, 99, 1) var output_quantity := 1
@export var key_recipe := false
