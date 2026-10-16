extends SceneTree
## Captura de tela de uma janela do hub (precisa de tela/xvfb, sem --headless).
##   godot --path . --script res://tests/shot_hub.gd -- panel=artesao shot=/caminho/foto.png
## panel: portal, bau, herois, artesao ou talentos (hero=icamiaba|mateira; com alguns pontos gastos). Com "materials", enche a bolsa de reagentes antes.

var _f := 0
var _panel := &"artesao"
var _shot := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("panel="):
			_panel = StringName(arg.trim_prefix("panel="))
		elif arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")


func _process(_d: float) -> bool:
	if _f == 0:
		change_scene_to_file("res://game/scenes/hub.tscn")
	_f += 1
	if _f == 5:
		var gs = root.get_node("GameState")
		var db = root.get_node("ItemDB")
		if "materials" in OS.get_cmdline_user_args():
			for id in ["minerio_ferro", "madeira_lei", "pena_arara", "couro_jacare", "latex_seringueira"]:
				gs.inventory.add(db.get_item(StringName(id)), 60)
		var ui = current_scene.get_node("HubUI")
		if _panel == &"talentos":
			var hero := &"icamiaba"
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("hero="):
					hero = StringName(arg.trim_prefix("hero="))
			gs.progress(hero).level = 30
			gs.progress(hero)["talents"] = {"couro_anta": 3, "escudo_firme": 2, "casco_vivo": 2, "pele_pedra": 1, "guarda_imovel": 1, "ponta_pedra": 2} if hero == &"icamiaba" else {"corda_tensa": 3, "mao_firme": 3, "olho_gaviao": 1, "flecha_perfurante": 1, "tiro_certeiro": 2, "cipo_grosso": 2}
			ui._open(&"herois")
			ui._talent_hero = hero
			ui._open_station = &"talentos"
			ui._refresh_open_panel()
		else:
			ui._open(_panel)
	if _f == 25:
		root.get_viewport().get_texture().get_image().save_png(_shot)
		print("captura salva em ", _shot)
		quit(0)
	return false
