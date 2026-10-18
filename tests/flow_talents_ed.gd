extends SceneTree
## Talentos do Encantado do Rio e da Druida da Mata: cada um faz o que a descrição promete,
## numa masmorra de verdade (bonecos parados como alvo).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_talents_ed.gd

var _ok := true
var _gs
var _main
var _player
var _kit
var T = load("res://game/scripts/systems/talents.gd")
var PROJ
var WC
var POR
var BOI
const ROOT := 2  # ROOT


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _all(hero_id: StringName, except: Array = []) -> Dictionary:
	var out := {}
	for b in T.branches(hero_id):
		for t in b.talents:
			if not t.id in except:
				out[t.id] = int(t.max)
	return out


func _set_talents(hero_id: StringName, talents: Dictionary) -> void:
	_gs.progress(hero_id)["talents"] = talents
	_player.refresh_stats()


func _clear() -> void:
	for group in ["enemies", "player_projectiles", "floor_effects", "telegraphs", "enemy_projectiles"]:
		for n in get_nodes_in_group(group):
			n.queue_free()


func _dummy(offset: Vector3):
	var room = _main.builder.rooms[_main.layout.start_index]
	var e = _main._spawn(&"queixada", room, _player.global_position + offset)
	e._dodge_cd = 999.0
	e._constrict_left = 0.0
	e.health.max_health = 99999
	e.health.health = 99999
	e.training_dummy = true
	return e


func _hold(e) -> void:
	# fica parado sem ser "apertado" (o aperto conta para talentos da Sucuri)
	e.set_physics_process(false)


func _start(hero_id: StringName) -> void:
	_gs.selected_hero = hero_id
	_gs.progress(hero_id).level = 40
	_gs.progress(hero_id)["talents"] = {}
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(8)
	_main = current_scene
	_player = _main.get_node("Player")
	_kit = _player.kit
	_clear()
	var room = _main.builder.rooms[_main.layout.start_index]
	_player.global_position = room.center() + Vector3(0, 0.1, 0)
	_player.reset_physics_interpolation()
	await _frames(2)


func _run() -> void:
	PROJ = load("res://game/scripts/gameplay/projectile.gd")
	WC = load("res://game/scripts/gameplay/kits/water_clone.gd")
	POR = load("res://game/scripts/gameplay/kits/pororoca.gd")
	BOI = load("res://game/scripts/gameplay/kits/boiuna.gd")
	_gs = root.get_node("GameState")
	_gs.debug_talent_points = 0
	await _test_encantado()
	await _test_druida()
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)


# ---------------------------------------------------------------- Encantado

func _test_encantado() -> void:
	await _start(&"encantado")
	var base_dmg: int = _player.weapon_stats.damage
	var base_speed: float = _player.weapon_stats.attack_speed
	_set_talents(&"encantado", _all(&"encantado", ["boiuna"]))
	check(_player.weapon_stats.damage == int(round(base_dmg * 1.12)), "Água Funda: +12%% de dano (%d -> %d)" % [base_dmg, _player.weapon_stats.damage])
	check(is_equal_approx(_player.weapon_stats.attack_speed, base_speed * 1.12), "Gota Ligeira: dispara 12% mais rápido")

	# Ricochete Longo: o 5º disparo quica em 2 + 2.
	_kit._shots = 0
	var p
	for i in 5:
		p = PROJ.new()
		_kit.modify_projectile(p)
		if i < 4:
			p.free()
	check(p.bounces == 4, "Ricochete Longo: o Ricochete quica em 4 inimigos (%d)" % p.bounces)
	p.free()

	# Pressão d'Água: mesmo alvo seguido = +5% por acerto.
	var a = _dummy(Vector3(-3, 0, 0))
	_hold(a)
	_player._target = a
	_kit._streak = 0
	_kit._streak_target = null
	var dmgs := []
	for i in 4:
		var q = PROJ.new()
		q.damage = 100
		_kit.modify_projectile(q)
		dmgs.append(q.damage)
		q.free()
	check(dmgs[0] == 100 and dmgs[1] == 105 and dmgs[3] == 115, "Pressão d'Água: 100, 105, 110, 115 no mesmo alvo (%s)" % str(dmgs))

	# Água que Volta: quique cura 2%.
	_player.health.health = 100
	var bounce = PROJ.new()
	bounce._hit = {1: true, 2: true}
	_kit._on_projectile_hit(a, bounce)
	check(_player.health.health == 100 + int(round(_player.health.max_health * 0.02)), "Água que Volta: o quique cura 2% da vida")
	bounce.free()
	check(a.is_soaked() and is_equal_approx(a._soaked_left, 8.0), "Encharcar Profundo: encharcado dura 8 s")
	check(is_equal_approx(a.slip_chance, 0.16) and is_equal_approx(a.miss_chance(), 0.16), "Chão Escorregadio: encharcado erra 16% dos ataques")

	# Gelo de Rio: 10% de congelar alvo encharcado (50 tentativas).
	var froze := false
	for i in 50:
		var g = PROJ.new()
		g._hit = {1: true}
		_kit._on_projectile_hit(a, g)
		g.free()
		if a._frozen_left > 0.0:
			froze = true
			break
	check(froze, "Gelo de Rio: disparo em encharcado congela às vezes")

	# Escorregar: com 100% de chance o ataque é perdido.
	var slipper = _dummy(Vector3(2, 0, 3))
	slipper.soak(5.0)
	slipper.slip_chance = 1.0
	slipper._start(slipper._attacks[0])
	check(slipper.state == slipper.State.RECOVER and get_nodes_in_group("telegraphs").is_empty(), "Escorregar: o ataque é perdido (sem aviso no chão)")

	# Enchente: encharcado que morre espirra no vizinho.
	_clear()
	await _frames(2)
	var victim = _dummy(Vector3(-4, 0, 0))
	var neighbor = _dummy(Vector3(-4, 0, 1.6))
	_hold(victim)
	_hold(neighbor)
	_kit.soak_enemy(victim)
	victim.health.health = 1
	var hp0: int = neighbor.health.health
	victim.take_hit(10, false, Vector3.ZERO)
	await _frames(3)
	check(neighbor.health.health < hp0 and neighbor.is_soaked(), "Enchente: o encharcado que morre espirra água no vizinho (dano e encharca)")

	# Espelho com talentos.
	_clear()
	await _frames(2)
	check(is_equal_approx(_kit.skill_cooldown(), 7.0), "Passo d'Água: Espelho recarrega em 7 s")
	var lured = _dummy(Vector3(5, 0, 2))
	_player._facing = Vector3(1, 0, 0)
	var start: Vector3 = _player.global_position
	check(_kit.try_skill(), "Espelho com talentos")
	check(_player.health.bubble == int(round(_player.health.max_health * 0.12)), "Bolha Protetora: escudo de 12% da vida")
	var clones := get_nodes_in_group("floor_effects").filter(func(n): return n.get_script() == WC)
	check(clones.size() == 1, "cópia de água deixada")
	var clone = clones[0] if clones.size() > 0 else null
	if clone:
		check(is_equal_approx(clone.lifetime, 10.0) and is_equal_approx(clone.radius, 5.0), "Cópia Teimosa dura 10 s; Explosão Funda: raio 5 m")
		check(lured.is_lured(), "Cópia Teimosa: atrai o inimigo próximo")
		var before := get_nodes_in_group("player_projectiles").size()
		var shot = PROJ.new()
		shot.damage = 100
		_kit.modify_projectile(shot)
		shot.free()
		await _frames(1)
		check(get_nodes_in_group("player_projectiles").size() > before, "Cópia Atiradora: a cópia atira junto")
		# Iara: o segundo toque volta para a cópia (sem gastar carga) e ela explode.
		var charges_before: int = _kit.charges()
		var foe = _dummy(Vector3(0, 0, 0))
		foe.global_position = clone.global_position + Vector3(1.5, 0.1, 0)
		_hold(foe)
		var foe_hp: int = foe.health.health
		check(_kit.try_skill(), "Iara: segundo toque do Espelho")
		check(_player.global_position.distance_to(Vector3(start.x, _player.global_position.y, start.z)) < 0.5, "Iara: voltou para onde estava a cópia")
		check(_kit.charges() == charges_before, "Iara: não gastou carga")
		await _frames(2)
		check(foe.health.health < foe_hp and foe.miss_chance() >= 0.3, "Iara faz a cópia explodir; Espuma: quem pegou erra 30%")

	# Pororoca com talentos (sem Boiuna).
	_clear()
	await _frames(2)
	var room = _main.builder.rooms[_main.layout.start_index]
	var wall_dir := Vector3(1, 0, 0)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if not room._door_dirs.has(d):
			wall_dir = Vector3(d.x, 0, d.y)
			break
	_player.global_position = room.center() - wall_dir * 3.0 + Vector3(0, 0.1, 0)
	_player._facing = wall_dir
	var target = _dummy(wall_dir * 4.0)
	target.stun(0.5)
	_kit.charge = 100.0
	check(_kit.try_ultimate(), "Pororoca com talentos")
	var waves := get_nodes_in_group("floor_effects").filter(func(n): return n.get_script() == POR)
	check(waves.size() == 1 and is_equal_approx(waves[0].width, 7.0 * 1.45) and is_equal_approx(waves[0].throw, 11.0),
		"Onda Larga: 45% mais larga; Maré Forte: arremessa 11 m")
	await _frames(120)
	check(_kit.charge >= 15.0, "Maré Cheia: inimigo jogado na parede devolveu carga (%.0f)" % _kit.charge)
	var returning := get_nodes_in_group("floor_effects").filter(func(n): return n.get_script() == POR and n.returning)
	var came_back := not returning.is_empty()
	if not came_back:
		await _frames(30)
	check(came_back or get_nodes_in_group("floor_effects").any(func(n): return n.get_script() == POR and n.returning), "Ressaca: a onda voltou")

	# Boiuna.
	_clear()
	await _frames(2)
	_set_talents(&"encantado", _all(&"encantado"))
	check(_kit.ultimate_name() == "Boiuna", "Boiuna troca o nome da ultimate")
	var bitten = _dummy(Vector3(3.0, 0, 0))
	_hold(bitten)
	var bhp: int = bitten.health.health
	_kit.charge = 100.0
	check(_kit.try_ultimate(), "Boiuna funciona")
	await _frames(40)
	check(bitten.health.health < bhp and bitten.is_soaked(), "Boiuna: morde e encharca quem está no círculo (3 m)")
	check(get_nodes_in_group("floor_effects").any(func(n): return n.get_script() == BOI), "Boiuna ainda circulando")
	await _frames(340)
	check(get_nodes_in_group("floor_effects").any(func(n): return n.get_script() == POR), "Boiuna: no fim avança como Pororoca")


# ---------------------------------------------------------------- Druida

func _test_druida() -> void:
	await _start(&"druida")
	_set_talents(&"druida", _all(&"druida"))
	_player.set_form(_player.Form.ONCA)
	_kit._instinct = false
	check(is_equal_approx(_kit.melee_multiplier(0), 1.12), "Garras Longas: Onça +12%")
	check(is_equal_approx(_kit.dodge_chance(), 0.12), "Pele Malhada: Onça esquiva 12%")
	# esquiva de verdade: 60 golpes, algum passa raspando
	var dodged := 0
	for i in 60:
		var hp: int = _player.health.health
		_player.health._invulnerable = 0.0
		_player.receive_attack(5, 0, 0.0, 0, Vector3.ZERO)
		if _player.health.health == hp:
			dodged += 1
	_player.health.reset()
	check(dodged > 0 and dodged < 30, "Pele Malhada: esquivou de %d de 60 golpes" % dodged)

	var hurt = _dummy(Vector3(-3, 0, 0))
	_hold(hurt)
	hurt.health.health = int(hurt.health.max_health * 0.3)
	check(is_equal_approx(_kit.target_multiplier(hurt), 1.24), "Caça ao Ferido: +24% em quem tem menos de 40% de vida")

	# Faro de Sangue
	_player._form_cooldown = 3.0
	_kit.on_kill(false)
	check(_player._form_cooldown <= 0.0, "Faro de Sangue: abate na Onça zera a recarga da troca")

	# Bote + Rugido + Onça-Pintada Alfa
	_clear()
	await _frames(2)
	var room = _main.builder.rooms[_main.layout.start_index]
	_player.global_position = room.center() + Vector3(-4.5, 0.1, 0)
	var far = _dummy(Vector3(8.5, 0, 0))
	var second = _dummy(Vector3(8.5, 0, 3.0))
	_hold(far)
	_hold(second)
	_player._target = far
	_kit._instinct = true
	_kit._chained = false
	var x0: float = _player.global_position.x
	_kit.before_attack()
	check(_player.global_position.x - x0 > 6.0, "Bote: o salto alcançou o alvo a 8,5 m (andou %.1f m)" % (_player.global_position.x - x0))
	check(second.is_scared(), "Rugido: o salto assusta quem está em volta")
	var hp2: int = second.health.health
	_kit.on_melee_hit(far, 0)
	await _frames(2)
	check(second.health.health < hp2, "Onça-Pintada Alfa: saltou no segundo alvo e bateu")

	# Sucuri
	_clear()
	await _frames(2)
	_player._form_cooldown = 0.0
	_player.set_form(_player.Form.NONE if false else _player.Form.SUCURI)
	_kit._instinct = false
	var no_talent_dr: float
	_set_talents(&"druida", {})
	_player.set_form(_player.Form.SUCURI)
	no_talent_dr = _player.health.damage_reduction
	var no_talent_range: float = _player.weapon_stats.attack_range
	_set_talents(&"druida", _all(&"druida"))
	_kit._instinct = false
	check(is_equal_approx(_player.health.damage_reduction - no_talent_dr, 0.15), "Escamas Grossas: Sucuri +15% de defesa")
	check(is_equal_approx(_player.weapon_stats.attack_range - no_talent_range, 0.6), "Cauda Longa: Sucuri +0,6 m de alcance")
	check(is_equal_approx(_kit.constrict_bonus(), 0.8), "Abraço Longo: aperto +0,8 s")
	check(is_equal_approx(_kit.melee_cone_bonus(), 290.0), "Cobra Grande: golpe em volta toda")
	_player.receive_attack(1, ROOT, 2.0, 0, Vector3.ZERO)
	check(not _player.status.is_rooted(), "Corpo Pesado: Sucuri não fica presa por raízes")
	# Cobra Grande: inimigo atrás também é pego e apertado.
	var behind = _dummy(Vector3(0, 0, 1.5))
	_player._facing = Vector3(0, 0, -1)
	_player.health.health = 100
	var bh: int = behind.health.health
	_player._melee_swing()
	check(behind.health.health < bh and behind.is_constricted(), "Cobra Grande: pegou e apertou o inimigo de trás")
	var tick0: int = behind.health.health
	await _frames(70)
	check(behind.health.health < tick0, "Nó Apertado: o aperto machuca enquanto dura")
	check(_player.health.health > 100, "Engolir: curou enquanto apertava (%d)" % _player.health.health)

	# Boto
	_clear()
	await _frames(2)
	_player._form_cooldown = 0.0
	_player.set_form(_player.Form.BOTO)
	check(is_equal_approx(_kit.regen_bonus(), 0.01), "Canto do Boto: +1% de cura por segundo")
	check(is_equal_approx(_kit.speed_factor(), 1.15), "Boto Ligeiro: +15% de velocidade")
	_kit._instinct = true
	_player.health.health = 100
	var bp = PROJ.new()
	bp.damage = 100
	_kit.modify_projectile(bp)
	var heal_now: int = _player.health.health - 100
	check(heal_now == int(round(_player.health.max_health * 0.11)), "Maré de Cura: Instinto do Boto cura 11%")
	var cycle_dmg: float = _kit.damage_factor()
	check(bp.damage == int(round(int(round(100 * cycle_dmg)) * 1.15)), "Sopro: Boto +15% de dano")
	bp.free()
	_kit._instinct = false
	var after_instant: int = _player.health.health
	await _frames(60)
	check(_player.health.health > after_instant, "Maré de Cura: continua curando depois")
	# Encanto: enfeitiça às vezes; o enfeitiçado ataca outro inimigo.
	var charmed = _dummy(Vector3(-3, 0, 0))
	var other = _dummy(Vector3(-4.2, 0, 0))
	_hold(other)
	var got := false
	for i in 80:
		_kit._on_boto_hit(charmed, null)
		if charmed.is_charmed():
			got = true
			break
	check(got, "Encanto: o disparo do Boto enfeitiça às vezes")
	var ohp: int = other.health.health
	await _frames(90)
	check(other.health.health < ohp, "Encanto: o enfeitiçado atacou outro inimigo")
	# Sonar: o Boto marca, a Onça salta direto no marcado (mais longe que o normal).
	_clear()
	await _frames(2)
	_player.global_position = room.center() + Vector3(-5, 0.1, 0)
	var marked = _dummy(Vector3(10.0, 0, 0))
	_hold(marked)
	_kit._on_boto_hit(marked, null)
	_player._form_cooldown = 0.0
	_player.set_form(_player.Form.ONCA)
	_player._target = null
	var sx: float = _player.global_position.x
	_kit.before_attack()
	check(_player.global_position.x - sx > 7.5, "Sonar: a Onça saltou direto no alvo marcado a 10 m")
	check(_kit.melee_multiplier(0) > 1.12 * 1.5 * 1.29, "Sonar: o salto no marcado bate +30%")

	# Espírito da Floresta: Ciclo com 2 formas e troca sem recarga.
	_kit.on_run_start()
	_player._form_cooldown = 0.0
	_player.set_form(_player.Form.SUCURI)
	_player._form_cooldown = 0.0
	_player.set_form(_player.Form.BOTO)
	check(_kit._cycle_left > 0.0, "Espírito da Floresta: Ciclo da Mata com 2 formas")
	check(is_equal_approx(_kit.skill_cooldown(), 0.15), "Espírito da Floresta: troca sem recarga durante o Ciclo")
