extends SceneTree
## Teste multijogador (convidado).
var _ok := true

func say(t: String) -> void:
	print("[convidado] ", t)

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
	var net = root.get_node("Net")
	var gs = root.get_node("GameState")
	gs.selected_hero = &"encantado"
	gs.progress(&"encantado").level = 20
	await _wait(1.5)
	check(net.join("127.0.0.1") == "", "conectou no anfitrião")
	net.start_requested.connect(func(): change_scene_to_file("res://game/scenes/main.tscn"))
	var t0 := Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	await _wait(1.0)
	var m = current_scene
	check(m.name == "Main", "convidado na masmorra")
	check(m._replicas.size() == 1, "cópia do anfitrião criada")
	m._player.health.set_current(9999, 9999)
	m._player.health.max_health = 9999
	# anda um pouco para a cópia no anfitrião acompanhar
	m._player.touch_move = Vector2(1, 0)
	for i in 30:
		m._player.touch_move = Vector2(1, 0)
		await physics_frame
	m._player.touch_move = Vector2.ZERO
	# espera a onda (o anfitrião entra numa sala)
	t0 = Time.get_ticks_msec()
	while m._net_enemies.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	await _wait(4.0)
	var host_n := int(FileAccess.get_file_as_string(OS.get_environment("MPDIR") + "/host_enemies.txt"))
	check(m._net_enemies.size() > 0 and absi(m._net_enemies.size() - host_n) <= 1, "bonecos dos bichos chegaram (%d aqui, %d no anfitrião)" % [m._net_enemies.size(), host_n])
	var e = m._net_enemies.values()[0]
	var p0: Vector3 = e.global_position
	check(e.puppet, "bicho é boneco no convidado")
	# usa a habilidade (Espelho do Rio)
	m._player.touch_form = true
	await _wait(0.5)
	var hp0: int = m._player.health.health + m._player.health.armor
	await _wait(4.0)
	check(not is_instance_valid(e) or e.global_position.distance_to(p0) > 0.2 or e.state == 4, "boneco anda conforme o anfitrião")
	var hp1: int = m._player.health.health + m._player.health.armor
	check(hp1 < hp0 or m._player.health.is_dead, "o convidado levou dano dos bichos do anfitrião (%d -> %d)" % [hp0, hp1])
	# sala limpa no anfitrião -> bonecos morrem aqui, porta abre
	t0 = Time.get_ticks_msec()
	while not m._net_enemies.is_empty() and Time.get_ticks_msec() - t0 < 25000:
		await process_frame
	check(m._net_enemies.is_empty(), "bichos morreram aqui também")
	# portal do anfitrião leva para o andar 2
	t0 = Time.get_ticks_msec()
	while m.floor_number < 2 and Time.get_ticks_msec() - t0 < 12000:
		await process_frame
	await _wait(5.0)
	check(m.floor_number == 2, "convidado no andar 2")
	var host_layout := FileAccess.get_file_as_string(OS.get_environment("MPDIR") + "/host_layout.txt")
	var mine := str(m.layout.rooms.size()) + "|" + str(m.builder.rooms[0].global_position)
	check(host_layout == mine, "mesmo andar nos dois aparelhos (%s / %s)" % [host_layout, mine])
	m._player.health.death_save = false
	m._player.health.take_damage(999999, false, true)
	check(m._player.health.is_dead, "convidado caiu")
	t0 = Time.get_ticks_msec()
	while m._player.health.is_dead and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	check(not m._player.health.is_dead and m._player.controls_enabled, "foi levantado e pode jogar de novo")
	await _wait(1.0)
	say("fim: " + ("TUDO OK" if _ok else "COM FALHAS"))
	quit(0 if _ok else 1)
