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
