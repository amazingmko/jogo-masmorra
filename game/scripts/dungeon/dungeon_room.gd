class_name DungeonRoom
extends Node3D
## Uma sala da masmorra: chão, paredes com vãos de porta, grades que fecham durante o combate
## e um sensor que avisa quando o herói entra. Construída por código a partir da planta.

signal player_entered(room: DungeonRoom)

const SIZE := 14.0        # largura interna da sala
const WALL_T := 0.6       # espessura da parede
const WALL_H := 1.6       # altura da parede
const DOOR_W := 3.6       # largura do vão da porta
const PILLAR_SPOTS: Array[Vector2] = [Vector2(-3.5, -3.5), Vector2(3.5, -3.5), Vector2(-3.5, 3.5), Vector2(3.5, 3.5)]

var index := 0
var type: DungeonLayout.RoomType = DungeonLayout.RoomType.COMBAT
var cell := Vector2i.ZERO
var cleared := false
var visited := false
## Inimigos vivos que nasceram nesta sala.
var alive := 0
## Ondas extras que ainda vão chegar nesta sala, e a onda atual (1 = a primeira).
var waves_left := 0
var wave_number := 1
var wave_total := 1
var wave_pending := false
var pillars: Array[Vector3] = []

var _door_dirs: Array[Vector2i] = []
var _barriers: Array[StaticBody3D] = []
var _materials: Dictionary
## Covil Furioso: sala rara, só com furiosos, com um baú grande no fim.
var is_den := false


## dirs: direções (da grade) que têm porta. materials: cores compartilhadas do DungeonBuilder.
func setup(room_index: int, info: Dictionary, dirs: Array[Vector2i], mats: Dictionary,
		rng: RandomNumberGenerator) -> void:
	index = room_index
	type = info.type
	cell = info.cell
	_door_dirs = dirs
	_materials = mats
	name = "Sala%d" % room_index
	is_den = bool(info.get("den", false))
	cleared = type != DungeonLayout.RoomType.COMBAT and type != DungeonLayout.RoomType.BOSS
	if type == DungeonLayout.RoomType.COMBAT or type == DungeonLayout.RoomType.BOSS:
		for spot in PILLAR_SPOTS:
			if rng.randf() < 0.45:
				pillars.append(Vector3(spot.x, 1.0, spot.y))


func _ready() -> void:
	var floor_mat: StandardMaterial3D = _materials.floor_boss if type == DungeonLayout.RoomType.BOSS else _materials.floor
	if is_den:
		floor_mat = _materials.floor_den
	DungeonBuilder.box(self, Vector3(SIZE + WALL_T * 2.0, 0.5, SIZE + WALL_T * 2.0), Vector3(0, -0.25, 0), floor_mat)
	for dir in DungeonLayout.DIRS:
		_build_side(dir)
	for p in pillars:
		DungeonBuilder.box(self, Vector3(1.2, 2.0, 1.2), p, _materials.pillar)
	_build_trigger()


func center() -> Vector3:
	return global_position


## True se o ponto está dentro da área interna da sala (não no corredor).
func contains(point: Vector3) -> bool:
	var half := SIZE * 0.5
	return absf(point.x - global_position.x) <= half and absf(point.z - global_position.z) <= half


func close_doors() -> void:
	for b in _barriers:
		b.visible = true
		b.get_child(0).set_deferred("disabled", false)


func open_doors() -> void:
	for b in _barriers:
		b.visible = false
		b.get_child(0).set_deferred("disabled", true)


## Ponto livre dentro da sala, longe de `avoid` e dos pilares.
func random_point(rng: RandomNumberGenerator, avoid: Vector3, min_dist: float) -> Vector3:
	var half := SIZE * 0.5 - 1.5
	var best := global_position
	for attempt in 30:
		var local := Vector3(rng.randf_range(-half, half), 0.1, rng.randf_range(-half, half))
		var ok := true
		for p in pillars:
			if Vector2(local.x - p.x, local.z - p.z).length() < 1.6:
				ok = false
		var world := global_position + local
		if ok and Vector2(world.x - avoid.x, world.z - avoid.z).length() >= min_dist:
			return world
		best = world
	return best


# ---------- construção ----------

func _build_side(dir: Vector2i) -> void:
	var half := SIZE * 0.5
	var full := SIZE + WALL_T * 2.0
	var along := Vector3(absf(dir.y), 0, absf(dir.x))   # direção ao longo da parede
	var out := Vector3(dir.x, 0, dir.y)                  # direção para fora da sala
	var wall_center := out * (half + WALL_T * 0.5) + Vector3(0, WALL_H * 0.5, 0)
	var thickness := Vector3(absf(dir.x), 0, absf(dir.y)) * WALL_T

	if not _door_dirs.has(dir):
		DungeonBuilder.box(self, along * full + thickness + Vector3(0, WALL_H, 0), wall_center, _materials.wall)
		return

	var seg := (full - DOOR_W) * 0.5
	for side in [-1.0, 1.0]:
		var pos: Vector3 = wall_center + along * side * (DOOR_W * 0.5 + seg * 0.5)
		DungeonBuilder.box(self, along * seg + thickness + Vector3(0, WALL_H, 0), pos, _materials.wall)

	# Grade da porta: começa aberta (invisível e sem colisão).
	var barrier := DungeonBuilder.box(self, along * DOOR_W + thickness * 0.6 + Vector3(0, WALL_H, 0),
		wall_center, _materials.barrier)
	barrier.visible = false
	barrier.get_child(0).disabled = true
	_barriers.append(barrier)


func _build_trigger() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Menor que a sala: o herói só "entra" quando já passou da porta.
	box.size = Vector3(SIZE - 3.0, 3.0, SIZE - 3.0)
	shape.shape = box
	area.add_child(shape)
	area.position.y = 1.5
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			player_entered.emit(self))
