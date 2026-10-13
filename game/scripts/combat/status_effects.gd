class_name StatusEffects
extends Node
## Efeitos negativos no herói: veneno (dano por segundo), raízes (não anda) e lentidão.
## Fica como filho do herói e usa o componente Health dele.

signal changed

const NAMES := {
	EnemyAttack.Effect.POISON: "Envenenado",
	EnemyAttack.Effect.ROOT: "Preso",
	EnemyAttack.Effect.SLOW: "Lento",
}
const COLORS := {
	EnemyAttack.Effect.POISON: Color("8be06b"),
	EnemyAttack.Effect.ROOT: Color("b483e8"),
	EnemyAttack.Effect.SLOW: Color("4db8ff"),
}
const POISON_TICK := 0.5

var health: Health
## kind -> {"time": segundos restantes, "power": int}
var _effects := {}
var _tick := 0.0


func apply(kind: int, duration: float, power: int = 0) -> void:
	if kind == EnemyAttack.Effect.NONE or duration <= 0.0:
		return
	var current: Dictionary = _effects.get(kind, {"time": 0.0, "power": 0})
	# Reaplicar renova a duração e fica com o mais forte; não acumula infinito.
	current.time = maxf(current.time, duration)
	current.power = maxi(current.power, power)
	_effects[kind] = current
	changed.emit()


func clear() -> void:
	_effects.clear()
	changed.emit()


func has(kind: int) -> bool:
	return _effects.has(kind)


func is_rooted() -> bool:
	return _effects.has(EnemyAttack.Effect.ROOT)


## Multiplicador da velocidade de movimento (1 = normal).
func move_factor() -> float:
	if is_rooted():
		return 0.0
	if _effects.has(EnemyAttack.Effect.SLOW):
		return clampf(1.0 - _effects[EnemyAttack.Effect.SLOW].power / 100.0, 0.2, 1.0)
	return 1.0


## Lista para a interface: [{"kind", "name", "time", "color"}]
func active() -> Array:
	var out := []
	for kind in _effects:
		out.append({"kind": kind, "name": NAMES.get(kind, "?"), "time": _effects[kind].time,
			"color": COLORS.get(kind, Color.WHITE)})
	return out


func _process(delta: float) -> void:
	tick(delta)


## Avança o tempo (separado do _process para os testes).
func tick(delta: float) -> void:
	if _effects.is_empty():
		return
	if _effects.has(EnemyAttack.Effect.POISON) and health:
		_tick += delta
		while _tick >= POISON_TICK:
			_tick -= POISON_TICK
			var dps: int = _effects[EnemyAttack.Effect.POISON].power
			# Veneno passa pela invencibilidade e não cria uma nova janela de invencibilidade.
			health.take_damage(maxi(int(round(dps * POISON_TICK)), 1), false, true)
	var ended := false
	for kind in _effects.keys():
		_effects[kind].time -= delta
		if _effects[kind].time <= 0.0:
			_effects.erase(kind)
			ended = true
	if ended:
		changed.emit()
