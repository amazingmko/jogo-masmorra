extends SceneTree
## Captura da tela de título de verdade (e confere que um toque leva ao hub).
##   godot --path . --fixed-fps 60 --script res://tests/shot_titulo.gd -- out=/pasta

var _out := "/tmp"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://game/scenes/title.tscn")
	await _frames(40)
	root.get_viewport().get_texture().get_image().save_png("%s/titulo_jogo.png" % _out)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	root.push_input(ev)
	await _frames(20)
	print("depois do toque: ", current_scene.name if current_scene else "nenhuma")
	quit(0 if current_scene and current_scene.name == "Hub" else 1)
