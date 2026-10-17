class_name DruidKit
extends HeroKit
## Druida da Mata: vira bicho.
##  Habilidade  Forma: troca entre Onça, Sucuri e Boto.
##  Passiva     Instinto: o 1º ataque depois de trocar de forma é especial — a Onça salta até o
##              alvo (e bate mais), a Sucuri prende por mais tempo, o Boto se cura um pouco.
##  Passiva     Ciclo da Mata: usar as 3 formas em até 10 s dá +20% de dano por 6 s.
##  Ultimate    Espírito Ancestral: por 8 s, trocar de forma não tem recarga e cada troca solta
##              uma explosão da forma nova.

const LEAP_RANGE := 7.0
const LEAP_BONUS := 0.5        # Onça: +50% no golpe do salto
const SUCURI_HOLD := 2.0       # Sucuri: aperta 2 s (normal 0,8 s)
const BOTO_HEAL := 0.05        # Boto: cura 5% da vida máxima
const CYCLE_WINDOW := 10.0
const CYCLE_BONUS := 0.2
const CYCLE_TIME := 6.0
const SPIRIT_TIME := 8.0
const BURST_RADIUS := 3.5
const COLOR := Color("6fdc7b")

var _instinct := false
var _cycle_left := 0.0
var _spirit_left := 0.0
var _form_seen := {}   # forma -> instante (s) em que foi usada
var _clock := 0.0


func skill_name() -> String:
	return "Forma"


func skill_cooldown() -> float:
	return 0.15 if _spirit_left > 0.0 else Player.FORM_COOLDOWN


func skill_color() -> Color:
	return COLOR


func ultimate_name() -> String:
	return "Espírito"


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Forma (habilidade, %d s): troca entre Onça, Sucuri e Boto." % Player.FORM_COOLDOWN,
		"Instinto (passiva): o 1º ataque depois de trocar de forma é especial — a Onça salta até o alvo (+50%), a Sucuri aperta por mais tempo e o Boto se cura.",
		"Ciclo da Mata (passiva): usar as 3 formas em até %d s dá +%d%% de dano por %d s." % [CYCLE_WINDOW, int(CYCLE_BONUS * 100), CYCLE_TIME],
		"Espírito Ancestral (ultimate): por %d s, trocar de forma não tem recarga e cada troca solta uma explosão da forma nova." % SPIRIT_TIME,
	])


func _use_skill() -> bool:
	if _spirit_left > 0.0:
		player._form_cooldown = 0.0
	return player.cycle_form()


func _use_ultimate() -> void:
	_spirit_left = SPIRIT_TIME
	_skill_cd = 0.0
	_charges = max_charges()
	player._form_cooldown = 0.0
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "ESPÍRITO ANCESTRAL!", COLOR)
	Vfx.particles(player, Vector3(0, 1.0, 0), "folha", 20, 0.8, Color(0.7, 1.0, 0.6), 0.4, Vector2(1.5, 3.5), 180.0, 0.0)


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _cycle_left > 0.0:
		_cycle_left -= delta
	if _spirit_left > 0.0:
		_spirit_left -= delta


func on_run_start() -> void:
	super()
	_instinct = false
	_cycle_left = 0.0
	_spirit_left = 0.0
	_form_seen.clear()


func on_form_changed(new_form: int) -> void:
	if player == null or not player.is_inside_tree():
		return
	_instinct = true
	_form_seen[new_form] = _clock
	# Ciclo da Mata: as três formas dentro da janela.
	var all_recent := _form_seen.size() >= 3
	for f in _form_seen:
		if _clock - float(_form_seen[f]) > CYCLE_WINDOW:
			all_recent = false
	if all_recent and _cycle_left <= 0.0:
		_cycle_left = CYCLE_TIME
		_form_seen.clear()
		_form_seen[new_form] = _clock
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.2, 0), "CICLO DA MATA!", COLOR)
	if _spirit_left > 0.0:
		_burst(new_form)


func damage_factor() -> float:
	return 1.0 + CYCLE_BONUS if _cycle_left > 0.0 else 1.0


# ---------- Instinto ----------

func before_attack() -> void:
	if not _instinct:
		return
	if player.form == Player.Form.ONCA:
		var target := player.current_target()
		if target:
			var to := target.global_position - player.global_position
			to.y = 0.0
			var reach: float = player.weapon_stats.attack_range
			if to.length() > reach and to.length() <= LEAP_RANGE:
				_leap(to)


func _leap(to: Vector3) -> void:
	var dir := to.normalized()
	var dist := to.length() - 1.0
	var from := player.global_position + Vector3(0, 0.6, 0)
	var space := player.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * dist, Layers.WORLD))
	if not hit.is_empty():
		dist = maxf(from.distance_to(hit.position) - 0.6, 0.0)
	Vfx.particles(player.get_parent(), player.global_position + Vector3(0, 0.3, 0), "poeira", 10, 0.5, Color(0.8, 0.7, 0.5), 0.5, Vector2(1.0, 2.0), 60.0, 0.0)
	player.global_position += dir * dist
	player.reset_physics_interpolation()
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.4, 0), "SALTO!", Color("d9a441"))


func melee_multiplier(_combo_step: int) -> float:
	var m := damage_factor()
	if _instinct and player.form == Player.Form.ONCA:
		m *= 1.0 + LEAP_BONUS
	return m


func on_melee_hit(enemy: Node3D, _combo_step: int) -> void:
	if _instinct and player.form == Player.Form.SUCURI and enemy.has_method("constrict"):
		enemy.constrict(SUCURI_HOLD, "apertado")


func modify_projectile(p: Projectile) -> void:
	p.damage = maxi(int(round(p.damage * damage_factor())), 1)
	if _instinct and player.form == Player.Form.BOTO:
		player.health.heal(int(round(player.health.max_health * BOTO_HEAL)))
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.4, 0), "CURA!", Color("f2a7c3"))


func on_attack_done() -> void:
	_instinct = false


# ---------- Espírito Ancestral ----------

## Explosão da forma nova: Onça arranha em volta, Sucuri prende todos perto, Boto cura e molha.
func _burst(new_form: int) -> void:
	var origin := player.global_position
	var dmg := maxi(int(round(player.weapon_stats.damage * 1.5)), 1)
	var color: Color = Player.FORMS[new_form].color
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - origin
		to.y = 0.0
		if to.length() > BURST_RADIUS or not Layers.clear_path(player.get_world_3d(), origin, enemy.global_position):
			continue
		match new_form:
			Player.Form.ONCA:
				enemy.take_hit(dmg, false, to)
			Player.Form.SUCURI:
				enemy.take_hit(int(dmg * 0.5), false, to)
				enemy.constrict(1.5, "apertado")
			Player.Form.BOTO:
				enemy.take_hit(int(dmg * 0.7), false, to)
	if new_form == Player.Form.BOTO:
		player.health.heal(int(round(player.health.max_health * 0.08)))
	Fx.shockwave(player.get_parent(), origin, BURST_RADIUS, color)
