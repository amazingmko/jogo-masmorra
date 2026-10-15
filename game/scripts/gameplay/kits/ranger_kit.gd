class_name RangerKit
extends HeroKit
## Mateira (ranger).
##  Habilidade  Armadilha de Cipó: joga uma armadilha no chão; o primeiro bicho que pisar fica preso 3 s.
##  Ultimate    Chamado da Harpia: o gavião-real mergulha nos inimigos por 8 s, começando pelo mais ferido.
##  Passivas    Olho de Caçadora: +20% de crítico contra inimigos a mais de 6 m.
##              Rastro Leve: depois de cada abate, corre 15% mais rápido por 2 s.

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


func skill_name() -> String:
	return "Armadilha"


func skill_cooldown() -> float:
	return TRAP_COOLDOWN


func skill_color() -> Color:
	return COLOR


func ultimate_name() -> String:
	return "Harpia"


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Armadilha de Cipó (habilidade, %ds): o primeiro bicho que pisar fica preso por %ds." % [TRAP_COOLDOWN, TRAP_HOLD],
		"Chamado da Harpia (ultimate): o gavião-real mergulha nos inimigos por %ds, começando pelo mais ferido." % HARPY_TIME,
		"Olho de Caçadora (passiva): +20%% de crítico contra inimigos a mais de 6 m.",
		"Rastro Leve (passiva): depois de cada abate, corre 15%% mais rápido por 2 s.",
	])


func _use_skill() -> bool:
	var trap := VineTrap.new()
	trap.hold_time = TRAP_HOLD
	player.get_parent().add_child(trap)
	var at := player.global_position + player.facing() * TRAP_DISTANCE
	trap.global_position = Vector3(at.x, 0.0, at.z)
	Vfx.particles(player.get_parent(), trap.global_position + Vector3(0, 0.3, 0), "folha", 8, 0.8, Color(1, 1, 1, 0.9), 0.35, Vector2(1.5, 3.0), 60.0, -6.0, false)
	player.play_kit_animation("armadilha", 1.0, "")
	return true


func _use_ultimate() -> void:
	var harpy := Harpy.new()
	harpy.owner_player = player
	harpy.duration = HARPY_TIME
	harpy.damage = maxi(int(round(player.weapon_stats.damage * HARPY_DAMAGE_MULT)), 1)
	player.get_parent().add_child(harpy)
	harpy.global_position = player.global_position + Vector3(0, 8.0, 0)
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "CHAMADO DA HARPIA!", Color("e8f5ff"))
	player.play_kit_animation("harpia", 1.6, "")


func _process(delta: float) -> void:
	super(delta)
	if _rush_left > 0.0:
		_rush_left -= delta


func on_run_start() -> void:
	super()
	_rush_left = 0.0


func on_kill(elite: bool) -> void:
	super(elite)
	_rush_left = RUSH_TIME  # Rastro Leve


func speed_factor() -> float:
	return 1.0 + RUSH_BONUS if _rush_left > 0.0 else 1.0


func modify_projectile(p: Projectile) -> void:
	p.far_crit_bonus = FAR_CRIT
	p.far_distance = FAR_DISTANCE
