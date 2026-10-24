extends SceneTree
## Encostar nas coisas do mapa e nos bichos:
## - o herói, andando contra muros, pilares, pedras, moitas e as outras peças da borda, para
##   encostado nelas (não entra dentro do desenho);
## - as portas continuam livres (as peças novas com colisão não tapam o vão);
## - quem fica fora da sala quando ela fecha aparece logo depois da porta (não no meio da sala);
## - bicho corpo a corpo para encostado no herói para bater (não entra dentro dele) e ainda acerta.
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_encostar.gd

var _ok := true
const HERO_R := 0.38
const MELEE := [&"formiga_fogo", &"queixada", &"jararaca", &"aranha_caranguejeira", &"onca_pintada"]


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Do centro da peça até a borda do desenho dela, na direção `dir` (caixa medida no modelo).
func _visual_extent(kind: String, xf: Transform3D, dir: Vector3) -> float:
	var rd = load("res://game/scripts/dungeon/room_decor.gd")
	var piece: Dictionary = rd._piece(kind)
	var a: AABB = piece.base * (piece.mesh as Mesh).get_aabb()
	var s := xf.basis.get_scale().x
	var b := xf.basis.orthonormalized()
	var lx := absf(dir.dot(b.x))
	var lz := absf(dir.dot(b.z))
	var hx := a.size.x * 0.5 * s
	var hz := a.size.z * 0.5 * s
	if rd.COLLIDE.has(kind) and rd.COLLIDE[kind][1]:
		return (hx + hz) * 0.5  # peça redonda: o desenho é um círculo, não a caixa
	var tx := hx / maxf(lx, 0.001)
	var tz := hz / maxf(lz, 0.001)
	return minf(tx, tz)


func _run() -> void:
	root.get_node("GameState").selected_hero = &"icamiaba"
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(12)
	var m = current_scene
	var p = m.get_node("Player")
	p.health.max_health = 999999
	p.health.health = 999999
	var rd = load("res://game/scripts/dungeon/room_decor.gd")
	var half := DungeonRoom.SIZE * 0.5

	var tested := 0
	var worst := {}   # tipo -> maior entrada (m)
	var stuck_doors := 0
	var doors := 0
	var far_entries := 0
	var entries := 0
	for f in [1, 3]:
		if f > 1:
			m.debug_jump_to_floor(f)
			await _frames(10)
		for prop in m.builder.props.values():
			prop.used = true
		for room in m.builder.rooms:
			room.cleared = true
			room.open_doors()
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		await _frames(30)  # cipós das portas abrindo
		for room in m.builder.rooms:
			var c: Vector3 = room.center()
			# --- peças da borda e do meio: andar contra elas ---
			var pieces := []  # [tipo, xf no mundo]
			for n in room.get_children():
				if n is MultiMeshInstance3D and rd.COLLIDE.has(String(n.get_meta("kind", ""))):
					for x: Transform3D in n.get_meta("xforms"):
						pieces.append([String(n.get_meta("kind")), room.global_transform * x])
				elif n is Node3D and String(n.name).begins_with("sumauma"):
					pieces.append(["sumauma", n.global_transform])
			var count := 0
			for pc in pieces:
				var kind: String = pc[0]
				var xf: Transform3D = pc[1]
				var local: Vector3 = xf.origin - c
				if maxf(absf(local.x), absf(local.z)) > half + 1.2:
					continue  # longe demais da área de andar
				count += 1
				if count > 7:
					break
				var to_piece := Vector3(local.x, 0, local.z)
				var start := c + to_piece.normalized() * maxf(to_piece.length() - 3.2, 0.0)
				start.x = clampf(start.x, c.x - half + 0.6, c.x + half - 0.6)
				start.z = clampf(start.z, c.z - half + 0.6, c.z + half - 0.6)
				p.global_position = start + Vector3(0, 0.1, 0)
				p.velocity = Vector3.ZERO
				p.reset_physics_interpolation()
				await physics_frame
				var target := Vector3(xf.origin.x, 0, xf.origin.z)
				for i in 100:
					var d := target - Vector3(p.global_position.x, 0, p.global_position.z)
					p.touch_move = Vector2(d.x, d.z).normalized() if d.length() > 0.05 else Vector2.ZERO
					await physics_frame
				p.touch_move = Vector2.ZERO
				var gap := Vector3(p.global_position.x, 0, p.global_position.z) - target
				var dist := gap.length()
				var into := _visual_extent(kind, xf, gap.normalized() if dist > 0.01 else Vector3.RIGHT) - (dist - HERO_R)
				worst[kind] = maxf(float(worst.get(kind, -9.0)), into)
				tested += 1
			# --- portas: sair da sala por cada uma ---
			for d: Vector2i in room._door_dirs:
				var out := Vector3(d.x, 0, d.y)
				doors += 1
				p.global_position = c + Vector3(0, 0.1, 0)
				p.velocity = Vector3.ZERO
				p.reset_physics_interpolation()
				await physics_frame
				for i in 150:
					p.touch_move = Vector2(out.x, out.z)
					await physics_frame
				p.touch_move = Vector2.ZERO
				if (p.global_position - c).dot(out) < half + 1.0:
					stuck_doors += 1
					print("  porta presa: %s lado %s (parou a %.1f m do centro)" % [room.name, d, (p.global_position - c).dot(out)])
				# --- quem ficou fora: aparece logo depois da porta ---
				if not room.has_method("entry_point"):
					continue
				entries += 1
				var door_c := c + out * half
				var ep: Vector3 = room.entry_point(c + out * (half + 3.0), 1)
				if not room.contains(ep) or ep.distance_to(door_c) > 3.2:
					far_entries += 1
	p.touch_move = Vector2.ZERO
	var limits := {"moita": 0.5}
	var bad := 0
	for kind in worst:
		var lim: float = limits.get(kind, 0.35)
		var good: bool = worst[kind] <= lim
		if not good:
			bad += 1
		print("  %-15s entra no máximo %.2f m%s" % [kind, worst[kind], "" if good else "  <-- demais"])
	check(tested > 20, "peças testadas: %d" % tested)
	check(bad == 0, "o herói encosta nas peças sem entrar no desenho (%d tipos passaram do limite)" % bad)
	check(stuck_doors == 0, "todas as portas continuam livres (%d de %d presas)" % [stuck_doors, doors])
	check(far_entries == 0, "quem fica fora entra logo depois da porta (%d de %d longe)" % [far_entries, entries])

	# --- sala fechando com o herói no corredor (o que o anfitrião faz) ---
	var room0 = m.builder.rooms[m.layout.start_index]
	if not room0._door_dirs.is_empty() and room0.has_method("entry_point"):
		var d0: Vector2i = room0._door_dirs[0]
		var out0 := Vector3(d0.x, 0, d0.y)
		p.global_position = room0.center() + out0 * (half + 2.5) + Vector3(0, 0.1, 0)
		p.reset_physics_interpolation()
		m._pull_heroes_into(room0)
		var door0: Vector3 = room0.center() + out0 * half
		var dd := Vector3(p.global_position.x, 0, p.global_position.z).distance_to(Vector3(door0.x, 0, door0.z))
		check(room0.contains(p.global_position) and dd < 3.2, "puxado para dentro fica perto da porta (%.1f m dela)" % dd)

	# --- bichos corpo a corpo: param encostados ---
	for room in m.builder.rooms:
		room.cleared = true
	var arena = m.builder.rooms[m.layout.start_index]
	for id in MELEE:
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
		await _frames(2)
		p.global_position = arena.center() + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.health.health = 999999
		p.health.armor = p.health.max_armor
		var e = m._spawn(id, arena, arena.center() + Vector3(4.0, 0.1, 1.0))
		if e == null:
			continue
		await _frames(2)
		var reach: float = float(e.get("_body_reach")) if e.get("_body_reach") != null else 0.4 * e.data.body_scale
		var body_in: float = HERO_R + reach * 0.45
		var inside := 0
		var frames := 0
		var closest := 99.0
		var hp0: int = p.health.health + p.health.armor
		for i in 420:
			p.global_position = arena.center() + Vector3(0, p.global_position.y - arena.center().y, 0)
			await physics_frame
			if not is_instance_valid(e) or e.state == e.State.DEAD:
				break
			var dd := Vector2(e.global_position.x - p.global_position.x, e.global_position.z - p.global_position.z).length()
			closest = minf(closest, dd)
			frames += 1
			if dd < body_in:
				inside += 1
		var hit: bool = p.health.health + p.health.armor < hp0
		var share := float(inside) / maxf(frames, 1)
		check(share < 0.05 and hit, "%s: encosta sem entrar no herói (mais perto %.2f m, dentro %.0f%% do tempo, espaço %.2f m) e acerta (%s)" % [id, closest, share * 100.0, float(e.get("_personal_space")) if is_instance_valid(e) and e.get("_personal_space") != null else 0.0, "sim" if hit else "não"])
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
