extends SceneTree
## Teia no chão (Armadilha de Teia da Aranha): prende uma vez quando o herói pisa; parado dentro,
## depois de soltar, não prende de novo (dá para sair); se sair e pisar outra vez, prende de novo.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_teia_chao.gd

var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	root.get_node("GameState").selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(10)
	var m = current_scene
	var p = m.get_node("Player")
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	p.health.max_health = 99999
	p.health.health = 99999
	var room = m.builder.rooms[m.layout.start_index]
	var center: Vector3 = room.center() + Vector3(0, 0.1, 0)
	p.global_position = center
	var spider = load("res://game/data/enemies/aranha_caranguejeira.tres")
	var trap_attack = null
	for a in spider.attacks:
		if a.id == &"armadilha_teia":
			trap_attack = a
	var tg = load("res://game/scripts/combat/telegraph.gd").for_attack(trap_attack, center, Vector3.FORWARD, 1.0)
	m.add_child(tg)
	await _frames(int(trap_attack.windup * 60) + 5)
	check(p.status.is_rooted(), "pisou na teia: preso")
	await _frames(int(trap_attack.effect_duration * 60) + 30)
	check(not p.status.is_rooted(), "parado dentro da teia, depois de soltar: não prende de novo")
	p.global_position = center + Vector3(tg.radius + 1.0, 0, 0)
	await _frames(10)
	check(not p.status.is_rooted(), "saiu da teia: livre")
	p.global_position = center
	await _frames(3)
	check(p.status.is_rooted(), "pisou de novo: preso de novo")
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
