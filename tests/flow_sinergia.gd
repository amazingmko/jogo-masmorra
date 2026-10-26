extends SceneTree
## Sinergia elemental: contagem por herói diferente, bônus no grupo, Provocação do tanque
## e a regra de levantar parceiro.
##   godot --headless --fixed-fps 60 --path . --script res://tests/flow_sinergia.gd

var _fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok: " if ok else "FALHOU: ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var db = root.get_node("ItemDB")
	var ica = db.get_hero(&"icamiaba")
	var mat = db.get_hero(&"mateira")
	var enc = db.get_hero(&"encantado")
	var dru = db.get_hero(&"druida")
	var W := GameEnums.Element.WATER
	var N := GameEnums.Element.NATURE
	var E := GameEnums.Element.EARTH
	check(ica.elemental_styles() == [E] and dru.elemental_styles() == [N] and enc.elemental_styles() == [W], "um elemento por herói: Icamiaba Terra, Druida Natureza, Encantado Água")
	check(Synergy.active([ica]).is_empty(), "sozinho: nenhuma sinergia")
	check(Synergy.active([mat, enc]).is_empty(), "Mateira + Encantado: nenhuma")
	var two := Synergy.active([mat, dru])
	check(two.size() == 1 and two[0].id == N and two[0].tier == 0 and is_equal_approx(two[0].value, 0.10), "Mateira + Druida: Raízes (Natureza ×2, +10%)")
	check(Synergy.active([mat, mat]).is_empty(), "o mesmo herói duas vezes conta uma só")
	var all := Synergy.active([ica, mat, enc, dru])
	check(all.size() == 1 and all[0].id == N, "grupo dos 4: só Natureza liga (Terra e Água têm 1)")
	print("  ", Synergy.describe(all[0]))

	# no jogo: o grupo de 3 com Druida ganha os bônus
	var gs = root.get_node("GameState")
	gs.run_trial = {}
	gs.selected_hero = &"druida"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(20)
	var m = current_scene
	var p = m.get_node("Player")
	var hp0: int = p.stats.max_health
	var spd0: float = p.move_speed
	var a1 = load("res://game/scenes/player.tscn").instantiate()
	m.add_child(a1)
	a1.set_hero(mat)
	var a2 = load("res://game/scenes/player.tscn").instantiate()
	m.add_child(a2)
	a2.set_hero(enc)
	m.sim_allies = [a1, a2]
	m._apply_synergy()
	check(absi(p.stats.max_health - int(round(hp0 * 1.10))) <= 1, "Raízes: Druida com +10%% de vida (%d -> %d)" % [hp0, p.stats.max_health])
	check(is_equal_approx(p.move_speed, spd0), "sem Água ×2: velocidade igual")
	check(m._hud._synergy_row.visible and m._hud._synergy_row.get_child_count() == 1, "HUD mostra o selo de sinergia")

	# Provocação do tanque: bicho mais perto do Encantado, mas a Icamiaba a 5 m chama
	var tank = load("res://game/scenes/player.tscn").instantiate()
	m.add_child(tank)
	tank.set_hero(ica)
	check(is_equal_approx(tank.threat_radius, 4.0) and a2.threat_radius == 0.0, "só o tanque provoca (4 m)")
	var room = m.builder.rooms[m.layout.start_index]
	var c: Vector3 = room.center()
	p.global_position = c + Vector3(-12, 0.1, 0)
	a1.global_position = c + Vector3(-12, 0.1, 3)
	a2.global_position = c + Vector3(2, 0.1, 0)
	tank.global_position = c + Vector3(-3.5, 0.1, 0)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	var e = m._spawn(&"macaco_prego", room, c + Vector3(0, 0.1, 0))
	await _frames(1)
	check(e._nearest_hero() == tank, "bicho a 2 m do Encantado e 3,5 m da Icamiaba vai na Icamiaba")
	tank.global_position = c + Vector3(-6, 0.1, 0)
	await _frames(1)
	check(e._nearest_hero() == a2, "com a Icamiaba a 6 m, vai no mais perto")

	# Provocar (habilidade): só pega bichos a até 5 m
	var near_e = m._spawn(&"macaco_prego", room, tank.global_position + Vector3(0, 0, 3.0))
	var far_e = m._spawn(&"macaco_prego", room, tank.global_position + Vector3(0, 0, -7.5))
	await _frames(1)
	tank.kit._use_skill()
	check(near_e._forced_target_left > 0.0 and far_e._forced_target_left <= 0.0, "Provocar pega o bicho a 3 m e não o de 7,5 m")

	# levantar: Druida 2 s / 60%; os outros 5 s / 25%
	check(is_equal_approx(m.revive_time(p), 2.0) and is_equal_approx(m.revive_hp(p), 0.6), "Druida levanta em 2 s com 60%")
	check(is_equal_approx(m.revive_time(a1), 5.0) and is_equal_approx(m.revive_hp(a1), 0.25), "os outros: 5 s com 25%")
	# 3 levantadas por andar; a Druida não gasta
	m.lifts_used = 0
	m.use_lift(a1)
	m.use_lift(a1)
	m.use_lift(p)
	check(m.lifts_left() == 1, "2 levantadas gastas, a da Druida não conta")
	m.use_lift(a1)
	check(not m.can_lift(a1) and m.can_lift(p), "sem levantadas: só a Druida levanta")
	print("fim: ", "TUDO OK" if _fails == 0 else "COM FALHAS")
	quit(0 if _fails == 0 else 1)
