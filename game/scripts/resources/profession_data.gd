class_name ProfessionData
extends Resource
## Profissão de crafting (Ferreiro, Curtidor, Tecelã, Erveira). Sobe de nível fabricando.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 100) var max_level: int = 50
## XP para ir do nível 1 ao 2. Cada nível seguinte custa mais (ver xp_growth).
@export_range(1, 100000) var base_xp: int = 100
## Crescimento por nível. 1.15 = cada nível pede 15% a mais que o anterior.
@export_range(1.0, 3.0) var xp_growth: float = 1.15


## XP necessário para sair de `level` e chegar ao próximo.
func xp_to_next(level: int) -> int:
	return int(round(base_xp * pow(xp_growth, maxi(level - 1, 0))))
