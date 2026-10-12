class_name Damage
extends RefCounted
## Regras de cálculo de dano, num lugar só para facilitar o balanceamento.

const CRIT_MULTIPLIER := 2.0


## Devolve {"amount": int, "crit": bool}.
static func roll(base: int, attacker_element: GameEnums.Element, target_element: GameEnums.Element,
		crit_chance: float, rng: RandomNumberGenerator) -> Dictionary:
	var crit := rng.randf() < crit_chance
	var value := float(base) * GameEnums.element_multiplier(attacker_element, target_element)
	if crit:
		value *= CRIT_MULTIPLIER
	return {"amount": maxi(int(round(value)), 1), "crit": crit}
