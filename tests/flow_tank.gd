extends SceneTree
## Poderes do tanque (Icamiaba) numa masmorra de verdade: Provocar, Muralha de Casco, Muiraquitã e Revide.
## Rodar: godot --headless --path . --script res://tests/flow_tank.gd

var _f := 0
var _ok := true


func check(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		print("FALHOU: ", label)
	else:
		print("ok: ", label)


func _process(_d: float) -> bool:
	if _f == 0:
		root.get_node("GameState").selected_hero = &"icamiaba"
		change_scene_to_file("res://game/scenes/main.tscn")
	_f += 1
	if _f < 5:
		return false
	var main = current_scene
	var player = main.get_node("Player")
	var kit = player.kit
	check(kit.get_script().get_global_name() == &"TankKit", "Icamiaba tem o kit de tanque")
	check(player.health.death_save, "Muiraquitã ativo no começo do andar")

	# Provocar: o inimigo perto para de recuar e bate mais fraco; a habilidade entra em recarga.
	var E = load("res://game/scripts/gameplay/enemy.gd")
	var room = main.builder.rooms[main.layout.start_index]
	var enemy = main._spawn(&"queixada", room, player.global_position + Vector3(3, 0.1, 0))
	enemy._set_tactic(E.Tactic.BACK_OFF)
	var dmg_before: float = enemy.damage_multiplier
	check(kit.try_skill(), "Provocar funciona")
	check(enemy.is_provoked() and enemy.tactic == E.Tactic.PRESS, "inimigo provocado avança")
	check(is_equal_approx(enemy.damage_multiplier, dmg_before * enemy.PROVOKE_DAMAGE), "provocado bate 25% mais fraco")
	enemy._set_tactic(E.Tactic.BACK_OFF)
	check(enemy.tactic == E.Tactic.PRESS, "provocado não recua")
	check(not kit.try_skill() and kit.skill_cooldown_ratio() > 0.9, "Provocar entra em recarga")
	enemy._physics_process(kit.PROVOKE_TIME + 0.1)
	check(not enemy.is_provoked() and is_equal_approx(enemy.damage_multiplier, dmg_before), "efeito acaba e o dano volta ao normal")
	enemy.queue_free()

	# Ultimate: carrega com abates; Muralha segura até mega magia; acaba no tempo.
	check(not kit.try_ultimate(), "ultimate vazia não ativa")
	for i in 13:
		kit.on_kill(false)
	check(kit.ultimate_ready(), "13 abates enchem a ultimate (%d%%)" % int(kit.charge))
	check(kit.try_ultimate() and player.health.wall_active and kit.charge == 0.0, "Muralha de Casco ativa e gasta a carga")
	var hp: int = player.health.health
	player.receive_attack(9999, 0, 0.0, 0, player.global_position, true)
	check(player.health.health == hp, "Muralha segura a mega magia")
	kit._process(kit.WALL_TIME + 0.1)
	check(not player.health.wall_active, "Muralha acaba depois de %ds" % kit.WALL_TIME)

	# Revide: depois de bloquear, o próximo golpe causa +50%.
	kit.on_blocked()
	check(kit.modify_outgoing(100) == 150, "Revide: +50% no próximo golpe")
	kit.on_attack_done()
	check(kit.modify_outgoing(100) == 100, "Revide gasto depois do golpe")

	# Muiraquitã: o primeiro golpe fatal deixa com 25% da vida; o segundo mata.
	player.health._invulnerable = 0.0
	player.receive_attack(999999, 0, 0.0, 0, player.global_position, true)
	check(not player.health.is_dead and player.health.health == int(round(player.health.max_health * 0.25)),
		"Muiraquitã salva do golpe fatal (vida %d)" % player.health.health)
	player.receive_attack(999999, 0, 0.0, 0, player.global_position, true)
	check(player.health.is_dead, "só salva uma vez por andar")
	main.debug_jump_to_floor(2)
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
	return false
