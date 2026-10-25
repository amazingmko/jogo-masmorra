extends SceneTree
## Capturas do hub de verdade (Salão dos Portais): visão do jogo ao entrar, perto de cada estação
## (com o botão de ação) e uma vista de cima.
##   godot --path . --fixed-fps 60 --script res://tests/shot_salao.gd -- out=/pasta

var _out := "/tmp"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/hub_%s.png" % [_out, name])


func _run() -> void:
	change_scene_to_file("res://game/scenes/hub.tscn")
	await _frames(30)
	var hub = current_scene
	var p = hub.get_node("Player")
	var cam: Camera3D = hub.get_node("Camera")
	_shot("entrada")
	for spot in [["portal", Vector3(-8.4, 0.1, -9.4)], ["altar", Vector3(7.5, 0.1, 5.2)], ["oficina", Vector3(0, 0.1, 10.4)], ["bau", Vector3(-7.5, 0.1, 4.6)]]:
		p.global_position = spot[1]
		p.reset_physics_interpolation()
		cam.snap()
		await _frames(20)
		_shot(spot[0])
	# vista de cima (câmera solta)
	cam.set_script(null)
	cam.global_position = Vector3(0, 26, 20)
	cam.look_at(Vector3(0, 0, -2), Vector3.UP)
	cam.fov = 55.0
	await _frames(6)
	_shot("cima")
	quit(0)
