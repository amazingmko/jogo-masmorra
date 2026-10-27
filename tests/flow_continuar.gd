extends SceneTree
## Continuar run (sozinho): o começo de cada andar fica gravado; abrindo de novo, a run volta no
## mesmo andar com a vida e o placar de antes. Em grupo não grava; terminar a run apaga.
##   godot --headless --fixed-fps 60 --path . --script res://tests/flow_continuar.gd

var _fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok: " if ok else "FALHOU: ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.run_trial = {}
	gs.run_resume = {}
	gs.selected_hero = &"mateira"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(30)
	var m = current_scene
	check(int(gs.run_resume.get("floor", 0)) == 1, "andar 1: a run ficou gravada")
	m.debug_jump_to_floor(4)
	await _frames(5)
	m._stats.kills = 37
	m._player.health.health = int(m._player.health.max_health * 0.5)
	m._save_run_state()
	check(int(gs.run_resume.get("floor", 0)) == 4 and int(gs.run_resume.kills) == 37, "andar 4: gravou o andar e os abates")
	# "fechou o app": abre a masmorra de novo pedindo para continuar
	gs.resume_now = true
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(30)
	m = current_scene
	check(m.floor_number == 4, "continuou no andar 4 (andar %d)" % m.floor_number)
	check(m._stats.kills == 37, "com os abates de antes")
	var frac: float = float(m._player.health.health) / float(m._player.health.max_health)
	check(absf(frac - 0.5) < 0.05, "com a vida de antes (%.2f)" % frac)
	# terminar apaga
	m._finish(false)
	check(gs.run_resume.is_empty(), "cair na run apaga a run gravada")
	# em grupo não grava
	gs.run_resume = {}
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(30)
	m = current_scene
	var a = load("res://game/scenes/player.tscn").instantiate()
	m.add_child(a)
	a.set_hero(root.get_node("ItemDB").get_hero(&"druida"))
	m.sim_allies = [a]
	m._save_run_state()
	check(gs.run_resume.is_empty(), "em grupo a run não fica gravada")
	print("fim: ", "TUDO OK" if _fails == 0 else "COM FALHAS")
	quit(0 if _fails == 0 else 1)
