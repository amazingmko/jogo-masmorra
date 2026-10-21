extends SceneTree
## Limites do mapa: empurrando o herói em todas as direções a partir de cada clareira, ele nunca
## entra no igarapé (só cruza por cima da pinguela).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_limites.gd

var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _on_bridge(m, pos: Vector3) -> bool:
	for b in m.find_children("Pinguela*", "Node3D", true, false):
		var d: Vector3 = pos - b.global_position
		if absf(d.dot(b.global_basis.x.normalized())) < 1.9 and absf(d.dot(b.global_basis.z.normalized())) < 2.6:
			return true
	return false


func _run() -> void:
	root.get_node("GameState").selected_hero = &"encantado"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(12)
	var m = current_scene
	m.set_process(false)
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	var floors := 0
	for f in range(1, 11):
		if f > 1:
			m.debug_jump_to_floor(f)
			await _frames(8)
		var ig: Igarape = m.builder.igarape
		if ig == null or ig.path.size() < 2:
			continue
		floors += 1
		var wet := 0
		var worst := 99.0
		for room in m.builder.rooms:
			room.cleared = true
			room.open_doors()
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		for room in m.builder.rooms:
			if Igarape.distance_to(ig.path, room.center()) > 14.0:
				continue  # só as clareiras perto do igarapé
			for a in 8:
				p.global_position = room.center() + Vector3(0, 0.1, 0)
				p.reset_physics_interpolation()
				await physics_frame
				var dir := Vector2.from_angle(TAU * a / 8.0 + 0.2)
				for i in 110:
					p.touch_move = dir
					await physics_frame
					var d := Igarape.distance_to(ig.path, p.global_position)
					if d < Igarape.HALF_WIDTH - 0.15 and not _on_bridge(m, p.global_position):
						wet += 1
						worst = minf(worst, d)
		p.touch_move = Vector2.ZERO
		check(wet == 0, "andar %d: o herói não entrou no igarapé (%d quadros na água%s)" % [f, wet, "" if wet == 0 else ", a %.2f m do meio" % worst])
		if floors >= 4:
			break
	check(floors > 0, "andares com igarapé testados: %d" % floors)
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
