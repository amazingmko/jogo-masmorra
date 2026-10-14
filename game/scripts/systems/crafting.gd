class_name Crafting
extends RefCounted
## Regras de crafting. Não guarda estado: recebe tudo que precisa.
##
## Chance de sucesso (replica/progressao.md, seção 6):
##   base por raridade + bônus por nível de profissão acima do exigido + 10% por falha seguida
##   na mesma receita (zera ao acertar), limite de 95%.
## Falha: perde metade dos reagentes (arredondando para cima), a peça-base volta inteira
## e a profissão ganha uma parte da XP.

const BASE_CHANCE := [0.90, 0.65, 0.40, 0.15]
const LEVEL_BONUS := [0.01, 0.01, 0.005, 0.005]
const STREAK_BONUS := 0.10
const MAX_CHANCE := 0.95
const FAIL_XP_FRACTION := 0.3
## Faixa interna das peças do Mundo 1 (Terra Firme). Não aparece para o jogador: a força
## vem da raridade. Um mundo novo pode usar uma faixa maior.
const WORLD_TIER := 5


static func success_chance(recipe: RecipeData, professions: ProfessionProgress, fail_streak: int = 0) -> float:
	var r := int(recipe.result_rarity)
	var chance: float = BASE_CHANCE[r]
	if recipe.profession_id != &"":
		var above := maxi(professions.level_of(recipe.profession_id) - recipe.required_level, 0)
		chance += above * LEVEL_BONUS[r]
	chance += fail_streak * STREAK_BONUS
	return minf(chance, MAX_CHANCE)


## Peça-base que a receita consumiria: a mesma peça na raridade anterior.
## Prefere uma que ninguém esteja vestindo (worn_uids). Devolve {} se não houver.
static func find_base(recipe: RecipeData, inventory: Inventory, worn_uids: Array = []) -> Dictionary:
	if not recipe.requires_base:
		return {}
	var want := int(recipe.result_rarity) - 1
	var fallback := {}
	for eq in inventory.equipment:
		if eq.item_id != String(recipe.result_item_id) or int(eq.rarity) != want:
			continue
		if not worn_uids.has(eq.uid):
			return eq
		if fallback.is_empty():
			fallback = eq
	return fallback


## Explica por que não dá para craftar, ou devolve "" se der.
static func check(recipe: RecipeData, inventory: Inventory, professions: ProfessionProgress, worn_uids: Array = []) -> String:
	if recipe == null:
		return "Receita não encontrada."
	if recipe.profession_id != &"" and professions.level_of(recipe.profession_id) < recipe.required_level:
		return "Precisa de nível %d na profissão." % recipe.required_level
	if recipe.requires_base and find_base(recipe, inventory, worn_uids).is_empty():
		return "Precisa da peça %s." % GameEnums.rarity_name(int(recipe.result_rarity) - 1)
	if not inventory.has_all(recipe.ingredients):
		return "Faltam reagentes."
	return ""


## Tenta craftar. Devolve:
##   ok        false se nem deu para tentar (falta algo) — nada é gasto
##   success   true se a peça saiu; false se falhou
##   reason    motivo quando ok = false
##   chance    chance usada
##   uid       uid da peça nova (sucesso com equipamento)
##   base_uid  uid da peça-base consumida (sucesso)
##   lost      reagentes perdidos na falha {id: qtd}
##   xp        XP de profissão ganha
static func craft(recipe: RecipeData, inventory: Inventory, professions: ProfessionProgress, catalog: ItemCatalog,
		rng: RandomNumberGenerator = null, fail_streak: int = 0, worn_uids: Array = []) -> Dictionary:
	var reason := check(recipe, inventory, professions, worn_uids)
	if reason != "":
		return {"ok": false, "success": false, "reason": reason}
	var result_item := catalog.get_item(recipe.result_item_id)
	if result_item == null:
		return {"ok": false, "success": false, "reason": "Item resultante não existe."}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var profession := catalog.get_profession(recipe.profession_id) if recipe.profession_id != &"" else null
	var chance := success_chance(recipe, professions, fail_streak)
	var out := {"ok": true, "success": false, "reason": "", "chance": chance, "uid": "", "base_uid": "", "lost": {}, "xp": 0}

	if rng.randf() >= chance:
		var lost := {}
		for item_id in recipe.ingredients:
			lost[item_id] = int(ceil(int(recipe.ingredients[item_id]) / 2.0))
		inventory.remove_all(lost)
		out.lost = lost
		out.xp = int(round(recipe.xp_reward * FAIL_XP_FRACTION))
		if profession:
			professions.add_xp(profession, out.xp)
		return out

	var base := find_base(recipe, inventory, worn_uids)
	inventory.remove_all(recipe.ingredients)
	if not base.is_empty():
		out.base_uid = base.uid
		inventory.remove_equipment(base.uid)
	if result_item.is_equipment():
		var r := int(recipe.result_rarity)
		for i in recipe.result_qty:
			out.uid = inventory.add_equipment(ItemFactory.roll(result_item, WORLD_TIER, r, rng))
	else:
		inventory.add(result_item, recipe.result_qty)
	out.success = true
	out.xp = recipe.xp_reward
	if profession:
		professions.add_xp(profession, out.xp)
	return out
