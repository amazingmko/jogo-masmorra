extends SceneTree
## Sem o escudo que regenera: só vida; sozinho a vida volta descansando, em grupo não;
## a proteção temporária aparece embaixo da vida; Pele de Pedra Verde liga abaixo de 30%.
##   godot --headless --fixed-fps 60 --path . --script res://tests/flow_sem_escudo.gd

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
	var gs = root.get_node("GameState")
	gs.run_trial = {}
	gs.selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(30)
	var m = current_scene
	var p = m.get_node("Player")
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	m._alive = 0
	check(p.health.max_armor == 0 and p.health.armor == 0, "sem escudo que regenera (max %d)" % p.health.max_armor)
	check(p.hero.max_health == 240, "Icamiaba: 240 de vida base (170 + 70% dos 100 de escudo)")
	check(not m._hud._armor_row.visible, "HUD: sem a barra azul")

	# sozinho: descansa e a vida volta
	p.health.health = p.health.max_health / 2
	p.health._since_hit = 0.0
	await _frames(120)
	var h1: int = p.health.health
	check(h1 == p.health.max_health / 2, "nos primeiros 6 s sem apanhar, nada volta")
	p.health._since_hit = 10.0
	await _frames(60)
	var gained: int = p.health.health - h1
	var expect := int(p.health.max_health * 0.03)
	check(gained >= expect - 2 and gained <= expect + 3, "sozinho, fora de luta: ~3%%/s (%d em 1 s, esperado %d)" % [gained, expect])

	# em grupo: não volta
	var a = load("res://game/scenes/player.tscn").instantiate()
	m.add_child(a)
	a.set_hero(root.get_node("ItemDB").get_hero(&"mateira"))
	m.sim_allies = [a]
	var h2: int = p.health.health
	p.health._since_hit = 10.0
	await _frames(60)
	check(p.health.health == h2, "em grupo, a vida não volta sozinha")
	m.sim_allies = []

	# proteção temporária
	p.health.add_bubble(40, 3.0)
	await _frames(2)
	check(m._hud._armor_row.visible and String(m._hud._health_bar.get_node("Texto").text).ends_with("+40"), "proteção aparece embaixo da vida (+40)")
	p.health.tick(3.5)
	await _frames(2)
	check(not m._hud._armor_row.visible, "e some quando acaba")

	# Pele de Pedra Verde abaixo de 30%
	p.profile = {}
	gs.progress(&"icamiaba")["talents"] = {"pele_pedra": 1}
	p.kit.queue_free()
	p.set_hero(p.hero)
	await _frames(2)
	p.health.health = int(p.health.max_health * 0.35)
	p.health._invulnerable = 0.0
	var red0: float = p.health.extra_reduction
	p.health.take_damage(int(p.health.max_health * 0.2), false, true)
	await _frames(2)
	check(p.health.extra_reduction > red0, "Pele de Pedra Verde liga quando a vida cai abaixo de 30%")
	print("fim: ", "TUDO OK" if _fails == 0 else "COM FALHAS")
	quit(0 if _fails == 0 else 1)
