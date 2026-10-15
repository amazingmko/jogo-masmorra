extends SceneTree
## Fotos da Mateira e dos poderes dela (armadilha e harpia).
##   godot --path . --script res://tests/shot_ranger.gd -- shot=/caminho/prefixo   (precisa de tela/xvfb)

var _f := 0
var _shot := ""
var _main
var _player


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")


func _snap(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_shot, name])
	print("captura: ", name)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		root.get_node("GameState").selected_hero = &"mateira"
		_main = load("res://game/scenes/main.tscn").instantiate()
		root.add_child(_main)
	if _f == 6:
		_player = _main.get_node("Player")
		_player.controls_enabled = false
		var room = _main.builder.rooms[_main.layout.start_index]
		for i in 3:
			var a := TAU * i / 3.0 + 0.4
			var e = _main._spawn([&"queixada", &"macaco_prego", &"jararaca"][i], room, _player.global_position + Vector3(cos(a), 0.1, sin(a)) * 4.5)
			e.process_mode = Node.PROCESS_MODE_DISABLED
		_main.get_node("Camera").snap()
	if _f == 15:
		_snap("parada")
		_player._facing = Vector3(0, 0, 1)
		_player.kit.try_skill()
	if _f == 30:
		_snap("armadilha")
		_player.kit.charge = 100.0
		_player.kit.try_ultimate()
	if _f == 75:
		_snap("harpia")
	if _f == 100:
		_snap("harpia_mergulho")
		quit(0)
	return false
