class_name Synergy
extends RefCounted
## Sinergia elemental do grupo: cada herói tem um ou mais estilos elementais (HeroData.styles).
## Quando 2, 3 ou 4 heróis DIFERENTES do grupo têm o mesmo estilo, o grupo todo ganha o bônus
## daquele elemento. Elementos novos (de biomas novos) só precisam de uma linha em INFO.
## Não depende de cena: dá para testar sozinho.

const TIERS := [2, 3, 4]

## elemento -> nome do bônus, cor, atributo e valor em cada degrau (2, 3, 4 heróis).
## stat: atributo das bênçãos (multiplica) ou "reduction" (corta o dano recebido).
const INFO := {
	GameEnums.Element.WATER: {"element": "Água", "icon": "spec_rio", "name": "Correnteza", "color": "4db8ff",
		"stats": [&"move_speed"], "values": [0.05, 0.08, 0.10],
		"text": "+%d%% de velocidade de movimento"},
	GameEnums.Element.NATURE: {"element": "Natureza", "icon": "spec_mata", "name": "Raízes", "color": "8be06b",
		"stats": [&"max_health"], "values": [0.10, 0.15, 0.20],
		"text": "+%d%% de vida máxima"},
	GameEnums.Element.EARTH: {"element": "Terra", "icon": "escudo", "name": "Firmeza", "color": "c9a26b",
		"stats": [&"reduction"], "values": [0.08, 0.12, 0.16],
		"text": "-%d%% de dano recebido"},
	GameEnums.Element.FIRE: {"element": "Fogo", "icon": "poder", "name": "Brasa", "color": "ff8a3d",
		"stats": [&"damage"], "values": [0.06, 0.09, 0.12],
		"text": "+%d%% de dano"},
}


## Quantos heróis diferentes do grupo têm cada estilo. heroes: Array de HeroData.
static func count(heroes: Array) -> Dictionary:
	var seen := {}
	var out := {}
	for h in heroes:
		if h == null or seen.has(h.id):
			continue
		seen[h.id] = true
		for e in h.elemental_styles():
			out[e] = int(out.get(e, 0)) + 1
	return out


## Sinergias ligadas: [{element, tier (0..2), heroes, value, ...INFO}], na ordem de INFO.
static func active(heroes: Array) -> Array:
	var counts := count(heroes)
	var out: Array = []
	for e in INFO:
		var n: int = int(counts.get(e, 0))
		var tier := -1
		for i in TIERS.size():
			if n >= TIERS[i]:
				tier = i
		if tier < 0:
			continue
		var info: Dictionary = INFO[e].duplicate()
		info["id"] = e
		info["tier"] = tier
		info["heroes"] = n
		info["value"] = float(info.values[tier])
		out.append(info)
	return out


## Bênçãos (BuffData, multiplicam) das sinergias ligadas.
static func buffs(heroes: Array) -> Array:
	var out: Array = []
	for s in active(heroes):
		for stat in s.stats:
			if stat == &"reduction":
				continue
			var b := BuffData.new()
			b.id = StringName("sinergia_%d" % int(s.id))
			b.display_name = s.name
			b.stat = stat
			b.mode = BuffData.Mode.MULTIPLY
			b.amount = 1.0 + float(s.value)
			out.append(b)
	return out


## Fração do dano recebido cortada pelas sinergias (Terra).
static func reduction(heroes: Array) -> float:
	var r := 0.0
	for s in active(heroes):
		if s.stats.has(&"reduction"):
			r += float(s.value)
	return r


## "Correnteza (Água ×3): +12% de velocidade de movimento e de ataque"
static func describe(s: Dictionary) -> String:
	return "%s (%s ×%d): %s" % [s.name, s.element, int(s.heroes), s.text % int(round(float(s.value) * 100.0))]
