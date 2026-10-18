class_name DruidKit
extends HeroKit
## Druida da Mata: vira bicho.
##  Habilidade  Forma: troca entre Onça, Sucuri e Boto.
##  Passiva     Instinto: o 1º ataque depois de trocar de forma é especial — a Onça salta até o
##              alvo (e bate mais), a Sucuri prende por mais tempo, o Boto se cura um pouco.
##  Passiva     Ciclo da Mata: usar as 3 formas em até 10 s dá +20% de dano por 6 s.
##  Ultimate    Espírito Ancestral: por 8 s, trocar de forma não tem recarga e cada troca solta
##              uma explosão da forma nova.
## Talentos (Onça, Sucuri, Boto): ver Talents.TREES[&"druida"].

const LEAP_RANGE := 7.0
const LEAP_BONUS := 0.5        # Onça: +50% no golpe do salto
const SUCURI_HOLD := 2.0       # Sucuri: aperta 2 s (normal 0,8 s)
const BOTO_HEAL := 0.05        # Boto: cura 5% da vida máxima
const CYCLE_WINDOW := 10.0
const CYCLE_BONUS := 0.2
const CYCLE_TIME := 6.0
const SPIRIT_TIME := 8.0
const BURST_RADIUS := 3.5
const WOUNDED := 0.4           # Caça ao Ferido: abaixo de 40% da vida
const ROAR_RADIUS := 3.5
const SONAR_RANGE := 12.0
const SQUEEZE_TICK := 1.0      # Nó Apertado: dano a cada segundo apertando
const SQUEEZE_DAMAGE := 0.2    # 20% do dano por segundo, crescendo
const COLOR := Color("6fdc7b")

var _instinct := false
var _cycle_left := 0.0
var _spirit_left := 0.0
var _form_seen := {}   # forma -> instante (s) em que foi usada
var _clock := 0.0
var _chained := false
var _sonar: WeakRef
var _hot_left := 0.0
var _hot_rate := 0.0
var _hot_acc := 0.0
var _squeezed := {}    # id do inimigo -> [WeakRef, segundos apertando, acumulador]
var _swallow_acc := 0.0


func skill_name() -> String:
	return "Forma"


func skill_cooldown() -> float:
	return 0.15 if _free_swap() else Player.FORM_COOLDOWN


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


## Troca de forma sem recarga: ultimate, ou Ciclo ativo com Espírito da Floresta.
func _free_swap() -> bool:
	return _spirit_left > 0.0 or (t("espirito_floresta") > 0 and _cycle_left > 0.0)


func _use_skill() -> bool:
	if _free_swap():
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
	if player == null or player.health.is_dead:
		return
	# Maré de Cura: o resto da cura do Instinto do Boto, aos poucos.
	if _hot_left > 0.0:
		_hot_left -= delta
		_hot_acc += _hot_rate * delta
		if _hot_acc >= 1.0:
			player.health.heal(int(_hot_acc))
			_hot_acc -= int(_hot_acc)
	_tick_squeeze(delta)


func on_run_start() -> void:
	super()
	_instinct = false
	_cycle_left = 0.0
	_spirit_left = 0.0
	_form_seen.clear()
	_squeezed.clear()
	_hot_left = 0.0


func on_form_changed(new_form: int) -> void:
	if player == null or not player.is_inside_tree():
		return
	_instinct = true
	_chained = false
	_form_seen[new_form] = _clock
	# Ciclo da Mata: as três formas (duas, com Espírito da Floresta) dentro da janela.
	var needed := 2 if t("espirito_floresta") > 0 else 3
	var recent := 0
	for f in _form_seen:
		if _clock - float(_form_seen[f]) <= CYCLE_WINDOW:
			recent += 1
	if recent >= needed and _cycle_left <= 0.0:
		_cycle_left = CYCLE_TIME
		_form_seen.clear()
		_form_seen[new_form] = _clock
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.2, 0), "CICLO DA MATA!", COLOR)
	if _spirit_left > 0.0:
		_burst(new_form)


func damage_factor() -> float:
	return 1.0 + CYCLE_BONUS if _cycle_left > 0.0 else 1.0


# ---------- talentos simples por forma ----------

func dodge_chance() -> float:
	return tv("pele_malhada") / 100.0 if player and player.form == Player.Form.ONCA else 0.0


func ignores_effect(effect: int) -> bool:
	if t("corpo_pesado") <= 0 or player == null or player.form != Player.Form.SUCURI:
		return false
	return effect in [EnemyAttack.Effect.ROOT, EnemyAttack.Effect.SLOW, EnemyAttack.Effect.FEAR]


func target_multiplier(enemy: Node3D) -> float:
	if t("caca_ferido") <= 0 or not is_instance_valid(enemy):
		return 1.0
	var h = enemy.health
	if float(h.health) / maxf(h.max_health, 1.0) < WOUNDED:
		return 1.0 + tv("caca_ferido") / 100.0
	return 1.0


func constrict_bonus() -> float:
	return tv("abraco_longo")


func regen_bonus() -> float:
	return tv("canto_boto") / 100.0 if player and player.form == Player.Form.BOTO else 0.0


func form_guard_bonus(form: int) -> float:
	return tv("escamas_grossas") / 100.0 if form == Player.Form.SUCURI else 0.0


func form_range_bonus(form: int) -> float:
	return tv("cauda_longa") if form == Player.Form.SUCURI else 0.0


func speed_factor() -> float:
	return 1.0 + tv("boto_ligeiro") / 100.0 if player and player.form == Player.Form.BOTO else 1.0


## Cobra Grande: a rabanada da Sucuri pega em volta toda.
func melee_cone_bonus() -> float:
	return 290.0 if t("cobra_grande") > 0 and player and player.form == Player.Form.SUCURI else 0.0


func on_kill(elite: bool) -> void:
	super(elite)
	# Faro de Sangue: abate na forma de Onça libera a troca na hora.
	if t("faro_sangue") > 0 and player and player.form == Player.Form.ONCA and player._form_cooldown > 0.0:
		player._form_cooldown = 0.0
		_skill_cd = 0.0
		_charges = max_charges()
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.6, 0), "FARO DE SANGUE!", Color("d9a441"))
		changed.emit()


# ---------- Instinto ----------

func before_attack() -> void:
	if not _instinct:
		return
	if player.form == Player.Form.ONCA:
		# Sonar: o salto vai direto no alvo marcado pelo Boto (mesmo um pouco mais longe).
		var target := player.current_target()
		var marked: Node3D = _sonar.get_ref() if _sonar else null
		var max_range := LEAP_RANGE + tv("bote")
		if marked and is_instance_valid(marked) and not marked.health.is_dead \
				and marked.global_position.distance_to(player.global_position) <= SONAR_RANGE:
			target = marked
			max_range = SONAR_RANGE
			player._target = marked
			player._attack_target = marked
		if target:
			var to := target.global_position - player.global_position
			to.y = 0.0
			var reach: float = player.weapon_stats.attack_range
			if to.length() > reach and to.length() <= max_range:
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
	_roar()


## Rugido: o salto assusta quem está em volta.
func _roar() -> void:
	if t("rugido") <= 0:
		return
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) <= ROAR_RADIUS and enemy.has_method("scare"):
			enemy.scare(tv("rugido"))
	Fx.shockwave(player.get_parent(), player.global_position, ROAR_RADIUS, Color("d9a441"))


func melee_multiplier(_combo_step: int) -> float:
	var m := damage_factor()
	if player.form == Player.Form.ONCA:
		m *= 1.0 + tv("garras_longas") / 100.0
		if _instinct:
			m *= 1.0 + LEAP_BONUS
			var marked: Node3D = _sonar.get_ref() if _sonar else null
			if marked and player._attack_target == marked:
				m *= 1.0 + tv("sonar") / 100.0
	return m


func on_melee_hit(enemy: Node3D, _combo_step: int) -> void:
	if _instinct and player.form == Player.Form.SUCURI and enemy.has_method("constrict"):
		enemy.constrict(SUCURI_HOLD + tv("abraco_longo"), "apertado")
	# Cobra Grande: a rabanada aperta todo mundo que pega.
	if t("cobra_grande") > 0 and player.form == Player.Form.SUCURI and enemy.has_method("constrict"):
		enemy.constrict(tv("cobra_grande") + tv("abraco_longo"), "apertado")
	if player.form == Player.Form.SUCURI:
		_track_squeeze(enemy)
	# Onça-Pintada Alfa: depois do salto, salta num segundo alvo e já bate nele.
	if _instinct and player.form == Player.Form.ONCA and t("onca_alfa") > 0 and not _chained:
		_chained = true
		_chain_leap.call_deferred(enemy)


func _chain_leap(first: Node3D) -> void:
	if player == null or not player.is_inside_tree():
		return
	var best: Node3D = null
	var best_d := LEAP_RANGE + tv("bote")
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if enemy == first or enemy.health.is_dead:
			continue
		var d: float = enemy.global_position.distance_to(player.global_position)
		if d < best_d and Layers.clear_path(player.get_world_3d(), player.global_position, enemy.global_position):
			best_d = d
			best = enemy
	if best == null:
		return
	var to := best.global_position - player.global_position
	to.y = 0.0
	_leap(to)
	var dmg := maxi(int(round(player.weapon_stats.damage * melee_multiplier(0) * target_multiplier(best))), 1)
	best.take_hit(dmg, false, to)
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.8, 0), "ALFA!", Color("ffb347"))


func modify_projectile(p: Projectile) -> void:
	p.damage = maxi(int(round(p.damage * damage_factor())), 1)
	if player.form == Player.Form.BOTO:
		p.damage = maxi(int(round(p.damage * (1.0 + tv("sopro") / 100.0))), 1)
		p.on_hit = _on_boto_hit
		if _instinct:
			var heal_pct := BOTO_HEAL + tv("mare_cura") / 100.0
			player.health.heal(int(round(player.health.max_health * heal_pct)))
			Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.4, 0), "CURA!", Color("f2a7c3"))
			if t("mare_cura") > 0:
				# continua curando o mesmo tanto pelos próximos 3 s
				_hot_left = 3.0
				_hot_rate = player.health.max_health * heal_pct / 3.0
				_hot_acc = 0.0


func _on_boto_hit(enemy: Node3D, _p: Projectile) -> void:
	if not is_instance_valid(enemy):
		return
	if t("sonar") > 0:
		_sonar = weakref(enemy)
		if enemy.has_method("mark"):
			enemy.mark("sonar", 0.0, 6.0)
	if t("encanto") > 0 and randf() < tv("encanto") / 100.0 and enemy.has_method("charm"):
		enemy.charm(2.0)


func on_attack_done() -> void:
	_instinct = false


# ---------- Sucuri: Engolir e Nó Apertado ----------

func _track_squeeze(enemy: Node3D) -> void:
	if t("engolir") <= 0 and t("no_apertado") <= 0:
		return
	var id := enemy.get_instance_id()
	if not _squeezed.has(id):
		_squeezed[id] = [weakref(enemy), 0.0, 0.0]


func _tick_squeeze(delta: float) -> void:
	if _squeezed.is_empty():
		return
	var any := false
	for id in _squeezed.keys():
		var entry: Array = _squeezed[id]
		var enemy: Node3D = entry[0].get_ref()
		if enemy == null or not is_instance_valid(enemy) or enemy.health.is_dead or not enemy.is_constricted():
			_squeezed.erase(id)
			continue
		any = true
		entry[1] += delta
		if t("no_apertado") > 0:
			entry[2] += delta
			if entry[2] >= SQUEEZE_TICK:
				entry[2] -= SQUEEZE_TICK
				var grow: float = 1.0 + tv("no_apertado") / 100.0 * entry[1]
				enemy.take_hit(maxi(int(round(player.weapon_stats.damage * SQUEEZE_DAMAGE * grow)), 1), false, Vector3.ZERO)
	# Engolir: cura enquanto aperta alguém.
	if any and t("engolir") > 0:
		_swallow_acc += player.health.max_health * tv("engolir") / 100.0 * delta
		if _swallow_acc >= 1.0:
			player.health.heal(int(_swallow_acc))
			_swallow_acc -= int(_swallow_acc)


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
