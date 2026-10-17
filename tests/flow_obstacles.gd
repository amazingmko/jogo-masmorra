extends SceneTree
## Golpes e magias não atravessam obstáculos (pedra, tronco, sumaúma, borda da mata).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_obstacles.gd

var _f := 0
var _ok := true
var _main
var _player
var _dummy
var _hp := 0
var _php := 0
var _wall


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		root.get_node("GameState").selected_hero = &"icamiaba"
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f == 6:
		_main = current_scene
		_player = _main.get_node("Player")
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		var room = _main.builder.rooms[_main.layout.start_index]
		_player.global_position = room.center() + Vector3(0, 0.1, 0)
		# Uma "pedra" (caixa sólida) entre a heroína e o boneco.
		_wall = StaticBody3D.new()
		_wall.collision_layer = 1
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 2.0, 3.0)
		col.shape = box
		_wall.add_child(col)
		_main.add_child(_wall)
		_wall.global_position = room.center() + Vector3(1.0, 1.0, 0)
	if _f == 8:
		var room = _main.builder.rooms[_main.layout.start_index]
		_dummy = _main._spawn(&"queixada", room, room.center() + Vector3(2.0, 0.1, 0))
		_dummy.training_dummy = true
		_dummy._constrict_left = 999.0
		_dummy.health.max_health = 99999
		_dummy.health.health = 99999
	if _f == 10:
		_hp = _dummy.health.health
		_player._target = _dummy
		_player._facing = Vector3(1, 0, 0)
		_player._melee_swing()
		check(_dummy.health.health == _hp, "golpe de lança não atravessa a pedra")
		# Garra do inimigo (aviso no chão saindo dele) com a pedra no meio.
		_php = _player.health.health + _player.health.armor
		var t = load("res://game/scripts/combat/telegraph.gd").new()
		t.radius = 3.5
		t.duration = 0.1
		t.damage = 40
		t.blockable = true
		_main.add_child(t)
		t.global_position = _dummy.global_position
	if _f == 30:
		check(_player.health.health + _player.health.armor == _php, "garra do inimigo não atravessa a pedra")
		_wall.queue_free()
	if _f == 34:
		_player._melee_swing()
		check(_dummy.health.health < _hp, "sem a pedra, o golpe acerta")
		var t = load("res://game/scripts/combat/telegraph.gd").new()
		t.radius = 3.5
		t.duration = 0.1
		t.damage = 40
		t.blockable = true
		_main.add_child(t)
		t.global_position = _dummy.global_position
	if _f == 50:
		check(_player.health.health + _player.health.armor < _php, "sem a pedra, a garra acerta")
		print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
		quit(0 if _ok else 1)
	return false
