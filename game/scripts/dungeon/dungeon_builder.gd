class_name DungeonBuilder
extends RefCounted
## Transforma a planta (DungeonLayout) em salas e corredores 3D.

const CELL := 22.0  # distância entre os centros de salas vizinhas

## Salas criadas, na mesma ordem da planta.
var rooms: Array[DungeonRoom] = []
## Objetos especiais por índice de sala (baú, fonte, portal).
var props: Dictionary = {}

var _materials := {}


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
	RoomDecor.trail(parent, left, right, side, rng)


## Chão de terra com musgo e folhas (shader em coordenadas do mundo: sem emendas).
static func _ground(tone: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/chao_mata.gdshader")
	m.set_shader_parameter("ruido", _noise(0.9, 2))
	m.set_shader_parameter("detalhe", _noise(3.5, 3))
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
