extends SceneTree
## Folha de poses: cada animação do modelo em 3 momentos (25%, 50%, 75%), vista de 3/4.
##   godot --path . --script res://tests/shot_anims.gd -- model=res://game/art/herois/icamiaba.glb shot=/caminho/prefixo
## (Precisa de tela/xvfb.) Gera prefixo_<animacao>_<n>.png.

var _f := 0
var _model := ""
var _shot := ""
var _anim: AnimationPlayer
var _jobs: Array = []


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
	_anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 45.0
	cam.look_at_from_position(Vector3(2.4, 1.6, 3.0), Vector3(0, 0.85, 0))
	for anim_name in _anim.get_animation_list():
		print(anim_name, " ", _anim.get_animation(anim_name).length)
		for n in 3:
			_jobs.append([anim_name, n])


func _process(_d: float) -> bool:
	var i := _f / 4
	if i >= _jobs.size():
		quit(0)
		return false
	var job: Array = _jobs[i]
	if _f % 4 == 0:
		_anim.play(job[0])
		_anim.seek(_anim.get_animation(job[0]).length * float(OS.get_environment("FRAC_" + str(job[1])) if OS.has_environment("FRAC_" + str(job[1])) else str(0.25 + 0.25 * job[1])), true)
		_anim.pause()
	if _f % 4 == 3:
		root.get_viewport().get_texture().get_image().save_png("%s_%s_%d.png" % [_shot, job[0], job[1]])
	_f += 1
	return false
