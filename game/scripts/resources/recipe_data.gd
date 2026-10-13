class_name RecipeData
extends Resource
## Receita de crafting.
## Equipamentos vêm em cadeia: a receita Rara de uma peça pede a mesma peça Comum (a "peça-base"),
## a Épica pede a Rara e a Lendária pede a Épica. Ver Crafting para chance e regras de falha.

@export var id: StringName
@export var display_name: String = ""
@export var result_item_id: StringName
@export_range(1, 999) var result_qty: int = 1
## Raridade da peça fabricada (só para equipamentos).
@export var result_rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## Pede uma peça do mesmo item na raridade anterior, que é consumida no sucesso e volta na falha.
@export var requires_base: bool = false
## Reagentes: {id_do_item: quantidade}. Ex.: {&"minerio_ferro": 5}
@export var ingredients: Dictionary = {}

@export_group("Profissão")
## Deixe vazio se qualquer um puder craftar.
@export var profession_id: StringName
@export_range(0, 100) var required_level: int = 0
@export_range(0, 10000) var xp_reward: int = 0
