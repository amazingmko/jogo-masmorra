class_name Crafting
extends RefCounted
## Regras de crafting. Não guarda estado: recebe tudo que precisa.


## Explica por que não dá para craftar, ou devolve "" se der.
static func check(recipe: RecipeData, inventory: Inventory, professions: ProfessionProgress) -> String:
	if recipe == null:
		return "Receita não encontrada."
	if recipe.profession_id != &"" and professions.level_of(recipe.profession_id) < recipe.required_level:
		return "Precisa de nível %d na profissão." % recipe.required_level
	if not inventory.has_all(recipe.ingredients):
		return "Faltam ingredientes."
	return ""


## Tenta craftar. Devolve {"ok": bool, "reason": String}.
static func craft(recipe: RecipeData, inventory: Inventory, professions: ProfessionProgress, catalog: ItemCatalog,
		rng: RandomNumberGenerator = null) -> Dictionary:
	var reason := check(recipe, inventory, professions)
	if reason != "":
		return {"ok": false, "reason": reason}
	var result_item := catalog.get_item(recipe.result_item_id)
	if result_item == null:
		return {"ok": false, "reason": "Item resultante não existe."}
	inventory.remove_all(recipe.ingredients)
	if result_item.is_equipment():
		if rng == null:
			rng = RandomNumberGenerator.new()
			rng.randomize()
		for i in recipe.result_qty:
			inventory.add_equipment(ItemFactory.roll(result_item, maxi(result_item.tier, 1), GameEnums.Rarity.COMMON, rng))
	else:
		inventory.add(result_item, recipe.result_qty)
	if recipe.profession_id != &"":
		professions.add_xp(catalog.get_profession(recipe.profession_id), recipe.xp_reward)
	return {"ok": true, "reason": ""}
