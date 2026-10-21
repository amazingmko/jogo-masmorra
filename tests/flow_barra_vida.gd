extends SceneTree
## Barrinha de vida dos inimigos: comuns só mostram ao levar dano e ela some sozinha;
## furiosos mostram sempre; chefes não têm (usam a barra grande da tela).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_barra_vida.gd

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
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(2)
	var room = m.builder.rooms[m.layout.start_index]
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	var common = m._spawn(&"queixada", room, room.center() + Vector3(5, 0.1, 0))
	await _frames(3)
	common.set_physics_process(false)
	var bar: EnemyHealthBar = common.get_node_or_null("BarraVida")
	check(bar != null, "inimigo comum tem barrinha")
	check(not bar.visible, "comum sem dano: barrinha escondida")
	common.take_hit(10, false, Vector3.FORWARD)
	await _frames(2)
	check(bar.visible, "comum levou dano: barrinha aparece")
	var fill: float = bar._mat.get_shader_parameter("fill")
	check(fill < 1.0 and fill > 0.0, "barrinha mostra a vida que falta (%.2f)" % fill)
	await _frames(int(60 * (EnemyHealthBar.SHOW_SECONDS + EnemyHealthBar.FADE_SECONDS + 0.5)))
	check(not bar.visible, "sem apanhar por alguns segundos: barrinha some")
	common.take_hit(5, false, Vector3.FORWARD)
	await _frames(2)
	check(bar.visible, "apanhou de novo: barrinha volta")

	var elite = m._spawn(&"onca_pintada", room, room.center() + Vector3(-5, 0.1, 0), false, true)
	await _frames(3)
	elite.set_physics_process(false)
	var eb: EnemyHealthBar = elite.get_node_or_null("BarraVida")
	check(elite.elite and eb != null and eb.visible and eb.always, "furioso: barrinha sempre à mostra")
	var boss = m._spawn(&"onca_alfa", room, room.center() + Vector3(0, 0.1, 6))
	await _frames(3)
	check(boss.get_node_or_null("BarraVida") == null, "chefe sem barrinha em cima (usa a barra da tela)")
	common.health.take_damage(999999, false, true)
	await _frames(3)
	check(not is_instance_valid(bar) or bar.is_queued_for_deletion() or not bar.is_inside_tree(), "morreu: barrinha some")
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
