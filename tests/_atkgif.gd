extends SceneTree
## temporário: grava um bicho fazendo ataques escolhidos
var _f := 0
var _m
var _e
var _p
var _queue := []
var _out := ""
var _cam: Camera3D
func _initialize():
	_out = OS.get_environment("OUT")
	_queue = OS.get_environment("ATKS").split(",")
func _process(_d):
	_f += 1
	if _f == 1:
		root.get_node("GameState").selected_hero = &"icamiaba"
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f == 12:
		_m = current_scene
		for e in get_nodes_in_group("enemies"): e.queue_free()
		_p = _m.get_node("Player")
		_p.health.max_health = 999999; _p.health.health = 999999
		var room = _m.builder.rooms[_m.layout.start_index]
		_p.global_position = room.center() + Vector3(float(OS.get_environment("PX")), 0.1, 1.0)
		_e = _m._spawn(StringName(OS.get_environment("ID")), room, room.center() + Vector3(-1, 0.1, 0))
		_e._awake = true
		_cam = Camera3D.new()
		_m.add_child(_cam)
		_cam.current = true
	if _cam and is_instance_valid(_e):
		var c: Vector3 = _e.global_position
		_cam.global_position = c + Vector3(float(OS.get_environment("CZ")) * 0.5, float(OS.get_environment("CY")), float(OS.get_environment("CZ")))
		_cam.look_at(c + Vector3(0, 1.0, 0))
	if _f > 14 and _e and _e.state == _e.State.MOVE and not _queue.is_empty() and _f % 2 == 0:
		var id = _queue[0]
		for a in _e._attacks:
			if String(a.id) == id:
				_e.velocity = Vector3.ZERO
				_e._start(a)
				_queue.pop_front()
				break
	if _f >= 16 and _f % 2 == 0:
		var img := root.get_viewport().get_texture().get_image()
		img.resize(480, 270)
		img.save_png(_out + "/f_%04d.png" % _f)
	if _f > 16 and _queue.is_empty() and _e.state == _e.State.MOVE:
		quit()
	if _f > 1400: quit()
	return false
