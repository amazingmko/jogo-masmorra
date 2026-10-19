extends SceneTree
## Bichos com esqueleto (Mapinguari, Macaco-prego): cada ataque toca a animação certa e o golpe da
## animação cai no instante em que o dano acontece (fim do aviso), normal e enfurecido.
## Ouriço do Macaco: sai da mão e cai junto com o aviso. Investida: corre durante a investida.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_rig_sync.gd

const TOL := 0.09   # segundos de animação

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
	var room = m.builder.rooms[m.layout.start_index]
	for id in [&"macaco_prego", &"mapinguari"]:
		for enraged in [false, true]:
			for e in get_nodes_in_group("enemies"):
				e.queue_free()
			await _frames(2)
			p.global_position = room.center() + Vector3(5, 0.1, 0)
			var e = m._spawn(id, room, room.center() + Vector3(-2, 0.1, 0))
			e._awake = true
			e.enraged = enraged
			await _frames(3)
			for a in e._attacks:
				e.state = e.State.MOVE
				e._rig_action = ""
				await _frames(2)
				# ouriços de um ataque que ele fez sozinho antes não contam
				var seen := {}
				for c in e.get_parent().get_children():
					seen[c.get_instance_id()] = true
				var entry: Array = e._rig_entry(a)
				e._start(a)
				var max_balls := 0
				var guard := 0
				while e.state == e.State.WINDUP and guard < 600:
					await physics_frame
					max_balls = maxi(max_balls, _count_balls(e.get_parent(), seen))
					guard += 1
				var anim: AnimationPlayer = e._anim
				var pos := anim.current_animation_position
				var expect: float = entry[2]
				var tag := "%s%s %s" % [id, " (enfurecido)" if enraged else "", a.id]
				if e.data.id == &"macaco_prego" and a.kind == EnemyAttack.Kind.GROUND_AOE:
					check(max_balls == a.count, "%s: %d ouriço(s) voando (esperado %d)" % [tag, max_balls, a.count])
					check(anim.current_animation == entry[0] and pos >= expect - TOL, "%s: já soltou da mão (%s em %.2f s, solta em %.2f)" % [tag, anim.current_animation, pos, expect])
				else:
					check(anim.current_animation == entry[0] and absf(pos - expect) <= TOL, "%s: %s no golpe em %.2f s (golpe da animação %.2f)" % [tag, anim.current_animation, pos, expect])
				if a.kind == EnemyAttack.Kind.CHARGE:
					await _frames(6)
					check(e.state != e.State.CHARGING or anim.current_animation == "run", "%s: corre durante a investida (%s)" % [tag, anim.current_animation])
				await _frames(90)
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)


func _count_balls(parent: Node, seen: Dictionary) -> int:
	var n := 0
	for c in parent.get_children():
		if not seen.has(c.get_instance_id()) and c is MeshInstance3D and c.has_meta("ourico"):
			n += 1
	return n
