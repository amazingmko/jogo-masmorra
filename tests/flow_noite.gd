extends SceneTree
## Noite na mata: andares 1-5 de dia; no Acampamento (andar 5) anoitece; andares 6-10 de noite,
## com a tocha do herói, bordas escuras, olhos nos bichos, cogumelos acesos e a lua no igarapé.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_noite.gd

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
	root.get_node("GameState").selected_hero = &"mateira"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(12)
	var m = current_scene
	var n = m.night
	check(not n.is_night and n.amount < 0.01, "andar 1: dia")
	m.debug_jump_to_floor(4)
	await _frames(10)
	check(not n.is_night, "andar 4: dia")
	# andar 5: vence a Alfa -> anoitece no Acampamento
	m.debug_jump_to_floor(5)
	await _frames(20)
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	p.global_position = m.builder.rooms[m.layout.goal_index].center() + Vector3(0, 0.1, 5)
	for i in 30:
		await physics_frame
	for e in get_nodes_in_group("enemies"):
		e.take_hit(9999999, false, Vector3.FORWARD)
	await _frames(20)
	check(n.is_night and n.amount > 0.0 and n.amount < 1.0, "Acampamento: começou a anoitecer (%.2f)" % n.amount)
	await _frames(int(m.NIGHTFALL_SECONDS * 60) + 20)
	check(n.amount > 0.99, "anoiteceu de vez")
	var env: Environment = m.get_node("WorldEnvironment").environment
	check(env.ambient_light_energy < 0.7, "luz da sala de noite (%.2f)" % env.ambient_light_energy)
	check(p.get_node("Tocha").visible and p.get_node("Tocha").light_energy > 2.0, "tocha do herói acesa")
	# andar 6: começa de noite, bichos com olhos
	m.debug_jump_to_floor(6)
	await _frames(20)
	check(n.is_night and n.amount > 0.99, "andar 6: noite")
	var room = m.builder.rooms[m.layout.start_index]
	var e = m._spawn(&"queixada", room, room.center() + Vector3(3, 0.1, 0))
	await _frames(5)
	check(e.get_node_or_null("OlhosNoite") != null, "de noite os bichos têm olhos brilhando")
	var water_ok := true
	for w in m.find_children("Agua", "MeshInstance3D", true, false):
		water_ok = water_ok and float(w.material_override.get_shader_parameter("lua")) > 0.99
	check(water_ok, "a lua no igarapé")
	var lamp: OmniLight3D = p.get_node("Tocha")
	check((lamp.light_cull_mask & Layers.WATER_VISUAL) == 0, "a tocha não ilumina (nem reflete) a água")
	var has_mush := false
	for d in m.find_children("Decor_*", "MultiMeshInstance3D", true, false):
		has_mush = has_mush or String(d.get_meta("kind", "")) == "cogumelos"
	if has_mush:
		check(not n._spores.is_empty() and m.find_children("Esporos", "MultiMeshInstance3D", true, false).size() > 0, "esporos acesos em cima dos cogumelos")
		var no_override := true
		for d in m.find_children("Decor_*", "MultiMeshInstance3D", true, false):
			if String(d.get_meta("kind", "")) == "cogumelos" and d.material_override != null:
				no_override = false
		check(no_override, "os cogumelos mantêm a pintura (sem material de brilho por cima)")
	check(float(m._loot_context("normal").reward_mult) > 1.2, "de noite rende mais reagentes")
	# tecla de teste
	n.set_night(false)
	check(not n.is_night and n.amount < 0.01 and not p.get_node("Tocha").visible, "dia de novo (teste)")
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
