class_name GameEnums
## Listas fixas usadas no jogo inteiro. Mude aqui e vale para todos os scripts.

enum HeroClass { TANK, RANGER, MAGE }

enum Element { NEUTRAL, FIRE, WATER, NATURE }

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

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
