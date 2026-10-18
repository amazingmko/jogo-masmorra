class_name DungeonLayout
extends RefCounted
## Planta de um andar: quais salas existem, onde ficam numa grade e quais se ligam.
## Não cria nada em 3D (isso é o DungeonBuilder). Com a mesma semente, sai a mesma planta.

enum RoomType { START, COMBAT, TREASURE, REST, EXIT, BOSS }

## Chance de porta extra entre duas salas vizinhas (além do caminho principal).
const EXTRA_LINK := 0.45
## Entre duas salas vizinhas, no máximo este tanto de portas para ir de uma à outra.
const MAX_DETOUR := 3
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Cada sala: {"cell": Vector2i, "type": RoomType, "links": Array[int] (índices das vizinhas ligadas), "depth": int}
var rooms: Array[Dictionary] = []
var start_index := 0
var goal_index := 0  # saída (andares comuns) ou chefe (último andar)
var is_boss_floor := false


## Gera a planta. room_count inclui início e saída/chefe.
func generate(rng: RandomNumberGenerator, room_count: int, boss_floor: bool) -> void:
	rooms.clear()
	is_boss_floor = boss_floor
	room_count = maxi(room_count, 4)
	var cell_to_index := {}

	_add_room(Vector2i.ZERO, cell_to_index)
	start_index = 0

	# Cresce a partir de salas existentes, preferindo as que têm poucas vizinhas
	# (deixa a planta mais "ramificada" e menos amontoada).
	var guard := 0
	while rooms.size() < room_count and guard < 1000:
		guard += 1
		var from := _pick_growth_room(rng)
		var dir := DIRS[rng.randi_range(0, 3)]
		var cell: Vector2i = rooms[from].cell + dir
		if cell_to_index.has(cell):
			continue
		if _neighbor_count(cell, cell_to_index) > 2:
			continue
		var idx := _add_room(cell, cell_to_index)
		_link(from, idx)

	# Ligações extras entre vizinhas criam atalhos (laços), para não ser só uma árvore.
	for i in rooms.size():
		for dir in DIRS:
			var other_cell: Vector2i = rooms[i].cell + dir
			if cell_to_index.has(other_cell):
				var j: int = cell_to_index[other_cell]
				if j > i and not rooms[i].links.has(j) and rng.randf() < EXTRA_LINK:
					_link(i, j)
	# Sala colada na outra, mas sem porta entre elas, obrigando a dar uma volta grande: abre a porta.
	for i in rooms.size():
		for dir in DIRS:
			var other_cell: Vector2i = rooms[i].cell + dir
			if cell_to_index.has(other_cell):
				var j: int = cell_to_index[other_cell]
				if j > i and not rooms[i].links.has(j) and path(i, j).size() - 1 > MAX_DETOUR:
					_link(i, j)

	_compute_depths()
	_assign_types(rng)


func room_count() -> int:
	return rooms.size()


func type_of(index: int) -> RoomType:
	return rooms[index].type


## Caminho de salas (índices) do início `from` até `to`, pela menor quantidade de portas.
func path(from: int, to: int) -> Array[int]:
	var prev := {from: -1}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to:
			break
		for n in rooms[cur].links:
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	var result: Array[int] = []
	if not prev.has(to):
		return result
	var node := to
	while node != -1:
		result.push_front(node)
		node = prev[node]
	return result


# ---------- interno ----------

func _add_room(cell: Vector2i, cell_to_index: Dictionary) -> int:
	rooms.append({"cell": cell, "type": RoomType.COMBAT, "links": [], "depth": 0})
	var idx := rooms.size() - 1
	cell_to_index[cell] = idx
	return idx


func _link(a: int, b: int) -> void:
	if not rooms[a].links.has(b):
		rooms[a].links.append(b)
	if not rooms[b].links.has(a):
		rooms[b].links.append(a)


func _neighbor_count(cell: Vector2i, cell_to_index: Dictionary) -> int:
	var n := 0
	for dir in DIRS:
		if cell_to_index.has(cell + dir):
			n += 1
	return n


func _pick_growth_room(rng: RandomNumberGenerator) -> int:
	var candidates: Array[int] = []
	for i in rooms.size():
		if rooms[i].links.size() < 3:
			candidates.append(i)
	if candidates.is_empty():
		return rng.randi_range(0, rooms.size() - 1)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Distância (em portas) de cada sala até o início.
func _compute_depths() -> void:
	for room in rooms:
		room.depth = -1
	rooms[start_index].depth = 0
	var queue: Array[int] = [start_index]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for n in rooms[cur].links:
			if rooms[n].depth == -1:
				rooms[n].depth = rooms[cur].depth + 1
				queue.append(n)


func _assign_types(rng: RandomNumberGenerator) -> void:
	rooms[start_index].type = RoomType.START

	# Objetivo (saída ou chefe) na sala mais distante; em empate, a de menos vizinhas (ponta).
	var best := -1
	for i in rooms.size():
		if i == start_index:
			continue
		if best == -1 or rooms[i].depth > rooms[best].depth or (
				rooms[i].depth == rooms[best].depth and rooms[i].links.size() < rooms[best].links.size()):
			best = i
	goal_index = best
	rooms[goal_index].type = RoomType.BOSS if is_boss_floor else RoomType.EXIT

	# Salas especiais preferem pontas (becos sem saída): recompensa por explorar.
	var free: Array[int] = []
	for i in rooms.size():
		if rooms[i].type == RoomType.COMBAT:
			free.append(i)
	free.sort_custom(func(a: int, b: int) -> bool: return rooms[a].links.size() < rooms[b].links.size())

	var treasures := 1 if rooms.size() < 8 else 2
	for t in treasures:
		if free.size() > 2:
			rooms[free.pop_front()].type = RoomType.TREASURE
	# Sala de descanso: no andar do chefe sempre; nos outros, metade das vezes.
	if free.size() > 2 and (is_boss_floor or rng.randf() < 0.5):
		var pick := rng.randi_range(0, free.size() - 1)
		rooms[free[pick]].type = RoomType.REST
		free.remove_at(pick)
