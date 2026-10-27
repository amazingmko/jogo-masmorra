extends SceneTree
## Captura da pergunta "Run em andamento" no hub.
##   godot --path . --script res://tests/shot_continuar.gd -- out=/pasta

var _out := "/tmp"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.run_resume = {"hero": "mateira", "difficulty": 0, "full": true, "floor": 6, "kills": 80, "hp": 0.7}
	change_scene_to_file("res://game/scenes/hub.tscn")
	for i in 40:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/continuar.png" % _out)
	gs.run_resume = {}
	quit(0)
