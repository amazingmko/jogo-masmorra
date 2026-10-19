extends SceneTree
## Heróis não deslizam: andando e correndo em linha reta, o pé apoiado no chão quase não se move
## (o ritmo da caminhada/corrida acompanha a velocidade do corpo). Mesmo teste dos bichos
## (flow_rig_feet), para cada herói com modelo 3D e em várias velocidades do joystick.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_hero_feet.gd

const MAX_SLIP := 0.3

var _ok := true
var _report := false


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_report = "report" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var gs = root.get_node("GameState")
	for hero in [&"icamiaba", &"mateira", &"encantado", &"druida"]:
		gs.selected_hero = hero
		change_scene_to_file("res://game/scenes/main.tscn")
		await _frames(10)
		var m = current_scene
		var p = m.get_node("Player")
		m.set_process(false)  # o joystick do teste (a HUD não sobrescreve)
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		var room = m.builder.rooms[m.layout.start_index]
		var sk: Skeleton3D = p._model.find_children("*", "Skeleton3D", true, false)[0]
		var feet := []
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if n.ends_with("LeftToeBase") or n.ends_with("RightToeBase"):
				feet.append(i)
		for amount in ([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.8, 1.0] if _report else [0.15, 0.3, 0.45, 0.6, 1.0]):
			var start: Vector3 = room.center() + Vector3(-7, 0.1, 0)
			p.global_position = start
			p.reset_physics_interpolation()
			await _frames(2)
			var prev := {}
			var slips := []
			var speeds := []
			var prev_body: Vector3 = p.global_position
			for f in 150:
				p.touch_move = Vector2(amount, 0)
				await physics_frame
				await process_frame
				if p.global_position.x > room.center().x + 7.0:
					p.global_position = start
					p.reset_physics_interpolation()
					prev.clear()
					prev_body = p.global_position
					continue
				var body_v := Vector2(p.global_position.x - prev_body.x, p.global_position.z - prev_body.z).length() * 60.0
				prev_body = p.global_position
				var lowest := -1
				var low_y := 1e9
				var pos := {}
				for b in feet:
					var w: Vector3 = sk.global_transform * sk.get_bone_global_pose(b).origin
					pos[b] = w
					if w.y < low_y:
						low_y = w.y
						lowest = b
				if f > 30 and body_v > 0.3 and prev.has(lowest) and low_y - p.global_position.y < 0.08:
					speeds.append(body_v)
					slips.append(Vector2(pos[lowest].x - prev[lowest].x, pos[lowest].z - prev[lowest].z).length() * 60.0 / body_v)
				prev = pos
			p.touch_move = Vector2.ZERO
			slips.sort()
			var med: float = slips[slips.size() / 2] if slips.size() > 0 else 1.0
			speeds.sort()
			if speeds.size() < 20:
				continue  # joystick na zona morta: parado
			var spd: float = speeds[speeds.size() / 2]
			check(med <= MAX_SLIP, "%s a %.1f m/s (%s, ritmo %.2f): pé apoiado desliza %.0f%%" % [hero, spd, p._animator._loco, p._animator._tree.get("parameters/%s_ts/scale" % p._animator._loco), med * 100.0])
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
