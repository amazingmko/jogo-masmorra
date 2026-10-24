class_name Economy
extends RefCounted
## Números da economia num lugar só (ouro, venda, custo de fabricar, proteção contra azar, mentor).
##
## De onde vem cada coisa:
##  - Bicho comum: só OURO (sobe com a dificuldade; igual com ou sem energia).
##  - Bicho furioso: ouro ×3 e uma chance pequena de reagente.
##  - Mini-chefe e chefe: reagentes garantidos (a fonte principal) e ouro.
##  - Baús (sala do tesouro e Covil Furioso): alguns reagentes.
## Para onde vai o ouro: fabricar (mais caro nas raridades altas) e, depois, as Provações.
## O reagente que sobra pode ser vendido por ouro.

const GOLD_MULT := [1.0, 1.6, 2.5, 4.0]
const ELITE_GOLD := 3
## Chance de um furioso deixar reagentes (uma rolada da tabela dele).
const ELITE_REAGENT_CHANCE := 0.12
## Preço de venda de 1 reagente, por raridade.
const SELL_PRICE := [2, 6, 15, 40]
## Ouro para fabricar, pela raridade do resultado (receitas sem equipamento: o primeiro valor).
const CRAFT_GOLD := [20, 80, 250, 800]
## Proteção contra azar do reagente mais raro do chefe: +chance a cada vitória sem ele.
const PITY_STEP := 0.10
## Mentor: quem está em grupo com alguém 5+ níveis abaixo ganha +25% de ouro.
const MENTOR_LEVEL_GAP := 5
const MENTOR_BONUS := 0.25


static func enemy_gold(xp_reward: int, elite: bool, difficulty: int) -> int:
	var g: float = (1.0 + xp_reward) * float(GOLD_MULT[clampi(difficulty, 0, 3)]) * (ELITE_GOLD if elite else 1)
	return maxi(int(round(g)), 1)


static func craft_cost(recipe: RecipeData, catalog: ItemCatalog) -> int:
	var item := catalog.get_item(recipe.result_item_id) if recipe else null
	if item == null or not item.is_equipment():
		return CRAFT_GOLD[0]
	return CRAFT_GOLD[clampi(int(recipe.result_rarity), 0, 3)]


static func sell_price(item: ItemData) -> int:
	return SELL_PRICE[clampi(int(item.rarity), 0, 3)]


## Peças (nomes, sem repetir) que usam este reagente nas receitas.
static func uses_of(item_id: StringName, catalog: ItemCatalog) -> PackedStringArray:
	var out := PackedStringArray()
	for recipe: RecipeData in catalog.recipes.values():
		if not recipe.ingredients.has(String(item_id)) and not recipe.ingredients.has(item_id):
			continue
		var res := catalog.get_item(recipe.result_item_id)
		var name := res.display_name if res else recipe.display_name
		if not out.has(name):
			out.append(name)
	return out
