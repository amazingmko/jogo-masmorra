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
## Cargas da habilidade (Bolsa de Cipó dá 2). A recarga devolve uma carga por vez.
var _charges := 1


static func for_hero(hero: HeroData) -> HeroKit:
	match hero.hero_class:
		GameEnums.HeroClass.TANK:
			return TankKit.new()
		GameEnums.HeroClass.RANGER:
			return RangerKit.new()
		GameEnums.HeroClass.DRUID:
			return DruidKit.new()
		GameEnums.HeroClass.MAGE:
			return MageKit.new()
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
	if _charges > 0:
		return 0.0
	return clampf(_skill_cd / maxf(skill_cooldown(), 0.01), 0.0, 1.0)


func skill_ready() -> bool:
	return has_skill() and _charges > 0 and not player.health.is_dead


func max_charges() -> int:
	return 1


func charges() -> int:
	return _charges


func ultimate_ready() -> bool:
	return has_ultimate() and charge >= 100.0 and not player.health.is_dead


# ---------- uso ----------

func try_skill() -> bool:
	if not skill_ready():
		return false
	if not _use_skill():
		return false
	_charges -= 1
	if _skill_cd <= 0.0:
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
		if _skill_cd <= 0.0:
			_charges = mini(_charges + 1, max_charges())
			if _charges < max_charges():
				_skill_cd = skill_cooldown()
			changed.emit()
	elif _charges < max_charges():
		_skill_cd = skill_cooldown()  # ganhou uma carga a mais (talento novo)


## Começo de uma run nova.
func on_run_start() -> void:
	charge = 0.0
	_skill_cd = 0.0
	_charges = max_charges()
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


## Multiplicador de velocidade de movimento (passivas como Rastro Leve).
func speed_factor() -> float:
	return 1.0


## Ajusta uma flecha/magia antes de sair (ex.: Olho de Caçadora).
func modify_projectile(_p: Projectile) -> void:
	pass


## Chamado depois de cada golpe/disparo do herói.
func on_attack_done() -> void:
	pass


# ---------- ganchos dos talentos ----------

## Graus a mais no cone do golpe corpo a corpo (metade para cada lado).
func melee_cone_bonus() -> float:
	return 0.0


## Multiplicador do golpe pela posição no combo (0, 1, 2...).
func melee_multiplier(_combo_step: int) -> float:
	return 1.0


## Depois de cada inimigo atingido pelo golpe corpo a corpo.
func on_melee_hit(_enemy: Node3D, _combo_step: int) -> void:
	pass


## Ângulos (radianos) das flechas de um disparo: [0.0] = uma flecha só.
func arrow_spread() -> Array:
	return [0.0]


## Crítico garantido neste disparo (gasta o efeito).
func consume_sure_crit() -> bool:
	return false


## Velocidade que sobra ao atirar andando.
func shoot_move_factor(base: float) -> float:
	return base


func on_shield_broken() -> void:
	pass


## Logo antes de cada golpe/disparo (ex.: a Onça salta até o alvo).
func before_attack() -> void:
	pass


## Druida trocou de forma.
func on_form_changed(_form: int) -> void:
	pass


func on_death_saved() -> void:
	pass


## Chance de esquivar de um golpe (Pele Malhada).
func dodge_chance() -> float:
	return 0.0


## Ignora este efeito de controle vindo dos inimigos (Corpo Pesado)?
func ignores_effect(_effect: int) -> bool:
	return false


## Multiplicador do golpe contra este inimigo (Caça ao Ferido).
func target_multiplier(_enemy: Node3D) -> float:
	return 1.0


## Segundos a mais no aperto da Sucuri.
func constrict_bonus() -> float:
	return 0.0


## Fração da vida curada por segundo a mais (Canto do Boto).
func regen_bonus() -> float:
	return 0.0


## Defesa a mais na forma (Escamas Grossas), em fração (0.05 = 5%).
func form_guard_bonus(_form: int) -> float:
	return 0.0


## Alcance a mais na forma (Cauda Longa).
func form_range_bonus(_form: int) -> float:
	return 0.0


## Pontos num talento do herói.
func t(id: String) -> int:
	return player.talent(id) if player else 0


func tv(id: String) -> float:
	return player.talent_value(id) if player else 0.0
