extends SceneTree
## Fotos da Icamiaba golpeando (precisa de tela/xvfb), com a câmera de perto:
##   godot --path . --script res://tests/shot_melee_move.gd -- shot=/pasta/prefixo [parada]
## Sem "parada": anda de lado golpeando um boneco. Com "parada": combo de 3 golpes sem alvo.
var _f := 0
var _main
var _player
var _shot := "/tmp/melee"
var _dummy
var _still := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")
		elif arg == "parada":
			_still = true


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		root.get_node("GameState").selected_hero = &"icamiaba"
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f == 8:
		_main = current_scene
		_player = _main.get_node("Player")
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		_main._camera.offset = Vector3(0, 5.5, 3.75)
		if _still:
			return false
		_main.spawn_training_dummies()
	if _f == 12 and not _still:
		_dummy = get_nodes_in_group("enemies").filter(func(e): return e.training_dummy)[0]
		_dummy._constrict_left = 999.0
		_dummy.global_position = _player.global_position + Vector3(0, 0.1, -1.8)
	if _f > 14 and _f < 400:
		if not _still:
			_main._hud.joystick.value = Vector2(1, 0)  # anda para a direita; o alvo está acima
		_main._hud.attack_button.is_pressed = true
	var frames: Array = [20, 32, 44, 56, 92, 104, 116, 128] if _still else [60, 70, 80, 90]
	if _f in frames:
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [_shot, _f])
	if _f > frames[-1]:
		quit(0)
	return false
