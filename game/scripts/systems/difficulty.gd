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
## Poder do equipamento vestido para liberar (além de vencer a anterior).
## Peça Comum = 10, Rara = 20, Épica = 35, Lendária = 55; 6 peças.
## 80 ≈ tudo Comum + 2 Raras · 140 ≈ 4 Raras + 2 Épicas · 200 ≈ quase tudo Épico.
const UNLOCK_POWER := [0, 80, 140, 200]

## Mundos. O 2º (Igapó) ainda não existe; o requisito já aparece no portal.
## clear: dificuldade que precisa ter vencido no mundo anterior · power: Poder mínimo.
const WORLDS := [
	{"id": &"terra_firme", "name": "Terra Firme", "clear": -1, "power": 0},
	{"id": &"igapo", "name": "Igapó", "clear": 0, "power": 90},
]

## Sem energia: a run rende só esta fração dos reagentes, e nada exclusivo de chefe.
const NO_ENERGY_REWARD := 0.35


static func name_of(d: int) -> String:
	return GameEnums.DIFFICULTY_NAMES[clampi(d, 0, 3)]


static func color_of(d: int) -> Color:
	return GameEnums.DIFFICULTY_COLORS[clampi(d, 0, 3)]


## Por que a dificuldade está trancada ("" se liberada).
## highest_cleared: maior dificuldade já vencida (-1 = nenhuma). power: Poder do herói.
static func lock_reason(d: int, highest_cleared: int, power: int) -> String:
	if d <= 0:
		return ""
	var parts := PackedStringArray()
	if highest_cleared < d - 1:
		parts.append("vencer o %s" % name_of(d - 1))
	if power < UNLOCK_POWER[d]:
		parts.append("Poder %d (o seu: %d)" % [UNLOCK_POWER[d], power])
	if parts.is_empty():
		return ""
	return "Precisa " + " e ".join(parts)


## Por que o mundo está trancado ("" se liberado).
static func world_lock_reason(world: int, highest_cleared: int, power: int) -> String:
	var w: Dictionary = WORLDS[world]
	var parts := PackedStringArray()
	if highest_cleared < int(w.clear):
		parts.append("vencer %s no %s" % [WORLDS[world - 1].name, name_of(int(w.clear))])
	if power < int(w.power):
		parts.append("Poder %d (o seu: %d)" % [int(w.power), power])
	if parts.is_empty():
		return ""
	return "Precisa " + " e ".join(parts)
