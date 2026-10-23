extends SceneTree
## Do acampamento para a masmorra gastando 1 energia: a tela de carregamento some e o jogo anda.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_entrar.gd

var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs = root.get_node("GameState")
	change_scene_to_file("res://game/scenes/hub.tscn")
	for i in 20:
		await process_frame
	for use_energy in [true, false]:
		if current_scene.scene_file_path.ends_with("main.tscn"):
			change_scene_to_file("res://game/scenes/hub.tscn")
			for i in 20:
				await process_frame
		var hub = current_scene
		var before: int = gs.energy_now()
		gs.run_difficulty = 0
		gs.run_full_rewards = use_energy and gs.spend_energy()
		var ui = hub.find_children("*", "", true, false).filter(func(n): return n.has_signal("enter_dungeon_requested"))
		check(not ui.is_empty(), "achou o painel do portal")
		ui[0].enter_dungeon_requested.emit()
		var t0 := Time.get_ticks_msec()
		var entered := false
		for i in 600:
			await process_frame
			var m = current_scene
			if m and m.scene_file_path.ends_with("main.tscn") and m.get("_loading") and not m._loading.visible:
				entered = true
				break
		check(entered, "%s: entrou no andar 1 (carregamento sumiu em %.1f s)" % ["com energia" if use_energy else "sem energia", (Time.get_ticks_msec() - t0) / 1000.0])
		if use_energy:
			check(gs.energy_now() == before - 1 or before == 0, "gastou 1 energia (%d -> %d)" % [before, gs.energy_now()])
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
