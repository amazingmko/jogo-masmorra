class_name DruidKit
extends HeroKit
## Druida da Mata: cura, utilidade e o Boto. Luta em forma humana com o Cajado de Raiz.
##  Ataque      Semente: o cajado lança uma semente; onde ela cai (no inimigo ou no chão) planta uma
##              muda (dura 8 s, no máximo 6).
##  Habilidade  Florescer: todas as mudas abrem em flor de uma vez: cada flor perto da Druida cura,
##              e machuca os inimigos em volta da flor. Sem mudas, planta duas aos seus pés.
##  Passiva     Rastro de Seiva: andando em luta, planta sozinha uma muda atrás de si a cada 4 m
##              (correr dos inimigos espalha o jardim que o Florescer vai abrir).
##  Ultimate    Despertar do Boto (10 s): vira o boto-cor-de-rosa numa bolha de água: mais rápida,
##              imune a lentidão e raízes; o ataque vira o Canto (onda sonora que atravessa todos e
##              cura a cada acerto). No fim, toda muda floresce.
## Talentos (Canto do Boto, Encanto do Boto, Marca do Rio): ver Talents.TREES[&"druida"].

const COLOR := Color("6fdc7b")
const SEED_LIFE := 8.0
const MAX_SEEDS := 6
const BLOOM_COOLDOWN := 8.0
const FLOWER_HEAL := 0.03          # cada flor perto da Druida cura 3% da vida máxima
const FLOWER_HEAL_RANGE := 4.0
const FLOWER_RADIUS := 2.2         # inimigos a até 2,2 m da flor levam o golpe dela
const FLOWER_DAMAGE := 0.5         # 50% do dano da arma
const TRAIL_STEP := 4.0           # uma muda a cada 4 m andados
const TRAIL_COMBAT_RANGE := 14.0   # só planta com inimigo acordado por perto (explorando, não)
const BOTO_TIME := 10.0
const BOTO_EXTEND_MAX := 5.0
const CANTO_HEAL := 0.015          # cada inimigo atingido pelo Canto cura 1,5%
const CANTO_DAMAGE := 0.8
const CANTO_SPEED := 1.6           # canta 60% mais rápido que a semente
const BOTO_MOVE := 1.25
const SLEEP_TIME := 2.5
const DANCE_RADIUS := 6.0
const ECO_TIME := 4.0
const WEAKEN_TIME := 4.0
const DROWSY_WINDOW := 4.0
const CARNIVORE_RADIUS := 1.3

var _seeds: Array = []
var _walked := 0.0
var _last_pos := Vector3.INF
var _boto_left := 0.0
var _boto_extended := 0.0
var _boto: BotoForm
var _drowsy := {}      # id do inimigo -> [sementes, tempo desde a primeira]
var _heal_acc := 0.0


func skill_name() -> String:
	return "Florescer"


func skill_cooldown() -> float:
	return BLOOM_COOLDOWN


func skill_color() -> Color:
	return Color("f29ccb")


func ultimate_name() -> String:
	return "Boto"


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Semente (ataque): onde a semente cai, nasce uma muda (dura %d s, no máximo %d)." % [SEED_LIFE, max_seeds()],
		"Florescer (habilidade, %d s): todas as mudas abrem em flor: cada flor perto de você cura %d%% da vida e machuca os inimigos em volta dela." % [BLOOM_COOLDOWN, int(FLOWER_HEAL * 100)],
		"Rastro de Seiva (passiva): andando em luta, planta uma muda atrás de você a cada %d m." % int(trail_step()),
		"Despertar do Boto (ultimate, %d s): vira o Boto numa bolha de água, mais rápida e imune a lentidão e raízes; o Canto atravessa os inimigos e cura a cada acerto. No fim, toda muda floresce." % BOTO_TIME,
	])


# ---------- números (com talentos) ----------

func max_seeds() -> int:
	return MAX_SEEDS + t("bosque")


func seed_life() -> float:
	return SEED_LIFE + 2.0 * t("bosque")


func trail_step() -> float:
	return TRAIL_STEP - tv("passo_semente")


func is_boto() -> bool:
	return _boto_left > 0.0


func seeds() -> Array:
	_seeds = _seeds.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion())
	return _seeds


# ---------- semente ----------

func modify_projectile(p: Projectile) -> void:
	if is_boto():
		_make_canto(p)
		return
	p.damage = maxi(int(round(p.damage * (1.0 + tv("semente_dura") / 100.0))), 1)
	p.element = GameEnums.Element.NATURE
	p.on_hit = _on_seed_hit
	p.on_end = _plant


func _on_seed_hit(enemy: Node3D, _p: Projectile) -> void:
	_echo(enemy)
	# Sonolência: várias sementes seguidas no mesmo bicho o fazem dormir
	if t("sonolencia") > 0 and enemy.has_method("sleep"):
		var id := enemy.get_instance_id()
		var e: Array = _drowsy.get(id, [0, 0.0])
		e[0] += 1
		_drowsy[id] = e
		if e[0] >= int(tv("sonolencia")):
			_drowsy.erase(id)
			enemy.sleep(_sleep_time(), _wake_bonus())


func _plant(at: Vector3) -> void:
	if player == null or not player.is_inside_tree():
		return
	var list := seeds()
	while list.size() >= max_seeds():
		var old = list.pop_front()
		if is_instance_valid(old):
			old.wither()
	var s := DruidSeed.new()
	s.kit = self
	s.life = seed_life()
	player.get_parent().add_child(s)
	s.global_position = Vector3(at.x, player.global_position.y, at.z)
	_seeds.append(s)


## A cada quadro, por muda: Muda Viva (cura por perto) e Muda Carnívora (morde quem passa).
func on_seed_tick(s: DruidSeed, delta: float) -> void:
	var d := s.global_position.distance_to(player.global_position)
	if t("muda_viva") > 0 and d <= FLOWER_HEAL_RANGE:
		_heal_acc += player.health.max_health * tv("muda_viva") / 100.0 * delta
		if _heal_acc >= 1.0:
			player.health.heal(int(_heal_acc))
			_heal_acc -= int(_heal_acc)
	if t("muda_carnivora") > 0:
		s._bite_acc += delta
		if s._bite_acc >= 1.0:
			s._bite_acc = 0.0
			var dmg := maxi(int(round(player.weapon_stats.damage * tv("muda_carnivora") / 100.0)), 1)
			for enemy in player.get_tree().get_nodes_in_group("enemies"):
				if enemy.health.is_dead:
					continue
				if enemy.global_position.distance_to(s.global_position) <= CARNIVORE_RADIUS:
					enemy.take_hit(dmg, false, enemy.global_position - s.global_position)
					MobFx.chunks(s.get_parent(), s.global_position + Vector3(0, 0.3, 0), Color(0.3, 0.6, 0.2), 3, 0.05, Vector2(1.0, 2.0))


# ---------- Florescer ----------

func _use_skill() -> bool:
	player.play_kit_animation("florescer", 0.8, "")
	var list := seeds()
	if list.is_empty():
		# sem mudas: duas nascem aos pés dela e já abrem
		for i in 2:
			var a := TAU * i / 2.0 + randf()
			_plant(player.global_position + Vector3(cos(a), 0, sin(a)) * 1.0)
		list = seeds()
	bloom_all(true)
	if t("ninho_flores") > 0:
		for i in int(tv("ninho_flores")):
			var a := TAU * i / maxf(tv("ninho_flores"), 1.0)
			_plant(player.global_position + Vector3(cos(a), 0, sin(a)) * 1.6)
	return true


## Todas as mudas abrem. Cada flor: cura (se perto), golpe nos inimigos em volta e talentos.
func bloom_all(from_skill: bool) -> int:
	var list := seeds()
	var healed := 0
	var heal_each := FLOWER_HEAL * (1.0 + tv("seiva_forte") / 100.0)
	var dmg := maxi(int(round(player.weapon_stats.damage * FLOWER_DAMAGE * (1.0 + tv("raiz_afiada") / 100.0))), 1)
	for s in list:
		if not is_instance_valid(s):
			continue
		var at: Vector3 = s.global_position
		if at.distance_to(player.global_position) <= FLOWER_HEAL_RANGE:
			healed += int(round(player.health.max_health * heal_each))
		for enemy in player.get_tree().get_nodes_in_group("enemies"):
			if enemy.health.is_dead or enemy.global_position.distance_to(at) > FLOWER_RADIUS:
				continue
			var hit := dmg
			if t("espinho_tucuma") > 0:
				hit = int(round(hit * 1.3))
				if enemy.has_method("weaken"):
					enemy.weaken(1.0 - tv("espinho_tucuma") / 100.0, WEAKEN_TIME)
			enemy.take_hit(hit, false, enemy.global_position - at)
			if t("flor_maracuja") > 0 and enemy.has_method("slow"):
				enemy.slow(1.0 - tv("flor_maracuja") / 100.0, 3.0)
		s.bloom()
	_seeds.clear()
	if healed > 0:
		player.health.heal(healed)
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.4, 0), "+%d" % healed, Color("6fdc7b"))
	if from_skill:
		Vfx.ground_ring(player.get_parent(), player.global_position, "anel_som", Color(1.0, 0.7, 0.9, 0.7), 3.0, 0.4)
	return list.size()


# ---------- Raízes Vivas ----------

func _process(delta: float) -> void:
	super(delta)
	if player == null or player.health.is_dead:
		return
	for id in _drowsy.keys():
		_drowsy[id][1] += delta
		if _drowsy[id][1] > DROWSY_WINDOW:
			_drowsy.erase(id)
	_trail()
	if _boto_left > 0.0:
		_boto_left -= delta
		if _boto_left <= 0.0:
			_end_boto()


## Rastro de Seiva: conta os metros andados (fora do Boto) e planta uma muda atrás dela.
func _trail() -> void:
	var pos: Vector3 = player.global_position
	if _last_pos == Vector3.INF:
		_last_pos = pos
	var step := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	if is_boto() or step > 2.0 or not _in_combat():  # teleporte/troca de andar não conta
		return
	_walked += step
	if _walked >= trail_step():
		_walked = 0.0
		var back := Vector3(player.velocity.x, 0, player.velocity.z)
		back = -back.normalized() * 0.6 if back.length() > 0.1 else Vector3.ZERO
		_plant(pos + back)


func _in_combat() -> bool:
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		if enemy.health.is_dead or not enemy.get("_awake"):
			continue
		if enemy.global_position.distance_to(player.global_position) <= TRAIL_COMBAT_RANGE:
			return true
	return false


# ---------- Despertar do Boto ----------

func _use_ultimate() -> void:
	player.play_kit_animation("despertar", 0.6, "")
	_boto_left = BOTO_TIME
	_boto_extended = 0.0
	_show_boto(true)
	player.refresh_stats()
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "DESPERTAR DO BOTO!", Color("f29ccb"))
	if t("orvalho") > 0:
		player.health.heal(int(round(player.health.max_health * tv("orvalho") / 100.0)))
	if t("festa_boto") > 0:
		var any := false
		for enemy in player.get_tree().get_nodes_in_group("enemies"):
			if enemy.health.is_dead or not enemy.has_method("dance"):
				continue
			if enemy.global_position.distance_to(player.global_position) <= DANCE_RADIUS:
				enemy.dance(tv("festa_boto"))
				any = true
		if any:
			Vfx.particles(player.get_parent(), player.global_position + Vector3(0, 1.5, 0), "faisca", 24, 1.2, Color(1.0, 0.6, 0.85), 0.3, Vector2(1.5, 4.0), 180.0, -1.0, true, true, 2.0)
			Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.5, 0), "FESTA DO BOTO!", Color("ff9ad5"))


func _end_boto() -> void:
	_boto_left = 0.0
	_show_boto(false)
	player.refresh_stats()
	bloom_all(false)


func _show_boto(on: bool) -> void:
	var body: Node3D = player._body
	if on:
		if is_instance_valid(_boto):
			_boto.queue_free()
		_boto = BotoForm.new()
		body.add_child(_boto)
	elif is_instance_valid(_boto):
		_boto.vanish()
		_boto = null
	if player._model:
		player._model.visible = not on
	if player._mesh:
		player._mesh.visible = not on and player._model == null
	Vfx.particles(player.get_parent(), player.global_position + Vector3(0, 1.0, 0), "faisca", 18, 0.6, Color(0.6, 0.85, 1.0), 0.3, Vector2(1.5, 3.5), 180.0, -1.0)


## Arma do Boto: o Canto (disparo que atravessa todos, mais rápido, cura a cada acerto).
func modify_weapon(w: WeaponStats) -> WeaponStats:
	if not is_boto():
		return w
	var c := WeaponStats.new()
	c.damage = maxi(int(round(w.damage * CANTO_DAMAGE)), 1)
	c.attack_speed = w.attack_speed * CANTO_SPEED
	c.attack_range = maxf(w.attack_range, 9.0)
	c.projectile_speed = 16.0
	return c


func _make_canto(p: Projectile) -> void:
	p.pierce = 99
	p.pierce_factor = 1.0
	p.element = GameEnums.Element.WATER
	p.on_hit = _on_canto_hit
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.1
	ring.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Vfx.tex("anel_som")
	m.albedo_color = Color(1.0, 0.7, 0.9, 0.9)
	ring.material_override = m
	p.add_child(ring)
	if is_instance_valid(_boto):
		_boto.pulse()


func _on_canto_hit(enemy: Node3D, _p: Projectile) -> void:
	player.health.heal(maxi(int(round(player.health.max_health * CANTO_HEAL * (1.0 + tv("canto_doce") / 100.0))), 1))
	if t("boto_ancestral") > 0 and _boto_extended < BOTO_EXTEND_MAX:
		var add := minf(tv("boto_ancestral"), BOTO_EXTEND_MAX - _boto_extended)
		_boto_left += add
		_boto_extended += add
	if t("sono") > 0 and enemy.has_method("sleep") and randf() < tv("sono") / 100.0:
		enemy.sleep(_sleep_time(), _wake_bonus())
	_echo(enemy)


## Eco (Marca do Rio): Semente e Canto marcam o inimigo para levar mais dano.
func _echo(enemy: Node3D) -> void:
	if t("eco") > 0 and enemy.has_method("mark"):
		enemy.mark("eco", tv("eco") / 100.0, ECO_TIME + tv("eco_longo"))


func _sleep_time() -> float:
	return SLEEP_TIME + tv("sono_profundo")


func _wake_bonus() -> float:
	return tv("despertar_rude") / 100.0


func speed_factor() -> float:
	return BOTO_MOVE if is_boto() else 1.0


func ignores_effect(effect: int) -> bool:
	return is_boto() and effect in [EnemyAttack.Effect.ROOT, EnemyAttack.Effect.SLOW]


func on_kill(elite: bool) -> void:
	super(elite)
	# Coração do Rio: inimigo marcado pelo Eco que morre cura e carrega a ultimate
	if t("coracao_rio") <= 0 or player == null:
		return
	var last: Node = player.get_meta("last_killed", null) if player.has_meta("last_killed") else null
	if last == null or not is_instance_valid(last):
		return
	if last.get("_marks") is Dictionary and last._marks.has("eco"):
		player.health.heal(int(round(player.health.max_health * tv("coracao_rio") / 100.0)))
		add_charge(10.0)
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.6, 0), "CORAÇÃO DO RIO", Color("f29ccb"))


func on_run_start() -> void:
	super()
	for s in seeds():
		s.queue_free()
	_seeds.clear()
	_boto_left = 0.0
	if is_instance_valid(_boto):
		_boto.queue_free()
	_walked = 0.0
	_last_pos = Vector3.INF
	_drowsy.clear()


func on_floor_start() -> void:
	_seeds.clear()
	if is_boto():
		_end_boto()
	_walked = 0.0
	_last_pos = Vector3.INF
