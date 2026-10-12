extends Node
## Autoload "ItemDB": catálogo de todos os dados do jogo, disponível em qualquer script.
## Uso: ItemDB.get_item(&"minerio_ferro")

var catalog := ItemCatalog.new()


func _ready() -> void:
	catalog.load_all()
	for problem in catalog.validate():
		push_error("Dados do jogo: " + problem)
	print("ItemDB: %d itens, %d receitas, %d tabelas de drop, %d heróis" % [
		catalog.items.size(), catalog.recipes.size(), catalog.drop_tables.size(), catalog.heroes.size()])


func get_item(id: StringName) -> ItemData:
	return catalog.get_item(id)


func get_recipe(id: StringName) -> RecipeData:
	return catalog.get_recipe(id)


func get_drop_table(id: StringName) -> DropTable:
	return catalog.get_drop_table(id)


func get_profession(id: StringName) -> ProfessionData:
	return catalog.get_profession(id)


func get_hero(id: StringName) -> HeroData:
	return catalog.get_hero(id)
