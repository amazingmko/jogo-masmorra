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
		"floor": _mat(Color("3d3a2c")),
		"floor_boss": _mat(Color("2e3324")),
		"wall": _mat(Color("2f4a2c")),
		"pillar": _mat(Color("5c4331")),
		"corridor": _mat(Color("35321f")),
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


func _build_corridor(parent: Node3D, a: Vector2i, b: Vector2i) -> void:
	var wa := cell_to_world(a)
	var wb := cell_to_world(b)
	var center := (wa + wb) * 0.5
	var horizontal := a.y == b.y
	var gap := CELL - DungeonRoom.SIZE - DungeonRoom.WALL_T * 2.0  # espaço entre as paredes das salas
	var floor_len := gap + DungeonRoom.WALL_T * 2.0
	var width := DungeonRoom.DOOR_W
	var t := DungeonRoom.WALL_T
	var h := DungeonRoom.WALL_H
	if horizontal:
		box(parent, Vector3(floor_len, 0.5, width), center + Vector3(0, -0.25, 0), _materials.corridor)
		for side in [-1.0, 1.0]:
			box(parent, Vector3(gap, h, t), center + Vector3(0, h * 0.5, side * (width * 0.5 + t * 0.5)), _materials.wall)
	else:
		box(parent, Vector3(width, 0.5, floor_len), center + Vector3(0, -0.25, 0), _materials.corridor)
		for side in [-1.0, 1.0]:
			box(parent, Vector3(t, h, gap), center + Vector3(side * (width * 0.5 + t * 0.5), h * 0.5, 0), _materials.wall)


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m
