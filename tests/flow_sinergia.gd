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
	check(ica.elemental_styles() == [E, W] and dru.elemental_styles() == [N, W], "estilos: Icamiaba Terra+Água, Druida Natureza+Água")
	check(Synergy.active([ica]).is_empty(), "sozinho: nenhuma sinergia")
	check(Synergy.active([mat, enc]).is_empty(), "Mateira + Encantado: nenhuma")
	var two := Synergy.active([enc, dru])
	check(two.size() == 1 and two[0].id == W and two[0].tier == 0, "Encantado + Druida: Correnteza (Água ×2)")
	check(Synergy.active([enc, enc]).is_empty(), "o mesmo herói duas vezes conta uma só")
	var all := Synergy.active([ica, mat, enc, dru])
	var ids := all.map(func(x): return x.id)
	check(ids.has(W) and ids.has(N) and not ids.has(E), "grupo dos 4: Água e Natureza ligadas (Terra só tem 1)")
	var water: Dictionary = all.filter(func(x): return x.id == W)[0]
	check(water.heroes == 3 and is_equal_approx(water.value, 0.12), "Água ×3: +12%")
	print("  ", Synergy.describe(water))

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
	check(p.stats.max_health == int(round(hp0 * 1.10)), "Raízes: Druida com +10%% de vida (%d -> %d)" % [hp0, p.stats.max_health])
	check(is_equal_approx(p.move_speed, spd0 * 1.08), "Correnteza: +8% de velocidade")
	check(m._hud._synergy_row.visible and m._hud._synergy_row.get_child_count() == 2, "HUD mostra os 2 selos de sinergia")

	# Provocação do tanque: bicho mais perto do Encantado, mas a Icamiaba a 5 m chama
	var tank = load("res://game/scenes/player.tscn").instantiate()
	m.add_child(tank)
	tank.set_hero(ica)
	check(is_equal_approx(tank.threat_radius, 6.0) and a2.threat_radius == 0.0, "só o tanque provoca")
	var room = m.builder.rooms[m.layout.start_index]
	var c: Vector3 = room.center()
	p.global_position = c + Vector3(-12, 0.1, 0)
	a1.global_position = c + Vector3(-12, 0.1, 3)
	a2.global_position = c + Vector3(2, 0.1, 0)
	tank.global_position = c + Vector3(-5, 0.1, 0)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	var e = m._spawn(&"macaco_prego", room, c + Vector3(0, 0.1, 0))
	await _frames(1)
	check(e._nearest_hero() == tank, "bicho a 2 m do Encantado e 5 m da Icamiaba vai na Icamiaba")
	tank.global_position = c + Vector3(-9, 0.1, 0)
	await _frames(1)
	check(e._nearest_hero() == a2, "com a Icamiaba a 9 m, vai no mais perto")

	# levantar: Druida 2 s / 60%; os outros 5 s / 25%
	check(is_equal_approx(m.revive_time(p), 2.0) and is_equal_approx(m.revive_hp(p), 0.6), "Druida levanta em 2 s com 60%")
	check(is_equal_approx(m.revive_time(a1), 5.0) and is_equal_approx(m.revive_hp(a1), 0.25), "os outros: 5 s com 25%")
	print("fim: ", "TUDO OK" if _fails == 0 else "COM FALHAS")
	quit(0 if _fails == 0 else 1)
