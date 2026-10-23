extends SceneTree
## Cenário: nenhuma peça grande (pedra, tronco, ruína, peças da mata, árvore) em cima de outra.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_sobreposicao.gd

const BIG := ["pedra_musgo", "tronco_caido", "muro_ruina", "pilar_ruina", "totem_pedra", "raiz_gigante",
		"rocha_paredao", "itacoatiara", "cupinzeiro", "toco_oco", "sapopema", "taboca", "palmeira_caida",
		"arvore_tombada", "sauveiro", "arvore_borda", "palmeira", "sumauma"]
var _ok := true


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _radius(kind: String, xf: Transform3D) -> float:
	if kind in ["arvore_borda", "palmeira"]:
		return 0.5 * xf.basis.get_scale().x  # só o tronco (as copas podem se tocar)
	return RoomDecor._footprint(kind, xf)


func _run() -> void:
	root.get_node("GameState").selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/main.tscn")
	for i in 12:
		await process_frame
	var m = current_scene
	var total := 0
	for f in [1, 3, 5, 7, 9]:
		if f > 1:
			m.debug_jump_to_floor(f)
			for i in 10:
				await process_frame
		var items: Array = []  # [kind, Vector2, r]
		for mmi in m.find_children("Decor_*", "MultiMeshInstance3D", true, false):
			var kind := String(mmi.get_meta("kind", ""))
			if not kind in BIG:
				continue
			for xf: Transform3D in mmi.get_meta("xforms", []):
				var g: Transform3D = mmi.global_transform * xf
				items.append([kind, Vector2(g.origin.x, g.origin.z), _radius(kind, xf)])
		for n in m.find_children("sumauma*", "Node3D", true, false):
			items.append(["sumauma", Vector2(n.global_position.x, n.global_position.z), 1.0])
		var bad := 0
		var example := ""
		for i in items.size():
			for j in range(i + 1, items.size()):
				var a: Array = items[i]
				var b: Array = items[j]
				if a[0] in ["arvore_borda", "palmeira"] and b[0] in ["arvore_borda", "palmeira"]:
					continue
				if (a[1] as Vector2).distance_to(b[1]) < (float(a[2]) + float(b[2])) * 0.7:
					bad += 1
					if example == "":
						example = "%s x %s" % [a[0], b[0]]
		total += items.size()
		check(bad == 0, "andar %d: %d peças, %d sobrepostas %s" % [f, items.size(), bad, example])
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
