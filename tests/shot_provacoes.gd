extends SceneTree
## Capturas das Provações (precisa de tela/xvfb): a caixa da Provação na tela de heróis,
## as 4 provas em andamento e o painel de vitória.
##   godot --path . --fixed-fps 60 --script res://tests/shot_provacoes.gd -- out=/pasta

var _out := "/tmp"
var gs
var _backup := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/prova_%s.png" % [_out, name])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	gs = root.get_node("GameState")
	_backup = gs.to_dict()
	for h in ["icamiaba", "mateira", "encantado", "druida"]:
		var p: Dictionary = gs.progress(StringName(h))
		p.level = 10
		p.xp = 0
		p.erase("trials")
	gs.coins = 3200
	gs.progress(&"mateira")["trials"] = {}
	gs.selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/hub.tscn")
	await _frames(10)
	var hp: GDScript = load("res://game/scripts/hub/heroes_panel.gd")
	hp.viewing = &"icamiaba"
	current_scene.get_node("HubUI")._open(&"herois")
	await _frames(20)
	_shot("herois")
	for h in ["icamiaba", "mateira", "encantado", "druida"]:
		gs.selected_hero = StringName(h)
		gs.run_trial = {"hero": h, "tier": 10}
		change_scene_to_file("res://game/scenes/main.tscn")
		await _frames(20)
		var m = current_scene
		m._player.health.max_health = 99999
		m._player.health.health = 99999
		m.trial._wave_t = 0.0
		await _frames(200)
		_shot(h)
		if h == "druida":
			m.trial.elapsed = 59.95
			await _frames(30)
			_shot("vitoria")
	gs.run_trial = {}
	gs.from_dict(_backup)
	gs.save()
	quit(0)
