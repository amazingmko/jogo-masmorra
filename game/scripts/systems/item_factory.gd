class_name ItemFactory
extends RefCounted
## Cria peças de equipamento únicas a partir de um molde (ItemData), com raridade e atributos.
## "ilvl" é uma faixa interna (por mundo), que o jogador não vê: a força visível vem da raridade.
## Uma peça é um dicionário salvo no inventário:
##   {"uid", "item_id", "ilvl", "rarity", "stats": {"strength": 12, "vigor": 8, "armor": 30, ...}}

## Peso de cada slot no "orçamento" de atributos (peito vale mais que mãos).
const SLOT_WEIGHT := [1.2, 0.8, 1.0, 0.6, 0.9, 0.6, 1.0]  # arma, cabeça, peito, mãos, pernas, pés, escudo
## Escudo (só tanques): mais armadura que uma peça comum e chance de bloquear, que sobe com a raridade.
const SHIELD_ARMOR_MULT := 1.6
const SHIELD_BLOCK := [4, 6, 8, 11]  # % de bloqueio por raridade
## Armadura base por tipo (tecido protege menos que placa).
const ARMOR_BASE := [4.0, 7.0, 11.0]
const SECONDARY_KEYS := ["crit", "haste", "luck"]


## Gera a peça. rarity é GameEnums.Rarity; ilvl começa em 1.
static func roll(template: ItemData, ilvl: int, rarity: int, rng: RandomNumberGenerator) -> Dictionary:
	ilvl = maxi(ilvl, 1)
	var power: float = GameEnums.RARITY_POWER[rarity]
	var weight: float = SLOT_WEIGHT[template.slot]
	var budget := (6.0 + ilvl * 2.0) * power * weight
	var stats := {}

	var primary: int = template.primary_stat if template.kind == ItemData.Kind.WEAPON \
		else GameEnums.PRIMARY_FOR_ARMOR[template.armor_type]
	stats[GameEnums.PRIMARY_KEYS[primary]] = maxi(int(round(budget * 0.6)), 1)
	stats["vigor"] = maxi(int(round(budget * 0.4)), 1)

	if template.kind == ItemData.Kind.ARMOR:
		stats["armor"] = int(round(ARMOR_BASE[template.armor_type] * (1.0 + ilvl * 0.15) * weight * power))
		if template.slot == GameEnums.Slot.OFFHAND:
			stats["armor"] = int(round(stats["armor"] * SHIELD_ARMOR_MULT))
			stats["block"] = SHIELD_BLOCK[clampi(rarity, 0, 3)]
	elif template.kind == ItemData.Kind.WEAPON:
		var base_damage := float(template.stats.get("damage", 30))
		stats["damage"] = int(round(base_damage * (1.0 + 0.1 * (ilvl - 1)) * power))

	# Secundários: Raro tem 1, Épico 2, Lendário 3.
	var keys := SECONDARY_KEYS.duplicate()
	for i in rarity:
		if keys.is_empty():
			break
		var key: String = keys.pop_at(rng.randi_range(0, keys.size() - 1))
		stats[key] = int(round(1.0 + ilvl * 0.3 * power))

	return {"uid": "", "item_id": String(template.id), "ilvl": ilvl, "rarity": rarity, "stats": stats}


## Sorteia a raridade de um drop. profile: "normal", "chest" ou "boss".
## Lendário nunca cai: só vem do crafting.
static func roll_rarity(profile: String, rng: RandomNumberGenerator) -> int:
	var weights: Array = {
		"normal": [75, 22, 3, 0],
		"chest": [55, 35, 10, 0],
		"boss": [0, 60, 40, 0],
	}.get(profile, [75, 22, 3, 0])
	var total := 0
	for w in weights:
		total += w
	var pick := rng.randi_range(1, total)
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0:
			return i
	return 0


## "Elmo de Placa" + raridade e nível, para avisos e listas.
static func display_name(instance: Dictionary, catalog: ItemCatalog) -> String:
	var template := catalog.get_item(StringName(instance.get("item_id", "")))
	var name := template.display_name if template else String(instance.get("item_id", "?"))
	return name


## Pontos de Poder de uma peça (pela raridade).
static func gear_power(instance: Dictionary) -> int:
	return GameEnums.RARITY_GEAR_POWER[clampi(int(instance.get("rarity", 0)), 0, 3)]


## Lista curta de atributos: "+12 Força · +8 Vigor · 30 Armadura".
static func describe_stats(stats: Dictionary) -> String:
	var parts := PackedStringArray()
	var order := ["damage", "strength", "agility", "intellect", "vigor", "armor", "block", "crit", "haste", "luck"]
	for key in order:
		if not stats.has(key):
			continue
		var value := int(stats[key])
		var label: String = GameEnums.STAT_NAMES.get(key, key)
		if key in ["crit", "haste", "luck", "block"]:
			parts.append("+%d%% %s" % [value, label])
		elif key in ["damage", "armor"]:
			parts.append("%d %s" % [value, label])
		else:
			parts.append("+%d %s" % [value, label])
	return " · ".join(parts)


## Se um herói pode vestir/usar esta peça.
static func can_use(hero: HeroData, template: ItemData) -> bool:
	if template == null or hero == null:
		return false
	if template.kind == ItemData.Kind.WEAPON:
		return template.weapon_type == hero.weapon_type
	if template.kind == ItemData.Kind.ARMOR:
		if template.slot == GameEnums.Slot.OFFHAND:
			return hero.hero_class == GameEnums.HeroClass.TANK  # escudo é coisa de tanque
		return template.armor_type == hero.armor_type()
	return false
