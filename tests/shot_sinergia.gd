extends SceneTree
## Captura do HUD com os selos de sinergia (Druida + Mateira + Encantado).
##   godot --path . --fixed-fps 60 --script res://tests/shot_sinergia.gd -- out=/pasta

var _out := "/tmp"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.run_trial = {}
	gs.selected_hero = &"druida"
	change_scene_to_file("res://game/scenes/main.tscn")
	for i in 30:
		await process_frame
	var m = current_scene
	var db = root.get_node("ItemDB")
	var allies: Array = []
	for id in [&"mateira", &"encantado", &"icamiaba"]:
		var a = load("res://game/scenes/player.tscn").instantiate()
		m.add_child(a)
		a.set_hero(db.get_hero(id))
		a.global_position = m.get_node("Player").global_position + Vector3(1.5 * allies.size() + 1.5, 0, 1)
		allies.append(a)
	m.sim_allies = allies
	m._apply_synergy()
	allies[0].health.health = int(allies[0].health.max_health * 0.8)
	allies[1].health.health = int(allies[1].health.max_health * 0.25)
	allies[2].health.health = int(allies[2].health.max_health * 0.5)
	for i in 160:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/sinergia.png" % _out)
	quit(0)
