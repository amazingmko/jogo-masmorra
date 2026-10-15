extends SceneTree
## Fotos dos efeitos dos poderes da Icamiaba (Provocar, Muralha, Muiraquitã, Revide).
##   godot --path . --script res://tests/shot_powers.gd -- shot=/caminho/prefixo   (precisa de tela/xvfb)
## Gera prefixo_provocar.png, prefixo_muralha.png, prefixo_muralha_golpe.png, prefixo_muiraquita.png, prefixo_revide.png

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
		root.get_node("GameState").selected_hero = &"icamiaba"
		_main = load("res://game/scenes/main.tscn").instantiate()
		root.add_child(_main)
	if _f == 6:
		_player = _main.get_node("Player")
		_player.controls_enabled = false
		var room = _main.builder.rooms[_main.layout.start_index]
		for i in 4:
			var a := TAU * i / 4.0 + 0.4
			var e = _main._spawn([&"queixada", &"macaco_prego", &"onca_pintada", &"jararaca"][i], room, _player.global_position + Vector3(cos(a), 0.1, sin(a)) * 4.5)
			e.process_mode = Node.PROCESS_MODE_DISABLED
		_main.get_node("Camera").snap()
	if _f == 20:
		_player.kit.try_skill()
	if _f == 29:
		_snap("provocar")
	if _f == 60:
		_player.kit.charge = 100.0
		_player.kit.try_ultimate()
	if _f == 85:
		_snap("muralha")
	if _f == 90:
		_player.receive_attack(50, 0, 0.0, 0, _player.global_position, true)
	if _f == 93:
		_snap("muralha_golpe")
	if _f == 120:
		_player.kit.on_blocked()
	if _f == 135:
		_snap("revide")
	if _f == 470:
		_player.health._invulnerable = 0.0
		_player.receive_attack(999999, 0, 0.0, 0, _player.global_position, true)
	if _f == 482:
		_snap("muiraquita")
		quit(0)
	return false
