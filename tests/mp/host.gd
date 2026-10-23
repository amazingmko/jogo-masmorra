extends SceneTree
## Teste multijogador (anfitrião). Rodar junto com tests/mp/client.gd (ver tests/mp/rodar.sh).
var net
var log_lines := []
var _ok := true

func say(t: String) -> void:
	print("[host] ", t)
	log_lines.append(t)

func check(c: bool, label: String) -> void:
	_ok = _ok and c
	say(("ok: " if c else "FALHOU: ") + label)

func _initialize() -> void:
	_run.call_deferred()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await process_frame

func _run() -> void:
	net = root.get_node("Net")
	var gs = root.get_node("GameState")
	gs.selected_hero = &"icamiaba"
	gs.progress(&"icamiaba").level = 20
	check(net.host() == "", "criou a partida")
	var t0 := Time.get_ticks_msec()
	while net.players.size() < 2 and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	check(net.players.size() == 2, "o convidado entrou no saguão (%d jogadores)" % net.players.size())
	net.start_requested.connect(func(): change_scene_to_file("res://game/scenes/main.tscn"))
	net.start_run(0)
	await _wait(4.0)
	var m = current_scene
	check(m.name == "Main", "anfitrião na masmorra")
	m._player.health.set_current(99999, 99999)
	var clones := [0]
	node_added.connect(func(n): if n.get_script() and n.get_script().get_global_name() == &"WaterClone": clones[0] += 1)
	check(m._replicas.size() == 1, "cópia do herói do convidado criada")
	check(m._ready_peers.size() == 1, "convidado avisou que carregou")
	var rep = m._replicas.values()[0]
	check(rep.hero_id == &"encantado", "cópia tem o herói do convidado (%s)" % rep.hero_id)
	# o convidado anda: a cópia acompanha
	await _wait(2.0)
	var client_pos: Vector3 = rep.global_position
	say("cópia em %s" % client_pos)
	# sala de luta: leva os dois para dentro (o anfitrião entra; o convidado é puxado)
	var room = null
	for r in m.builder.rooms:
		if r.type == 1 and not r.is_den:  # COMBAT
			room = r
			break
	if room == null:
		for r in m.builder.rooms:
			if r.type != 0: room = r; break
	m._player.global_position = room.center() + Vector3(0, 0.1, 0)
	m._player.reset_physics_interpolation()
	await _wait(3.0)
	var alive := m.get_tree().get_nodes_in_group("enemies").size()
	check(alive > 0, "onda nasceu no anfitrião (%d bichos)" % alive)
	check(room._barriers.size() == 0 or room._barriers[0]._closed, "portas fecharam")
	var f := FileAccess.open(OS.get_environment("MPDIR") + "/host_enemies.txt", FileAccess.WRITE)
	f.store_string(str(alive))
	f.close()
	# deixa os bichos baterem um pouco (no convidado, que foi puxado para dentro)
	await _wait(5.0)
	check(clones[0] > 0, "a habilidade do convidado (Espelho) apareceu no anfitrião (%d)" % clones[0])
	# limpa a sala
	for k in 8:  # a sala pode ter ondas extras
		for e in m.get_tree().get_nodes_in_group("enemies"):
			e.health.take_damage(999999, false, true)
		await _wait(2.5)
		if room.cleared:
			break
	check(room.cleared, "sala limpa no anfitrião")
	# portal: próximo andar para todos
	var portal = null
	for p in m.builder.props.values():
		if p.kind == 2: portal = p
	say("portal %s run_over %s changing %s" % [portal, m._run_over, m._changing_floor])
	portal.activate()
	await _wait(4.0)
	say("depois: andar %d run_over %s changing %s" % [m.floor_number, m._run_over, m._changing_floor])
	check(m.floor_number == 2, "anfitrião no andar 2")
	var sig := ""
	for r in m.builder.rooms:
		sig += "%d,%d;" % [r.cell.x if "cell" in r else 0, r.type]
	var f2 := FileAccess.open(OS.get_environment("MPDIR") + "/host_layout.txt", FileAccess.WRITE)
	f2.store_string(str(m.layout.rooms.size()) + "|" + str(m.builder.rooms[0].global_position))
	f2.close()
	# levantar parceiro: o convidado cai; o anfitrião fica perto dele
	var t1 := Time.get_ticks_msec()
	while not rep.health.is_dead and Time.get_ticks_msec() - t1 < 15000:
		await process_frame
	check(rep.health.is_dead, "a cópia mostra o convidado caído")
	var any_down: bool = m._run_over
	check(not any_down, "a run continua com um de pé")
	m._player.global_position = rep.global_position + Vector3(0.8, 0.1, 0)
	m._player.reset_physics_interpolation()
	t1 = Time.get_ticks_msec()
	while rep.health.is_dead and Time.get_ticks_msec() - t1 < 8000:
		m._player.global_position = rep.global_position + Vector3(0.8, 0.1, 0)
		await process_frame
	check(not rep.health.is_dead, "convidado levantado pelo anfitrião")
	await _wait(3.0)
	say("fim: " + ("TUDO OK" if _ok else "COM FALHAS"))
	quit(0 if _ok else 1)
