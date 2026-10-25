extends SceneTree
## Captura do aviso de ataque no corpo dos bichos (o brilho na hora de atacar), um de cada:
##   godot --path . --fixed-fps 60 --script res://tests/shot_aviso.gd -- out=/pasta

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
	gs.selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(30)
	var m = current_scene
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	var room = m.builder.rooms[m.layout.start_index]
	for id in [&"macaco_prego", &"aranha_caranguejeira", &"queixada", &"formiga_fogo", &"jararaca", &"onca_pintada"]:
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		await _frames(2)
		var e = m._spawn(id, room, p.global_position + Vector3(2.5, 0.1, -1.0))
		e._awake = true
		var got := false
		for i in 400:
			await process_frame
			if is_instance_valid(e) and e.state == e.State.WINDUP:
				await _frames(6)
				root.get_viewport().get_texture().get_image().save_png("%s/aviso_%s.png" % [_out, id])
				got = true
				break
		print(id, ": ", "capturado" if got else "não atacou")
	quit(0)
