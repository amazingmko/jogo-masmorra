extends SceneTree
## Teleportes e saltos nunca deixam o herói preso dentro de obstáculo (tronco caído, pedra, sumaúma):
## Espelho do Rio (Encantado), salto da Onça (Druida) e o salto encadeado da Onça-Pintada Alfa.
## Para cada obstáculo, várias distâncias e ângulos; no fim o corpo do herói não pode estar
## encostando dentro de nenhum sólido.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_dash.gd

const KINDS := ["tronco_caido", "pedra_musgo", "sumauma"]
const DISTS := [1.2, 2.0, 3.0, 4.0, 5.0]
const ANGLES := [-60.0, -25.0, 0.0, 25.0, 60.0]
## Desvio para o lado: o caminho passa raspando na ponta do obstáculo (o corpo tem 0,8 m de largura).
const SIDE := [0.0, 0.7, 1.1, 1.5]

var _ok := true
var _gs
var _main
var _player
var _kit
var _stuck := 0
var _cases := 0


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_gs = root.get_node("GameState")
	for hero in [&"encantado", &"druida"]:
		await _hero(hero)
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)


func _hero(hero: StringName) -> void:
	_gs.selected_hero = hero
	_gs.progress(hero).level = 40
	_gs.progress(hero)["talents"] = {}
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(8)
	_main = current_scene
	_player = _main.get_node("Player")
	_kit = _player.kit
	_stuck = 0
	_cases = 0
	var room = _main.builder.rooms[_main.layout.start_index]
	var rd = load("res://game/scripts/dungeon/room_decor.gd")
	for kind in KINDS:
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		for n in room.get_children():
			if String(n.name).begins_with("Teste"):
				n.queue_free()
		var holder := Node3D.new()
		holder.name = "Teste_" + kind
		room.add_child(holder)
		if kind == "sumauma":
			load("res://game/scripts/dungeon/dungeon_builder.gd").box(holder, Vector3(1.2, 2.0, 1.2), Vector3(0, 1.0, 0), null)
		else:
			var size := Vector3(1.2, 1.0, 1.2) if kind == "pedra_musgo" else Vector3(2.6, 0.7, 0.8)
			var xf := Transform3D(Basis(Vector3.UP, PI * 0.5) if kind == "tronco_caido" else Basis(), Vector3.ZERO)
			rd._solid(holder, kind, xf, size)
		holder.position = Vector3(0, 0, 0)
		await _frames(2)
		for combo in _combos():
				var dist: float = combo[0]
				var ang: float = combo[1]
				var side: float = combo[2]
				var dir := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(ang))
				var lateral := Vector3(-dir.z, 0, dir.x) * side
				_player.global_position = room.center() - dir * dist + lateral + Vector3(0, 0.05, 0)
				_player.velocity = Vector3.ZERO
				_player.reset_physics_interpolation()
				await _frames(2)
				var before: Vector3 = _player.global_position
				if hero == &"encantado":
					_player._facing = dir
					_kit._skill_cd = 0.0
					_kit._charges = _kit.max_charges()
					_kit.try_skill()
				else:
					# alvo do outro lado do obstáculo: a Onça salta na direção dele
					var target = _main._spawn(&"queixada", room, room.center() + dir * 3.0 + lateral + Vector3(0, 0.1, 0))
					target.set_physics_process(false)
					_player._form_cooldown = 0.0
					_player.set_form(_player.Form.ONCA)
					_kit._instinct = true
					_player._target = target
					_kit.before_attack()
					target.queue_free()
				_cases += 1
				if _inside_solid():
					_stuck += 1
					if _stuck <= 6:
						print("  preso: %s a %.1f m, %.0f°, %.1f m de lado (andou %.1f m)" % [kind, dist, ang, side, before.distance_to(_player.global_position)])
				await _frames(1)
		for n in get_nodes_in_group("floor_effects"):
			n.queue_free()
	check(_stuck == 0, "%s: nunca fica preso dentro do obstáculo (%d de %d casos presos)" % [hero, _stuck, _cases])
	if hero == &"encantado":
		# Encostado na pedra, de costas para ela: o Espelho ainda leva os 5 m inteiros.
		var dir := Vector3(-1, 0, 0)
		_player.global_position = room.center() + Vector3(-1.0, 0.05, 0)  # colado no lado da sumaúma (1,2 m)
		_player.reset_physics_interpolation()
		await _frames(2)
		var p0: Vector3 = _player.global_position
		_player._facing = dir
		_kit._skill_cd = 0.0
		_kit._charges = _kit.max_charges()
		_kit.try_skill()
		var moved: float = p0.distance_to(_player.global_position)
		check(moved > 4.5, "Espelho encostado num obstáculo, indo para longe dele: andou %.1f m" % moved)


func _combos() -> Array:
	var out := []
	for d in DISTS:
		for a in ANGLES:
			for s in SIDE:
				out.append([d, a, s])
	return out


## O corpo do herói (cápsula) está entrando em algum sólido?
func _inside_solid() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36   # um pouco menor que o corpo (0,4): encostar de leve não conta
	cap.height = 1.5
	q.shape = cap
	q.transform = Transform3D(Basis(), _player.global_position + Vector3(0, 0.85, 0))
	q.collision_mask = 1  # Layers.WORLD
	q.exclude = [_player.get_rid()]
	var hits: Array = _player.get_world_3d().direct_space_state.intersect_shape(q, 4)
	for h in hits:
		var c = h.collider
		# o chão não conta
		if c is StaticBody3D and c.get_child_count() > 0:
			var shape_node = c.get_child(0)
			if shape_node is CollisionShape3D and shape_node.shape is BoxShape3D and shape_node.shape.size.y < 1.0 and shape_node.shape.size.x > 30.0:
				continue
		return true
	return false
