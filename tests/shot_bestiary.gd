extends SceneTree
## Foto do bestiário: todos os inimigos lado a lado na primeira sala, parados (a queixada, furiosa).
##   godot --path . --script res://tests/shot_bestiary.gd -- shot=/caminho/foto.png
## (Precisa de tela/xvfb, sem --headless.)

var _main: Node
var _f := 0
var _shot := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_main = load("res://game/scenes/main.tscn").instantiate()
		root.add_child(_main)
	if _f == 4:
		var room = _main.builder.rooms[_main.layout.start_index]
		var c: Vector3 = room.center()
		var ids := [&"queixada", &"formiga_fogo", &"macaco_prego", &"aranha_caranguejeira", &"jararaca", &"onca_pintada"]
		for i in ids.size():
			# O primeiro aparece furioso, para mostrar o visual de elite.
			var e = _main._spawn(ids[i], room, c + Vector3(-6.0 + i * 2.4, 0.1, 3.0), false, i == 0)
			e.process_mode = Node.PROCESS_MODE_DISABLED
		var boss = _main._spawn(&"mapinguari", room, c + Vector3(0, 0.1, -0.8))
		boss.process_mode = Node.PROCESS_MODE_DISABLED
		var player = _main.get_node("Player")
		player.global_position = c + Vector3(0, 0.1, 6.0)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		_main.get_node("Camera").snap()
	if _f == 20:
		root.get_viewport().get_texture().get_image().save_png(_shot)
		print("captura salva em ", _shot)
		quit(0)
	return false
