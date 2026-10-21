extends SceneTree
## Baú grande do Covil Furioso: depois do último furioso, aparece no meio da sala e abre quando o herói encosta.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_bau_covil.gd

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
	var room: DungeonRoom = null
	for r in m.builder.rooms if "rooms" in m.builder else []:
		if r.type == DungeonLayout.RoomType.COMBAT:
			room = r
			break
	if room == null:
		for r in m.find_children("*", "DungeonRoom", true, false):
			room = r
			if r.index > 0:
				break
	check(room != null, "achou uma sala")
	var p = m.get_node("Player")
	for start in [Vector3(4.0, 0, 0), Vector3(0.3, 0, 0)]:  # herói longe do baú / em cima de onde ele nasce
		p.global_position = room.center() + start + Vector3(0, 0.1, 0)
		p.reset_physics_interpolation()
		await physics_frame
		m._spawn_den_chest(room)
		var chest: RoomProp = m.builder.props[room.index]
		var opened := [false]
		chest.activated.connect(func(_c): opened[0] = true)
		await _frames(4)
		var to: Vector3 = chest.global_position - p.global_position
		for i in 120:
			if opened[0]:
				break
			var d: Vector3 = chest.global_position - p.global_position
			p.touch_move = Vector2(d.x, d.z).normalized() if d.length() > 0.3 else Vector2.ZERO
			await physics_frame
		p.touch_move = Vector2.ZERO
		check(opened[0] and chest.used, "baú do covil abriu (herói começou a %.1f m)" % to.length())
		chest.queue_free()
		await _frames(2)
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
