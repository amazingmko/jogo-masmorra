class_name DungeonBuilder
extends RefCounted
## Transforma a planta (DungeonLayout) em salas e corredores 3D.

const CELL := 22.0  # distância entre os centros de salas vizinhas

## Salas criadas, na mesma ordem da planta.
var rooms: Array[DungeonRoom] = []
## Objetos especiais por índice de sala (baú, fonte, portal).
var props: Dictionary = {}

var _materials := {}
## Linha do meio de cada trilha (para o chão pintar a trilha e o igarapé pôr as pinguelas).
var trails: Array[PackedVector3Array] = []
var igarape: Igarape
var _water := PackedVector3Array()


func _init() -> void:
	_materials = {
		# Terra Firme: chão de terra escura, paredes de mata fechada, pilares como troncos.
		"floor": _ground(Color.WHITE),
		"floor_boss": _ground(Color(0.8, 0.9, 0.8)),
		"floor_den": _ground(Color(1.15, 0.7, 0.62)),
		"wall": _mat(Color("1f3a1e")),
		"pillar": _mat(Color("5c4331")),
		"corridor": _ground(Color(0.92, 0.92, 0.9)),
		"barrier": _mat(Color("b8434a")),
	}


func build(layout: DungeonLayout, parent: Node3D, rng: RandomNumberGenerator) -> void:
	rooms.clear()
	props.clear()
	trails.clear()
	RoomDecor.begin_floor(layout)
	var water_rng := RandomNumberGenerator.new()
	water_rng.seed = rng.seed ^ 0x16a4a9e
	_water = Igarape.plan(layout, water_rng)
	RoomDecor.set_water(_water, Igarape.HALF_WIDTH + Igarape.MUD)
	for i in layout.room_count():
		var info: Dictionary = layout.rooms[i]
		var dirs: Array[Vector2i] = []
		for n in info.links:
			dirs.append(layout.rooms[n].cell - info.cell)
		var room := DungeonRoom.new()
		room.setup(i, info, dirs, _materials, rng)
		room.position = cell_to_world(info.cell)
		parent.add_child(room)
		rooms.append(room)
		_add_prop(room, parent)

	for i in layout.room_count():
		for n in layout.rooms[i].links:
			if n > i:
				_build_corridor(parent, layout.rooms[i].cell, layout.rooms[n].cell)
	var forest_rng := RandomNumberGenerator.new()
	forest_rng.seed = rng.randi()
	RoomDecor.forest(parent, forest_rng)
	igarape = Igarape.new()
	parent.add_child(igarape)
	igarape.setup(_water, trails)
	_build_ground(parent)


## Um chão só, contínuo, debaixo de todo o andar (clareiras, trilhas e a mata entre elas).
func _build_ground(parent: Node3D) -> void:
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for r in rooms:
		lo = Vector3(minf(lo.x, r.position.x), 0, minf(lo.z, r.position.z))
		hi = Vector3(maxf(hi.x, r.position.x), 0, maxf(hi.z, r.position.z))
	var margin := CELL
	var size := Vector3(hi.x - lo.x + margin * 2.0, 0.5, hi.z - lo.z + margin * 2.0)
	box(parent, size, (lo + hi) * 0.5 + Vector3(0, -0.25, 0), _materials.floor)
	_paint_floor_map(Vector2(lo.x - margin, lo.z - margin), Vector2(size.x, size.z))


## Mapa do chão (4 pixels por metro): R = trilha batida, G = barro da margem do igarapé.
## Pintado com "carimbos" redondos e suaves ao longo das linhas.
func _paint_floor_map(origin: Vector2, size: Vector2) -> void:
	var ppm := 4.0
	var w := int(ceil(size.x * ppm))
	var h := int(ceil(size.y * ppm))
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var to_px := func(p: Vector3) -> Vector2:
		return (Vector2(p.x, p.z) - origin) * ppm
	# trilhas, entrando um pouco nas clareiras pelas portas (some aos poucos)
	for line in trails:
		var a: Vector3 = line[0]
		var b: Vector3 = line[line.size() - 1]
		var dir := (b - a).normalized()
		var ext := PackedVector3Array([a - dir * 2.5])
		ext.append_array(line)
		ext.append(b + dir * 2.5)
		_stamp_line(img, ext, to_px, DungeonRoom.DOOR_W * 0.5 * ppm, 0, 2.5 * ppm)
	# um pouco de chão batido no meio de cada clareira (onde todo mundo luta)
	for r in rooms:
		_stamp(img, to_px.call(r.global_position), 4.5 * ppm, 0, 0.3)
	# barro dos dois lados do igarapé
	_stamp_line(img, _water, to_px, (Igarape.HALF_WIDTH + Igarape.MUD) * ppm, 1, 0.0)
	var tex := ImageTexture.create_from_image(img)
	for key in ["floor", "floor_boss", "floor_den", "corridor"]:
		var m: ShaderMaterial = _materials[key]
		m.set_shader_parameter("mapa", tex)
		m.set_shader_parameter("mapa_origem", origin)
		m.set_shader_parameter("mapa_tamanho", Vector2(w, h) / ppm)


## Carimba ao longo da linha. fade_px: nos primeiros/últimos N pixels a força cai até zero.
func _stamp_line(img: Image, line: PackedVector3Array, to_px: Callable, radius: float, channel: int, fade_px: float) -> void:
	var total := 0.0
	for i in line.size() - 1:
		total += (to_px.call(line[i + 1]) - to_px.call(line[i])).length()
	var walked := 0.0
	for i in line.size() - 1:
		var a: Vector2 = to_px.call(line[i])
		var b: Vector2 = to_px.call(line[i + 1])
		var seg := (b - a).length()
		var steps := maxi(int(seg / 1.5), 1)
		for s in steps:
			var d := walked + seg * s / steps
			var strength := 1.0
			if fade_px > 0.0:
				strength = clampf(minf(d, total - d) / fade_px, 0.0, 1.0)
			_stamp(img, a.lerp(b, float(s) / steps), radius, channel, strength)
		walked += seg


func _stamp(img: Image, center: Vector2, radius: float, channel: int, strength: float) -> void:
	var r := int(ceil(radius))
	for y in range(int(center.y) - r, int(center.y) + r + 1):
		if y < 0 or y >= img.get_height():
			continue
		for x in range(int(center.x) - r, int(center.x) + r + 1):
			if x < 0 or x >= img.get_width():
				continue
			var d := Vector2(x, y).distance_to(center) / radius
			if d > 1.0:
				continue
			var v := (1.0 - smoothstep(0.55, 1.0, d)) * strength
			var c := img.get_pixel(x, y)
			if v > c[channel]:
				c[channel] = v
				img.set_pixel(x, y, c)


static func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL)


## Caixa sólida (colisão + malha). Filho 0 = colisão, filho 1 = malha.
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	body.add_child(mesh)
	parent.add_child(body)
	return body


func _add_prop(room: DungeonRoom, parent: Node3D) -> void:
	var kind := -1
	match room.type:
		DungeonLayout.RoomType.TREASURE:
			kind = RoomProp.Kind.CHEST
		DungeonLayout.RoomType.REST:
			kind = RoomProp.Kind.FOUNTAIN
		DungeonLayout.RoomType.EXIT:
			kind = RoomProp.Kind.PORTAL
	if kind == -1:
		return
	var prop := RoomProp.create(kind)
	prop.position = room.position
	parent.add_child(prop)
	props[room.index] = prop


## Trilha entre duas clareiras: faz uma curva (sorteada), com a borda de mata e colisão
## invisível dos dois lados. Começa e termina exatamente nos vãos das portas.
func _build_corridor(parent: Node3D, a: Vector2i, b: Vector2i) -> void:
	var wa := cell_to_world(a)
	var wb := cell_to_world(b)
	var dir := (wb - wa).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var edge := DungeonRoom.SIZE * 0.5 + DungeonRoom.WALL_T * 0.5
	var start := wa + dir * edge
	var finish := wb - dir * edge
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(a) ^ (hash(b) << 1)
	var bend := rng.randf_range(-1.3, 1.3)
	var steps := 8
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var center_line := PackedVector3Array()
	for i in steps + 1:
		var k := float(i) / steps
		var c := start.lerp(finish, k) + side * bend * sin(k * PI)
		var w := DungeonRoom.DOOR_W * 0.5 + 0.35 * sin(k * PI) * rng.randf_range(0.5, 1.0)
		center_line.append(c)
		left.append(c - side * w)
		right.append(c + side * w)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	parent.add_child(body)
	for line in [left, right]:
		for i in line.size() - 1:
			var p0: Vector3 = line[i]
			var p1: Vector3 = line[i + 1]
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(p0.distance_to(p1) + 0.3, 2.0, DungeonRoom.WALL_T)
			col.shape = shape
			# a parede fica por fora da trilha (meia espessura para fora)
			var outward: Vector3 = side * (-1.0 if line == left else 1.0) * DungeonRoom.WALL_T * 0.5
			col.position = (p0 + p1) * 0.5 + outward + Vector3(0, 1.0, 0)
			col.rotation.y = atan2(p1.x - p0.x, p1.z - p0.z) + PI * 0.5
			body.add_child(col)
	trails.append(center_line)
	RoomDecor.trail(parent, left, right, side, rng)


## Chão de terra com musgo e folhas (shader em coordenadas do mundo: sem emendas).
static func _ground(tone: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/chao_mata.gdshader")
	m.set_shader_parameter("ruido", _noise(0.9, 2))
	for t in ["terra", "musgo", "trilha", "barro"]:
		var file: String = "barro_margem" if t == "barro" else "chao_" + t
		m.set_shader_parameter(t + "_tex", load("res://game/art/chao/%s.jpg" % file))
	m.set_shader_parameter("tom", Vector3(tone.r, tone.g, tone.b))
	return m


static func _noise(freq: float, octaves: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq / 100.0 * 4.0
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	return t


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m
