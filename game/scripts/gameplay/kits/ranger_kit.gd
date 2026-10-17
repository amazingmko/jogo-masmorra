class_name RangerKit
extends HeroKit
## Mateira (ranger).
##  Habilidade  Armadilha de Cipó: joga uma armadilha no chão; o primeiro bicho que pisar fica preso 3 s.
##  Ultimate    Chamado da Harpia: o gavião-real mergulha nos inimigos por 8 s, começando pelo mais ferido.
##  Passivas    Olho de Caçadora: +20% de crítico contra inimigos a mais de 6 m.
##              Rastro Leve: depois de cada abate, corre 15% mais rápido por 2 s.
## Talentos (ver Talents): Precisão, Armadilheira e Mata mexem nos números e somam efeitos aqui.

const TRAP_COOLDOWN := 10.0
const TRAP_HOLD := 3.0
const TRAP_DISTANCE := 1.5  # à frente dela
const HARPY_TIME := 8.0
const HARPY_DAMAGE_MULT := 1.2  # cada mergulho: 120% do dano do arco
const FAR_CRIT := 0.2
const FAR_DISTANCE := 6.0
const RUSH_BONUS := 0.15
const RUSH_TIME := 2.0
const COLOR := Color("8be06b")

var _rush_left := 0.0
var _harpy: Harpy       # a do Chamado (ou a companheira, com Revoada)
const FURY_TIME := 8.0
var _still := 0.0
var _sure_crit_shown := false
var _shots := 0
const SPREAD_ANGLE := 0.21  # ~12° entre as flechas da Chuva de Flechas


func skill_name() -> String:
	return "Armadilha"


func skill_cooldown() -> float:
	return TRAP_COOLDOWN - tv("maos_ageis")


func max_charges() -> int:
	return 2 if t("bolsa_cipo") > 0 else 1


func _hold_time() -> float:
	return TRAP_HOLD + tv("cipo_grosso")


func _harpy_time() -> float:
	return HARPY_TIME + tv("pena_gaviao")


func _far_distance() -> float:
	return FAR_DISTANCE - tv("olho_gaviao")


func _far_crit() -> float:
	return FAR_CRIT + 0.05 * t("olho_gaviao")


func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else String.num(v, 1).replace(".", ",")


func skill_color() -> Color:
	return COLOR


func ultimate_name() -> String:
	return "Harpia"


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Armadilha de Cipó (habilidade, %s s%s): o primeiro bicho que pisar fica preso por %s s." % [_num(skill_cooldown()), ", 2 cargas" if max_charges() > 1 else "", _num(_hold_time())],
		("Fúria da Harpia (ultimate): a Harpia que a acompanha mergulha com dano em dobro e mais rápido por %d s." % FURY_TIME) if t("revoada") > 0 else ("Chamado da Harpia (ultimate): o gavião-real mergulha nos inimigos por %s s, começando pelo mais ferido." % _num(_harpy_time())),
		"Olho de Caçadora (passiva): +%d%% de crítico contra inimigos a mais de %s m." % [int(round(_far_crit() * 100)), _num(_far_distance())],
		"Rastro Leve (passiva): depois de cada abate, corre 15%% mais rápido por %s s." % _num(RUSH_TIME + tv("rastro_longo")),
	])


func _use_skill() -> bool:
	var trap := VineTrap.new()
	trap.hold_time = _hold_time()
	var bow := float(player.weapon_stats.damage)
	trap.thorn_dps = bow * tv("espinhos") / 100.0
	trap.mark_bonus = tv("presa_marcada") / 100.0
	trap.spread_radius = tv("cipo_alastra")
	trap.timbo_radius = tv("timbo")
	trap.timbo_dps = bow * 0.3
	player.get_parent().add_child(trap)
	var at := player.global_position + player.facing() * TRAP_DISTANCE
	trap.global_position = Vector3(at.x, 0.0, at.z)
	Vfx.particles(player.get_parent(), trap.global_position + Vector3(0, 0.3, 0), "folha", 8, 0.8, Color(1, 1, 1, 0.9), 0.35, Vector2(1.5, 3.0), 60.0, -6.0, false)
	player.play_kit_animation("armadilha", 1.0, "")
	return true


func _harpy_damage() -> int:
	return maxi(int(round(player.weapon_stats.damage * HARPY_DAMAGE_MULT * (1.0 + tv("garras_afiadas") / 100.0))), 1)


func _spawn_harpy(companion: bool) -> Harpy:
	var harpy := Harpy.new()
	harpy.owner_player = player
	harpy.duration = _harpy_time()
	harpy.damage = _harpy_damage()
	harpy.companion = companion
	harpy.companion_factor = tv("revoada") / 100.0
	player.get_parent().add_child(harpy)
	harpy.global_position = player.global_position + Vector3(0, 8.0, 0)
	return harpy


func _use_ultimate() -> void:
	if t("revoada") > 0:
		# Revoada: a ultimate enfurece a Harpia que já a acompanha.
		if not _alive(_harpy):
			_harpy = _spawn_harpy(true)
		_harpy.damage = _harpy_damage()
		_harpy.fury(FURY_TIME)
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "FÚRIA DA HARPIA!", Color("ffd34d"))
	else:
		_harpy = _spawn_harpy(false)
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "CHAMADO DA HARPIA!", Color("e8f5ff"))
	player.play_kit_animation("harpia", 1.6, "")


func _process(delta: float) -> void:
	super(delta)
	if _rush_left > 0.0:
		_rush_left -= delta
	# Respiração Calma: parada um tempo, o próximo tiro é crítico garantido.
	if t("respiracao_calma") > 0 and player and not player.health.is_dead:
		if player.is_moving():
			_still = 0.0
			_sure_crit_shown = false
		else:
			_still += delta
			if _still >= tv("respiracao_calma") and not _sure_crit_shown:
				_sure_crit_shown = true
				Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.8, 0), "MIRA CALMA", COLOR)


func on_run_start() -> void:
	super()
	_rush_left = 0.0
	_still = 0.0
	_shots = 0


## Revoada: a Harpia volta a acompanhá-la em cada andar.
func on_floor_start() -> void:
	# (a do andar anterior foi apagada na troca: queue_free ainda deixa o nó "válido" neste quadro)
	if t("revoada") > 0 and not _alive(_harpy):
		_harpy = _spawn_harpy(true)


func _alive(h: Harpy) -> bool:
	return is_instance_valid(h) and not h.is_queued_for_deletion() and h.is_inside_tree()


func on_kill(elite: bool) -> void:
	super(elite)
	_rush_left = RUSH_TIME + tv("rastro_longo")  # Rastro Leve
	# Vínculo: abate com a Harpia ativa a mantém por mais tempo.
	if t("vinculo") > 0:
		if _alive(_harpy):
			_harpy.extend(tv("vinculo"))


func speed_factor() -> float:
	return 1.0 + RUSH_BONUS if _rush_left > 0.0 else 1.0


func modify_projectile(p: Projectile) -> void:
	p.far_crit_bonus = _far_crit()
	p.far_distance = _far_distance()
	p.crit_damage_bonus = tv("tiro_certeiro") / 100.0
	if t("flecha_perfurante") > 0:
		p.pierce = 1
		p.pierce_factor = tv("flecha_perfurante") / 100.0


func arrow_spread() -> Array:
	if t("chuva_flechas") <= 0:
		return [0.0]
	_shots += 1
	if _shots > int(tv("chuva_flechas")):
		_shots = 0
		return [-SPREAD_ANGLE, 0.0, SPREAD_ANGLE]
	return [0.0]


func consume_sure_crit() -> bool:
	if t("respiracao_calma") > 0 and _still >= tv("respiracao_calma"):
		_still = 0.0
		_sure_crit_shown = false
		return true
	return false


func shoot_move_factor(base: float) -> float:
	return base + tv("atirar_correndo") / 100.0
