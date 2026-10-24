extends SceneTree
## Economia e regras novas, numa masmorra de verdade:
## - bicho comum deixa só ouro (nenhum reagente no chão); furioso às vezes deixa reagente;
##   o chefe deixa reagentes sempre;
## - proteção contra azar do troféu mais raro do chefe;
## - fabricar cobra ouro (e não deixa sem ouro); vender reagente dá ouro;
## - Sincronia de Poder: com o limite Comum, uma peça Lendária vale como Comum.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_economia.gd

var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


var _made := 0


## Quantos itens já caíram no chão (conta na hora em que nascem: o herói pode recolher logo).
func _pickups() -> int:
	return _made


func _on_node_added(n: Node) -> void:
	if n.get_script() != null and n.get_script().resource_path.ends_with("loot_pickup.gd"):
		_made += 1


func _kill(e) -> void:
	e.health.take_damage(99999999, false, true)


func _run() -> void:
	node_added.connect(_on_node_added)
	var gs = root.get_node("GameState")
	var db = root.get_node("ItemDB")
	gs.debug_clear_talents()
	gs.selected_hero = &"icamiaba"
	gs.run_difficulty = 0
	gs.run_full_rewards = true
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(14)
	var m = current_scene
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(3)
	for n in get_nodes_in_group("pickups"):
		n.queue_free()
	await _frames(2)
	_made = 0
	var room = m.builder.rooms[m.layout.start_index]

	# bichos comuns: só ouro
	var gold0: int = gs.coins
	for i in 20:
		var e = m._spawn(&"queixada", room, room.center() + Vector3(3, 0.1, float(i % 5) - 2.0))
		await _frames(1)
		_kill(e)
	await _frames(20)
	check(_pickups() == 0, "20 bichos comuns: nenhum reagente no chão (%d)" % _pickups())
	check(gs.coins - gold0 >= 20 * 4, "20 bichos comuns: ouro (%d)" % (gs.coins - gold0))

	# furiosos: às vezes reagente (12%)
	var with_loot := 0
	for i in 60:
		var before := _pickups()
		var e = m._spawn(&"queixada", room, room.center() + Vector3(-3, 0.1, float(i % 5) - 2.0), false, true)
		await _frames(1)
		_kill(e)
		await _frames(2)
		if _pickups() > before:
			with_loot += 1
	check(with_loot >= 1 and with_loot <= 20, "60 furiosos: %d deixaram reagente (perto de 12%%)" % with_loot)
	_made = 0

	# chefe: reagentes garantidos
	var boss = m._spawn(&"mapinguari", room, room.center() + Vector3(0, 0.1, 3))
	await _frames(2)
	_kill(boss)
	await _frames(30)
	check(_pickups() >= 3, "chefe deixa reagentes (%d no chão)" % _pickups())

	# proteção contra azar (Muiraquitã no Mítico)
	var table = db.get_drop_table(&"chefe_mapinguari")
	gs.boss_pity.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var given := false
	for i in 30:
		var extra: Array = gs.boss_pity_roll(table, 3, [], rng, true)
		if not extra.is_empty():
			given = true
			check(extra[0].item.id == &"muiraquita", "a ajuda dá o troféu mais raro (Muiraquitã)")
			break
	check(given, "proteção contra azar: Muiraquitã vem depois de várias vitórias sem ela")
	check(gs.boss_pity.is_empty(), "contador zera depois que vem")

	# fabricar cobra ouro; sem ouro não fabrica
	var recipe = db.get_recipe(&"lanca_ipe_comum")
	for id in recipe.ingredients:
		gs.inventory.add(db.get_item(StringName(id)), int(recipe.ingredients[id]) * 3)
	gs.coins = 5
	var r1: Dictionary = gs.craft(&"lanca_ipe_comum")
	check(not r1.ok and String(r1.reason).contains("ouro"), "sem ouro não fabrica (%s)" % r1.get("reason", ""))
	gs.coins = 1000
	var r2: Dictionary = gs.craft(&"lanca_ipe_comum")
	check(r2.ok and gs.coins == 1000 - Economy.craft_cost(recipe, db.catalog), "fabricar cobra %d de ouro (sobrou %d)" % [Economy.craft_cost(recipe, db.catalog), gs.coins])

	# vender reagente
	gs.inventory.add(db.get_item(&"madeira_lei"), 10)
	var c0: int = gs.coins
	var have: int = gs.inventory.count(&"madeira_lei")
	var got: int = gs.sell_material(&"madeira_lei", 10)
	check(got == 20 and gs.coins == c0 + 20 and gs.inventory.count(&"madeira_lei") == have - 10, "vender 10 Madeiras de Lei dá 20 de ouro")

	# Sincronia de Poder
	var helm = db.get_item(&"elmo_placa")
	var leg := ItemFactory.roll(helm, 16, 3, rng)
	var hero = db.get_hero(&"icamiaba")
	HeroStats.rarity_cap = 3
	var free = HeroStats.compute(hero, 10, {GameEnums.Slot.HEAD: leg}, db.catalog)
	HeroStats.rarity_cap = 0
	var synced = HeroStats.compute(hero, 10, {GameEnums.Slot.HEAD: leg}, db.catalog)
	HeroStats.rarity_cap = 3
	check(synced.armor < free.armor and synced.primary < free.primary, "Sincronia: Lendária vale como Comum (armadura %d -> %d)" % [free.armor, synced.armor])

	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	gs.debug_clear_talents()
	quit(0 if _ok else 1)
