extends SceneTree
## Simulação de combate sem tela: um "robô" joga a arena segurando ataque e andando
## até o inimigo mais próximo. Serve para pegar erros de execução e ter uma ideia
## grosseira de balanceamento (quantas ondas cada herói aguenta parado no corpo a corpo).
##
## (Autoloads são acessados por root.get_node porque este script compila antes deles existirem.)
## Rodar:  godot --headless --fixed-fps 60 --path . --script res://tests/sim_combat.gd -- hero=guardiao

const MAX_SECONDS := 150

var _main: Node
var _frames := 0
var _hero := &"guardiao"
var _loot_before := 0
var _shot_path := ""
var _shot_frame := 360


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("hero="):
			_hero = StringName(arg.trim_prefix("hero="))
		elif arg.begins_with("shot="):
			_shot_path = arg.trim_prefix("shot=")
		elif arg.begins_with("shot_at="):
			_shot_frame = int(arg.trim_prefix("shot_at=")) * 60


func _process(_delta: float) -> bool:
	if _main == null:
		_main = load("res://game/scenes/main.tscn").instantiate()
		root.add_child(_main)
		return false
	_frames += 1
	var player = _main.get_node("Player")  # sem tipo: Player depende dos autoloads
	var hud = _main.get_node("HUD")
	if _frames == 2:
		player.set_hero(root.get_node("ItemDB").get_hero(_hero))
		_loot_before = _count_loot()
		Input.action_press("attack")

	# Robô: anda até o inimigo mais próximo (para no alcance da arma) ou até o loot.
	var goal: Node3D = _nearest(player, "enemies")
	var stop_at: float = player.weapon_stats.attack_range * (0.8 if player.weapon_stats.is_ranged() else 0.7)
	if goal == null:
		goal = _nearest(player, "pickups")
		stop_at = 0.0
	var move := Vector2.ZERO
	if goal:
		var to: Vector3 = goal.global_position - player.global_position
		if Vector2(to.x, to.z).length() > stop_at:
			move = Vector2(to.x, to.z).normalized()
	hud.joystick.value = move

	# Captura de tela opcional (só funciona com renderização, não em --headless).
	if _shot_path != "" and _frames == _shot_frame:
		root.get_viewport().get_texture().get_image().save_png(_shot_path)
		print("captura salva em ", _shot_path)

	if _frames % 600 == 0:
		print("t=%ds onda=%d vida=%d armadura=%d inimigos=%d" % [
			_frames / 60, _main._wave_index + 1, player.health.health, player.health.armor,
			get_nodes_in_group("enemies").size()])

	if _main._run_over or _frames > MAX_SECONDS * 60:
		var result := "VENCEU a sala" if not player.health.is_dead and _main._run_over else (
			"CAIU na onda %d" % (_main._wave_index + 1) if player.health.is_dead else "tempo esgotado")
		print("RESULTADO [%s]: %s em %ds; itens recolhidos: %d" % [
			_hero, result, _frames / 60, _count_loot() - _loot_before])
		Input.action_release("attack")
		quit(0)
	return false


func _nearest(player: Node3D, group: String) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in get_nodes_in_group(group):
		var d := player.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _count_loot() -> int:
	var total := 0
	for k in root.get_node("GameState").inventory.stacks:
		total += root.get_node("GameState").inventory.stacks[k]
	return total + root.get_node("GameState").inventory.equipment.size()
