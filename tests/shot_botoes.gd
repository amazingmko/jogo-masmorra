extends SceneTree
## Botões da luta de cada herói (ícone da habilidade e da ultimate), um recorte por herói.
##   godot --path . --fixed-fps 60 --script res://tests/shot_botoes.gd -- out=/pasta

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
	var gs = root.get_node("GameState")
	gs.run_trial = {}
	var sheet := Image.create(4 * 420, 360, false, Image.FORMAT_RGBA8)
	var i := 0
	for hero in [&"icamiaba", &"mateira", &"encantado", &"druida"]:
		gs.selected_hero = hero
		change_scene_to_file("res://game/scenes/main.tscn")
		await _frames(30)
		var p = current_scene.get_node("Player")
		p.kit.charge = 88.0 if i % 2 == 0 else 100.0
		await _frames(10)
		var img: Image = root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(1280 - 420, 720 - 360, 420, 360), Vector2i(i * 420, 0))
		i += 1
	sheet.save_png("%s/botoes_herois.png" % _out)
	quit(0)
