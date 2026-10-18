extends SceneTree
## Luz do cenário: só o chão recebe a sombra do sol. Pedras, troncos, plantas, inimigos e a heroína
## não podem receber (no renderizador Mobile isso deixava o objeto inteiro escuro, "apagado").
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_luz.gd

var _f := 0
var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _count(node: Node, out: Dictionary) -> void:
	var mats: Array = []
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mats.append(mi.material_override)
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				mats.append(mi.get_active_material(i))
	elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
		for i in node.multimesh.mesh.get_surface_count():
			mats.append(node.multimesh.mesh.surface_get_material(i))
	for m in mats:
		if m is ShaderMaterial and m.shader and "Bichos da mata" in m.shader.code:
			# modelos com shader próprio (bichos): precisam de "shadows_disabled" no render_mode
			out.total += 1
			if not "shadows_disabled" in m.shader.code:
				out.bad += 1
			continue
		if m is BaseMaterial3D:
			if (m as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				continue
			out.total += 1
			if not (m as BaseMaterial3D).disable_receive_shadows:
				out.bad += 1
				if out.bad <= 3:
					print("  recebe sombra: ", node.get_path())
	for c in node.get_children():
		_count(c, out)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		root.get_node("GameState").selected_hero = &"mateira"
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f == 10:
		current_scene.new_run(4242)
	if _f == 20:
		current_scene.spawn_training_dummies()
	if _f == 25:
		var m = current_scene
		for kind in ["sumauma", "pedra_musgo", "tronco_caido", "moita", "samambaia", "arvore_borda", "palmeira", "bromelia", "cogumelos"]:
			var r := {"total": 0, "bad": 0}
			_count(load("res://game/scripts/dungeon/room_decor.gd")._instance(kind), r)
			check(r.total > 0 and r.bad == 0, "%s não recebe sombra (%d materiais)" % [kind, r.total])
		var d := {"total": 0, "bad": 0}
		_count(m.get_node("Dungeon"), d)
		check(d.total > 0 and d.bad == 0, "cenário inteiro: %d materiais, %d recebendo sombra" % [d.total, d.bad])
		var e := {"total": 0, "bad": 0}
		for en in get_nodes_in_group("enemies"):
			_count(en, e)
		check(e.total > 0 and e.bad == 0, "inimigos: %d materiais, %d recebendo sombra" % [e.total, e.bad])
		var p := {"total": 0, "bad": 0}
		_count(m.get_node("Player"), p)
		check(p.total > 0 and p.bad == 0, "heroína: %d materiais, %d recebendo sombra" % [p.total, p.bad])
		var sun: DirectionalLight3D = m.get_node("Sun")
		check(sun.shadow_enabled, "o sol continua fazendo sombra no chão")
		print("RESULTADO: ", "OK" if _ok else "FALHOU")
		quit(0 if _ok else 1)
	return false
