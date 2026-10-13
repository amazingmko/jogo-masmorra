class_name Difficulty
extends RefCounted
## Números das 4 dificuldades (índice = GameEnums.Difficulty). Mude aqui para rebalancear.
## Os valores seguem replica/progressao.md, seção 1.

## Vida e dano dos inimigos (o chefe também).
const HEALTH_MULT := [1.0, 1.8, 3.2, 5.6]
const DAMAGE_MULT := [1.0, 1.5, 2.2, 3.2]
## Somado ao perigo das salas (inimigos emendam mais ataques, esquivam e soltam mais magia).
const THREAT_BONUS := [0.0, 0.15, 0.3, 0.45]
const XP_MULT := [1.0, 2.0, 4.0, 8.0]
## Quantidade de reagentes que caem.
const REWARD_MULT := [1.0, 1.5, 2.0, 3.0]
## Nível de item médio do equipamento vestido para liberar (além de vencer a anterior).
const UNLOCK_AVG_ILVL := [0, 8, 12, 16]

## Sem energia: a run rende só esta fração dos reagentes, e nada exclusivo de chefe.
const NO_ENERGY_REWARD := 0.35


static func name_of(d: int) -> String:
	return GameEnums.DIFFICULTY_NAMES[clampi(d, 0, 3)]


static func color_of(d: int) -> Color:
	return GameEnums.DIFFICULTY_COLORS[clampi(d, 0, 3)]


## Por que a dificuldade está trancada ("" se liberada).
## highest_cleared: maior dificuldade já vencida (-1 = nenhuma). avg_ilvl: média do herói.
static func lock_reason(d: int, highest_cleared: int, avg_ilvl: float) -> String:
	if d <= 0:
		return ""
	var parts := PackedStringArray()
	if highest_cleared < d - 1:
		parts.append("vencer o %s" % name_of(d - 1))
	if avg_ilvl + 0.001 < UNLOCK_AVG_ILVL[d]:
		parts.append("nível de item médio %d (o seu: %s)" % [UNLOCK_AVG_ILVL[d], ("%.1f" % avg_ilvl).replace(".", ",")])
	if parts.is_empty():
		return ""
	return "Precisa " + " e ".join(parts)
