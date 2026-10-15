class_name HeroKit
extends Node
## Conjunto de poderes de uma classe: uma habilidade (com recarga), uma ultimate (carrega com o
## combate) e passivas (já vêm com o herói). Cada classe estende esta base; o Player só chama os ganchos.
##
## Carga da ultimate (0 a 100): matar, bloquear e apanhar enchem. Fica entre andares; zera a cada run.

signal changed

const CHARGE_KILL := 8.0
const CHARGE_ELITE := 20.0
const CHARGE_BLOCK := 5.0
## Por apanhar: pontos a cada 1% da vida máxima perdida.
const CHARGE_PER_DAMAGE_PCT := 0.5

var player: Player
var charge := 0.0
var _skill_cd := 0.0


static func for_hero(hero: HeroData) -> HeroKit:
	match hero.hero_class:
		GameEnums.HeroClass.TANK:
			return TankKit.new()
		GameEnums.HeroClass.DRUID:
			return DruidKit.new()
	return HeroKit.new()


# ---------- descrição (para a interface) ----------

func skill_name() -> String:
	return ""


func skill_cooldown() -> float:
	return 1.0


func skill_color() -> Color:
	return Color("6fdc7b")


func ultimate_name() -> String:
	return ""


## Texto curto de cada poder, para a tela do herói.
func describe() -> PackedStringArray:
	return PackedStringArray()


func has_skill() -> bool:
	return skill_name() != ""


func has_ultimate() -> bool:
	return ultimate_name() != ""


## 0 = pronta; 1 = acabou de usar.
func skill_cooldown_ratio() -> float:
	return clampf(_skill_cd / maxf(skill_cooldown(), 0.01), 0.0, 1.0)


func skill_ready() -> bool:
	return has_skill() and _skill_cd <= 0.0 and not player.health.is_dead


func ultimate_ready() -> bool:
	return has_ultimate() and charge >= 100.0 and not player.health.is_dead


# ---------- uso ----------

func try_skill() -> bool:
	if not skill_ready():
		return false
	if not _use_skill():
		return false
	_skill_cd = skill_cooldown()
	changed.emit()
	return true


func try_ultimate() -> bool:
	if not ultimate_ready():
		return false
	charge = 0.0
	_use_ultimate()
	changed.emit()
	return true


func _use_skill() -> bool:
	return false


func _use_ultimate() -> void:
	pass


func add_charge(amount: float) -> void:
	if not has_ultimate() or amount <= 0.0:
		return
	var before := charge
	charge = minf(charge + amount, 100.0)
	if before < 100.0 and charge >= 100.0:
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.1, 0),
			"%s PRONTA!" % ultimate_name().to_upper(), Color("ffe08a"))
	changed.emit()


# ---------- ganchos chamados pelo Player / partida ----------

func _process(delta: float) -> void:
	if _skill_cd > 0.0:
		_skill_cd -= delta


## Começo de uma run nova.
func on_run_start() -> void:
	charge = 0.0
	_skill_cd = 0.0
	changed.emit()


## Começo de cada andar.
func on_floor_start() -> void:
	pass


func on_kill(elite: bool) -> void:
	add_charge(CHARGE_ELITE if elite else CHARGE_KILL)


func on_blocked() -> void:
	add_charge(CHARGE_BLOCK)


func on_damaged(amount: int) -> void:
	add_charge(100.0 * float(amount) / maxf(player.health.max_health, 1.0) * CHARGE_PER_DAMAGE_PCT)


## Dano de um golpe do herói, depois das passivas. consume: o golpe aconteceu (gasta efeitos de "próximo golpe").
func modify_outgoing(amount: int) -> int:
	return amount


## Chamado depois de cada golpe/disparo do herói.
func on_attack_done() -> void:
	pass
