class_name TankKit
extends HeroKit
## Icamiaba (tanque).
##  Habilidade  Provocar: grito com o escudo; inimigos perto vêm para cima dela sem recuar,
##              saem da tocaia/camuflagem e batem 25% mais fraco por alguns segundos.
##  Ultimate    Muralha de Casco: por alguns segundos segura TODO golpe direto, até mega magia.
##  Passivas    Muiraquitã: uma vez por andar, um golpe fatal a deixa com 25% da vida.
##              Revide: depois de bloquear, o próximo golpe causa +50% de dano.
## Talentos (ver Talents): Proteção, Fúria e Guardiã mexem nos números e somam efeitos aqui.

const PROVOKE_RADIUS := 9.0
const PROVOKE_TIME := 6.0
const PROVOKE_COOLDOWN := 12.0
const WALL_TIME := 6.0
const REVIDE_BONUS := 0.5
const REVIDE_WINDOW := 4.0
const COLOR := Color("e8c26a")
const SPEAR_MODEL := "res://game/art/armas/lanca_icamiaba.glb"

var _wall_left := 0.0
var _revide_left := 0.0
var _stone_left := 0.0
var _stone_cd := 0.0
var _extra_saves := 0
var _vengeful := 0.0
var _vengeful_left := 0.0
var _dome: MeshInstance3D
var _glow: CPUParticles3D


func skill_name() -> String:
	return "Provocar"


func skill_cooldown() -> float:
	return PROVOKE_COOLDOWN - tv("folego_curto")


func _provoke_radius() -> float:
	return PROVOKE_RADIUS + tv("grito_forte")


func _wall_time() -> float:
	return WALL_TIME + tv("casco_vivo")


func _revide_bonus() -> float:
	return REVIDE_BONUS + tv("revide_feroz") / 100.0


func skill_color() -> Color:
	return Color("ff9f43")


func ultimate_name() -> String:
	return "Muralha"


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Provocar (habilidade, %ds): inimigos a %dm vêm para cima, sem recuar, e batem %d%% mais fraco por %ds." % [skill_cooldown(), _provoke_radius(), int(round((1.0 - _provoke_factor()) * 100)), PROVOKE_TIME],
		"Muralha de Casco (ultimate): por %s s segura todo golpe, até a mega magia. Carrega matando, bloqueando e apanhando." % _num(_wall_time()),
		"Muiraquitã (passiva): %s por andar, um golpe fatal deixa com 25%% da vida." % ("duas vezes" if t("muiraquita_ancestral") > 0 else "uma vez"),
		"Revide (passiva): depois de bloquear, o próximo golpe causa +%d%% de dano." % int(round(_revide_bonus() * 100)),
	])


func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, round(v)) else String.num(v, 1).replace(".", ",")


func _provoke_factor() -> float:
	return Enemy.PROVOKE_DAMAGE - tv("voz_tribo") / 100.0


func _use_skill() -> bool:
	var origin := player.global_position
	var radius := _provoke_radius()
	var hit := 0
	var farthest: Node3D = null
	var far_d := -1.0
	var provoked: Array = []
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		var d := origin.distance_to(enemy.global_position)
		if enemy.has_method("provoke") and d <= radius:
			enemy.provoke(PROVOKE_TIME, _provoke_factor(), player)
			enemy.provoked_vulnerability = tv("grito_amazonas") / 100.0
			if t("chao_tremido") > 0:
				enemy.slow(1.0 - tv("chao_tremido") / 100.0, 3.0)
			hit += 1
			if d > far_d and Layers.clear_path(player.get_world_3d(), origin, enemy.global_position):
				far_d = d
				farthest = enemy
	Vfx.provoke(player.get_parent(), origin, radius, provoked)
	if t("lanca_certeira") > 0 and farthest and far_d > 2.5:
		_throw_spear(farthest)
	if t("guarda_vingativa") > 0 and hit > 0:
		_set_vengeful(hit)
	if t("grito_amazonas") > 0:
		add_charge(10.0)
	Fx.float_text(player.get_parent(), origin + Vector3(0, 2.8, 0), "PROVOCAR!", Color("ff9f43"))
	player.play_kit_animation("provocar", 1.0)
	return true


## Lança Certeira: a lança voa até o inimigo mais distante, fere e o puxa para perto dela.
func _throw_spear(enemy: Node3D) -> void:
	var from := player.global_position + Vector3(0, 1.2, 0)
	# a lança de verdade (o modelo da arma), com rastro dourado
	var spear := Node3D.new()
	player.get_parent().add_child(spear)
	spear.global_position = from
	var to := enemy.global_position + Vector3(0, 0.8, 0)
	spear.look_at(to, Vector3.UP)
	if ResourceLoader.exists(SPEAR_MODEL):
		var model: Node3D = load(SPEAR_MODEL).instantiate()
		spear.add_child(model)
		var aabb := HeroGear._aabb(model)
		var k := 1.7 / maxf(aabb.get_longest_axis_size(), 0.001)
		# a ponta do modelo fica no lado -X: gira para a ponta olhar para a frente (-Z)
		model.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * k), Vector3.ZERO)
		model.position = -(model.basis * aabb.get_center())
	RibbonTrail.follow(spear, 0.45, COLOR, 0.18)
	Vfx.particles(spear, Vector3.ZERO, "faisca", 10, 0.3, COLOR, 0.3, Vector2(0.0, 0.3), 180.0, 0.0, true, false)
	var tw := spear.create_tween()
	tw.tween_property(spear, "global_position", to, clampf(from.distance_to(to) / 25.0, 0.2, 0.5))
	var enemy_ref: WeakRef = weakref(enemy)  # pode morrer antes da lança chegar
	tw.tween_callback(func() -> void:
		spear.queue_free()
		var target: Node3D = enemy_ref.get_ref()
		if not is_instance_valid(target) or not is_instance_valid(player):
			return
		var dmg := int(round(player.weapon_stats.damage * tv("lanca_certeira") / 100.0))
		var dir: Vector3 = player.global_position - target.global_position
		target.take_hit(dmg, false, -dir)
		target.push(dir, maxf(dir.length() - 1.6, 0.0))
		Fx.float_text(player.get_parent(), target.global_position + Vector3(0, 2.2, 0), "PUXADO!", COLOR)
		Vfx.particles(player.get_parent(), to, "faisca", 10, 0.35, COLOR, 0.35, Vector2(2.0, 4.0), 180.0, 0.0))


## Guarda Vingativa: armadura extra por inimigo provocado, enquanto o Provocar durar.
func _set_vengeful(count: int) -> void:
	var armor := float(player.stats.armor)
	var boosted := armor * (1.0 + tv("guarda_vingativa") / 100.0 * count)
	var base_red := armor / (armor + 200.0)
	var new_red := boosted / (boosted + 200.0)
	player.health.extra_reduction -= _vengeful
	_vengeful = maxf(new_red - base_red, 0.0)
	player.health.extra_reduction += _vengeful
	_vengeful_left = PROVOKE_TIME


func _use_ultimate() -> void:
	_wall_left = _wall_time()
	player.health.wall_active = true
	if is_instance_valid(_dome):
		_dome.queue_free()
	_dome = Vfx.shell_dome(player, 1.7, _wall_left)
	if t("muralha_avancada") > 0:
		var reach := tv("muralha_avancada")
		for enemy in player.get_tree().get_nodes_in_group("enemies"):
			var away: Vector3 = enemy.global_position - player.global_position
			if away.length() <= reach and enemy.has_method("push"):
				enemy.push(away, reach + 1.0 - away.length())
		Fx.shockwave(player.get_parent(), player.global_position, reach, COLOR)
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "MURALHA DE CASCO!", COLOR)
	player.play_kit_animation("muralha", 1.1)


func _process(delta: float) -> void:
	super(delta)
	if _wall_left > 0.0:
		_wall_left -= delta
		if _wall_left <= 0.0:
			player.health.wall_active = false
	if _revide_left > 0.0:
		_revide_left -= delta
		if _revide_left <= 0.0:
			_stop_glow()
	_stone_cd -= delta
	if _stone_left > 0.0:
		_stone_left -= delta
		if _stone_left <= 0.0:
			player.health.extra_reduction -= tv("pele_pedra") / 100.0
	if _vengeful_left > 0.0:
		_vengeful_left -= delta
		if _vengeful_left <= 0.0:
			player.health.extra_reduction -= _vengeful
			_vengeful = 0.0
	# Guarda Imóvel: parada, bloqueia mais.
	player.health.extra_block = tv("guarda_imovel") / 100.0 if not player.is_moving() else 0.0


func wall_active() -> bool:
	return _wall_left > 0.0


func on_run_start() -> void:
	super()
	_wall_left = 0.0
	_revide_left = 0.0
	_stone_left = 0.0
	_stone_cd = 0.0
	_vengeful = 0.0
	_vengeful_left = 0.0
	player.health.extra_reduction = 0.0
	player.health.extra_block = 0.0
	player.health.wall_active = false
	_stop_glow()
	if is_instance_valid(_dome):
		_dome.queue_free()
	on_floor_start()


func on_floor_start() -> void:
	player.health.death_save = true  # Muiraquitã volta a cada andar
	_extra_saves = t("muiraquita_ancestral")


func on_death_saved() -> void:
	# Muiraquitã Ancestral: o amuleto aguenta mais uma vez no mesmo andar.
	if _extra_saves > 0:
		_extra_saves -= 1
		player.health.death_save = true


func on_shield_broken() -> void:
	# Pele de Pedra Verde: o corpo endurece quando o escudo cai.
	if t("pele_pedra") <= 0 or _stone_cd > 0.0:
		return
	if _stone_left <= 0.0:
		player.health.extra_reduction += tv("pele_pedra") / 100.0
	_stone_left = 3.0
	_stone_cd = 20.0
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.3, 0), "PELE DE PEDRA!", Color("6fdc7b"))


func on_kill(elite: bool) -> void:
	super(elite)
	if t("sede_batalha") > 0:
		player.health.heal(int(round(player.health.max_health * tv("sede_batalha") / 100.0)))


func melee_cone_bonus() -> float:
	return tv("golpe_largo") * 0.5  # o talento fala do ângulo total; aqui é para cada lado


func melee_multiplier(combo_step: int) -> float:
	if combo_step == 2 and t("terceiro_golpe") > 0:
		return 1.0 + tv("terceiro_golpe") / 100.0
	return 1.0


func on_melee_hit(enemy: Node3D, combo_step: int) -> void:
	if combo_step == 2 and t("terceiro_golpe") > 0 and enemy.has_method("stun"):
		enemy.stun(0.8)


func on_blocked() -> void:
	# Durante a Muralha, cada golpe segurado também arma o Revide, mas não enche a ultimate.
	if not wall_active():
		super()
	else:
		Vfx.shell_hit(_dome)
		if t("muralha_espelhada") > 0:
			_reflect(int(round(player.last_hit_amount * tv("muralha_espelhada") / 100.0)))
	if t("furia_icamiaba") > 0 and randf() < tv("furia_icamiaba") / 100.0:
		_spin()
	if _revide_left <= 0.0:
		_stop_glow()
		_glow = Vfx.revide_glow(_spear_hand())
	_revide_left = REVIDE_WINDOW


## Muralha Espelhada: devolve parte do golpe para quem bateu (o inimigo mais perto de onde veio).
func _reflect(amount: int) -> void:
	if amount <= 0:
		return
	var best: Node3D = null
	var best_d := 4.0
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		var d: float = enemy.global_position.distance_to(player.last_hit_from)
		if d < best_d:
			best_d = d
			best = enemy
	if best:
		best.take_hit(amount, false, best.global_position - player.global_position)
		Vfx.particles(player.get_parent(), best.global_position + Vector3(0, 1.0, 0), "casco_hex", 6, 0.4, COLOR, 0.4, Vector2(1.0, 2.5), 180.0, 0.0)


## Fúria Icamiaba: contragolpe giratório que acerta todos em volta.
func _spin() -> void:
	var reach := player.weapon_stats.attack_range + 0.4
	for enemy in player.get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - player.global_position
		to.y = 0.0
		if to.length() <= reach and Layers.clear_path(player.get_world_3d(), player.global_position, enemy.global_position):
			var hit := Damage.roll(player.weapon_stats.damage, player.hero.element, enemy.data.element, player.crit_chance, player._rng)
			enemy.take_hit(hit.amount, hit.crit, to)
	FxKit.spin_slash(player.get_parent(), player.global_position, reach + 0.3, Color("ff9f43"), 0.28)
	FxKit.ground_wave(player.get_parent(), player.global_position, reach + 0.5, Color(1.0, 0.6, 0.25), 0.3, 0.5)
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "FÚRIA!", Color("ff9f43"))
	player.play_kit_animation("ataque3", 0.5, "")


## Onde fica a lança (mão direita do modelo); sem modelo, o próprio herói.
func _spear_hand() -> Node3D:
	var found := player.find_children("Gear_mixamorig_RightHand", "BoneAttachment3D", true, false)
	return found[0] if not found.is_empty() else player


func _stop_glow() -> void:
	if is_instance_valid(_glow):
		_glow.emitting = false
		_glow.get_tree().create_timer(0.6, false).timeout.connect(_glow.queue_free)
	_glow = null


func revide_ready() -> bool:
	return _revide_left > 0.0


func modify_outgoing(amount: int) -> int:
	if _revide_left > 0.0:
		return int(round(amount * (1.0 + _revide_bonus())))
	return amount


func on_attack_done() -> void:
	if _revide_left > 0.0:
		_revide_left = 0.0
		_stop_glow()
		Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 2.5, 0), "REVIDE!", COLOR)
		Vfx.revide_strike(player.get_parent(), player.global_position + player.facing() * 1.4 + Vector3(0, 1.0, 0))
