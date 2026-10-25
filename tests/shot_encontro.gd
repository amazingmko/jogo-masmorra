extends SceneTree
## Capturas do Encontro das Águas (precisa de tela/xvfb): as duas ondas saindo, o choque e o
## redemoinho.  godot --path . --fixed-fps 60 --script res://tests/shot_encontro.gd -- out=/pasta

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
	var backup: Dictionary = gs.to_dict()
	gs.debug_all_specs = true
	gs.selected_hero = &"encantado"
	gs.run_trial = {}
	gs.progress(&"encantado").level = 40
	gs.progress(&"encantado")["talents"] = {"encontro_aguas": 1}
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(30)
	var m = current_scene
	var p = m.get_node("Player")
	p.health.max_health = 99999
	p.health.health = 99999
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var room = m.builder.rooms[m.layout.start_index]
	p.global_position = room.center() + Vector3(0, 0.1, 3.0)
	p.reset_physics_interpolation()
	p._facing = Vector3(0, 0, -1)
	await _frames(20)
	for off in [Vector3(-3, 0, -6), Vector3(2.5, 0, -8), Vector3(0.5, 0, -5), Vector3(3.5, 0, -6), Vector3(-1.5, 0, -9)]:
		var e = m._spawn(&"queixada", room, p.global_position + off)
		if e:
			e.training_dummy = true
	await _frames(40)
	p.refresh_stats()
	p.kit.charge = 100.0
	p.kit.try_ultimate()
	for k in [["1_ondas", 22], ["2_choque", 22], ["3_redemoinho", 20], ["4_fim", 30]]:
		await _frames(k[1])
		root.get_viewport().get_texture().get_image().save_png("%s/encontro_%s.png" % [_out, k[0]])
	gs.debug_all_specs = false
	gs.from_dict(backup)
	gs.save()
	quit(0)
