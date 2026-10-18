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
var _target
var _last_hp := 99999
var _hit_frames := 0
var _np := 0
var _spawned := 0


func _hits_count() -> int:
	return _hit_frames


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
		check(not is_instance_valid(_enemy) or _enemy.health.health < _hp_before, "a harpia mergulhou e feriu o bicho")
		# Flecha sincronizada: não sai no toque, sai na soltura da corda (73% da animação).
		for p in get_nodes_in_group("player_projectiles"):
			p.free()
		_player._attack()
		_shot_at = _f
		check(get_nodes_in_group("player_projectiles").is_empty(), "a flecha não sai no instante do toque")
	if _f > 120 and _shot_seen < 0 and not get_nodes_in_group("player_projectiles").is_empty():
		_shot_seen = int((_f - _shot_at) * 1000.0 / 60.0)  # tempo de jogo (--fixed-fps 60), não do relógio
	if _f == 200:
		var expected: float = _player.weapon_stats.cooldown() * 0.98 * 0.73 * 1000.0
		check(_shot_seen > 0 and absf(_shot_seen - expected) < 120.0, "a flecha sai na soltura (%d ms; esperado ~%d ms)" % [_shot_seen, int(expected)])
		check(not get_nodes_in_group("floor_effects").is_empty(), "armadilha/harpia ainda no andar")
		_main.debug_jump_to_floor(2)
	if _f == 205:
		check(get_nodes_in_group("floor_effects").is_empty(), "trocar de andar limpa armadilhas e a harpia")
		# Pontaria: alvo parado a 8 m; a flecha sai da mão (de lado do corpo) e precisa acertar.
		var room = _main.builder.rooms[_main.layout.start_index]
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		_player.global_position = room.center() + Vector3(4, 0.1, 0)
		_target = _main._spawn(&"formiga_fogo", room, room.center() + Vector3(-4, 0.1, 1.5))
		_target._constrict_left = 999.0  # parado (preso), mas ainda no mundo físico
		_target._dodge_cd = 999.0  # sem esquivar: o teste é de pontaria
		_target.health.damaged.connect(func(_a: int) -> void: _hit_frames += 1)
		_target.health.max_health = 99999
		_target.health.health = 99999
	if _f in [230, 290, 350] and is_instance_valid(_target):
		_target._dodge_cd = 999.0
		_player._target = _target
		var to: Vector3 = _target.global_position - _player.global_position
		to.y = 0.0
		_player._facing = to.normalized()
		_player._attack()
	if _f > 230:
		var flying := get_nodes_in_group("player_projectiles").size()
		if flying > _np:
			_spawned += flying - _np
		_np = flying
		if (_spawned >= 3 and flying == 0) or _f > 3000:
			check(_hits_count() >= 3, "acerta o alvo parado nas 3 flechas (%d de 3)" % _hits_count())
			print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
			quit(0 if _ok else 1)
	return false
