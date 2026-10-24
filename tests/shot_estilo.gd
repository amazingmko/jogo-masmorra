extends SceneTree
## Capturas da identidade visual (precisa de tela/xvfb): hub (portal, heróis), luta (números de
## dano, avisos, botões) e o diálogo de fim de run.
##   godot --path . --script res://tests/shot_estilo.gd -- variant=aventura out=/pasta

var _f := 0
var _out := "/tmp"
var _m
var _shots := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("variant="):
			UiStyle.variant = arg.trim_prefix("variant=")
		elif arg.begins_with("out="):
			_out = arg.trim_prefix("out=")


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, UiStyle.variant, name])
	_shots += 1


func _process(_d: float) -> bool:
	_f += 1
	var gs = root.get_node("GameState") if root.has_node("GameState") else null
	if _f == 1:
		gs.selected_hero = &"icamiaba"
		gs.progress(&"icamiaba").level = 12
		change_scene_to_file("res://game/scenes/hub.tscn")
	elif _f == 8:
		current_scene.get_node("HubUI")._open(&"portal")
	elif _f == 24:
		_shot("hub_portal")
		current_scene.get_node("HubUI")._close()
		current_scene.get_node("HubUI")._open(&"herois")
	elif _f == 40:
		_shot("hub_herois")
		change_scene_to_file("res://game/scenes/main.tscn")
	elif _f == 60:
		_m = current_scene
		var p = _m.get_node("Player")
		p.health.max_health = 99999
		p.health.health = 99999
		var room = _m.builder.rooms[_m.layout.start_index]
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		for i in 3:
			var e = _m._spawn(&"queixada", room, p.global_position + Vector3(2.5 + i * 0.8, 0.1, -1.5 + i * 1.2))
			if e:
				e.training_dummy = true
	elif _f == 70:
		var p = _m.get_node("Player")
		var enemies := get_nodes_in_group("enemies")
		for i in enemies.size():
			var e: Node3D = enemies[i]
			Fx.damage_number(_m, e.global_position + Vector3(0, 1.8, 0), [87, 142, 61][i % 3], i == 1)
		Fx.float_text(_m, p.global_position + Vector3(0, 3.0, 0), "MURALHA!", Color("e8c26a"))
		_m._hud.show_toast("+3 Madeira de Lei", Color("6fbf4a"))
		_m._hud.show_toast("Sala limpa!", UiStyle.GOLD)
	elif _f == 84:
		_shot("luta")
		_m._hud.show_panel("Você caiu", "A mata venceu desta vez. Os reagentes e o XP ficam com você.\nMadeira de Lei ×12 · Fibra de Tucum ×8 · Pena de Arara ×2", "Voltar ao hub")
		_m._hud._panel_button2.text = "Jogar de novo"
		_m._hud._panel_button2.visible = true
	elif _f == 100:
		_shot("dialogo")
		print("capturas: ", _shots)
		quit(0)
	return false
