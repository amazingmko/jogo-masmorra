class_name DruidKit
extends HeroKit
## Druida da Mata: a habilidade é trocar de forma (Onça → Sucuri → Boto). Sem ultimate por enquanto.


func skill_name() -> String:
	return "Forma"


func skill_cooldown() -> float:
	return Player.FORM_COOLDOWN


func describe() -> PackedStringArray:
	return PackedStringArray(["Forma (habilidade): troca entre Onça, Sucuri e Boto."])


func _use_skill() -> bool:
	return player.cycle_form()
