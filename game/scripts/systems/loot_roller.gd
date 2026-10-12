class_name LootRoller
extends RefCounted
## Transforma o sorteio de uma tabela de drop em itens de verdade:
## materiais com quantidade, e equipamentos como peças únicas (raridade + nível de item).
## Resultado: lista de {"item": ItemData, "qty": int, "instance": Dictionary (vazio se não for equipamento)}


## context:
##   ilvl     nível de item dos equipamentos que caírem
##   profile  "normal", "chest" ou "boss" (chances de raridade)
##   hero     HeroData do jogador (metade dos equipamentos vem no tipo dele)
static func roll(table: DropTable, catalog: ItemCatalog, rng: RandomNumberGenerator, context: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if table == null:
		return out
	for drop in table.roll(rng):
		var id := String(drop.item_id)
		if id.begins_with("@"):
			for i in int(drop.qty):
				var sub := catalog.get_drop_table(StringName(id.substr(1)))
				out.append_array(_roll_equipment(sub, catalog, rng, context))
			continue
		var item := catalog.get_item(drop.item_id)
		if item == null:
			continue
		if item.is_equipment():
			for i in int(drop.qty):
				out.append(_make(item, rng, context))
		else:
			out.append({"item": item, "qty": int(drop.qty), "instance": {}})
	return out


## Sorteia uma peça de uma tabela de equipamentos; metade das vezes, prefere o que o herói usa.
static func _roll_equipment(table: DropTable, catalog: ItemCatalog, rng: RandomNumberGenerator, context: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if table == null or table.entries.is_empty():
		return out
	var hero: HeroData = context.get("hero")
	var pool: Array[ItemData] = []
	if hero and rng.randf() < 0.5:
		for entry in table.entries:
			var t := catalog.get_item(entry.item_id)
			if ItemFactory.can_use(hero, t):
				pool.append(t)
	if pool.is_empty():
		for entry in table.entries:
			var t := catalog.get_item(entry.item_id)
			if t:
				pool.append(t)
	if pool.is_empty():
		return out
	out.append(_make(pool[rng.randi_range(0, pool.size() - 1)], rng, context))
	return out


static func _make(template: ItemData, rng: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	var rarity := ItemFactory.roll_rarity(context.get("profile", "normal"), rng)
	var ilvl: int = context.get("ilvl", 1)
	return {"item": template, "qty": 1, "instance": ItemFactory.roll(template, ilvl, rarity, rng)}
