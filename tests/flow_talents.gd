extends SceneTree
## Árvore de talentos: regras dos pontos (nível, fileiras, máximo, redistribuir, save) e os
## efeitos dos talentos da Icamiaba e da Mateira numa masmorra de verdade.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_talents.gd

var _f := 0
var _ok := true
var _gs
var _db
var _main
var _player
var _kit
var _far
var _near
var _far_d0 := 0.0
var _far_hp0 := 0
var _near_d0 := 0.0
var _trap_target
var _trap_hp0 := 0
var _step_pos := {}
var T = load("res://game/scripts/systems/talents.gd")


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _all(hero_id: StringName) -> Dictionary:
	var out := {}
	for b in T.branches(hero_id):
		for t in b.talents:
			out[t.id] = int(t.max)
	return out


func _enemy_at(offset: Vector3):
	var room = _main.builder.rooms[_main.layout.start_index]
	var e = _main._spawn(&"queixada", room, _player.global_position + offset)
	e._dodge_cd = 999.0
	e.health.max_health = 99999
	e.health.health = 99999
	return e


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_gs = root.get_node("GameState")
		_db = root.get_node("ItemDB")
		_gs.debug_talent_points = 0
		_gs.progress(&"icamiaba").level = 1
		_gs.reset_talents(&"icamiaba")
		_test_rules()
		_gs.selected_hero = &"icamiaba"
		_gs.progress(&"icamiaba")["talents"] = _all(&"icamiaba")
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f == 6:
		_main = current_scene
		_player = _main.get_node("Player")
		_kit = _player.kit
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		_player.start_floor()
		check(is_equal_approx(_kit._provoke_radius(), 12.0), "Grito Forte: Provocar alcança 12 m")
		check(is_equal_approx(_kit.skill_cooldown(), 9.0), "Fôlego Curto: Provocar recarrega em 9 s")
		check(is_equal_approx(_kit.melee_multiplier(2), 1.5) and is_equal_approx(_kit.melee_multiplier(0), 1.0), "Terceiro Golpe: só o 3º golpe bate +50%")
		check(is_equal_approx(_kit.melee_cone_bonus(), 15.0), "Golpe Largo: +30° no golpe (15° para cada lado)")
		var start_room = _main.builder.rooms[_main.layout.start_index]
		_player.global_position = start_room.center() + Vector3(-5.5, 0.1, 0)  # o alvo distante fica dentro da clareira
		_far = _enemy_at(Vector3(10.5, 0.1, 0))
		_near = _enemy_at(Vector3(0, 0.1, 2.0))
	if _f == 10:
		_far_d0 = _far.global_position.distance_to(_player.global_position)
		_far_hp0 = _far.health.health
		check(_kit.try_skill(), "Provocar com os talentos")
		check(_far.is_provoked() and _far._slow_left > 0.0 and is_equal_approx(_far.provoked_vulnerability, 0.2),
			"provocado a 10,5 m: lento (Chão Tremido) e leva +20% de dano (Grito das Amazonas)")
		check(is_equal_approx(_far._provoke_factor, 0.65), "Voz da Tribo: provocado bate 35% mais fraco")
		check(_kit.charge >= 10.0, "Grito das Amazonas: Provocar carrega a ultimate")
		check(_player.health.extra_reduction > 0.0, "Guarda Vingativa: armadura extra com inimigos provocados")
		_near.stun(0.8)
		check(_near._stun_left > 0.0, "atordoar funciona (Terceiro Golpe)")
	if _f == 60:
		var d: float = _far.global_position.distance_to(_player.global_position)
		check(_far.health.health < _far_hp0, "Lança Certeira: a lança feriu o mais distante")
		check(d < _far_d0 - 3.0, "Lança Certeira: puxou para perto (%.1f m -> %.1f m)" % [_far_d0, d])
		_near_d0 = _near.global_position.distance_to(_player.global_position)
		_kit.charge = 100.0
		check(_kit.try_ultimate(), "Muralha de Casco")
		check(is_equal_approx(_kit._wall_left, 9.0), "Casco Vivo: Muralha dura 9 s")
	if _f == 90:
		check(_near.global_position.distance_to(_player.global_position) > _near_d0 + 1.0, "Muralha Avançada: empurrou quem estava perto")
		_player.last_hit_amount = 100
		_player.last_hit_from = _near.global_position
		var hp: int = _near.health.health
		_kit.on_blocked()
		check(_near.health.health < hp, "Muralha Espelhada: golpe segurado volta para o atacante")
		# Muiraquitã Ancestral: salva duas vezes no mesmo andar.
		_kit._wall_left = 0.0
		_player.health.wall_active = false
		_player.health.take_damage(999999, false, true)
		_player.health.take_damage(999999, false, true)
		check(not _player.health.is_dead, "Muiraquitã Ancestral: salvou duas vezes")
		check(not _player.health.death_save, "depois da segunda vez, o amuleto acabou neste andar")
		_player.health.heal(99999)
		# Mateira com a árvore inteira.
		_gs.progress(&"mateira")["talents"] = _all(&"mateira")
		_gs.selected_hero = &"mateira"
		_player.set_hero(_db.get_hero(&"mateira"))
		_kit = _player.kit
		_player.start_floor()
	if _f == 95:
		var companions := get_nodes_in_group("floor_effects").filter(func(n): return n.get_script().get_global_name() == &"Harpy" and n.companion)
		check(companions.size() == 1, "Revoada: a Harpia acompanha desde o começo do andar")
		check(_kit.max_charges() == 2 and _kit.try_skill() and _kit.try_skill() and not _kit.try_skill(), "Bolsa de Cipó: duas armadilhas seguidas")
		var spreads := []
		for i in 6:
			spreads.append(_kit.arrow_spread().size())
		check(spreads == [1, 1, 1, 1, 1, 3], "Chuva de Flechas: 5 tiros, o 6º sai em leque (%s)" % str(spreads))
		var p = load("res://game/scripts/gameplay/projectile.gd").new()
		_kit.modify_projectile(p)
		check(p.pierce == 1 and is_equal_approx(p.far_distance, 4.0) and is_equal_approx(p.crit_damage_bonus, 0.3),
			"Precisão: flecha atravessa, Olho de Caçadora a 4 m, crítico +30%")
		p.free()
		check(is_equal_approx(_kit.shoot_move_factor(0.55), 0.85), "Atirar Correndo: mantém 85% da velocidade")
		_kit.charge = 100.0
		check(_kit.try_ultimate() and _harpies().size() == 1 and _harpies()[0].is_furious(), "Fúria da Harpia: a ultimate enfurece a companheira (sem segunda harpia)")
		check(_harpies()[0]._dive_damage() == _harpies()[0].damage * 2, "Fúria da Harpia: dano em dobro")
		# Armadilha de Timbó: solta o bicho e envenena em volta.
		for e in get_nodes_in_group("floor_effects"):
			if e.get_script().get_global_name() == &"VineTrap":
				e.queue_free()
		_trap_target = _enemy_at(Vector3(-3, 0.1, -3))
		_trap_hp0 = _trap_target.health.health
		var trap = load("res://game/scripts/gameplay/kits/vine_trap.gd").new()
		trap.hold_time = 0.3
		trap.thorn_dps = 30.0
		trap.timbo_radius = 3.0
		trap.timbo_dps = 40.0
		_main.add_child(trap)
		trap.global_position = Vector3(_trap_target.global_position.x, 0.0, _trap_target.global_position.z)
	if _f == 150:
		check(_trap_target._poison_left > 0.0 and _trap_target.health.health < _trap_hp0, "Timbó: veneno depois de soltar o bicho")
		_main.debug_jump_to_floor(2)
	if _f == 155:
		check(_companions() == 1, "Revoada: a companheira continua no andar seguinte")
		_main.new_run()
	if _f == 160:
		check(_companions() == 1, "Revoada: a companheira continua numa run nova")
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		_main.spawn_training_dummies()
	if _f == 162:
		var dummies := get_nodes_in_group("enemies").filter(func(e): return e.training_dummy)
		check(dummies.size() == 3 and dummies[0].health.max_health > 50000, "tecla T: 3 bonecos de treino com vida enorme")
		_harpies()[0].fury(0.3)
		check(_harpies()[0]._body.scale.x > 1.2, "Fúria da Harpia: fica maior e dourada")
	if _f == 200:
		check(not _harpies()[0].is_furious() and is_equal_approx(_harpies()[0]._body.scale.x, 1.0), "Fúria da Harpia: acaba e ela volta ao normal")
	if _f == 1200:
		check(_companions() == 1, "Revoada: a companheira continua depois de 17 s de combate")
		# Icamiaba golpeando andando: anda mais devagar e o tronco gira para o alvo (sem patinar).
		_gs.selected_hero = &"icamiaba"
		_player.set_hero(_db.get_hero(&"icamiaba"))
		_kit = _player.kit
	if _f == 1205:
		var dummy = get_nodes_in_group("enemies")[0]
		_main._hud.joystick.value = Vector2(1, 0)
		_player._target = dummy
		_player._attack()
	if _f == 1215:
		var v := Vector2(_player.velocity.x, _player.velocity.z).length()
		check(v < _player.move_speed * 0.6, "Icamiaba golpeando andando: passo mais lento (%.1f de %.1f m/s)" % [v, _player.move_speed])
		check(_player._animator._aim_active, "Icamiaba golpeando andando: pernas seguem o movimento, tronco vira para o alvo")
		_main._hud.joystick.value = Vector2.ZERO
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
	if _f == 1300:
		# Parada e sem alvo: golpes 1 e 2 no lugar; o giro (golpe 3) avança com o passo do golpe.
		_main._hud.attack_button.is_pressed = true
		_player._swings = 0
		_player._animator._combo = 0
		_step_pos = {}
	if _f > 1300 and _f < 1600:
		var step: int = _player._combo_step
		if not _step_pos.has(step) and _player._attack_left > 0.0:
			_step_pos[step] = _player.global_position
	if _f == 1600:
		_main._hud.attack_button.is_pressed = false
		var p0: Vector3 = _step_pos.get(0, Vector3.ZERO)
		var p2: Vector3 = _step_pos.get(2, Vector3.ZERO)
		var moved_12: float = p0.distance_to(_step_pos.get(1, p0)) if _step_pos.has(1) else -1.0
		check(_step_pos.has(2), "três golpes seguidos parada")
		check(moved_12 < 0.3, "golpes 1 e 2 sem sair do lugar (%.2f m)" % moved_12)
		check(_player.global_position.distance_to(p2) > 1.5, "giro (golpe 3) avança com o golpe: %.1f m, sem patinar" % _player.global_position.distance_to(p2))
		print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
		quit(0 if _ok else 1)
	return false


func _harpies() -> Array:
	return get_nodes_in_group("floor_effects").filter(func(n): return n.get_script().get_global_name() == &"Harpy" and not n.is_queued_for_deletion())


func _companions() -> int:
	return _harpies().filter(func(n): return n.companion).size()


func _test_rules() -> void:
	var h := &"icamiaba"
	check(T.points_for_level(1) == 0 and T.points_for_level(40) == 20, "1 ponto a cada 2 níveis (20 no nível 40)")
	check(_gs.add_talent(h, "couro_anta") != "", "nível 1: sem pontos")
	_gs.progress(h).level = 20
	check(_gs.talent_points_free(h) == 10, "nível 20: 10 pontos")
	var armor0: int = _gs.stats_for(h).armor
	check(_gs.add_talent(h, "casco_vivo") != "", "fileira 2 fechada sem 3 pontos no ramo")
	for i in 3:
		check(_gs.add_talent(h, "couro_anta") == "", "Couro de Anta %d/3" % (i + 1))
	check(_gs.add_talent(h, "couro_anta") != "", "não passa do máximo")
	check(_gs.stats_for(h).armor > armor0, "Couro de Anta aumenta a armadura (%d -> %d)" % [armor0, _gs.stats_for(h).armor])
	check(_gs.add_talent(h, "casco_vivo") == "", "3 pontos no ramo abrem a fileira 2")
	check(_gs.add_talent(h, "revide_feroz") != "", "pontos de um ramo não abrem outro")
	var copy: Dictionary = _gs.to_dict()
	_gs.reset_talents(h)
	check(_gs.talent_points_free(h) == 10, "Redistribuir devolve tudo")
	_gs.from_dict(copy)
	check(_gs.talent_rank(h, "couro_anta") == 3 and _gs.talent_rank(h, "casco_vivo") == 1, "talentos sobrevivem ao save")
	_gs.reset_talents(h)
	var m := &"mateira"
	_gs.progress(m).level = 40
	_gs.reset_talents(m)
	var speed0: float = _gs.stats_for(m).move_speed
	_gs.add_talent(m, "pes_leves")
	check(_gs.stats_for(m).move_speed > speed0, "Pés Leves aumenta a velocidade")
	_gs.reset_talents(m)
