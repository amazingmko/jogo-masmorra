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
		gs.selected_hero = &"mateira"
		gs.unequip(&"mateira", 2)  # peito livre, para a conta ficar exata
		player.set_hero(db.get_hero(&"mateira"))
		var before: int = player.stats.primary
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var piece: Dictionary = load("res://game/scripts/systems/item_factory.gd").roll(db.get_item(&"armadura_couro"), 6, 2, rng)
		var uid: String = gs.inventory.add_equipment(piece)
		var err: String = gs.equip(&"mateira", uid)
		check(err == "", "mateira veste gibão de couro")
		check(player.stats.primary == before + int(piece.stats.agility), "agilidade sobe com a peça (%d -> %d)" % [before, player.stats.primary])
		check(gs.equip(&"icamiaba", uid) != "", "icamiaba não pode vestir couro")

		# Energia: recarrega 1 por hora até o máximo, e gastar desconta.
		gs.energy = 2
		gs.energy_at = gs.now()
		gs.debug_time_offset += 2 * 3600 + 30
		check(gs.energy_now() == 4, "energia recarrega 1 por hora (%d)" % gs.energy_now())
		check(gs.spend_energy() and gs.energy_now() == 3, "gastar energia desconta 1")
		gs.debug_time_offset += 50 * 3600
		check(gs.energy_now() == gs.MAX_ENERGY, "energia não passa do máximo")
		gs.debug_time_offset = 0

		# Oficina: fabrica o Capuz Comum, veste, e a Rara substitui a peça vestida.
		var common = db.get_recipe(&"capuz_couro_comum")
		var rare = db.get_recipe(&"capuz_couro_raro")
		gs.professions.add_xp(db.catalog.get_profession(&"curtidor"), 5000)
		for rec in [common, rare]:
			for id in rec.ingredients:
				gs.inventory.add(db.get_item(StringName(id)), int(rec.ingredients[id]) * 30)
		# Sem capuzes sobrando: assim a peça-base só pode ser a vestida.
		for eq in gs.inventory.equipment.duplicate():
			if eq.item_id == "capuz_couro":
				gs.inventory.remove_equipment(eq.uid)
		var made := ""
		for i in 30:
			var res: Dictionary = gs.craft(&"capuz_couro_comum")
			if res.success:
				made = res.uid
				break
		check(made != "", "a oficina fabrica o Capuz de Couro Comum")
		gs.equip(&"mateira", made)
		var rare_uid := ""
		for i in 30:
			var res: Dictionary = gs.craft(&"capuz_couro_raro")
			if res.success:
				rare_uid = res.uid
				break
			check(gs.craft_streak(&"capuz_couro_raro") > 0, "falha conta para o bônus da próxima")
		var head: Dictionary = gs.equipped_items(&"mateira").get(1, {})
		check(rare_uid != "" and head.get("uid", "") == rare_uid, "a Rara entra no lugar da Comum vestida")
		check(gs.craft_streak(&"capuz_couro_raro") == 0, "acertar zera as falhas seguidas")

		# Druida: troca de forma muda o ataque.
		player.set_hero(db.get_hero(&"druida"))
		check(player.form == 1 and not player.weapon_stats.is_ranged(), "Druida começa como Onça, corpo a corpo")
		player._form_cooldown = 0.0
		player.cycle_form()
		check(player.form == 2 and player.weapon_stats.attack_range > 2.0 and player.health.damage_reduction > player.stats.damage_reduction,
			"Sucuri: alcance maior e aguenta mais")
		player._form_cooldown = 0.0
		player.cycle_form()
		check(player.form == 3 and player.weapon_stats.is_ranged(), "Boto ataca de longe")
		player._form_cooldown = 0.0
		player.cycle_form()
		check(player.form == 1, "volta para a Onça")
		player.set_hero(db.get_hero(&"mateira"))
		check(player.form == 0, "outros heróis não trocam de forma")

		var ui = _hub.get_node("HubUI")
		ui._open(&"artesao")
		ui._close()
		ui._open(&"portal")
		check(gs.difficulty_lock(1, &"mateira") != "" or gs.highest_cleared >= 0, "Difícil trancado sem vencer o Normal")
		ui._close()
		gs.run_difficulty = 1
		gs.run_full_rewards = false
		ui.enter_dungeon_requested.emit()
	if _f == 6:
		print("cena atual depois do portal: ", current_scene.name if current_scene else "nenhuma")
	if _f == 30:
		var scene = current_scene
		check(scene != null and scene.has_node("Dungeon"), "portal leva para a masmorra (cena: %s)" % [scene.name if scene else "nenhuma"])
		if scene and scene.has_node("Player"):
			check(scene.get_node("Player").hero_id == &"mateira", "a run começa com o herói escolhido")
			check(scene.difficulty == 1 and not scene.full_rewards, "a run usa a dificuldade e a energia escolhidas")
			gs.run_difficulty = 0
			gs.run_full_rewards = true
			scene._back_to_hub()
	if _f == 45:
		check(current_scene != null and current_scene.name == "Hub", "\"Voltar à base\" leva de volta ao hub")
		quit(0 if _ok else 1)
	return false
