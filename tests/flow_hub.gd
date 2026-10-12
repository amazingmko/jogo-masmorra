extends SceneTree
## Teste do fluxo base -> masmorra: equipar no hub muda os atributos, e o portal leva à run
## com o herói escolhido. Rodar: godot --headless --path . --script res://tests/flow_hub.gd
## (Autoloads acessados por root.get_node: este script compila antes deles existirem.)

var _hub
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
		change_scene_to_file("res://game/scenes/hub.tscn")
	_f += 1
	if _f < 3:
		return false
	_hub = current_scene
	var gs = root.get_node("GameState")
	var db = root.get_node("ItemDB")
	if _f == 5:
		print("cena inicial: ", _hub.name)
		var player = _hub.get_node("Player")
		gs.selected_hero = &"batedora"
		gs.unequip(&"batedora", 2)  # peito livre, para a conta ficar exata
		player.set_hero(db.get_hero(&"batedora"))
		var before: int = player.stats.primary
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var piece: Dictionary = load("res://game/scripts/systems/item_factory.gd").roll(db.get_item(&"armadura_couro"), 6, 2, rng)
		var uid: String = gs.inventory.add_equipment(piece)
		var err: String = gs.equip(&"batedora", uid)
		check(err == "", "batedora veste gibão de couro")
		check(player.stats.primary == before + int(piece.stats.agility), "agilidade sobe com a peça (%d -> %d)" % [before, player.stats.primary])
		check(gs.equip(&"guardiao", uid) != "", "guardião não pode vestir couro")
		_hub.get_node("HubUI").enter_dungeon_requested.emit()
	if _f == 6:
		print("cena atual depois do portal: ", current_scene.name if current_scene else "nenhuma")
	if _f == 30:
		var scene = current_scene
		check(scene != null and scene.has_node("Dungeon"), "portal leva para a masmorra (cena: %s)" % [scene.name if scene else "nenhuma"])
		if scene and scene.has_node("Player"):
			check(scene.get_node("Player").hero_id == &"batedora", "a run começa com o herói escolhido")
			scene._back_to_hub()
	if _f == 45:
		check(current_scene != null and current_scene.name == "Hub", "\"Voltar à base\" leva de volta ao hub")
		quit(0 if _ok else 1)
	return false
