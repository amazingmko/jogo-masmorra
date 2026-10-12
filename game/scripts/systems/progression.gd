class_name Progression
extends RefCounted
## Curva de nível dos heróis. Números iniciais; serão calibrados com a planilha de economia.

const MAX_LEVEL := 40
const BASE_XP := 200
## Cada nível pede 12% a mais de XP que o anterior.
const XP_GROWTH := 1.12
## Ganho por nível acima do 1.
const PRIMARY_PER_LEVEL := 2
const VIGOR_PER_LEVEL := 1


## XP para sair de `level` e chegar ao próximo.
static func xp_to_next(level: int) -> int:
	return int(round(BASE_XP * pow(XP_GROWTH, maxi(level - 1, 0))))


## Aplica XP a {"level", "xp"} e devolve quantos níveis subiu.
static func add_xp(progress: Dictionary, amount: int) -> int:
	var gained := 0
	var level: int = progress.get("level", 1)
	var xp: int = progress.get("xp", 0) + maxi(amount, 0)
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	progress["level"] = level
	progress["xp"] = xp
	return gained
