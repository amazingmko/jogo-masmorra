extends SceneTree
## Testes automáticos das regras do jogo (sem abrir a janela).
## Rodar:  godot --headless --path . --script res://tests/run_tests.gd
## Termina com código 0 se tudo passou, 1 se algo falhou.

var _failures := 0
var _passes := 0
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var catalog := ItemCatalog.new()
	catalog.load_all()

	_test_catalog(catalog)
	_test_elements()
	_test_drops(catalog)
	_test_inventory(catalog)
	_test_crafting(catalog)
	_test_professions(catalog)
	_test_save_file()
	_test_health()
	_test_damage(catalog)
	_test_dungeon_layout()
	_test_items_and_stats(catalog)
	_test_progression()
	_test_telegraphs_and_status(catalog)

	print("\n%d verificações passaram, %d falharam." % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
	return true


func check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		print("FALHOU: " + label)


func _test_catalog(catalog: ItemCatalog) -> void:
	check(catalog.items.size() >= 9, "catálogo carrega os itens")
	check(catalog.validate().is_empty(), "todos os ids citados existem: %s" % [catalog.validate()])


func _test_elements() -> void:
	var E := GameEnums.Element
	check(is_equal_approx(GameEnums.element_multiplier(E.FIRE, E.NATURE), 1.3), "fogo vence natureza (+30%)")
	check(is_equal_approx(GameEnums.element_multiplier(E.NATURE, E.FIRE), 1.0), "natureza não vence fogo")
	check(is_equal_approx(GameEnums.element_multiplier(E.NEUTRAL, E.WATER), 1.0), "neutro sem bônus")


func _test_drops(catalog: ItemCatalog) -> void:
	var table := catalog.get_drop_table(&"esqueleto")
	# Mesma semente -> mesmo resultado (importante para reproduzir bugs).
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	var same := true
	for i in 50:
		if table.roll(a) != table.roll(b):
			same = false
	check(same, "drop com a mesma semente é reproduzível")

	# Em 10 mil sorteios, a taxa de "nada" deve ficar perto de 30/112.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var empty := 0
	var n := 10000
	for i in n:
		if table.roll(rng).is_empty():
			empty += 1
	var expected := 30.0 / 112.0
	check(absf(float(empty) / n - expected) < 0.02, "taxa de drop vazio ~%.2f (obtido %.3f)" % [expected, float(empty) / n])

	# Chefe sorteia 3 vezes e nunca vem vazio.
	var boss := catalog.get_drop_table(&"chefe_rei_ossudo")
	var never_empty := true
	for i in 200:
		if boss.roll(rng).is_empty():
			never_empty = false
	check(never_empty, "chefe sempre deixa loot")


func _test_inventory(catalog: ItemCatalog) -> void:
	var inv := Inventory.new()
	inv.add(catalog.get_item(&"minerio_ferro"), 3)
	inv.add(catalog.get_item(&"minerio_ferro"), 2)
	check(inv.count(&"minerio_ferro") == 5, "materiais empilham")
	inv.add(catalog.get_item(&"espada_ferro"), 2)
	check(inv.equipment.size() == 2 and inv.equipment[0].uid != inv.equipment[1].uid, "equipamentos ficam separados com uid próprio")
	check(not inv.remove_all({"minerio_ferro": 9}), "não remove se faltar")
	check(inv.count(&"minerio_ferro") == 5, "tentativa falha não consome nada")
	check(inv.remove_all({"minerio_ferro": 5, "espada_ferro": 1}), "remove material e equipamento")
	check(inv.count(&"minerio_ferro") == 0 and inv.equipment.size() == 1, "quantidades certas depois de remover")

	var copy := Inventory.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	check(copy.equipment.size() == 1 and copy.count(&"espada_ferro") == 1, "inventário sobrevive à ida e volta em JSON")
	copy.add(catalog.get_item(&"espada_ferro"), 1)
	check(copy.equipment[0].uid != copy.equipment[1].uid, "uid continua único depois de carregar")


func _test_crafting(catalog: ItemCatalog) -> void:
	var inv := Inventory.new()
	var prof := ProfessionProgress.new()
	var recipe := catalog.get_recipe(&"forjar_espada_ferro")
	var r := Crafting.craft(recipe, inv, prof, catalog)
	check(not r.ok, "não forja sem ingredientes")
	inv.add(catalog.get_item(&"minerio_ferro"), 6)
	inv.add(catalog.get_item(&"fragmento_osso"), 2)
	r = Crafting.craft(recipe, inv, prof, catalog)
	check(r.ok, "forja com ingredientes: %s" % r.reason)
	check(inv.count(&"espada_ferro") == 1, "espada entra no inventário")
	check(inv.count(&"minerio_ferro") == 1 and inv.count(&"fragmento_osso") == 0, "ingredientes consumidos")
	check(prof.xp_of(&"ferreiro") == 40, "ferreiro ganha XP")

	var locked := RecipeData.new()
	locked.id = &"teste"
	locked.result_item_id = &"espada_ferro"
	locked.profession_id = &"ferreiro"
	locked.required_level = 5
	check(Crafting.check(locked, inv, prof).begins_with("Precisa de nível"), "receita bloqueada por nível de profissão")


func _test_professions(catalog: ItemCatalog) -> void:
	var smith := catalog.get_profession(&"ferreiro")
	check(smith.xp_to_next(1) == 100 and smith.xp_to_next(2) == 115, "curva de XP cresce 15% por nível")
	var prof := ProfessionProgress.new()
	prof.add_xp(smith, 230)
	check(prof.level_of(&"ferreiro") == 3 and prof.xp_of(&"ferreiro") == 15, "sobe vários níveis e guarda a sobra")


func _test_save_file() -> void:
	var path := "user://teste_save.json"
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	check(SaveFile.read(path).is_empty(), "sem save devolve vazio")
	check(SaveFile.write(path, {"coins": 10}) == OK, "primeira gravação")
	check(SaveFile.write(path, {"coins": 20}) == OK, "segunda gravação")
	check(int(SaveFile.read(path).get("coins", -1)) == 20, "lê o save mais recente")
	check(int(SaveFile.read(path).get("save_version", 0)) == SaveFile.CURRENT_VERSION, "save tem versão")

	# Simula save corrompido (app morreu no meio da escrita de outro jeito).
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ isso não é json")
	f.close()
	check(int(SaveFile.read(path).get("coins", -1)) == 10, "save corrompido recupera do backup")

	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _test_health() -> void:
	var h := Health.new()
	h.max_health = 5
	h.max_armor = 2
	h.armor_regen_delay = 4.0
	h.armor_regen_interval = 1.0
	h.reset()
	h.take_damage(3)
	check(h.armor == 0 and h.health == 4, "armadura absorve antes da vida")
	h.tick(3.9)
	check(h.armor == 0, "armadura não volta antes do tempo")
	h.tick(1.2)
	check(h.armor == 1, "armadura volta 1 ponto depois de 4s + 1s")
	var died := [false]
	h.died.connect(func() -> void: died[0] = true)
	h.take_damage(10)
	check(h.is_dead and h.health == 0 and died[0], "morre e avisa")
	check(h.take_damage(1) == 0, "morto não toma mais dano")

	var inv := Health.new()
	inv.max_health = 5
	inv.invulnerability_time = 0.6
	inv.reset()
	inv.take_damage(1)
	check(inv.take_damage(1) == 0, "invencível logo depois de apanhar")
	inv.tick(0.7)
	check(inv.take_damage(1) == 1, "volta a tomar dano depois da invencibilidade")
	h.free()
	inv.free()


func _test_damage(catalog: ItemCatalog) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var E := GameEnums.Element
	var normal := Damage.roll(10, E.NEUTRAL, E.NEUTRAL, 0.0, rng)
	check(normal.amount == 10 and not normal.crit, "dano base sem crítico")
	var elemental := Damage.roll(10, E.FIRE, E.NATURE, 0.0, rng)
	check(elemental.amount == 13, "fogo contra natureza dá +30%")
	var crit := Damage.roll(10, E.NEUTRAL, E.NEUTRAL, 1.0, rng)
	check(crit.crit and crit.amount == 20, "crítico dobra o dano")

	var sword := WeaponStats.from_item(catalog.get_item(&"espada_ferro"))
	var bow := WeaponStats.from_item(catalog.get_item(&"arco_simples"))
	check(not sword.is_ranged() and bow.is_ranged(), "espada é corpo a corpo, arco dispara")
	check(is_equal_approx(sword.cooldown(), 0.5), "espada ataca 2x por segundo")
	check(catalog.enemies.size() >= 3, "inimigos carregados")


func _test_dungeon_layout() -> void:
	var T := DungeonLayout.RoomType
	var all_ok := true
	for seed in range(1, 201):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var boss := seed % 5 == 0
		var size := 6 + seed % 3
		var layout := DungeonLayout.new()
		layout.generate(rng, size, boss)
		var cells := {}
		var counts := {}
		for r in layout.rooms:
			cells[r.cell] = true
			counts[r.type] = counts.get(r.type, 0) + 1
			for n in r.links:
				var d: Vector2i = layout.rooms[n].cell - r.cell
				if absi(d.x) + absi(d.y) != 1:
					all_ok = false  # ligação entre salas não vizinhas
		var reach_all := true
		for i in layout.room_count():
			if layout.path(layout.start_index, i).is_empty():
				reach_all = false
		var goal_type := T.BOSS if boss else T.EXIT
		var deepest := true
		for r in layout.rooms:
			if r.depth > layout.rooms[layout.goal_index].depth:
				deepest = false
		if layout.room_count() != size or cells.size() != size or not reach_all \
				or counts.get(T.START, 0) != 1 or counts.get(goal_type, 0) != 1 \
				or counts.get(T.TREASURE, 0) < 1 or not deepest:
			all_ok = false
			print("  planta inválida com semente %d" % seed)
	check(all_ok, "200 plantas: todas conectadas, sem salas repetidas, 1 início, 1 objetivo no ponto mais fundo, baú presente")

	var a := DungeonLayout.new()
	var b := DungeonLayout.new()
	var ra := RandomNumberGenerator.new()
	var rb := RandomNumberGenerator.new()
	ra.seed = 99
	rb.seed = 99
	a.generate(ra, 8, true)
	b.generate(rb, 8, true)
	var same := a.room_count() == b.room_count()
	for i in a.room_count():
		if a.rooms[i].cell != b.rooms[i].cell or a.rooms[i].type != b.rooms[i].type:
			same = false
	check(same, "mesma semente gera a mesma planta")


func _test_items_and_stats(catalog: ItemCatalog) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var R := GameEnums.Rarity
	var helm := catalog.get_item(&"elmo_placa")
	var robe := catalog.get_item(&"tunica_tecido")
	var common := ItemFactory.roll(helm, 5, R.COMMON, rng)
	var epic := ItemFactory.roll(helm, 5, R.EPIC, rng)
	check(common.stats.has("strength") and not common.stats.has("intellect"), "placa dá força")
	check(ItemFactory.roll(robe, 5, R.COMMON, rng).stats.has("intellect"), "tecido dá inteligência")
	check(int(epic.stats.strength) > int(common.stats.strength) and int(epic.stats.armor) > int(common.stats.armor),
		"épico é mais forte que comum no mesmo nível")
	var secondaries := 0
	for k in ["crit", "haste", "luck"]:
		if epic.stats.has(k):
			secondaries += 1
	check(secondaries == 2 and not common.stats.has("crit") and not common.stats.has("haste"), "épico tem 2 secundários, comum nenhum")
	var high := ItemFactory.roll(helm, 10, R.COMMON, rng)
	check(int(high.stats.strength) > int(common.stats.strength), "nível de item maior dá mais atributo")

	var legendary_drop := false
	for i in 3000:
		if ItemFactory.roll_rarity("boss", rng) == R.LEGENDARY or ItemFactory.roll_rarity("normal", rng) == R.LEGENDARY:
			legendary_drop = true
	check(not legendary_drop, "lendário nunca cai de inimigo (só crafting)")

	var guardian := catalog.get_hero(&"guardiao")
	check(ItemFactory.can_use(guardian, helm) and not ItemFactory.can_use(guardian, robe), "guardião veste placa e não tecido")
	check(ItemFactory.can_use(guardian, catalog.get_item(&"espada_ferro")) and not ItemFactory.can_use(guardian, catalog.get_item(&"arco_simples")),
		"guardião usa espada e não arco")

	# Drop de equipamento: tabela "equipamento" vira peça única com atributos.
	var got_piece := false
	var own_type := 0
	var total := 0
	for i in 300:
		for d in LootRoller.roll(catalog.get_drop_table(&"chefe_rei_ossudo"), catalog, rng, {"ilvl": 8, "profile": "boss", "hero": guardian}):
			if not d.instance.is_empty():
				got_piece = true
				total += 1
				if ItemFactory.can_use(guardian, d.item):
					own_type += 1
				if int(d.instance.ilvl) != 8 or int(d.instance.rarity) < R.RARE:
					got_piece = false
	check(got_piece and total > 0, "chefe deixa peças de nível 8, raras ou épicas")
	check(float(own_type) / total > 0.5, "mais da metade das peças serve no herói atual (%d/%d)" % [own_type, total])

	# Atributos do herói: nível e equipamento somam.
	var base := HeroStats.compute(guardian, 1, {}, catalog)
	var leveled := HeroStats.compute(guardian, 5, {}, catalog)
	var chest := ItemFactory.roll(catalog.get_item(&"peitoral_placa"), 5, R.RARE, rng)
	var geared := HeroStats.compute(guardian, 5, {GameEnums.Slot.CHEST: chest}, catalog)
	check(base.primary == 10 and leveled.primary == 18 and leveled.max_health > base.max_health, "nível dá força e vida")
	check(geared.primary == leveled.primary + int(chest.stats.strength) and geared.armor == int(chest.stats.armor),
		"equipamento soma força e armadura")
	check(geared.damage_reduction > 0.0 and geared.weapon.damage > leveled.weapon.damage - 1, "armadura reduz dano; força aumenta o dano")
	var fury: BuffData = catalog.buffs.get(&"furia")
	var buffed := HeroStats.compute(guardian, 5, {}, catalog, [fury])
	check(buffed.weapon.damage > leveled.weapon.damage, "bênção Fúria aumenta o dano")

	var inv := Inventory.new()
	var uid := inv.add_equipment(chest)
	var back := Inventory.new()
	back.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	var loaded := back.get_equipment(uid)
	check(int(loaded.rarity) == R.RARE and int(loaded.stats.strength) == int(chest.stats.strength), "peça mantém raridade e atributos no save")


func _test_progression() -> void:
	check(Progression.xp_to_next(1) == 200 and Progression.xp_to_next(2) == 224, "curva de XP cresce 12% por nível")
	var p := {"level": 1, "xp": 0}
	var gained := Progression.add_xp(p, 450)
	check(gained == 2 and p.level == 3 and p.xp == 26, "XP sobe vários níveis e guarda a sobra")
	var capped := {"level": Progression.MAX_LEVEL, "xp": 0}
	check(Progression.add_xp(capped, 99999) == 0 and capped.level == Progression.MAX_LEVEL, "não passa do nível máximo")


func _test_telegraphs_and_status(catalog: ItemCatalog) -> void:
	var holder := Node3D.new()
	root.add_child(holder)

	var circle := Telegraph.new()
	circle.shape = Telegraph.Shape.CIRCLE
	circle.radius = 2.0
	circle.position = Vector3(10, 0, 0)
	holder.add_child(circle)
	check(circle.contains(Vector3(11, 0, 0)) and not circle.contains(Vector3(13, 0, 0)), "aviso em círculo: dentro e fora")
	check(not circle.contains(circle.escape_point(Vector3(10.5, 0, 0))), "ponto de fuga do círculo fica fora")

	var line := Telegraph.new()
	line.shape = Telegraph.Shape.LINE
	line.length = 6.0
	line.width = 1.0
	line.rotation.y = 0.0  # aponta para +z
	holder.add_child(line)
	check(line.contains(Vector3(0, 0, 4)) and not line.contains(Vector3(2, 0, 4)) and not line.contains(Vector3(0, 0, 8)),
		"aviso em linha (investida)")

	var cone := Telegraph.new()
	cone.shape = Telegraph.Shape.CONE
	cone.radius = 3.0
	cone.half_angle_deg = 60.0
	holder.add_child(cone)
	check(cone.contains(Vector3(0, 0, 2)) and not cone.contains(Vector3(0, 0, -2)), "aviso em cone só pega na frente")

	var mega := Telegraph.new()
	mega.shape = Telegraph.Shape.MEGA
	mega.radius = 10.0
	mega.safe_zones = [Vector3(4, 0, 0)]
	mega.safe_radius = 1.7
	holder.add_child(mega)
	check(mega.contains(Vector3(-3, 0, 2)) and not mega.contains(Vector3(4.5, 0, 0.5)), "mega magia: zona segura protege")
	check(mega.escape_point(Vector3(-3, 0, 0)).is_equal_approx(Vector3(4, 0, 0)), "fuga da mega magia vai para a zona segura")
	holder.free()

	var hp := Health.new()
	hp.max_health = 100
	hp.invulnerability_time = 0.6
	hp.reset()
	var st := StatusEffects.new()
	st.health = hp
	st.apply(EnemyAttack.Effect.POISON, 2.0, 10)
	hp.take_damage(1)  # abre a invencibilidade
	st.tick(1.0)
	check(hp.health == 89, "veneno atravessa a invencibilidade (10/s por 1s; vida %d)" % hp.health)
	st.tick(1.5)
	check(not st.has(EnemyAttack.Effect.POISON), "veneno acaba no tempo certo")
	st.apply(EnemyAttack.Effect.ROOT, 1.0)
	check(st.is_rooted() and st.move_factor() == 0.0, "raízes prendem o herói")
	st.tick(1.1)
	check(not st.is_rooted() and st.move_factor() == 1.0, "raízes soltam depois do tempo")
	st.apply(EnemyAttack.Effect.SLOW, 2.0, 40)
	check(is_equal_approx(st.move_factor(), 0.6), "lentidão de 40% reduz a velocidade")
	hp.untouchable = true
	check(hp.take_damage(50, true, true) == 0, "imune não toma dano nem com ataque que atravessa invencibilidade")
	hp.free()
	st.free()

	var boss := catalog.get_enemy(&"rei_ossudo")
	var kinds := {}
	var has_phase := false
	for a in boss.attacks:
		kinds[a.kind] = true
		if a.below_health < 1.0:
			has_phase = true
	check(boss.is_boss and kinds.has(EnemyAttack.Kind.MEGA) and kinds.has(EnemyAttack.Kind.SUMMON) and has_phase,
		"chefe tem fases, invocação e mega magia")
	var ranged := 0
	for e: EnemyData in catalog.enemies.values():
		for a in e.attacks:
			if a.kind in [EnemyAttack.Kind.PROJECTILE, EnemyAttack.Kind.FAN] and not e.is_boss:
				ranged += 1
				break
	check(ranged >= 2, "há inimigos que atacam de longe (%d)" % ranged)
