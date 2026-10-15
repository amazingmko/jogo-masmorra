class_name GameEnums
## Listas fixas usadas no jogo inteiro. Mude aqui e vale para todos os scripts.

enum HeroClass { TANK, RANGER, MAGE, DRUID }

enum Element { NEUTRAL, FIRE, WATER, NATURE }

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

## Atributo principal de cada classe (define o tipo de armadura).
enum PrimaryStat { STRENGTH, AGILITY, INTELLECT }

enum ArmorType { CLOTH, LEATHER, PLATE }

## OFFHAND (escudo) fica no fim para não mudar o número dos slots nos saves antigos.
enum Slot { WEAPON, HEAD, CHEST, HANDS, LEGS, FEET, OFFHAND }

enum Difficulty { NORMAL, HARD, HEROIC, MYTHIC }

const DIFFICULTY_NAMES := ["Normal", "Difícil", "Heroico", "Mítico"]
const DIFFICULTY_COLORS := [Color("d9d4e6"), Color("6fdc7b"), Color("4da3ff"), Color("ff6b6b")]
const RARITY_NAMES := ["Comum", "Raro", "Épico", "Lendário"]
const RARITY_COLORS := [Color("d9d4e6"), Color("4da3ff"), Color("c06bff"), Color("ffa53d")]
## Quanto mais forte é um item de cada raridade (Comum = 100%). Sem nível de item, a raridade
## é o que separa uma peça da outra, por isso os saltos são grandes.
const RARITY_POWER := [1.0, 1.6, 2.4, 3.5]
## Pontos de Poder de cada peça vestida, por raridade. O Poder do herói é a soma das 6 peças
## e libera dificuldades e mundos (ver Difficulty).
const RARITY_GEAR_POWER := [10, 20, 35, 55]

const PRIMARY_NAMES := ["Força", "Agilidade", "Inteligência"]
const PRIMARY_KEYS := ["strength", "agility", "intellect"]
const ARMOR_NAMES := ["Tecido", "Couro", "Placa"]
## Tipo de armadura de quem usa cada atributo.
const ARMOR_FOR_PRIMARY := [ArmorType.PLATE, ArmorType.LEATHER, ArmorType.CLOTH]
const PRIMARY_FOR_ARMOR := [PrimaryStat.INTELLECT, PrimaryStat.AGILITY, PrimaryStat.STRENGTH]
const SLOT_NAMES := ["Arma", "Cabeça", "Peito", "Mãos", "Pernas", "Pés", "Escudo"]

## Nome de exibição de cada atributo guardado nos itens.
const STAT_NAMES := {
	"strength": "Força",
	"agility": "Agilidade",
	"intellect": "Inteligência",
	"vigor": "Vigor",
	"armor": "Armadura",
	"crit": "Crítico",
	"haste": "Aceleração",
	"luck": "Sorte",
	"damage": "Dano",
	"block": "Bloqueio",
}

## Bônus de dano quando o elemento do atacante vence o do alvo.
const ELEMENT_ADVANTAGE_BONUS := 0.30

## Quem vence quem: fogo > natureza > água > fogo. Neutro não vence nem perde.
const ELEMENT_BEATS := {
	Element.FIRE: Element.NATURE,
	Element.NATURE: Element.WATER,
	Element.WATER: Element.FIRE,
}


static func element_multiplier(attacker: Element, target: Element) -> float:
	if ELEMENT_BEATS.get(attacker, -1) == target:
		return 1.0 + ELEMENT_ADVANTAGE_BONUS
	return 1.0


static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


static func rarity_name(rarity: int) -> String:
	return RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)]
