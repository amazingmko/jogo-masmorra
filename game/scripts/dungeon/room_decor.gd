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
	"arvore_borda": ["h", 6.0], "palmeira": ["h", 5.5], "sumauma": ["w", 2.6], "moita": ["w", 1.7],
	"samambaia": ["w", 0.85], "bromelia": ["w", 0.6], "cogumelos": ["h", 0.4],
	"pedra_musgo": ["w", 1.4], "tronco_caido": ["w", 2.6],
	# borda com cara de masmorra (modelos do Tripo; enquanto não existem, a borda usa as outras)
	"muro_ruina": ["w", 3.0], "pilar_ruina": ["h", 2.6], "totem_pedra": ["h", 2.3],
	"raiz_gigante": ["w", 3.2], "rocha_paredao": ["w", 3.0],
	"bau": ["w", 1.6], "fonte": ["w", 2.6], "portal": ["w", 3.2],
}

static var _cache := {}

## Árvores e palmeiras: copa (raio, em metros, na escala 1) e distância mínima entre troncos.
const CANOPY := {"arvore_borda": 2.3, "palmeira": 1.8}
const TREE_GAP := 4.0
const PALM_SHARE := 0.45
## A câmera fica ao sul e acima da heroína (10 m acima do peito, 7,5 m ao sul): uma copa na altura y
## tampa quem está 0,75 × (y − 1) m ao norte dela. A copa vai de ~2,5 m até o topo (~6 m).
const VIEW_SHIFT_MIN := 1.0
const VIEW_SHIFT_MAX := 3.8

## Registro do andar: onde dá para andar (clareiras e trilhas, em retângulos x/z) e os troncos já
## plantados (para as árvores não nascerem coladas umas nas outras, nem tamparem a visão).
static var _walk: Array[Rect2] = []
const GRID_PER_M := 2.0
static var _grid := PackedByteArray()
static var _grid_origin := Vector2.ZERO
static var _grid_size := Vector2i.ZERO
static var _tall: Array[Vector3] = []
static var _water := PackedVector3Array()
const WET_RANGE := 4.5
static var _wet_grid := PackedFloat32Array()
static var _wet_origin := Vector2.ZERO
static var _wet_size := Vector2i.ZERO
static var _water_reach := 0.0


## Linha do igarapé do andar: nada de planta grande nascendo dentro d'água ou no barro.
static func set_water(path: PackedVector3Array, reach: float) -> void:
	_water = path
	_water_reach = reach
	_wet_grid = PackedFloat32Array()
	if path.size() < 2:
		return
	# distância até a água pré-calculada numa grade (meio metro), só perto do igarapé:
	# a mata pergunta isso milhares de vezes por andar
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in path:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	lo -= Vector2.ONE * WET_RANGE
	hi += Vector2.ONE * WET_RANGE
	_wet_origin = lo
	_wet_size = Vector2i(int(ceil((hi.x - lo.x) * GRID_PER_M)) + 1, int(ceil((hi.y - lo.y) * GRID_PER_M)) + 1)
	_wet_grid.resize(_wet_size.x * _wet_size.y)
	_wet_grid.fill(INF)
	var r := int(ceil(WET_RANGE * GRID_PER_M))
	for p in path:
		var cx := int((p.x - lo.x) * GRID_PER_M)
		var cz := int((p.z - lo.y) * GRID_PER_M)
		for gz in range(maxi(cz - r, 0), mini(cz + r + 1, _wet_size.y)):
			for gx in range(maxi(cx - r, 0), mini(cx + r + 1, _wet_size.x)):
				var c := Vector2(lo.x + (gx + 0.5) / GRID_PER_M, lo.y + (gz + 0.5) / GRID_PER_M)
				var d := c.distance_to(Vector2(p.x, p.z))
				var i := gz * _wet_size.x + gx
				if d < _wet_grid[i]:
					_wet_grid[i] = d


static func _wet(p: Vector3, extra: float) -> bool:
	if _wet_grid.is_empty():
		return false
	var gx := int((p.x - _wet_origin.x) * GRID_PER_M)
	var gz := int((p.z - _wet_origin.y) * GRID_PER_M)
	if gx < 0 or gz < 0 or gx >= _wet_size.x or gz >= _wet_size.y:
		return false
	# a grade erra no máximo ~0,4 m (meia diagonal da célula + espaçamento dos pontos): folga
	return _wet_grid[gz * _wet_size.x + gx] < _water_reach + extra + 0.4


static func begin_floor(layout: DungeonLayout) -> void:
	_walk.clear()
	_tall.clear()
	var reach := DungeonRoom.SIZE * 0.5 + DungeonRoom.WALL_T * 0.5 + DungeonRoom.BORDER_OUT + 0.3
	for i in layout.room_count():
		var c := DungeonBuilder.cell_to_world(layout.rooms[i].cell)
		_walk.append(Rect2(c.x - reach, c.z - reach, reach * 2.0, reach * 2.0))
		for n in layout.rooms[i].links:
			if n > i:
				var d := DungeonBuilder.cell_to_world(layout.rooms[n].cell)
				var w := DungeonRoom.DOOR_W * 0.5 + 1.3 + 0.6  # meia largura + curva máxima + folga
				var lo := Vector2(minf(c.x, d.x), minf(c.z, d.z)) - Vector2(w, w)
				var hi := Vector2(maxf(c.x, d.x), maxf(c.z, d.z)) + Vector2(w, w)
				_walk.append(Rect2(lo, hi - lo))
	_build_grid()


static func _walkable(x: float, z: float) -> bool:
	var gx := int(floor((x - _grid_origin.x) * GRID_PER_M))
	var gz := int(floor((z - _grid_origin.y) * GRID_PER_M))
	if gx < 0 or gz < 0 or gx >= _grid_size.x or gz >= _grid_size.y:
		return false
	return _grid[gz * _grid_size.x + gx] == 1


## Grade de "dá para andar aqui?" (2 células por metro): a consulta vira uma leitura só, em vez de
## testar cada retângulo (as árvores fazem centenas de consultas cada).
static func _build_grid() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r in _walk:
		lo = lo.min(r.position)
		hi = hi.max(r.end)
	_grid_origin = lo
	_grid_size = Vector2i(int(ceil((hi.x - lo.x) * GRID_PER_M)) + 1, int(ceil((hi.y - lo.y) * GRID_PER_M)) + 1)
	_grid = PackedByteArray()
	_grid.resize(_grid_size.x * _grid_size.y)
	for r in _walk:
		var x0 := int(floor((r.position.x - lo.x) * GRID_PER_M))
		var x1 := int(floor((r.end.x - lo.x) * GRID_PER_M))
		var z0 := int(floor((r.position.y - lo.y) * GRID_PER_M))
		var z1 := int(floor((r.end.y - lo.y) * GRID_PER_M))
		for gz in range(maxi(z0, 0), mini(z1 + 1, _grid_size.y)):
			for gx in range(maxi(x0, 0), mini(x1 + 1, _grid_size.x)):
				_grid[gz * _grid_size.x + gx] = 1


## A copa desta árvore (no mundo) tamparia algum lugar onde a heroína anda? E fica longe das outras?
static func _tree_ok(world: Vector3, radius: float) -> bool:
	if _wet(world, 0.8):
		return false
	for t in _tall:
		if Vector2(t.x - world.x, t.z - world.z).length() < TREE_GAP:
			return false
	if _walk.is_empty():
		return true
	var x := -radius
	while x <= radius + 0.01:
		var z := -radius - VIEW_SHIFT_MAX
		while z <= radius - VIEW_SHIFT_MIN + 0.01:
			if _walkable(world.x + x, world.z + z):
				return false
			z += 0.7
		x += 0.7
	return true


## Tenta plantar uma árvore ou palmeira perto de `world` (algumas tentativas com pequenos desvios).
static func _plant_tall(rng: RandomNumberGenerator, world: Vector3, to_local: Vector3, trees: Array[Transform3D], palms: Array[Transform3D]) -> void:
	var palm := rng.randf() < PALM_SHARE
	var kind := "palmeira" if palm else "arvore_borda"
	var s := rng.randf_range(0.8, 1.1) if palm else rng.randf_range(0.75, 1.1)
	for attempt in 4:
		var p := world + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2)) * float(attempt)
		if _tree_ok(p, CANOPY[kind] * s):
			_tall.append(p)
			(palms if palm else trees).append(_xf(rng, p - to_local, s))
			return


## Monta a decoração da sala. rng: sorteio próprio da sala (a mesma semente = a mesma sala).
static func populate(room: DungeonRoom, rng: RandomNumberGenerator, door_dirs: Array[Vector2i]) -> void:
	var half := DungeonRoom.SIZE * 0.5
	var origin := room.global_position
	var bushes: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var ferns_edge: Array[Transform3D] = []
	# Borda da clareira: moitas em cima do contorno (escondem a colisão), samambaias na beirada de
	# dentro e, por trás, árvores e palmeiras espaçadas, só onde a copa não tampa a luta.
	# A borda varia em trechos: mata fechada, pedras, tronco caído, ruína (muro, pilar, totem) e
	# raízes gigantes. Do lado de baixo da tela (perto da câmera) só peças baixas, para não tapar a luta.
	var extra := {}
	for line in room.border_lines:
		var style := ""
		var left := 0
		for i in line.size():
			var p: Vector3 = line[i]
			var outward := Vector3(p.x, 0, p.z).normalized()
			var south := p.z > half * 0.6
			if left <= 0:
				style = _border_style(rng, south)
				left = rng.randi_range(3, 6)
			left -= 1
			var tangent: Vector3 = (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)])
			tangent.y = 0.0
			var yaw := atan2(tangent.x, tangent.z) if tangent.length() > 0.01 else rng.randf() * TAU
			if _wet(origin + p, 0.0):
				continue
			match style:
				"pedras":
					_add(extra, "pedra_musgo", _xf(rng, p + outward * rng.randf_range(0.3, 0.8), rng.randf_range(0.55, 0.85) if south else rng.randf_range(0.8, 1.35)))
					if rng.randf() < 0.5:
						_add(extra, "pedra_musgo", _xf(rng, p + outward * rng.randf_range(0.9, 1.6) + tangent.normalized() * 0.5, rng.randf_range(0.4, 0.7)))
					if rng.randf() < 0.4:
						bushes.append(_xf(rng, p + outward * 1.4, rng.randf_range(0.6, 0.9)))
				"tronco":
					if i % 2 == 0:
						var xf := Transform3D(Basis(Vector3.UP, yaw + PI * 0.5 + rng.randf_range(-0.2, 0.2)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.1)), p + outward * 0.6)
						_add(extra, "tronco_caido", xf)
					if not south and rng.randf() < 0.6:
						bushes.append(_xf(rng, p + outward * 1.5, rng.randf_range(0.8, 1.1)))
				"ruina":
					if i % 2 == 0:
						var xf := Transform3D(Basis(Vector3.UP, yaw + PI * 0.5).scaled(Vector3.ONE * rng.randf_range(0.9, 1.1)), p + outward * 0.5)
						_add(extra, "muro_ruina", xf)
					elif rng.randf() < 0.5:
						_add(extra, "pilar_ruina" if rng.randf() < 0.65 or not ResourceLoader.exists(ART % "totem_pedra") else "totem_pedra", _xf(rng, p + outward * 0.7, rng.randf_range(0.85, 1.15)))
					if rng.randf() < 0.5:
						ferns_edge.append(_xf(rng, p - outward * 0.3, rng.randf_range(0.8, 1.2)))
				"raizes":
					if i % 3 == 0:
						var xf := Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.3, 0.3)).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)), p + outward * 0.8)
						_add(extra, "raiz_gigante", xf)
					bushes.append(_xf(rng, p + outward * 1.8, rng.randf_range(0.7, 1.0)))
				"paredao":
					if i % 2 == 0:
						_add(extra, "rocha_paredao", Transform3D(Basis(Vector3.UP, yaw + PI * 0.5 + rng.randf_range(-0.25, 0.25)).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)), p + outward * 0.9))
				_:
					var bush := p + outward * rng.randf_range(0.2, 0.5)
					bushes.append(_xf(rng, bush, rng.randf_range(0.55, 0.75) if south else rng.randf_range(0.9, 1.35)))
			if rng.randf() < 0.5:
				ferns_edge.append(_xf(rng, p - outward * rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.3)))
			if rng.randf() < 0.55:
				var tree_pos := p + outward * rng.randf_range(2.0, 4.5)
				_plant_tall(rng, origin + tree_pos, origin, trees, palms)
	for kind in extra:
		var list: Array[Transform3D] = []
		list.assign(extra[kind])
		_multimesh(room, kind, list, false)
	_multimesh(room, "moita", bushes, false)
	_multimesh(room, "arvore_borda", trees, false)
	_multimesh(room, "palmeira", palms, false)
	_multimesh(room, "samambaia", ferns_edge, false)

	# Obstáculos com colisão (pedras e tronco caído) só nas salas de luta, perto das paredes, sem
	# encostar nas sumaúmas nem uns nos outros. Às vezes vêm em dupla (pedra grande + pequena).
	var taken: Array = []  # [posição, raio]
	for pillar in room.pillars:
		taken.append([Vector3(pillar.x, 0, pillar.z), 1.4])
	if room.type == DungeonLayout.RoomType.COMBAT:
		var rocks := rng.randi_range(0, 2)
		for i in rocks:
			var s := rng.randf_range(0.75, 1.3)
			var p := _free_spot(rng, half - 1.8, 4.2, 0.75 * s, taken, door_dirs, half)
			if p == Vector3.INF:
				continue
			_solid(room, "pedra_musgo", _xf(rng, p, s), Vector3(1.2, 1.0, 1.2))
			room.pillars.append(Vector3(p.x, 1.0, p.z))
			taken.append([p, 0.75 * s])
		if rng.randf() < 0.5:
			var p := _free_spot(rng, half - 2.0, 4.5, 1.35, taken, door_dirs, half)
			if p != Vector3.INF:
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p)
				_solid(room, "tronco_caido", xf, Vector3(2.6, 0.7, 0.8))
				room.pillars.append(Vector3(p.x, 1.0, p.z))
				taken.append([p, 1.35])

	# Chão: plantas pequenas, mais perto das paredes (o meio fica limpo para lutar), fora das peças.
	var small := {"samambaia": [], "bromelia": [], "cogumelos": []}
	var count := 26 if room.type != DungeonLayout.RoomType.BOSS else 34
	for i in count:
		var p := _edge_point(rng, half - 0.6, 3.0)
		var roll := rng.randf()
		var kind := "samambaia" if roll < 0.6 else ("bromelia" if roll < 0.85 else "cogumelos")
		var inside := false
		for t in taken:
			if Vector2(p.x - t[0].x, p.z - t[0].z).length() < float(t[1]) + 0.25:
				inside = true
		if inside:
			# encostadinha na pedra/tronco fica bonito (cogumelo e samambaia ao pé), dentro não
			continue
		small[kind].append(_xf(rng, p, rng.randf_range(0.7, 1.4)))
	for kind in small:
		var list: Array[Transform3D] = []
		list.assign(small[kind])
		_multimesh(room, kind, list, false)


## Estilo de um trecho da borda (só os que têm modelo; o sul, perto da câmera, só os baixos).
static func _border_style(rng: RandomNumberGenerator, south: bool) -> String:
	var options := [["mata", 3.0], ["pedras", 2.0], ["tronco", 1.5]]
	if not south:
		if ResourceLoader.exists(ART % "muro_ruina") and ResourceLoader.exists(ART % "pilar_ruina"):
			options.append(["ruina", 2.5])
		if ResourceLoader.exists(ART % "raiz_gigante"):
			options.append(["raizes", 1.5])
		if ResourceLoader.exists(ART % "rocha_paredao"):
			options.append(["paredao", 1.5])
	var total := 0.0
	for o in options:
		total += float(o[1])
	var roll := rng.randf() * total
	for o in options:
		roll -= float(o[1])
		if roll <= 0.0:
			return o[0]
	return "mata"


static func _add(bucket: Dictionary, kind: String, xf: Transform3D) -> void:
	if not bucket.has(kind):
		bucket[kind] = []
	bucket[kind].append(xf)


## Ponto livre perto da parede: fora do meio, longe das portas e com folga das peças já postas.
static func _free_spot(rng: RandomNumberGenerator, limit: float, min_from_center: float, radius: float,
		taken: Array, door_dirs: Array[Vector2i], half: float) -> Vector3:
	for attempt in 10:
		var p := _edge_point(rng, limit, min_from_center)
		if _near_door(p, door_dirs, half):
			continue
		var ok := true
		for t in taken:
			if Vector2(p.x - t[0].x, p.z - t[0].z).length() < radius + float(t[1]) + 1.0:
				ok = false
				break
		if ok:
			return p
	return Vector3.INF


## Mata entre as clareiras e trilhas: árvores e palmeiras onde a copa não tampa ninguém, moitas e
## samambaias no chão. Em blocos do tamanho de uma sala (cada bloco é desenhado só quando aparece).
static func forest(parent: Node3D, rng: RandomNumberGenerator) -> void:
	if _walk.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r in _walk:
		lo = lo.min(r.position)
		hi = hi.max(r.end)
	lo -= Vector2(7, 7)
	hi += Vector2(7, 7)
	var chunks := {}  # bloco -> {tipo: [Transform3D]}
	var step := 2.4
	var x := lo.x
	while x <= hi.x:
		var z := lo.y
		while z <= hi.y:
			var p := Vector3(x + rng.randf_range(-0.9, 0.9), 0, z + rng.randf_range(-0.9, 0.9))
			z += step
			# plantas baixas podem chegar perto da clareira (não tampam nada); árvores, só mais longe
			if _near_walk(p.x, p.z, -0.4) or _wet(p, 1.2):
				continue
			var key := Vector2i(floori(p.x / DungeonBuilder.CELL), floori(p.z / DungeonBuilder.CELL))
			if not chunks.has(key):
				chunks[key] = {"arvore_borda": [], "palmeira": [], "moita": [], "samambaia": []}
			var c: Dictionary = chunks[key]
			var trees: Array[Transform3D] = []
			var palms: Array[Transform3D] = []
			if rng.randf() < 0.6 and not _near_walk(p.x, p.z, 1.2):
				_plant_tall(rng, p, Vector3.ZERO, trees, palms)
			c.arvore_borda.append_array(trees)
			c.palmeira.append_array(palms)
			if rng.randf() < 0.4:
				c.moita.append(_xf(rng, p + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)), rng.randf_range(0.9, 1.5)))
			if rng.randf() < 0.3:
				c.samambaia.append(_xf(rng, p + Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4)), rng.randf_range(0.9, 1.5)))
		x += step
	for key in chunks:
		for kind in chunks[key]:
			var list: Array[Transform3D] = []
			list.assign(chunks[key][kind])
			_multimesh(parent, kind, list, false)


static func _near_walk(x: float, z: float, margin: float) -> bool:
	for r in _walk:
		if r.grow(margin).has_point(Vector2(x, z)):
			return true
	return false


## Sumaúma no lugar do pilar (a colisão continua a do pilar).
static func trunk(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var node := _instance("sumauma")
	node.name = "sumauma_%d" % parent.get_child_count()
	node.transform = _xf(rng, Vector3(pos.x, 0.0, pos.z), rng.randf_range(0.85, 1.15))
	parent.add_child(node)


## Trilha: moitas pelas duas bordas, samambaias na beirada e algumas árvores por trás.
static func trail(parent: Node3D, left: PackedVector3Array, right: PackedVector3Array, side: Vector3, rng: RandomNumberGenerator) -> void:
	var bushes: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for pair in [[left, -1.0], [right, 1.0]]:
		var line: PackedVector3Array = pair[0]
		var out: Vector3 = side * float(pair[1])
		for i in range(1, line.size() - 1):
			var p: Vector3 = line[i]
			var south := out.z > 0.5
			if _wet(p, 0.4):
				continue  # onde a trilha cruza o igarapé: a pinguela, sem moita em cima
			if rng.randf() < 0.22:
				rocks.append(_xf(rng, p + out * rng.randf_range(0.4, 0.8), rng.randf_range(0.5, 0.9)))
			else:
				bushes.append(_xf(rng, p + out * rng.randf_range(0.4, 0.7), rng.randf_range(0.55, 0.75) if south else rng.randf_range(0.9, 1.3)))
			if rng.randf() < 0.6:
				ferns.append(_xf(rng, p - out * 0.35, rng.randf_range(0.7, 1.1)))
			if rng.randf() < 0.5:
				_plant_tall(rng, p + out * rng.randf_range(2.2, 4.5), Vector3.ZERO, trees, palms)
	_multimesh(parent, "moita", bushes, false)
	_multimesh(parent, "pedra_musgo", rocks, false)
	_multimesh(parent, "samambaia", ferns, false)
	_multimesh(parent, "arvore_borda", trees, false)
	_multimesh(parent, "palmeira", palms, false)


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
	node.name = "Decor_%s_%d" % [kind, parent.get_child_count()]  # nome único (trilhas e mata dividem o pai)
	node.set_meta("kind", kind)
	node.multimesh = mm
	node.set_meta("xforms", transforms)  # posições das cópias (os testes sem tela não leem o MultiMesh)
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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	Lighting.mesh_no_shadow_receive(piece.mesh)
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
