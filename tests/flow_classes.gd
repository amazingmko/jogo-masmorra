extends SceneTree
## Poderes do Encantado e da Druida numa masmorra de verdade.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_classes.gd

var _f := 0
var _ok := true
var _main
var _player
var _kit
var _gs
var _db
var _a
var _b
var _hp := 0
var _pos := Vector3.ZERO
var _np := 0
var _wall_dir := Vector3.RIGHT


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _dummy(offset: Vector3):
	var room = _main.builder.rooms[_main.layout.start_index]
	var e = _main._spawn(&"queixada", room, _player.global_position + offset)
	e.training_dummy = true
	e.damage_multiplier = 0.0
	e.health.max_health = 99999
	e.health.health = 99999
	return e


func _clear() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	for e in get_nodes_in_group("floor_effects"):
		e.queue_free()


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_gs = root.get_node("GameState")
		_db = root.get_node("ItemDB")
		_gs.selected_hero = &"encantado"
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f == 6:
		_main = current_scene
		_player = _main.get_node("Player")
		_kit = _player.kit
		check(_kit.get_script().get_global_name() == &"MageKit", "Encantado tem o kit de mago")
		_clear()
		var room = _main.builder.rooms[_main.layout.start_index]
		_player.global_position = room.center() + Vector3(0, 0.1, 0)
	if _f == 8:
		_a = _dummy(Vector3(-4, 0.1, 0))
		_a._constrict_left = 999.0
	if _f == 10:
		# Encharcar: o disparo deixa encharcado.
		_player._target = _a
		_player._facing = Vector3(-1, 0, 0)
		_player._release_shot()
	if _f == 40:
		check(_a.is_soaked(), "Encharcar: o disparo deixa o inimigo encharcado")
		# Espelho do Rio: teletransporte e cópia de água.
		_pos = _player.global_position
		_player._facing = Vector3(1, 0, 0)
		check(_kit.try_skill(), "Espelho do Rio funciona")
		var moved: float = _player.global_position.distance_to(_pos)
		check(moved > 3.5 and moved <= 5.1, "Espelho do Rio: teletransportou %.1f m" % moved)
		var clones := get_nodes_in_group("floor_effects").filter(func(n): return n.get_script().get_global_name() == &"WaterClone")
		check(clones.size() == 1, "Espelho do Rio: deixou a cópia de água no lugar")
		_b = _dummy(_pos - _player.global_position + Vector3(0, 0.1, 0))
		_b._constrict_left = 999.0
		_hp = _b.health.health
	if _f == 50:
		check(_b.health.health < _hp and _b.is_soaked(), "a cópia explode quando o inimigo encosta (e encharca)")
		# Ricochete: o 5º disparo quica.
		_kit._shots = 4
		var p = load("res://game/scripts/gameplay/projectile.gd").new()
		_kit.modify_projectile(p)
		check(p.bounces == 2, "Ricochete: a cada 4 disparos, o seguinte quica em 2")
		p.free()
		# Pororoca contra a parede.
		_clear()
		var room = _main.builder.rooms[_main.layout.start_index]
		# Um lado da sala sem porta (senão o inimigo voa pelo vão e não bate em nada).
		_wall_dir = Vector3(1, 0, 0)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if not room._door_dirs.has(d):
				_wall_dir = Vector3(d.x, 0, d.y)
				break
		_player.global_position = room.center() - _wall_dir * 3.0 + Vector3(0, 0.1, 0)
		_player._facing = _wall_dir
	if _f == 55:
		_a = _dummy(_wall_dir * 4.0 + Vector3(0, 0.1, 0))  # entre ela e a parede
		_a.soak(10.0)
		_a.stun(0.4)  # parado onde foi posto (andando até ela, às vezes a onda não o levava até a parede)
		_hp = _a.health.health
		_kit.charge = 100.0
		check(_kit.try_ultimate(), "Pororoca funciona")
	if _f == 130:
		check(_a.health.health < _hp - 40 and _a._slam_damage > 0, "Pororoca: a onda pega e joga o inimigo (%d de dano)" % (_hp - _a.health.health))
		check(_a._slam_left <= 0.0 and _a._slam_damage > 0 and _hp - _a.health.health > 300, "Pororoca: bateu na parede e levou o dano dobrado de encharcado (%d no total)" % (_hp - _a.health.health))
		# Druida.
		_clear()
		_gs.selected_hero = &"druida"
		_player.set_hero(_db.get_hero(&"druida"))
		_kit = _player.kit
		_player.start_floor()
	if _f == 135:
		check(_kit.get_script().get_global_name() == &"DruidKit", "Druida tem o kit dela")
		check(_player.weapon_stats.is_ranged() and _player.form == 0, "Druida luta em forma humana, de longe (Cajado de Raiz)")
		_a = _dummy(Vector3(4.0, 0.1, 0))
		_a._constrict_left = 999.0
		_player._target = _a
		_player._facing = Vector3(1, 0, 0)
		_player._release_shot()
	if _f == 175:
		check(_kit.seeds().size() >= 1, "Semente: o disparo plantou uma muda (%d)" % _kit.seeds().size())
		_hp = _a.health.health
		_player.health.health = 100
		check(_kit.try_skill(), "Florescer funciona")
		check(_kit.seeds().is_empty(), "Florescer: as mudas abriram")
		check(_a.health.health < _hp, "Florescer: a flor machucou o inimigo em volta")
		check(not _kit.try_skill(), "Florescer tem recarga")
		var ws: float = _player.weapon_stats.attack_speed
		_kit.charge = 100.0
		check(_kit.try_ultimate(), "Despertar do Boto funciona")
		check(_kit.is_boto() and is_instance_valid(_kit._boto), "Boto: aparece a bolha com o boto")
		check(_player._model == null or not _player._model.visible, "Boto: o modelo da Druida some")
		check(_player.weapon_stats.attack_speed > ws * 1.5, "Boto: o Canto sai mais rápido")
		check(is_equal_approx(_kit.speed_factor(), 1.25), "Boto: anda 25% mais rápido")
		_player.receive_attack(1, 2, 2.0, 0, Vector3.ZERO)
		check(not _player.status.is_rooted(), "Boto: imune a raízes")
		_player._target = _a
		_player.health.health = 100
		_hp = _a.health.health
		_player._release_shot()
	if _f == 205:
		check(_a.health.health < _hp, "Canto: acertou o inimigo")
		check(_player.health.health > 100, "Canto: cada acerto cura")
		_kit._plant(_player.global_position + Vector3(1, 0, 0))
		_kit._boto_left = 0.01
	if _f == 210:
		check(not _kit.is_boto() and _player.weapon_stats.attack_speed < 2.0, "fim do Boto: volta a Druida com o Cajado")
		check(_player._model == null or _player._model.visible, "fim do Boto: o modelo volta")
		check(_kit.seeds().is_empty(), "fim do Boto: as mudas florescem")
		_a._awake = true
		_pos = _player.global_position
	if _f > 210 and _f < 300:
		# Rastro de Seiva: andando em luta (8 m), planta mudas sozinha
		_player.global_position = _pos + Vector3(0, 0, 0.1 * (_f - 210))
	if _f == 300:
		check(_kit.seeds().size() >= 2, "Rastro de Seiva: andando 9 m em luta plantou %d mudas" % _kit.seeds().size())
		print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
		quit(0 if _ok else 1)
	return false
