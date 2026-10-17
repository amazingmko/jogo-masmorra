extends SceneTree
## Flechas e magias não atravessam obstáculos de verdade do mapa (pedra com musgo, tronco caído,
## sumaúma). Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_obstacles_arco.gd

var _f := 0
var _ok := true
var _main
var _player
var _dummy
var _hp := 0
var _php := 0
var _case := 0
const CASES := ["pedra_musgo", "tronco_caido", "sumauma", "nenhum"]  # o último: sem obstáculo (tem que acertar)


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		root.get_node("GameState").selected_hero = &"mateira"
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f == 6:
		_main = current_scene
		_player = _main.get_node("Player")
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
	var base := 10 + _case * 60
	if _case < CASES.size() and _f == base:
		var room = _main.builder.rooms[_main.layout.start_index]
		for n in room.get_children():
			if n.name.begins_with("Obstaculo"):
				n.queue_free()
		_player.global_position = room.center() + Vector3(-4, 0.1, 0)
		var rd = load("res://game/scripts/dungeon/room_decor.gd")
		var kind: String = CASES[_case]
		var holder := Node3D.new()
		holder.name = "Obstaculo%d" % _case
		room.add_child(holder)
		if kind == "nenhum":
			pass
		elif kind == "sumauma":
			# pilar: caixa de colisão 1,2 x 2 x 1,2 (como na sala)
			var pillar = load("res://game/scripts/dungeon/dungeon_builder.gd").box(holder, Vector3(1.2, 2.0, 1.2), Vector3(0, 1.0, 0), null)
			rd.trunk(holder, Vector3.ZERO, RandomNumberGenerator.new())
		else:
			var size := Vector3(1.2, 1.0, 1.2) if kind == "pedra_musgo" else Vector3(2.6, 0.7, 0.8)
			var xf := Transform3D(Basis(Vector3.UP, PI * 0.5) if kind == "tronco_caido" else Basis(), Vector3.ZERO)
			rd._solid(holder, kind, xf, size)
		holder.position = Vector3(-1.0, 0, 0)
		_dummy = _main._spawn(&"queixada", room, room.center() + Vector3(1.5, 0.1, 0))
		_dummy.training_dummy = true
		_dummy._constrict_left = 999.0
		_dummy.health.max_health = 99999
		_dummy.health.health = 99999
	if _case < CASES.size() and _f == base + 4:
		_hp = _dummy.health.health
		_player._target = _dummy
		_player._attack_target = _dummy
		_player._facing = Vector3(1, 0, 0)
		_player._release_shot()
	if _case < CASES.size() and _f == base + 6:
		# Disparo de inimigo (pedrada) vindo do outro lado do obstáculo.
		_php = _player.health.health + _player.health.armor
		_player.health._invulnerable = 0.0
		var e = load("res://game/scripts/combat/enemy_projectile.gd").new()
		e.direction = Vector3(-1, 0, 0)
		e.damage = 30
		_main.add_child(e)
		e.global_position = _dummy.global_position + Vector3(-0.8, 0.9, 0)
	if _case < CASES.size() and _f == base + 50:
		if CASES[_case] == "nenhum":
			check(_dummy.health.health < _hp, "sem obstáculo, a flecha acerta")
			check(_player.health.health + _player.health.armor < _php, "sem obstáculo, a pedrada acerta")
		else:
			check(_dummy.health.health == _hp, "flecha não atravessa %s" % CASES[_case])
			check(_player.health.health + _player.health.armor == _php, "pedrada do inimigo não atravessa %s" % CASES[_case])
		_dummy.queue_free()
		_case += 1
		if _case >= CASES.size():
			print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
			quit(0 if _ok else 1)
	return false
