class_name DungeonRoom
extends Node3D
## Uma sala da masmorra, desenhada como clareira na mata: a borda é irregular (árvores, moitas e
## raízes, sem parede reta), com vãos de porta que viram cipós com espinhos durante a luta, e um
## sensor que avisa quando o herói entra. A área de luta continua sendo o quadrado SIZE x SIZE;
## a borda só se abre para fora dele (os inimigos nunca nascem dentro da mata).

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
var _barriers: Array[VineBarrier] = []
## Contorno da clareira, um trecho por lado (sem o vão das portas), em coordenadas da sala.
var border_lines: Array[PackedVector3Array] = []
## Até onde a borda avança para fora do quadrado.
const BORDER_OUT := 1.8
var _materials: Dictionary
## Covil Furioso: sala rara, só com furiosos, com um baú grande no fim.
var is_den := false
## Semente da decoração (plantas, pedras): a mesma sala sai sempre igual.
var _decor_seed := 0


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
	_decor_seed = rng.randi()
	cleared = type != DungeonLayout.RoomType.COMBAT and type != DungeonLayout.RoomType.BOSS
	if type == DungeonLayout.RoomType.COMBAT or type == DungeonLayout.RoomType.BOSS:
		for spot in PILLAR_SPOTS:
			if rng.randf() < 0.45:
				pillars.append(Vector3(spot.x, 1.0, spot.y))


func _ready() -> void:
	var decor_rng := RandomNumberGenerator.new()
	decor_rng.seed = _decor_seed
	# Chão do chefe e do covil: mesmo chão, com outro tom por cima.
	if type == DungeonLayout.RoomType.BOSS or is_den:
		var tint := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(SIZE + 2.0, SIZE + 2.0)
		tint.mesh = plane
		tint.position.y = 0.01
		tint.material_override = _materials.floor_den if is_den else _materials.floor_boss
		tint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tint)
	for dir in DungeonLayout.DIRS:
		_build_border(dir, decor_rng)
	for p in pillars:
		var pillar := DungeonBuilder.box(self, Vector3(1.2, 2.0, 1.2), p, _materials.pillar)
		pillar.get_child(1).visible = false  # a caixa só dá a colisão; o que se vê é a sumaúma
		RoomDecor.trunk(self, p, decor_rng)
	RoomDecor.populate(self, decor_rng, _door_dirs)
	_build_trigger()


func center() -> Vector3:
	return global_position


## True se o ponto está dentro da área interna da sala (não no corredor).
func contains(point: Vector3) -> bool:
	var half := SIZE * 0.5
	return absf(point.x - global_position.x) <= half and absf(point.z - global_position.z) <= half


func close_doors() -> void:
	for b in _barriers:
		b.close()


func open_doors() -> void:
	for b in _barriers:
		b.open()


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

## Um lado da clareira: contorno irregular (só para fora do quadrado), colisão invisível seguindo
## o contorno e, se houver porta, o vão com a barreira de cipós.
func _build_border(dir: Vector2i, rng: RandomNumberGenerator) -> void:
	var half := SIZE * 0.5
	var along := Vector3(absf(dir.y), 0, absf(dir.x))
	var out := Vector3(dir.x, 0, dir.y)
	var has_door := _door_dirs.has(dir)
	var gap := DOOR_W * 0.5
	var ts: Array[float] = []
	var t := -half - 1.0
	while t <= half + 1.0 + 0.01:
		if not (has_door and absf(t) < gap):
			ts.append(t)
		t += 0.9
	if has_door:
		ts.append(-gap)
		ts.append(gap)
		ts.sort()
	var lines: Array[PackedVector3Array] = [PackedVector3Array()]
	var phase := rng.randf() * TAU
	for i in ts.size():
		var tt: float = ts[i]
		if has_door and i > 0 and ts[i - 1] <= -gap + 0.001 and tt >= gap - 0.001:
			lines.append(PackedVector3Array())  # o vão da porta
		# Quanto a borda se afasta: ondulação suave + sorteio; perto da porta e dos cantos volta à linha.
		var bulge := (0.5 + 0.5 * sin(tt * 0.55 + phase)) * BORDER_OUT * rng.randf_range(0.6, 1.0)
		if has_door:
			bulge *= clampf((absf(tt) - gap) / 2.0, 0.0, 1.0)
		bulge *= clampf((half + 1.0 - absf(tt)) / 2.5, 0.25, 1.0)
		lines[-1].append(out * (half + WALL_T * 0.5 + bulge) + along * tt)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	for line in lines:
		if line.size() < 2:
			continue
		border_lines.append(line)
		for i in line.size() - 1:
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(a.distance_to(b) + 0.35, 2.0, WALL_T)
			col.shape = shape
			col.position = (a + b) * 0.5 + Vector3(0, 1.0, 0)
			col.rotation.y = atan2(b.x - a.x, b.z - a.z) + PI * 0.5
			body.add_child(col)
	if has_door:
		var barrier := VineBarrier.new()
		barrier.setup(DOOR_W, WALL_T)
		barrier.position = out * (half + WALL_T * 0.5)
		barrier.rotation.y = atan2(along.x, along.z) - PI * 0.5
		add_child(barrier)
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
