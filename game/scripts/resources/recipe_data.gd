class_name RecipeData
extends Resource
## Receita de crafting.

@export var id: StringName
@export var display_name: String = ""
@export var result_item_id: StringName
@export_range(1, 999) var result_qty: int = 1
## Ingredientes: {id_do_item: quantidade}. Ex.: {&"minerio_ferro": 5}
@export var ingredients: Dictionary = {}

@export_group("Profissão")
## Deixe vazio se qualquer um puder craftar.
@export var profession_id: StringName
@export_range(0, 100) var required_level: int = 0
@export_range(0, 10000) var xp_reward: int = 0
