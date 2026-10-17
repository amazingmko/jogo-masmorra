extends SceneTree
## Folha das peças do ambiente (game/art/ambiente/*.glb), cada uma no tamanho do jogo, ao lado
## de uma heroína de 1,7 m para comparar. Precisa de tela/xvfb:
##   godot --path . --script res://tests/shot_ambiente.gd -- shot=/caminho/foto.png
var _f := 0
var _shot := "/tmp/ambiente.png"
var _only := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			_shot = arg.trim_prefix("shot=")
		elif arg.begins_with("so="):
			_only = arg.trim_prefix("so=")
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
	var x := 0.0
	var names: Array[String] = []
	for f in DirAccess.get_files_at("res://game/art/ambiente"):
		if f.ends_with(".glb") and (_only == "" or f.get_basename() in _only.split(",")):
			names.append(f.get_basename())
	names.sort()
	var hero: Node3D = load("res://game/art/herois/icamiaba.glb").instantiate()
	root3d.add_child(hero)
	hero.position = Vector3(x, 0, 0)
	x += 1.6
	var rd = load("res://game/scripts/dungeon/room_decor.gd")
	for n in names:
		var node: Node3D = rd._instance(n)
		root3d.add_child(node)
		var w: float = rd._piece(n).mesh.get_aabb().size.x * rd._piece(n).base.basis.get_scale().x
		x += w * 0.5 + 0.4
		node.position = Vector3(x, 0, 0)
		x += w * 0.5 + 0.4
		print(n, " largura ", snappedf(w, 0.01))
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 40.0
	var mid := x * 0.5
	cam.look_at_from_position(Vector3(mid, 4.0 + x * 0.25, 4.0 + x * 0.55), Vector3(mid, 0.8, 0))


func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		root.get_viewport().get_texture().get_image().save_png(_shot)
		quit()
	return false
