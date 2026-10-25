extends SceneTree
## Salão dos Portais (hub): um portal por região, chegar perto de um portal escolhe a região dele
## no painel, o herói não cai do salão nem atravessa as paredes, e o Altar dos Heróis mostra o
## herói escolhido (e troca quando troca o herói).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_salao.gd

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
	var gs = root.get_node("GameState")
	var start_hero: StringName = gs.selected_hero
	change_scene_to_file("res://game/scenes/hub.tscn")
	await _frames(10)
	var hub = current_scene
	var ui = hub.get_node("HubUI")
	var p = hub.get_node("Player")
	var hall = hub.get_node("Town/Salao")
	var portals := []
	for n in hall.get_children():
		if n is Area3D and n.station_id == &"portal":
			portals.append(n)
	check(portals.size() == 4, "um portal por região (%d)" % portals.size())
	await _frames(60)
	check(p.global_position.y > -0.3, "herói fica em pé no salão (y %.2f)" % p.global_position.y)
	# chegar perto do portal do Igapó
	var igapo = portals.filter(func(s): return s.region == "igapo")
	check(igapo.size() == 1, "portal do Igapó existe")
	if igapo.size() == 1:
		p.global_position = igapo[0].global_position + Vector3(0, 0.1, 0)
		await _frames(10)
		check(ui._station == igapo[0] and ui._region == "igapo" and ui.action_button.visible, "perto do portal: região escolhida e botão de ação")
	# paredes: andando para fora não sai do salão
	p.global_position = Vector3(10.0, 0.1, 0.0)
	for i in 120:
		ui.joystick.value = Vector2(1, 0)  # o hub copia o joystick para o herói a cada quadro
		await physics_frame
	ui.joystick.value = Vector2.ZERO
	check(p.global_position.x > 10.3 and p.global_position.x < 11.5, "andou até a mureta e ela segura o herói (x %.1f)" % p.global_position.x)
	# Altar dos Heróis
	await _frames(2)
	var spirit_hero: StringName = hall._spirit_hero
	check(spirit_hero == gs.selected_hero and hall._spirit != null, "altar mostra o herói escolhido (%s)" % spirit_hero)
	var other: StringName = &"druida" if gs.selected_hero != &"druida" else &"mateira"
	gs.selected_hero = other
	await process_frame
	await process_frame
	check(hall._spirit_hero == other, "trocar o herói troca o espírito do altar")
	gs.selected_hero = start_hero
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
