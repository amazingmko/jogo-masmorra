extends SceneTree
## Cenário: (1) árvores e palmeiras não tampam a heroína na câmera, nem nas clareiras nem nas
## trilhas; (2) peças grandes não ficam encavaladas (árvore em cima de árvore, tronco dentro de
## pedra); (3) palmeiras aparecem de verdade. Várias masmorras (sementes fixas).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_visao.gd

var RoomDecorRef = load("res://game/scripts/dungeon/room_decor.gd")
const SEEDS := [4242, 7, 1234, 9001, 31337, 555]
const TREE_LAYER := 1 << 15
const TALL := ["arvore_borda", "palmeira"]
const MIN_TREE_GAP := 2.8      # entre troncos de árvore/palmeira
const MAX_OCCLUDED := 0.02     # no máximo 2% dos pontos andáveis tampados

var _f := 0
var _ok := true
var _seed_i := 0
var _occ := 0
var _samples := 0
var _occ_where := {}
var _palms := 0
var _trees := 0
var _close_trees := 0
var _overlaps := 0
var _plant_in_solid := 0
var _water_floors := 0
var _water_in_clearing := 0
var _crossings := 0
var _missing_bridge := 0
var _wet_trees := 0
var _wet_bushes := 0


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		root.get_node("GameState").selected_hero = &"mateira"
		change_scene_to_file("res://game/scenes/main.tscn")
	if _f >= 10 and (_f - 10) % 12 == 0 and _seed_i < SEEDS.size():
		current_scene.new_run(SEEDS[_seed_i])
	if _f >= 10 and (_f - 10) % 12 == 6 and _seed_i < SEEDS.size():
		_measure(current_scene)
	if _f >= 10 and (_f - 10) % 12 == 9 and _seed_i < SEEDS.size():
		_raycasts(current_scene)  # os corpos de teste só entram na física no quadro seguinte
		_seed_i += 1
		if _seed_i >= SEEDS.size():
			_report()
	return false


func _measure(m) -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var dungeon: Node3D = m.get_node("Dungeon")
	var trunks: Array[Vector3] = []
	# copa de verdade: colisão com a malha exata de cada árvore/palmeira, numa camada só do teste
	for mmi in dungeon.find_children("Decor_*", "MultiMeshInstance3D", true, false):
		var kind: String = mmi.get_meta("kind", "")
		if not kind in TALL:
			continue
		var mm: MultiMesh = mmi.multimesh
		var faces: PackedVector3Array = mm.mesh.get_faces()
		var base: Transform3D = RoomDecorRef._piece(kind).base
		for local in mmi.get_meta("xforms"):
			var xf: Transform3D = mmi.global_transform * local
			trunks.append(xf.origin)
			if kind == "palmeira":
				_palms += 1
			else:
				_trees += 1
			var body := StaticBody3D.new()
			body.collision_layer = TREE_LAYER
			body.collision_mask = 0
			# a física ignora a escala do corpo: a escala vai para os vértices
			var full: Transform3D = xf * base
			var baked := PackedVector3Array()
			baked.resize(faces.size())
			for v in faces.size():
				baked[v] = full.basis * faces[v] + (full.origin - xf.origin)
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(baked)
			shape.backface_collision = true
			var col := CollisionShape3D.new()
			col.shape = shape
			body.add_child(col)
			m.add_child(body)
			body.global_position = xf.origin
			_bodies.append(body)
	for i in trunks.size():
		for j in range(i + 1, trunks.size()):
			if Vector2(trunks[i].x - trunks[j].x, trunks[i].z - trunks[j].z).length() < MIN_TREE_GAP:
				_close_trees += 1
	# peças sólidas (pedra, tronco caído, sumaúma): círculos no chão
	var solids := []  # [pos, raio, tipo, sala]
	for room in m.builder.rooms:
		for body in room.get_children():
			if body is StaticBody3D:
				for c in body.get_children():
					if c is Node3D and c.name in ["pedra_musgo", "tronco_caido"]:
						var r: float = (0.75 if c.name == "pedra_musgo" else 1.35) * c.scale.x
						solids.append([body.global_position, r, String(c.name), room.name])
			elif body is Node3D and String(body.name).begins_with("sumauma"):
				solids.append([body.global_position, 1.4, "sumauma", room.name])
	for i in solids.size():
		for j in range(i + 1, solids.size()):
			var a = solids[i]
			var b = solids[j]
			if a[3] != b[3]:
				continue
			var d := Vector2(a[0].x - b[0].x, a[0].z - b[0].z).length()
			if d < a[1] + b[1] + 0.3:
				_overlaps += 1
				print("  encavalados: %s e %s em %s (%.1f m)" % [a[2], b[2], a[3], d])
	# plantinhas do chão dentro de pedra/tronco/sumaúma
	for mmi in dungeon.find_children("Decor_*", "MultiMeshInstance3D", true, false):
		var kind: String = mmi.get_meta("kind", "")
		if not kind in ["bromelia", "cogumelos"]:
			continue
		for local in mmi.get_meta("xforms"):
			var p: Vector3 = (mmi.global_transform * local).origin
			for s in solids:
				if Vector2(p.x - s[0].x, p.z - s[0].z).length() < s[1] * 0.8:
					_plant_in_solid += 1

var _bodies: Array[Node] = []


func _raycasts(m) -> void:
	_water_checks(m)
	# visão: da heroína (peito e cabeça) até a câmera
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	if _seed_i == 0 and not _bodies.is_empty():
		var t: Vector3 = _bodies[0].global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(t + Vector3(0.3, 20, 0.3), t + Vector3(0.3, -1, 0.3), TREE_LAYER))
		var sh: ConcavePolygonShape3D = _bodies[0].get_child(0).shape
		var fz := sh.get_faces()
		var bb := AABB(fz[0], Vector3.ZERO)
		for v in fz: bb = bb.expand(v)
		print("  sonda de cima na 1ª árvore: ", hit.get("position", "nada"), " faces ", fz.size(), " aabb ", bb, " em ", t, " inside ", _bodies[0].is_inside_tree(), " layer ", _bodies[0].collision_layer)
	var offset: Vector3 = m.get_node("Camera").offset
	var points := []
	for room in m.builder.rooms:
		for x in range(-6, 7, 2):
			for z in range(-6, 7, 2):
				points.append([room.global_position + Vector3(x, 0, z), "clareira"])
	for i in m.layout.room_count():
		for n in m.layout.rooms[i].links:
			if n > i:
				var a: Vector3 = m.builder.rooms[i].global_position
				var b: Vector3 = m.builder.rooms[n].global_position
				for k in range(1, 8):
					var t := 0.5 + (float(k) / 8.0 - 0.5) * (8.0 / 22.0)  # só o trecho de trilha
					points.append([a.lerp(b, t), "trilha"])
	for p in points:
		_samples += 1
		for h in [1.0, 1.6]:
			var from: Vector3 = p[0] + Vector3(0, h, 0)
			var q := PhysicsRayQueryParameters3D.create(from, p[0] + offset, TREE_LAYER)
			if not space.intersect_ray(q).is_empty():
				_occ += 1
				_occ_where[p[1]] = int(_occ_where.get(p[1], 0)) + 1
				break
	for b in _bodies:
		b.free()
	_bodies.clear()


## Igarapé: existe, fica fora das clareiras, tem pinguela onde cruza trilha, sem planta dentro.
func _water_checks(m) -> void:
	var ig = m.builder.igarape
	if ig == null or ig.path.size() < 2:
		return
	_water_floors += 1
	var IG = load("res://game/scripts/dungeon/igarape.gd")
	var clearing: float = 7.0 + 0.3 + 1.8   # meia sala + parede + borda que mais se afasta
	for p in ig.path:
		for room in m.builder.rooms:
			var d: Vector3 = p - room.global_position
			if maxf(absf(d.x), absf(d.z)) - IG.HALF_WIDTH < clearing:
				_water_in_clearing += 1
	var bridges: Array = ig.find_children("Pinguela*", "", true, false)
	for line in m.builder.trails:
		var crosses := false
		var where := Vector3.ZERO
		for q in line:
			if IG.distance_to(ig.path, q) < IG.HALF_WIDTH:
				crosses = true
				where = q
		if crosses:
			_crossings += 1
			var ok := false
			for b in bridges:
				if Vector2(b.global_position.x - where.x, b.global_position.z - where.z).length() < 2.0:
					ok = true
			if not ok:
				_missing_bridge += 1
	for mmi in m.get_node("Dungeon").find_children("Decor_*", "MultiMeshInstance3D", true, false):
		var kind: String = mmi.get_meta("kind", "")
		for local in mmi.get_meta("xforms"):
			var p: Vector3 = (mmi.global_transform * local).origin
			var d: float = IG.distance_to(ig.path, p)
			if kind in TALL and d < IG.HALF_WIDTH + IG.MUD:
				_wet_trees += 1
			elif kind == "moita" and d < IG.HALF_WIDTH + 0.2:
				_wet_bushes += 1


func _report() -> void:
	var frac := float(_occ) / maxf(_samples, 1)
	print("pontos: %d, tampados: %d (%.1f%%) %s" % [_samples, _occ, frac * 100.0, _occ_where])
	print("árvores: %d, palmeiras: %d" % [_trees, _palms])
	check(frac <= MAX_OCCLUDED, "árvores/palmeiras tampam a heroína em no máximo %d%% dos pontos (%.1f%%)" % [int(MAX_OCCLUDED * 100), frac * 100.0])
	check(_close_trees == 0, "nenhuma árvore a menos de %.1f m de outra (%d pares)" % [MIN_TREE_GAP, _close_trees])
	check(_overlaps == 0, "nenhuma pedra/tronco/sumaúma encavalada (%d)" % _overlaps)
	check(_plant_in_solid == 0, "nenhuma plantinha dentro de pedra/tronco (%d)" % _plant_in_solid)
	check(_palms * 3 >= _trees, "palmeiras aparecem (pelo menos 1 para cada 3 árvores: %d / %d)" % [_palms, _trees])
	print("igarapé em %d de %d andares, %d cruzamentos com trilha" % [_water_floors, SEEDS.size(), _crossings])
	check(_water_floors == SEEDS.size(), "todo andar tem igarapé")
	check(_water_in_clearing == 0, "a água nunca entra numa clareira (%d pontos)" % _water_in_clearing)
	check(_missing_bridge == 0, "toda trilha que cruza o igarapé tem pinguela (%d sem)" % _missing_bridge)
	check(_wet_trees == 0 and _wet_bushes == 0, "nenhuma árvore/palmeira/moita dentro d'água (%d / %d)" % [_wet_trees, _wet_bushes])
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)
