extends SceneTree
## Fotos de um modelo 3D (frente, costas e vista do jogo), para conferir antes de encaixar.
##   godot --path . --script res://tests/shot_model.gd -- model=res://game/art/herois/icamiaba.glb shot=/caminho/prefixo
## (Precisa de tela/xvfb, sem --headless.) Gera prefixo_frente.png, prefixo_costas.png, prefixo_jogo.png.

var _f := 0
var _model := ""
var _shot := ""
var _cam: Camera3D
var _views := [["frente", Vector3(0, 1.0, 3.2)], ["costas", Vector3(0, 1.0, -3.2)], ["jogo", Vector3(0, 11.0, 7.5)]]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("model="):
			_model = arg.trim_prefix("model=")
		elif arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("2b2a33")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root3d.add_child(sun)
	var model: Node3D = load(_model).instantiate()
	root3d.add_child(model)
	_cam = Camera3D.new()
	root3d.add_child(_cam)


func _process(_d: float) -> bool:
	_f += 1
	var i := (_f - 1) / 10
	if i >= _views.size():
		quit(0)
		return false
	if (_f - 1) % 10 == 0:
		var v: Array = _views[i]
		_cam.position = v[1]
		_cam.fov = 40.0 if v[0] != "jogo" else 50.0
		_cam.look_at(Vector3(0, 0.9 if v[0] != "jogo" else 0.4, 0))
	if (_f - 1) % 10 == 8:
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_shot, _views[i][0]])
	return false
