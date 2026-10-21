extends SceneTree
## Pinguela: andando de lado em cima dela, o herói não sai para a água (paredes invisíveis nas beiras).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_pinguela.gd

var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	root.get_node("GameState").selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(12)
	var m = current_scene
	m.set_process(false)
	var tested := 0
	for f in range(1, 11):
		if f > 1:
			m.debug_jump_to_floor(f)
			await _frames(8)
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		var bridges = m.find_children("Pinguela*", "Node3D", true, false)
		for b in bridges:
			var p = m.get_node("Player")
			var side: Vector3 = b.global_basis.x.normalized()
			for dir in [1.0, -1.0]:
				p.global_position = b.global_position + Vector3(0, 0.1, 0)
				p.reset_physics_interpolation()
				await physics_frame
				var mv: Vector2 = Vector2(side.x, side.z) * float(dir)
				for i in 60:
					p.touch_move = mv
					await physics_frame
				p.touch_move = Vector2.ZERO
				var off: float = absf((p.global_position - b.global_position).dot(side))
				var limit: float = (DungeonRoom.DOOR_W - 0.4) * 0.5 + 0.1
				check(off <= limit, "andar %d: andando de lado na pinguela, ficou em cima dela (%.2f m do meio, limite %.2f)" % [f, off, limit])
				tested += 1
			# e atravessar continua livre: de um barranco ao outro, por cima dela
			var along: Vector3 = b.global_basis.z.normalized()
			p.global_position = b.global_position - along * 2.6 + Vector3(0, 0.1, 0)
			p.reset_physics_interpolation()
			await physics_frame
			for i in 150:
				p.touch_move = Vector2(along.x, along.z)
				await physics_frame
			p.touch_move = Vector2.ZERO
			var crossed: float = (p.global_position - b.global_position).dot(along)
			check(crossed > 2.0, "andar %d: atravessou a pinguela de ponta a ponta (%.2f m do outro lado)" % [f, crossed])
		if tested >= 4:
			break
	check(tested > 0, "achou pinguelas para testar (%d casos)" % tested)
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
