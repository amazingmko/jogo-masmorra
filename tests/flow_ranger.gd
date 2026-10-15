extends SceneTree
## Poderes da Mateira numa masmorra de verdade: Armadilha de Cipó, Chamado da Harpia,
## Olho de Caçadora e Rastro Leve. Rodar: godot --headless --path . --script res://tests/flow_ranger.gd

var _f := 0
var _ok := true
var _main
var _player
var _kit
var _enemy
var _hp_before := 0
var _shot_at := 0
var _shot_seen := -1


func check(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		print("FALHOU: ", label)
	else:
		print("ok: ", label)


func _process(_d: float) -> bool:
	if _f == 0:
		root.get_node("GameState").selected_hero = &"mateira"
		change_scene_to_file("res://game/scenes/main.tscn")
	_f += 1
	if _f == 5:
		_main = current_scene
		_player = _main.get_node("Player")
		_kit = _player.kit
		check(_kit.get_script().get_global_name() == &"RangerKit", "Mateira tem o kit de ranger")
		# Armadilha à frente; um bicho parado em cima dela fica preso.
		var room = _main.builder.rooms[_main.layout.start_index]
		_player._facing = Vector3(1, 0, 0)
		check(_kit.try_skill(), "Armadilha de Cipó funciona")
		check(not _kit.try_skill(), "Armadilha entra em recarga")
		_enemy = _main._spawn(&"queixada", room, _player.global_position + Vector3(1.5, 0.1, 0))
	if _f == 12:
		check(_enemy._constrict_left > 0.0, "bicho que pisa na armadilha fica preso")
		# Olho de Caçadora: flecha com crítico extra só de longe.
		var p = load("res://game/scripts/gameplay/projectile.gd").new()
		_kit.modify_projectile(p)
		check(is_equal_approx(p.far_crit_bonus, 0.2) and p.far_distance == 6.0, "Olho de Caçadora: +20% de crítico de longe")
		p.free()
		# Rastro Leve.
		check(is_equal_approx(_kit.speed_factor(), 1.0), "sem abate, velocidade normal")
		_kit.on_kill(false)
		check(is_equal_approx(_kit.speed_factor(), 1.15), "depois de um abate, +15% de velocidade")
		_kit._process(2.1)
		check(is_equal_approx(_kit.speed_factor(), 1.0), "Rastro Leve acaba em 2 s")
		# Harpia: carrega e ataca sozinha.
		_kit.charge = 100.0
		_hp_before = _enemy.health.health
		_enemy._constrict_left = 10.0  # parado, para a harpia achar fácil
		check(_kit.try_ultimate(), "Chamado da Harpia funciona")
	if _f == 120:
		check(_enemy.health.health < _hp_before or not is_instance_valid(_enemy), "a harpia mergulhou e feriu o bicho")
		# Flecha sincronizada: não sai no toque, sai na soltura da corda (73% da animação).
		for p in get_nodes_in_group("player_projectiles"):
			p.free()
		_player._attack()
		_shot_at = Time.get_ticks_msec()
		check(get_nodes_in_group("player_projectiles").is_empty(), "a flecha não sai no instante do toque")
	if _f > 120 and _shot_seen < 0 and not get_nodes_in_group("player_projectiles").is_empty():
		_shot_seen = Time.get_ticks_msec() - _shot_at
	if _f == 200:
		var expected: float = _player.weapon_stats.cooldown() * 0.98 * 0.73 * 1000.0
		check(_shot_seen > 0 and absf(_shot_seen - expected) < 120.0, "a flecha sai na soltura (%d ms; esperado ~%d ms)" % [_shot_seen, int(expected)])
		check(not get_nodes_in_group("floor_effects").is_empty(), "armadilha/harpia ainda no andar")
		_main.debug_jump_to_floor(2)
	if _f == 205:
		check(get_nodes_in_group("floor_effects").is_empty(), "trocar de andar limpa armadilhas e a harpia")
		print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
		quit(0 if _ok else 1)
	return false
