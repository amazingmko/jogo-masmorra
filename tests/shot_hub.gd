extends SceneTree
## Captura de tela de uma janela do hub (precisa de tela/xvfb, sem --headless).
##   godot --path . --script res://tests/shot_hub.gd -- panel=artesao shot=/caminho/foto.png
## panel: portal, bau, herois ou artesao. Com "materials", enche a bolsa de reagentes antes.

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
		current_scene.get_node("HubUI")._open(_panel)
	if _f == 25:
		root.get_viewport().get_texture().get_image().save_png(_shot)
		print("captura salva em ", _shot)
		quit(0)
	return false
