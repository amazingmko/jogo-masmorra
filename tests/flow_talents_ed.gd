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
var ENC
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
	ENC = load("res://game/scripts/gameplay/kits/encontro_aguas.gd")
	_gs = root.get_node("GameState")
	_gs.debug_all_specs = true  # testa efeitos de ramos diferentes juntos
	_gs.debug_talent_points = 0
	await _test_encantado()
	await _test_druida()
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	_gs.debug_clear_talents()  # não deixa talentos para os outros testes
	_gs.save()
	quit(0 if _ok else 1)


# ---------------------------------------------------------------- Encantado

func _test_encantado() -> void:
	await _start(&"encantado")
	var base_dmg: int = _player.weapon_stats.damage
	var base_speed: float = _player.weapon_stats.attack_speed
	_set_talents(&"encantado", _all(&"encantado", ["encontro_aguas"]))
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

	# Pororoca com talentos (sem o Encontro das Águas).
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

	# Encontro das Águas: duas ondas (Rio Negro e Solimões) que se chocam e viram redemoinho.
	_clear()
	await _frames(2)
	_set_talents(&"encantado", _all(&"encantado"))
	check(_kit.ultimate_name() == "Encontro", "Encontro das Águas troca o nome da ultimate")
	var center: Vector3 = room.center()
	_player.global_position = center - Vector3(0, 0, -3.0) + Vector3(0, 0.1, 0)
	_player._facing = Vector3(0, 0, -1)
	await _frames(2)
	var meet: Vector3 = _player.global_position + Vector3(0, 0, -7.0)
	var near = _dummy(Vector3(2.8, 0, -7.0))
	var far = _dummy(Vector3(0, 0, 4.0))
	near.stun(30.0)  # parado (o boneco andaria até o herói): só o redemoinho o move
	far.stun(30.0)
	var near_d0: float = Vector2(near.global_position.x - meet.x, near.global_position.z - meet.z).length()
	var near_hp: int = near.health.health
	var far_hp: int = far.health.health
	_kit.charge = 100.0
	check(_kit.try_ultimate(), "Encontro das Águas funciona")
	await _frames(2)
	var two := get_nodes_in_group("floor_effects").filter(func(n): return n.get_script() == POR)
	var tints := two.map(func(n): return n.tint)
	check(two.size() == 2 and tints.has("negro") and tints.has("solimoes"), "saem duas ondas: Rio Negro e Solimões (%s)" % str(tints))
	await _frames(150)
	var near_d1: float = Vector2(near.global_position.x - meet.x, near.global_position.z - meet.z).length()
	check(near_d1 < near_d0 - 1.0, "redemoinho puxa para o meio (%.1f m -> %.1f m)" % [near_d0, near_d1])
	check(near.health.health < near_hp and near._stun_left > 0.0, "redemoinho: dano e atordoa (%d -> %d)" % [near_hp, near.health.health])
	check(far.health.health == far_hp, "quem está atrás não é pego")
	check(T.sanitize({"boiuna": 1}, &"encantado", 40).get("encontro_aguas", 0) == 1, "save antigo: o ponto da Boiuna vai para o Encontro das Águas")


# ---------------------------------------------------------------- Druida

func _seed_at(offset: Vector3) -> void:
	_kit._plant(_player.global_position + offset)


func _test_druida() -> void:
	await _start(&"druida")
	var room = _main.builder.rooms[_main.layout.start_index]
	# sem talentos: números de base
	check(_kit.max_seeds() == 6 and is_equal_approx(_kit.seed_life(), 8.0), "base: 6 mudas de 8 s")
	_set_talents(&"druida", _all(&"druida"))
	check(_kit.max_seeds() == 8 and is_equal_approx(_kit.seed_life(), 12.0), "Bosque: 8 mudas de 12 s")
	check(is_equal_approx(_kit.trail_step(), 3.0), "Passo de Semente: uma muda a cada 3 m")
	var p = PROJ.new()
	p.damage = 100
	_kit.modify_projectile(p)
	check(p.damage == 115, "Semente Dura: +15%% (%d)" % p.damage)
	p.free()

	# Seiva Forte + Raiz Afiada + Espinho de Tucumã + Flor de Maracujá
	_clear()
	await _frames(2)
	var e = _dummy(Vector3(2.0, 0, 0))
	_hold(e)
	_seed_at(Vector3(2.0, 0, 0))
	await _frames(1)
	_player.health.health = 100
	var hp: int = e.health.health
	_kit.bloom_all(false)
	var heal: int = _player.health.health - 100
	check(heal == int(round(_player.health.max_health * 0.04 * 1.45)), "Seiva Forte: a flor cura 5,8%% (%d)" % heal)
	var expect := int(round(int(round(_player.weapon_stats.damage * 0.5 * 1.5)) * 1.3))
	check(hp - e.health.health >= expect, "Raiz Afiada + Espinho: a flor bateu %d (>= %d)" % [hp - e.health.health, expect])
	check(e.is_weakened() and is_equal_approx(e.damage_multiplier, 0.7), "Espinho de Tucumã: inimigo bate 30% mais fraco")
	check(e._slow_left > 0.0 and is_equal_approx(e._slow_factor, 0.6), "Flor de Maracujá: 40% mais lento")

	# Muda Viva: cura parada perto da muda; Muda Carnívora: morde quem encosta
	_clear()
	await _frames(2)
	var biter = _dummy(Vector3(1.5, 0, 0))
	_hold(biter)
	_seed_at(Vector3(1.5, 0, 0))
	_player.health.health = 100
	var bh: int = biter.health.health
	await _frames(130)
	check(_player.health.health > 100, "Muda Viva: curou %d em ~2 s" % (_player.health.health - 100))
	check(biter.health.health < bh, "Muda Carnívora: a muda mordeu o inimigo encostado")

	# Ninho de Flores: depois do Florescer nascem 2 mudas
	_clear()
	await _frames(2)
	_kit._seeds.clear()
	_kit._skill_cd = 0.0
	check(_kit.try_skill(), "Florescer sem mudas funciona")
	await _frames(1)
	check(_kit.seeds().size() == 2, "Ninho de Flores: 2 mudas novas (%d)" % _kit.seeds().size())

	# Sonolência: 3 sementes no mesmo inimigo = sono; Despertar Rude: o golpe que acorda dói +30%
	var sl = _dummy(Vector3(3, 0, 0))
	_hold(sl)
	for i in 3:
		_kit._on_seed_hit(sl, null)
	check(sl.is_asleep(), "Sonolência: 3 sementes fazem dormir")
	check(sl._marks.has("eco"), "Eco: a Semente também marca")
	var shp: int = sl.health.health
	sl.take_hit(100, false, Vector3.RIGHT)
	check(shp - sl.health.health >= 130 and not sl.is_asleep(), "Despertar Rude: acordou com %d de dano (100 base)" % (shp - sl.health.health))

	# Boto: Orvalho, Festa do Boto, Canto (cura, Eco, Sono, Boto Ancestral), Coração do Rio
	_clear()
	await _frames(2)
	_player.global_position = room.center() + Vector3(0, 0.1, 0)
	var d1 = _dummy(Vector3(3, 0, 0))
	var d2 = _dummy(Vector3(-3, 0, 1))
	_player.health.health = 100
	_kit.charge = 100.0
	check(_kit.try_ultimate(), "Despertar do Boto funciona")
	check(_player.health.health >= 100 + int(_player.health.max_health * 0.3) - 1, "Orvalho: curou 30% ao despertar")
	check(d1.is_dancing() and d2.is_dancing(), "Festa do Boto: os inimigos perto dançam")
	var cp = PROJ.new()
	cp.damage = 100
	_kit.modify_projectile(cp)
	check(cp.pierce >= 99, "Canto atravessa todos")
	_player.health.health = 100
	var left0: float = _kit._boto_left
	_kit._on_canto_hit(d1, cp)
	check(_player.health.health - 100 == maxi(int(round(_player.health.max_health * 0.015 * 1.6)), 1), "Canto Doce: o Canto cura 2,4%%")
	check(_kit._boto_left > left0 + 0.4, "Boto Ancestral: o acerto estende o Boto")
	check(is_equal_approx(d1.damage_taken_bonus(), 0.15), "Eco: marcado recebe +15%")
	for i in 20:
		_kit._on_canto_hit(d1, cp)
	check(_kit._boto_extended <= 5.0 + 0.001, "Boto Ancestral: no máximo +5 s")
	var slept := false
	for i in 200:
		d2._sleep_left = 0.0
		_kit._on_canto_hit(d2, cp)
		if d2.is_asleep():
			slept = true
			break
	check(slept and d2._sleep_left >= 4.4, "Sono + Sono Profundo: o Canto faz dormir (%.1f s)" % d2._sleep_left)
	cp.free()
	# Coração do Rio: matar um marcado cura e carrega a ultimate
	_player.health.health = 100
	_kit.charge = 0.0
	_player.set_meta("last_killed", d1)
	_kit.on_kill(false)
	check(_player.health.health > 100 and _kit.charge >= 10.0, "Coração do Rio: abate de marcado cura e carrega a ultimate")
	cp = null
