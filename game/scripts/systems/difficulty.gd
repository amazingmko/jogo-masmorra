class_name Difficulty
extends RefCounted
## Números das 4 dificuldades (índice = GameEnums.Difficulty). Mude aqui para rebalancear.
## Os valores seguem replica/progressao.md, seção 1.

## Vida e dano dos inimigos (o chefe também).
const HEALTH_MULT := [1.0, 1.8, 3.2, 7.5]
const DAMAGE_MULT := [1.0, 1.5, 2.2, 7.5]
## Somado ao perigo das salas (inimigos emendam mais ataques, esquivam e soltam mais magia).
const THREAT_BONUS := [0.0, 0.15, 0.3, 0.45]
const XP_MULT := [1.0, 2.0, 4.0, 8.0]
## Quantidade de reagentes que caem.
const REWARD_MULT := [1.0, 1.5, 2.0, 3.0]
## Para liberar uma dificuldade: vencer a anterior E ter as 6 peças (arma, cabeça, peito, mãos,
## pernas, pés) vestidas com pelo menos esta raridade. Difícil: todas Comuns; Heroico: todas Raras;
## Mítico: todas Épicas. (O escudo da Icamiaba não conta.) O Poder continua só como número.
const SET_SLOTS := [GameEnums.Slot.WEAPON, GameEnums.Slot.HEAD, GameEnums.Slot.CHEST,
	GameEnums.Slot.HANDS, GameEnums.Slot.LEGS, GameEnums.Slot.FEET]
const SET_RARITY := [-1, 0, 1, 2]

## Mundos. O 2º (Igapó) ainda não existe; o requisito já aparece no portal.
## clear: dificuldade que precisa ter vencido no mundo anterior; set: raridade mínima das 6 peças.
const WORLDS := [
	{"id": &"terra_firme", "name": "Terra Firme", "clear": -1, "set": -1},
	{"id": &"igapo", "name": "Igapó", "clear": 0, "set": 0},
]

## Sem energia: a run rende só esta fração dos reagentes, e nada exclusivo de chefe.
const NO_ENERGY_REWARD := 0.35


static func name_of(d: int) -> String:
	return GameEnums.DIFFICULTY_NAMES[clampi(d, 0, 3)]


static func color_of(d: int) -> Color:
	return GameEnums.DIFFICULTY_COLORS[clampi(d, 0, 3)]


## Situação das 6 peças para uma raridade mínima: [{slot, ok, rarity (-1 = vazio)}].
## equipped: slot (int) -> peça ({rarity, ...}).
static func set_status(min_rarity: int, equipped: Dictionary) -> Array:
	var out := []
	for slot in SET_SLOTS:
		var inst: Dictionary = equipped.get(slot, equipped.get(str(slot), {}))
		var r := int(inst.get("rarity", -1)) if not inst.is_empty() else -1
		out.append({"slot": slot, "ok": min_rarity < 0 or r >= min_rarity, "rarity": r})
	return out


static func set_ok(min_rarity: int, equipped: Dictionary) -> bool:
	for s in set_status(min_rarity, equipped):
		if not s.ok:
			return false
	return true


static func set_text(min_rarity: int) -> String:
	return "ter as 6 peças %s" % ["Comuns", "Raras", "Épicas", "Lendárias"][clampi(min_rarity, 0, 3)]


## Por que a dificuldade está trancada ("" se liberada).
## highest_cleared: maior dificuldade já vencida (-1 = nenhuma). equipped: peças vestidas.
static func lock_reason(d: int, highest_cleared: int, equipped: Dictionary) -> String:
	if d <= 0:
		return ""
	var parts := PackedStringArray()
	if highest_cleared < d - 1:
		parts.append("vencer o %s" % name_of(d - 1))
	if not set_ok(SET_RARITY[d], equipped):
		parts.append(set_text(SET_RARITY[d]))
	if parts.is_empty():
		return ""
	return "Precisa " + " e ".join(parts)


## Por que o mundo está trancado ("" se liberado).
static func world_lock_reason(world: int, highest_cleared: int, equipped: Dictionary) -> String:
	var w: Dictionary = WORLDS[world]
	var parts := PackedStringArray()
	if highest_cleared < int(w.clear):
		parts.append("vencer %s no %s" % [WORLDS[world - 1].name, name_of(int(w.clear))])
	if not set_ok(int(w.set), equipped):
		parts.append(set_text(int(w.set)))
	if parts.is_empty():
		return ""
	return "Precisa " + " e ".join(parts)
