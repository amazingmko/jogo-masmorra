extends SceneTree
## O portal de saída visto do jeito que o jogador chega (herói ao sul e ao norte dele) e a tela
## de carregamento entre andares.
##   godot --path . --fixed-fps 60 --script res://tests/shot_portal.gd -- out=/pasta

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
	gs.selected_hero = &"mateira"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(40)
	var m = current_scene
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	var portal: Node3D = null
	var want := Vector2i(0, -1)  # chega pelo norte: o caso em que antes se via as costas do arco
	for seed in range(1, 60):
		m.new_run(seed)
		await _frames(3)
		for idx in m.builder.props:
			if m.builder.props[idx].kind == 2:
				portal = m.builder.props[idx]
		break
	await _frames(30)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var room = m.builder.rooms[m.layout.goal_index]
	print("portal em ", portal.global_position, " sala ", room.position, " portas ", room._door_dirs)
	if "girar" in OS.get_cmdline_user_args():
		p.global_position = portal.global_position + Vector3(2.5, 0.1, 3.5)
		var arch: Node3D = portal.get_child(1) if portal.get_child_count() > 1 else null
		for c in portal.get_children():
			if c is Node3D and c.get_class() != "CollisionShape3D" and arch == null:
				arch = c
		print("filhos: ", portal.get_children().map(func(c): return "%s:%s" % [c.name, c.get_class()]))
		for deg in [0, 90, 180, 270]:
			portal.rotation_degrees.y = deg
			await _frames(20)
			root.get_viewport().get_texture().get_image().save_png("%s/portal_rot%d.png" % [_out, deg])
		quit(0)
		return
	for side in [["sul", Vector3(0, 0.1, 3.5)], ["lado", Vector3(3.5, 0.1, 1.0)]]:
		p.global_position = portal.global_position + side[1]
		p.reset_physics_interpolation()
		await _frames(30)
		root.get_viewport().get_texture().get_image().save_png("%s/portal_%s.png" % [_out, side[0]])
	# tela de carregamento: quanto tempo fica e como aparece
	var t0 := Time.get_ticks_msec()
	m._portal_to_next_floor()
	var loading = m._loading
	for k in 6:
		await _frames(10)
		print("quadro %d: visível %s, opacidade %.2f, texto '%s'" % [(k + 1) * 10, loading.visible, m._loading_fade.modulate.a, m._loading_label.text])
		if k == 3:
			root.get_viewport().get_texture().get_image().save_png("%s/carregando.png" % _out)
	var n := 60
	while loading.visible and n < 6000:
		await process_frame
		n += 1
	print("carregamento durou %d quadros = %.2f s num celular a 60 quadros/s" % [n, n / 60.0])
	quit(0)
