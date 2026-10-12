extends SceneTree
## Robô que joga uma run inteira sem tela: luta, recolhe loot, abre baús, anda até o portal,
## escolhe o primeiro buff e desce, até vencer o chefe ou cair. Serve para achar erros de
## execução e ter uma noção grosseira de dificuldade. O robô nunca desvia de propósito.
##
## Rodar:
##   godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=guardiao seed=123
## Com captura de tela (precisa de tela/xvfb, sem --headless):
##   ... -- hero=arcanista shot=/caminho/foto.png shot_at=20
## (Autoloads e classes que dependem deles ficam sem tipo aqui: este script compila antes deles existirem.)

const MAX_SECONDS := 900

var _main: Node
var _frames := 0
var _hero := &"guardiao"
var _seed := 0
var _shot_path := ""
var _shot_frame := 1200
var _shot_on_buff := false
var _buff_wait := 0
var _last_pos := Vector3.ZERO
var _stuck_frames := 0
var _detour := 0
var _floor_seen := 0
var _floor_started := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("hero="):
			_hero = StringName(arg.trim_prefix("hero="))
		elif arg.begins_with("seed="):
			_seed = int(arg.trim_prefix("seed="))
		elif arg.begins_with("shot="):
			_shot_path = arg.trim_prefix("shot=")
		elif arg == "shot_on=buff":
			_shot_on_buff = true
		elif arg.begins_with("shot_at="):
			_shot_frame = int(arg.trim_prefix("shot_at=")) * 60


func _process(_delta: float) -> bool:
	if _main == null:
		_main = load("res://game/scenes/main.tscn").instantiate()
		root.add_child(_main)
		return false
	_frames += 1
	var player = _main.get_node("Player")
	var hud = _main.get_node("HUD")
	if _frames == 2:
		player.set_hero(root.get_node("ItemDB").get_hero(_hero))
		if _seed > 0:
			_main.new_run(_seed)
		Input.action_press("attack")
		return false

	# Escolha de buff: pega a primeira carta.
	if hud._buff_panel.visible:
		if _shot_on_buff and _shot_path != "":
			_buff_wait += 1
			if _buff_wait == 30:
				RenderingServer.force_draw(true)
				root.get_viewport().get_texture().get_image().save_png(_shot_path)
				print("captura salva em ", _shot_path)
				quit(0)
			return false
		var cards: Array = hud._buff_cards.get_children()
		if not cards.is_empty():
			cards[0].pressed.emit()
		return false

	if _main.floor_number != _floor_seen:
		if _floor_seen > 0:
			print("  andar %d concluído em %ds (vida %d/%d)" % [_floor_seen, (_frames - _floor_started) / 60,
				player.health.health, player.health.max_health])
		_floor_seen = _main.floor_number
		_floor_started = _frames

	hud.joystick.value = _steer(player)

	if _shot_path != "" and _frames == _shot_frame:
		root.get_viewport().get_texture().get_image().save_png(_shot_path)
		print("captura salva em ", _shot_path)
		Input.action_release("attack")
		quit(0)  # com captura, o objetivo é só a foto
		return false

	if _main._run_over or _frames > MAX_SECONDS * 60:
		var result: String = "tempo esgotado no andar %d" % _main.floor_number
		if _main._run_over:
			result = "CAIU no andar %d" % _main.floor_number if player.health.is_dead else "VENCEU a run"
		print("RESULTADO [%s, semente %d]: %s em %ds; abates %d; buffs %s" % [
			_hero, _main.run_seed, result, _frames / 60, _main._stats.kills, _main._stats.buffs])
		Input.action_release("attack")
		quit(0 if _main._run_over else 1)
	return false


func _steer(player: Node3D) -> Vector2:
	var pos: Vector3 = player.global_position
	var target := _choose_target(player)

	# Destravar: se não sai do lugar, vai um tempo em direção ao centro da sala.
	if pos.distance_to(_last_pos) < 0.02 and target != Vector3.INF:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	_last_pos = pos
	if _stuck_frames > 20:
		_detour = 45
		_stuck_frames = 0
	if _detour > 0 and _main._current_room:
		_detour -= 1
		target = _main._current_room.center()

	if target == Vector3.INF:
		return Vector2.ZERO
	var to := target - pos
	var flat := Vector2(to.x, to.z)
	return flat.normalized() if flat.length() > 0.3 else Vector2.ZERO


func _choose_target(player: Node3D) -> Vector3:
	var pos: Vector3 = player.global_position
	# 1) inimigos
	var enemy := _nearest(pos, get_nodes_in_group("enemies"))
	if enemy:
		var reach: float = player.weapon_stats.attack_range * (0.8 if player.weapon_stats.is_ranged() else 0.7)
		if pos.distance_to(enemy.global_position) > reach:
			return enemy.global_position
		return Vector3.INF
	# 2) loot por perto
	var pickup := _nearest(pos, get_nodes_in_group("pickups"))
	if pickup and pos.distance_to(pickup.global_position) < 12.0:
		return pickup.global_position
	# 3) próxima sala: baús ainda fechados primeiro, depois o objetivo
	var layout = _main.layout
	var builder = _main.builder
	var cur = _main._current_room
	if layout == null or cur == null:
		return Vector3.INF
	var goal_index: int = layout.goal_index
	for idx in builder.props:
		var prop = builder.props[idx]
		if prop.kind == 0 and not prop.used:  # baú
			goal_index = idx
			break
	if cur.index == goal_index:
		return cur.center()  # baú, portal ou centro da sala do chefe
	var path: Array = layout.path(cur.index, goal_index)
	if path.size() < 2:
		return Vector3.INF
	var next = builder.rooms[path[1]]
	var dir: Vector3 = (next.center() - cur.center()).normalized()
	var rel: Vector3 = pos - cur.center()
	var along := rel.dot(dir)
	var lateral := (rel - dir * along).length()
	# Primeiro se alinha com a porta, depois atravessa até o centro da próxima sala.
	if lateral > 0.8:
		return cur.center() + dir * maxf(along, 0.0)
	return next.center()


func _nearest(pos: Vector3, nodes: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in nodes:
		var d := pos.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
