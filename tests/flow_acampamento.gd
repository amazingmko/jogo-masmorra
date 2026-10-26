extends SceneTree
## Andar 5: a Onça Alfa cai e aparece o Acampamento. A fogueira pergunta (voltar ou continuar);
## "Continuar" não encerra a run e o portal leva ao andar 6; "Voltar" encerra e o portal não faz mais nada.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_acampamento.gd

var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _camp_floor():
	root.get_node("GameState").selected_hero = &"mateira"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(12)
	var m = current_scene
	m.debug_jump_to_floor(5)
	await _frames(20)
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	var room = m.builder.rooms[m.layout.goal_index]
	p.global_position = room.center() + Vector3(0, 0.1, 5)
	for i in 30:
		await physics_frame
	var alfa = null
	for e in get_nodes_in_group("enemies"):
		if e.data.id == &"onca_alfa":
			alfa = e
	check(alfa != null, "andar 5: a Onça Alfa está na sala do chefe")
	if alfa:
		alfa.take_hit(9999999, false, Vector3.FORWARD)
	await _frames(40)
	var camp = m.find_children("Fogueira", "Area3D", true, false)
	var portal = m.find_children("Portal", "Area3D", true, false)
	check(camp.size() == 1 and portal.size() == 1, "acampamento: fogueira e portal apareceram")
	return [m, camp[0] if camp.size() else null, portal[0] if portal.size() else null]


func _run() -> void:
	# 1) fogueira -> Continuar -> portal -> andar 6
	var r = await _camp_floor()
	var m = r[0]
	var camp = r[1]
	var portal = r[2]
	camp.used = true
	m._on_prop_activated(camp)
	check(m._hud.is_asking(), "fogueira: pergunta se volta ou continua")
	m._hud._on_panel_button(false)
	check(not m._run_over and not m._hud.is_asking(), "Continuar: a run segue")
	check(not camp.used, "Continuar: a fogueira pode ser usada de novo")
	m._on_prop_activated(portal)
	await _frames(40)
	check(m.floor_number == 6, "portal do acampamento: desceu para o andar 6 (andar %d)" % m.floor_number)
	check(m._loading.visible, "a tela de carregamento fica aberta um tempo (não pisca)")
	await _frames(120)
	check(not m._loading.visible, "a tela de carregamento sumiu (não congelou)")
	# 2) fogueira -> Voltar -> fim da run; o portal não faz nada
	r = await _camp_floor()
	m = r[0]
	camp = r[1]
	portal = r[2]
	m._on_prop_activated(camp)
	m._hud._on_panel_button(true)
	check(m._run_over, "Voltar à base: a run termina com o resumo")
	m._on_prop_activated(portal)
	await _frames(40)
	check(m.floor_number == 5 and not m._loading.visible, "depois de voltar, o portal não troca de andar nem trava na tela de carregamento")
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
