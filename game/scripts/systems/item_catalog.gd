class_name ItemCatalog
extends RefCounted
## Lê todos os dados do jogo em game/data/ e permite buscá-los pelo id.
## O autoload ItemDB usa esta classe; os testes também usam, sem depender do autoload.

const DATA_ROOT := "res://game/data"

var items: Dictionary = {}          # id -> ItemData
var heroes: Dictionary = {}         # id -> HeroData
var drop_tables: Dictionary = {}    # id -> DropTable
var recipes: Dictionary = {}        # id -> RecipeData
var professions: Dictionary = {}    # id -> ProfessionData
var buffs: Dictionary = {}          # id -> BuffData
var enemies: Dictionary = {}        # id -> EnemyData


func load_all(root: String = DATA_ROOT) -> void:
	_load_folder(root + "/items", items)
	_load_folder(root + "/heroes", heroes)
	_load_folder(root + "/drop_tables", drop_tables)
	_load_folder(root + "/recipes", recipes)
	_load_folder(root + "/professions", professions)
	_load_folder(root + "/buffs", buffs)
	_load_folder(root + "/enemies", enemies)


func get_item(id: StringName) -> ItemData:
	return items.get(id)


func get_recipe(id: StringName) -> RecipeData:
	return recipes.get(id)


func get_drop_table(id: StringName) -> DropTable:
	return drop_tables.get(id)


func get_profession(id: StringName) -> ProfessionData:
	return professions.get(id)


func get_hero(id: StringName) -> HeroData:
	return heroes.get(id)


func get_enemy(id: StringName) -> EnemyData:
	return enemies.get(id)


## Confere se todo id citado em drops e receitas existe. Devolve a lista de problemas.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for table: DropTable in drop_tables.values():
		for entry in table.entries:
			if entry.table_id != &"":
				if not drop_tables.has(entry.table_id):
					problems.append("Drop '%s' cita tabela inexistente '%s'" % [table.id, entry.table_id])
			elif not items.has(entry.item_id):
				problems.append("Drop '%s' cita item inexistente '%s'" % [table.id, entry.item_id])
	for recipe: RecipeData in recipes.values():
		if not items.has(recipe.result_item_id):
			problems.append("Receita '%s' gera item inexistente '%s'" % [recipe.id, recipe.result_item_id])
		for ingredient_id in recipe.ingredients:
			if not items.has(StringName(ingredient_id)):
				problems.append("Receita '%s' usa item inexistente '%s'" % [recipe.id, ingredient_id])
		if recipe.profession_id != &"" and not professions.has(recipe.profession_id):
			problems.append("Receita '%s' exige profissão inexistente '%s'" % [recipe.id, recipe.profession_id])
	for hero: HeroData in heroes.values():
		if hero.starting_weapon_id != &"" and not items.has(hero.starting_weapon_id):
			problems.append("Herói '%s' começa com item inexistente '%s'" % [hero.id, hero.starting_weapon_id])
	for enemy: EnemyData in enemies.values():
		if enemy.drop_table_id != &"" and not drop_tables.has(enemy.drop_table_id):
			problems.append("Inimigo '%s' usa tabela de drop inexistente '%s'" % [enemy.id, enemy.drop_table_id])
	return problems


func _load_folder(path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		# No jogo exportado os arquivos aparecem como "x.tres.remap".
		var clean := file_name.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var res := load(path + "/" + clean)
		if res == null or not "id" in res:
			push_warning("Dado ignorado (sem id): %s/%s" % [path, clean])
			continue
		if target.has(res.id):
			push_error("Id repetido '%s' em %s" % [res.id, path])
			continue
		target[res.id] = res
