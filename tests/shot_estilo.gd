extends SceneTree
## Capturas da identidade visual (precisa de tela/xvfb): tela do personagem (vazia de seleção e com
## um item tocado), portal, luta (números de dano, avisos, botões) e diálogo de fim de run.
##   godot --path . --fixed-fps 60 --script res://tests/shot_estilo.gd -- palette=obsidiana out=/pasta

var _f := 0
var _out := "/tmp"
var _m
var _ui
var _shots := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("palette="):
			UiStyle.palette = arg.trim_prefix("palette=")
		elif arg.begins_with("variant="):
			UiStyle.variant = arg.trim_prefix("variant=")
		elif arg.begins_with("watermark="):
			UiStyle.watermark = arg.trim_prefix("watermark=")
		elif arg.begins_with("out="):
			_out = arg.trim_prefix("out=")


## (carregado na hora: a tela usa os autoloads, que não existem quando este script compila)
func _cp() -> GDScript:
	return load("res://game/scripts/hub/character_panel.gd")


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s.png" % [_out, UiStyle.variant, UiStyle.watermark, name])
	_shots += 1


## Bolsa de exemplo: peças de placa (algumas vestidas), uma de couro (não serve) e reagentes.
func _fill_bag(gs) -> void:
	var db = root.get_node("ItemDB")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	gs.inventory.equipment.clear()
	var wear := []
	for spec in [["elmo_placa", 2], ["peitoral_placa", 1], ["manoplas_placa", 0], ["grevas_placa", 1], ["botas_placa", 3],
			["escudo_casco", 2], ["lanca_ipe", 2], ["peitoral_placa", 2], ["elmo_placa", 0], ["luvas_couro", 1], ["lanca_ipe", 0]]:
		var uid: String = gs.inventory.add_equipment(ItemFactory.roll(db.get_item(StringName(spec[0])), 16, spec[1], rng), false)
		wear.append(uid)
	for i in [0, 1, 3, 5, 6]:
		gs.equip(&"icamiaba", wear[i])
	for id in ["madeira_lei", "fibra_tucum", "couro_jacare", "minerio_ferro", "pena_arara", "latex_seringueira", "oleo_andiroba", "semente_guarana"]:
		gs.inventory.add(db.get_item(StringName(id)), 37 + id.length() * 13)
	return


func _process(_d: float) -> bool:
	_f += 1
	var gs = root.get_node("GameState") if root.has_node("GameState") else null
	if _f == 1:
		gs.selected_hero = &"icamiaba"
		gs.progress(&"icamiaba").level = 12
		_fill_bag(gs)
		change_scene_to_file("res://game/scenes/hub.tscn")
	elif _f == 8:
		_ui = current_scene.get_node("HubUI")
		_cp().tab = "equip"
		_cp().selected = {}
		_ui._open(&"bau")
	elif _f == 30:
		_shot("personagem")
		# toca numa peça da bolsa que não está vestida (mostra a comparação)
		for e in gs.inventory.equipment:
			if gs.wearer_of(e.uid) == &"" and e.item_id == &"peitoral_placa":
				_cp().selected = {"uid": String(e.uid)}
		_ui._refresh_open_panel()
	elif _f == 50:
		_shot("personagem_item")
		_cp().tab = "mat"
		_cp().selected = {"mat": "pena_arara"}
		_ui._refresh_open_panel()
	elif _f == 66:
		_shot("personagem_reagentes")
		_ui._close()
		_ui._open(&"portal")
	elif _f == 82:
		_shot("portal")
		_ui._portal_tab = "grupo"
		_ui._refresh_open_panel()
	elif _f == 96:
		_shot("portal_grupo")
		_ui._portal_tab = "solo"
		_ui._close()
		var hp: GDScript = load("res://game/scripts/hub/heroes_panel.gd")
		hp.viewing = &"encantado"
		_ui._open(&"herois")
	elif _f == 112:
		_shot("herois")
		gs.progress(&"icamiaba")["talents"] = {"couro_anta": 3, "escudo_firme": 2, "casco_vivo": 2, "pele_pedra": 1, "guarda_imovel": 1, "ponta_pedra": 2}
		_ui._talent_hero = &"icamiaba"
		_ui._open_station = &"talentos"
		var tp: GDScript = load("res://game/scripts/hub/talents_panel.gd")
		tp.spec = "protecao"
		tp.picked = "pele_pedra"
		_ui._refresh_open_panel()
	elif _f == 128:
		_shot("talentos")
		_ui._close()
		_ui._craft_prof = &"ferreiro"
		_ui._open(&"artesao")
	elif _f == 144:
		_shot("oficina")
		_ui._close()
	elif _f == 156:
		_shot("hub")
		change_scene_to_file("res://game/scenes/main.tscn")
	elif _f == 176:
		_m = current_scene
		var p = _m.get_node("Player")
		p.health.max_health = 99999
		p.health.health = 99999
		var room = _m.builder.rooms[_m.layout.start_index]
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		for i in 3:
			var e = _m._spawn(&"queixada", room, p.global_position + Vector3(2.5 + i * 0.8, 0.1, -1.5 + i * 1.2))
			if e:
				e.training_dummy = true
	elif _f == 186:
		var p = _m.get_node("Player")
		var enemies := get_nodes_in_group("enemies")
		for i in enemies.size():
			Fx.damage_number(_m, (enemies[i] as Node3D).global_position + Vector3(0, 1.8, 0), [87, 142, 61][i % 3], i == 1)
		Fx.float_text(_m, p.global_position + Vector3(0, 3.0, 0), "MURALHA!", Color("e8c26a"))
		_m._hud.show_toast("+3 Madeira de Lei", Color("6fbf4a"))
		_m._hud.show_toast("Sala limpa!", UiStyle.GOLD)
	elif _f == 200:
		_shot("luta")
		_m._hud.show_panel("Você caiu", "A mata venceu desta vez. Os reagentes e o XP ficam com você.", "Voltar ao hub")
		_m._hud._panel_button2.text = "Jogar de novo"
		_m._hud._panel_button2.visible = true
	elif _f == 216:
		_shot("dialogo")
		print("capturas: ", _shots)
		quit(0)
	return false
