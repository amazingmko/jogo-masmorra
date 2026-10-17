class_name RoomDecor
extends RefCounted
## Vida nas salas da Terra Firme: moitas em cima das paredes (mata fechada), árvores altas por
## fora das salas, samambaias, bromélias e cogumelos no chão, pedras com musgo e troncos caídos,
## e sumaúmas no lugar dos pilares.
##
## Cada peça usa o modelo em game/art/ambiente/<nome>.glb quando ele existe; senão, uma forma
## simples provisória (assim o mapa já fica vivo e as peças de verdade entram sozinhas).
## Plantas repetidas usam MultiMesh (uma chamada de desenho por tipo e sala: leve no celular).

const ART := "res://game/art/ambiente/%s.glb"
## Tamanho final de cada peça, em metros: "h" = altura, "w" = maior lado no chão
## (os modelos do Tripo vêm com proporções livres; o toco da sumaúma, por exemplo, é largo e baixo).
const SIZE := {
	"arvore_borda": ["h", 7.0], "palmeira": ["h", 6.0], "sumauma": ["w", 2.6], "moita": ["w", 1.7],
	"samambaia": ["w", 0.85], "bromelia": ["w", 0.6], "cogumelos": ["h", 0.3],
	"pedra_musgo": ["w", 1.4], "tronco_caido": ["w", 2.6],
}

static var _cache := {}


## Monta a decoração da sala. rng: sorteio próprio da sala (a mesma semente = a mesma sala).
static func populate(room: DungeonRoom, rng: RandomNumberGenerator, door_dirs: Array[Vector2i]) -> void:
	var half := DungeonRoom.SIZE * 0.5
	var wall := half + DungeonRoom.WALL_T * 0.5
	var bushes: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	for dir in DungeonLayout.DIRS:
		var along := Vector3(absf(dir.y), 0, absf(dir.x))
		var out := Vector3(dir.x, 0, dir.y)
		var has_door := door_dirs.has(dir)
		# Moitas em cima da parede (a parede vira mata fechada), sem tampar o vão da porta.
		var t := -half - 0.4
		while t <= half + 0.4:
			if not (has_door and absf(t) < DungeonRoom.DOOR_W * 0.5 + 0.3):
				var pos := out * (wall + rng.randf_range(-0.15, 0.25)) + along * (t + rng.randf_range(-0.3, 0.3))
				# do lado da câmera (sul), moitas baixas para não esconder a heroína
				var low := dir == Vector2i(0, 1)
				pos.y = DungeonRoom.WALL_H * (rng.randf_range(0.35, 0.5) if low else rng.randf_range(0.55, 0.85))
				bushes.append(_xf(rng, pos, rng.randf_range(0.5, 0.7) if low else rng.randf_range(0.9, 1.4)))
			t += rng.randf_range(0.9, 1.3)
		# Árvores altas por fora (não do lado da câmera, para não tampar a heroína).
		if dir == Vector2i(0, 1):
			continue
		for i in rng.randi_range(2, 4):
			var s := rng.randf_range(-half, half)
			if has_door and absf(s) < DungeonRoom.DOOR_W:
				continue
			var pos := out * (wall + rng.randf_range(1.2, 3.2)) + along * s
			if rng.randf() < 0.35:
				palms.append(_xf(rng, pos, rng.randf_range(0.85, 1.15)))
			else:
				trees.append(_xf(rng, pos, rng.randf_range(0.8, 1.2)))
	_multimesh(room, "moita", bushes, false)
	_multimesh(room, "arvore_borda", trees, true)
	_multimesh(room, "palmeira", palms, true)

	# Chão: plantas pequenas, mais perto das paredes (o meio fica limpo para lutar).
	var small := {"samambaia": [], "bromelia": [], "cogumelos": []}
	var count := 26 if room.type != DungeonLayout.RoomType.BOSS else 34
	for i in count:
		var p := _edge_point(rng, half - 0.6, 3.0)
		var roll := rng.randf()
		var kind := "samambaia" if roll < 0.6 else ("bromelia" if roll < 0.85 else "cogumelos")
		small[kind].append(_xf(rng, p, rng.randf_range(0.7, 1.4)))
	for kind in small:
		var list: Array[Transform3D] = []
		list.assign(small[kind])
		_multimesh(room, kind, list, false)

	# Obstáculos com colisão (pedras e tronco caído) só nas salas de luta, perto das paredes.
	if room.type == DungeonLayout.RoomType.COMBAT:
		for i in rng.randi_range(0, 2):
			var p := _edge_point(rng, half - 1.8, 4.2)
			if _near_door(p, door_dirs, half):
				continue
			_solid(room, "pedra_musgo", _xf(rng, p, rng.randf_range(0.8, 1.3)), Vector3(1.2, 1.0, 1.2))
			room.pillars.append(Vector3(p.x, 1.0, p.z))
		if rng.randf() < 0.5:
			var p := _edge_point(rng, half - 2.0, 4.5)
			if not _near_door(p, door_dirs, half):
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
				_solid(room, "tronco_caido", xf, Vector3(2.6, 0.7, 0.8))
				room.pillars.append(Vector3(p.x, 1.0, p.z))


## Sumaúma no lugar do pilar (a colisão continua a do pilar).
static func trunk(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var node := _instance("sumauma")
	node.transform = _xf(rng, Vector3(pos.x, 0.0, pos.z), rng.randf_range(0.95, 1.1))
	parent.add_child(node)


## Moitas dos dois lados de um corredor.
static func corridor(parent: Node3D, center: Vector3, horizontal: bool, length: float, rng: RandomNumberGenerator) -> void:
	var list: Array[Transform3D] = []
	var along := Vector3.RIGHT if horizontal else Vector3.BACK
	var side_dir := Vector3.BACK if horizontal else Vector3.RIGHT
	for side in [-1.0, 1.0]:
		var t := -length * 0.5
		while t <= length * 0.5:
			var pos: Vector3 = center + along * t + side_dir * side * (DungeonRoom.DOOR_W * 0.5 + DungeonRoom.WALL_T * 0.5)
			pos.y = DungeonRoom.WALL_H * rng.randf_range(0.55, 0.85)
			list.append(_xf(rng, pos, rng.randf_range(0.9, 1.3)))
			t += rng.randf_range(0.9, 1.3)
	_multimesh(parent, "moita", list, false)


# ---------- peças ----------

static func _xf(rng: RandomNumberGenerator, pos: Vector3, s: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos)


## Ponto aleatório na sala, longe do centro (min_from_center) e dentro de `limit`.
static func _edge_point(rng: RandomNumberGenerator, limit: float, min_from_center: float) -> Vector3:
	for attempt in 12:
		var p := Vector3(rng.randf_range(-limit, limit), 0.0, rng.randf_range(-limit, limit))
		if maxf(absf(p.x), absf(p.z)) >= min_from_center:
			return p
	return Vector3(limit, 0, rng.randf_range(-limit, limit))


static func _near_door(p: Vector3, door_dirs: Array[Vector2i], half: float) -> bool:
	for d in door_dirs:
		var door := Vector3(d.x, 0, d.y) * half
		if Vector2(p.x - door.x, p.z - door.z).length() < DungeonRoom.DOOR_W:
			return true
	return false


static func _multimesh(parent: Node3D, kind: String, transforms: Array[Transform3D], shadows: bool) -> void:
	if transforms.is_empty():
		return
	var piece := _piece(kind)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = piece.mesh
	mm.instance_count = transforms.size()
	var tint_rng := RandomNumberGenerator.new()
	tint_rng.seed = hash(kind) + transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i] * piece.base)
		var v := tint_rng.randf_range(0.82, 1.08)
		mm.set_instance_color(i, Color(v, v * tint_rng.randf_range(0.95, 1.05), v))
	var node := MultiMeshInstance3D.new()
	node.name = "Decor_" + kind
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func _solid(parent: Node3D, kind: String, xf: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size * xf.basis.get_scale().x
	col.shape = shape
	col.position.y = shape.size.y * 0.5
	body.add_child(col)
	var node := _instance(kind)
	node.scale = Vector3.ONE * xf.basis.get_scale().x
	body.add_child(node)
	parent.add_child(body)


static func _instance(kind: String) -> Node3D:
	var piece := _piece(kind)
	var mi := MeshInstance3D.new()
	mi.mesh = piece.mesh
	mi.transform = piece.base
	var holder := Node3D.new()
	holder.name = kind
	holder.add_child(mi)
	return holder


## {mesh, base}: o modelo de verdade (normalizado para a altura da peça, apoiado no chão) ou o provisório.
static func _piece(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var piece := {}
	var path: String = ART % kind
	if ResourceLoader.exists(path):
		var scene: Node = load(path).instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			var mi: MeshInstance3D = found[0]
			var mesh: Mesh = mi.mesh
			var aabb := mesh.get_aabb()
			var spec: Array = SIZE.get(kind, ["h", 1.0])
			var measured: float = aabb.size.y if spec[0] == "h" else maxf(aabb.size.x, aabb.size.z)
			var k: float = float(spec[1]) / maxf(measured, 0.001)
			var base := Transform3D(Basis().scaled(Vector3.ONE * k), Vector3(-aabb.get_center().x * k, -aabb.position.y * k, -aabb.get_center().z * k))
			piece = {"mesh": mesh, "base": base}
		scene.free()
	if piece.is_empty():
		piece = {"mesh": _placeholder(kind), "base": Transform3D()}
	_cache[kind] = piece
	return piece


# ---------- formas provisórias ----------

static func _placeholder(kind: String) -> Mesh:
	var bark := Color("4a3626")
	var leaf := Color("2f5a28")
	match kind:
		"arvore_borda":
			return _combo([
				[_cyl(0.28, 0.42, 4.4), Transform3D(Basis(), Vector3(0, 2.2, 0)), bark],
				[_sphere(1.9), Transform3D(Basis().scaled(Vector3(1.0, 0.75, 1.0)), Vector3(0, 5.2, 0)), leaf],
				[_sphere(1.3), Transform3D(Basis(), Vector3(0.9, 4.6, 0.4)), leaf.darkened(0.15)],
			])
		"palmeira":
			var parts := [[_cyl(0.13, 0.18, 5.2), Transform3D(Basis(), Vector3(0, 2.6, 0)), Color("5a4a32")]]
			for i in 6:
				var b := Basis(Vector3.UP, TAU * i / 6.0) * Basis(Vector3.RIGHT, deg_to_rad(65))
				parts.append([_box(Vector3(0.35, 0.04, 2.0)), Transform3D(b, Vector3(0, 5.2, 0) + b * Vector3(0, 0, 0.9)), Color("3d6b2c")])
			return _combo(parts)
		"sumauma":
			var parts := [[_cyl(0.45, 0.6, 3.2), Transform3D(Basis(), Vector3(0, 1.6, 0)), bark]]
			for i in 5:  # sapopemas: as raízes-tábua da sumaúma
				var b := Basis(Vector3.UP, TAU * i / 5.0 + 0.3)
				parts.append([_box(Vector3(0.12, 1.2, 1.1)), Transform3D(b, b * Vector3(0, 0.55, 0.75)), bark.lightened(0.08)])
			return _combo(parts)
		"moita":
			return _combo([
				[_sphere(0.7), Transform3D(Basis().scaled(Vector3(1.0, 0.8, 1.0)), Vector3(0, 0.5, 0)), leaf],
				[_sphere(0.5), Transform3D(Basis(), Vector3(0.45, 0.65, 0.2)), leaf.lightened(0.1)],
			])
		"samambaia":
			var parts := []
			for i in 5:
				var b := Basis(Vector3.UP, TAU * i / 5.0) * Basis(Vector3.RIGHT, deg_to_rad(50))
				parts.append([_box(Vector3(0.12, 0.02, 0.55)), Transform3D(b, b * Vector3(0, 0, 0.22) + Vector3(0, 0.15, 0)), Color("3f7a33")])
			return _combo(parts)
		"bromelia":
			var parts := [[_sphere(0.09), Transform3D(Basis(), Vector3(0, 0.22, 0)), Color("d8433a")]]
			for i in 6:
				var b := Basis(Vector3.UP, TAU * i / 6.0) * Basis(Vector3.RIGHT, deg_to_rad(40))
				parts.append([_box(Vector3(0.08, 0.02, 0.4)), Transform3D(b, b * Vector3(0, 0, 0.15) + Vector3(0, 0.1, 0)), Color("4f8a3a")])
			return _combo(parts)
		"cogumelos":
			return _combo([
				[_cyl(0.03, 0.03, 0.18), Transform3D(Basis(), Vector3(0, 0.09, 0)), Color("e8dcc0")],
				[_sphere(0.1), Transform3D(Basis().scaled(Vector3(1, 0.5, 1)), Vector3(0, 0.19, 0)), Color("c9733a")],
				[_cyl(0.02, 0.02, 0.12), Transform3D(Basis(), Vector3(0.12, 0.06, 0.05)), Color("e8dcc0")],
				[_sphere(0.07), Transform3D(Basis().scaled(Vector3(1, 0.5, 1)), Vector3(0.12, 0.13, 0.05)), Color("c9733a")],
			])
		"pedra_musgo":
			return _combo([
				[_sphere(0.6), Transform3D(Basis().scaled(Vector3(1.0, 0.75, 0.85)), Vector3(0, 0.4, 0)), Color("5d5d55")],
				[_sphere(0.45), Transform3D(Basis().scaled(Vector3(1.0, 0.4, 0.9)), Vector3(0.05, 0.75, 0)), Color("3e6a2e")],
			])
		"tronco_caido":
			return _combo([
				[_cyl(0.32, 0.36, 2.6), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.34, 0)), bark],
				[_sphere(0.3), Transform3D(Basis().scaled(Vector3(1.2, 0.4, 1.0)), Vector3(0.4, 0.66, 0)), Color("3e6a2e")],
			])
	return _sphere(0.3)


static func _combo(parts: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for part in parts:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(part[0], 0, part[1])
		out = st.commit(out)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[2]
		mat.roughness = 1.0
		mat.vertex_color_use_as_albedo = true  # a cor de cada cópia (MultiMesh) varia um pouco o tom
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return out


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
