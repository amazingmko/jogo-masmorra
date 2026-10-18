extends SceneTree
## Portal de saída: entrar nele desce exatamente um andar (nunca pula andar), em muitas runs.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_portal.gd

var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	root.get_node("GameState").selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/main.tscn")
	for i in 10:
		await process_frame
	var m = current_scene
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	var bad := 0
	var total := 0
	for run in 40:
		if m.floor_number >= m.FLOORS - 1:
			m.floor_number = 0
			m._next_floor()
			await _frames(3)
		var before: int = m.floor_number
		var portal = null
		for prop in m.builder.props.values():
			if prop.kind == RoomProp.Kind.PORTAL:
				portal = prop
		if portal == null:
			continue
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		p.global_position = portal.global_position + Vector3(0, 0.1, 0)
		p.reset_physics_interpolation()
		await _frames(60)
		total += 1
		if m.floor_number != before + 1:
			bad += 1
			print("  andar %d -> %d" % [before, m.floor_number])
	check(bad == 0, "portal desce exatamente um andar (%d de %d pularam)" % [bad, total])
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
