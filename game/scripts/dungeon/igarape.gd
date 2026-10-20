class_name Igarape
extends Node3D
## Igarapé: um córrego estreito correndo pela mata entre as clareiras (nunca dentro delas).
## Passa no vão entre duas fileiras de salas (ou por fora do andar), com curvas suaves.
## Onde cruza uma trilha, uma pinguela de tábuas. Folhas descem boiando na correnteza.
## Não tem colisão: fica atrás da borda de mata; nas trilhas, a heroína passa pela pinguela.

const HALF_WIDTH := 0.95       # meia largura da água (m)
const MUD := 0.75              # faixa de barro de cada lado (pintada no chão)
const MEANDER := 0.5           # quanto a curva se afasta da linha (m)
const LEAF_COUNT := 7
const LEAF_SPEED := 0.45       # m/s
const TEX_DIR := "res://game/art/chao/%s"

var path := PackedVector3Array()    # linha do meio, no mundo (y = 0)
var _lengths := PackedFloat32Array()
var _leaves: Array[MeshInstance3D] = []
var _leaf_pos: Array[float] = []
var _leaf_side: Array[float] = []


## Escolhe por onde o igarapé passa neste andar. Devolve a linha do meio (vazia = sem igarapé).
static func plan(layout: DungeonLayout, rng: RandomNumberGenerator) -> PackedVector3Array:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for r in layout.rooms:
		lo = Vector2i(mini(lo.x, r.cell.x), mini(lo.y, r.cell.y))
		hi = Vector2i(maxi(hi.x, r.cell.x), maxi(hi.y, r.cell.y))
	var vertical := rng.randf() < 0.5
	if hi.x == lo.x:
		vertical = false
	elif hi.y == lo.y:
		vertical = true
	# linhas possíveis: os vãos entre colunas (ou linhas) de salas, mais as duas de fora
	var a := lo.x if vertical else lo.y
	var b := hi.x if vertical else hi.y
	var lines: Array[float] = []
	for i in range(a - 1, b + 1):
		lines.append((i + 0.5) * DungeonBuilder.CELL)
	# preferir os vãos de dentro (aparece mais durante a run); os de fora às vezes
	var inner := lines.slice(1, lines.size() - 1)
	var line: float = inner[rng.randi_range(0, inner.size() - 1)] if not inner.is_empty() and rng.randf() < 0.7 \
			else lines[rng.randi_range(0, lines.size() - 1)]
	var from := (float(lo.y if vertical else lo.x) - 0.7) * DungeonBuilder.CELL
	var to := (float(hi.y if vertical else hi.x) + 0.7) * DungeonBuilder.CELL
	var phase := rng.randf() * TAU
	var out := PackedVector3Array()
	var t := from
	while t <= to + 0.01:
		var off := sin(t * 0.21 + phase) * MEANDER + sin(t * 0.07 + phase * 1.7) * MEANDER * 0.5
		out.append(Vector3(line + off, 0, t) if vertical else Vector3(t, 0, line + off))
		t += 1.0
	return out


## Distância horizontal do ponto até a linha do meio do igarapé.
static func distance_to(points: PackedVector3Array, p: Vector3) -> float:
	var best := INF
	for i in points.size() - 1:
		var a := Vector2(points[i].x, points[i].z)
		var b := Vector2(points[i + 1].x, points[i + 1].z)
		var q := Vector2(p.x, p.z)
		var ab := b - a
		var k := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * k))
	return best


func setup(points: PackedVector3Array, trails: Array) -> void:
	path = points
	name = "Igarape"
	if path.size() < 2:
		return
	_lengths.resize(path.size())
	_lengths[0] = 0.0
	for i in range(1, path.size()):
		_lengths[i] = _lengths[i - 1] + path[i].distance_to(path[i - 1])
	_build_water()
	for trail in trails:
		_maybe_bridge(trail)
	_build_leaves()


# ---------- água ----------

func _build_water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in path.size() - 1:
		var segs := []
		for k in [i, i + 1]:
			var d := _dir_at(k)
			var side := Vector3(-d.z, 0, d.x)
			var c := path[k] + Vector3(0, 0.03, 0)
			segs.append([c - side * HALF_WIDTH, c + side * HALF_WIDTH, _lengths[k] / (HALF_WIDTH * 2.0)])
		var a = segs[0]
		var b = segs[1]
		_tri(st, a[0], Vector2(0, a[2]), b[0], Vector2(0, b[2]), b[1], Vector2(1, b[2]))
		_tri(st, a[0], Vector2(0, a[2]), b[1], Vector2(1, b[2]), a[1], Vector2(1, a[2]))
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Agua"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/agua_igarape.gdshader")
	mat.set_shader_parameter("agua", load(TEX_DIR % "agua_igarape.jpg"))
	mi.material_override = mat
	add_child(mi)


func _tri(st: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
	for v in [[a, ua], [b, ub], [c, uc]]:
		st.set_normal(Vector3.UP)
		st.set_uv(v[1])
		st.add_vertex(v[0])


func _dir_at(i: int) -> Vector3:
	var a := path[maxi(i - 1, 0)]
	var b := path[mini(i + 1, path.size() - 1)]
	var d := b - a
	d.y = 0.0
	return d.normalized()


# ---------- pinguela ----------

## Se a trilha cruza o igarapé, põe uma pinguela de tábuas no cruzamento.
func _maybe_bridge(center_line: PackedVector3Array) -> void:
	# o ponto da trilha mais perto da água: se a trilha encosta no igarapé (mesmo só de raspão),
	# a pinguela vai ali
	var best := INF
	var best_p := Vector3.ZERO
	var best_dir := Vector3.FORWARD
	for i in center_line.size() - 1:
		var a := center_line[i]
		var b := center_line[i + 1]
		for s in 6:
			var p := a.lerp(b, s / 5.0)
			var d := distance_to(path, p)
			if d < best:
				best = d
				best_p = p
				best_dir = Vector3(b.x - a.x, 0.0, b.z - a.z)
	if best < HALF_WIDTH:
		_bridge(best_p, best_dir.normalized())


func _bridge(at: Vector3, along: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Pinguela"
	add_child(node, true)  # nome legível também na 2ª pinguela (Pinguela2), para achar pelo nome
	node.global_position = Vector3(at.x, 0, at.z)
	node.rotation.y = atan2(along.x, along.z)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.z * 17.0)
	var length := HALF_WIDTH * 2.0 + MUD * 2.0 + 0.4   # vai de barranco a barranco
	var planks := 6
	var width := DungeonRoom.DOOR_W - 0.4
	if ResourceLoader.exists(BRIDGE_MODEL) and _bridge_model(node, width, length):
		return
	for k in planks:
		var plank := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width / planks - 0.06, 0.08, length + rng.randf_range(-0.2, 0.2))
		plank.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("6b4a2f").darkened(rng.randf_range(0.0, 0.25))
		m.roughness = 1.0
		plank.material_override = m
		plank.position = Vector3(-width * 0.5 + (k + 0.5) * width / planks, 0.1 + rng.randf_range(0.0, 0.02), 0)
		plank.rotation.y = rng.randf_range(-0.04, 0.04)
		node.add_child(plank)
	for side in [-1.0, 1.0]:  # vigas por baixo, de tronco
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.12
		cyl.height = length + 0.3
		cyl.radial_segments = 6
		beam.mesh = cyl
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color("4a3626")
		bm.roughness = 1.0
		beam.material_override = bm
		beam.rotation.x = PI * 0.5
		beam.position = Vector3(side * width * 0.35, 0.02, 0)
		node.add_child(beam)


const BRIDGE_MODEL := "res://game/art/ambiente/pinguela.glb"
const PLANK_TOP := 0.92  # altura do tampo das tábuas no modelo (fração da altura; as cordas ficam acima)


## A pinguela de verdade (modelo): as tábuas do modelo correm no eixo Z dele (o lado curto),
## então Z vai na direção da trilha (de barranco a barranco) e X na largura da passagem.
func _bridge_model(node: Node3D, width: float, length: float) -> bool:
	var scene: Node = load(BRIDGE_MODEL).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		scene.free()
		return false
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh
	scene.free()
	var aabb := mesh.get_aabb()
	var sx := width / maxf(aabb.size.x, 0.001)
	var sz := length / maxf(aabb.size.z, 0.001)
	var sy := minf(sx, sz) * 0.5  # achatada: a pinguela é baixa
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3(sx, sy, sz)
	# o herói anda no chão (altura 0): o tampo das tábuas fica rente ao chão e as toras de baixo
	# entram no barranco; assim o pé pisa em cima da madeira, sem afundar nela
	var top := aabb.position.y + aabb.size.y * PLANK_TOP
	mi.position = Vector3(-aabb.get_center().x * sx, -top * sy + 0.03, -aabb.get_center().z * sz)
	node.add_child(mi)
	return true


# ---------- folhas boiando ----------

func _build_leaves() -> void:
	var tex: Texture2D = load(TEX_DIR % "folhas.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_lengths[_lengths.size() - 1] * 100.0)
	for i in LEAF_COUNT:
		var q := PlaneMesh.new()
		q.size = Vector2.ONE * rng.randf_range(0.28, 0.4)
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 1.0
		m.uv1_scale = Vector3(0.5, 0.5, 1)
		m.uv1_offset = Vector3(0.5 * (i % 2), 0.5 * ((i / 2) % 2), 0)
		q.material = m
		var leaf := MeshInstance3D.new()
		leaf.mesh = q
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(leaf)
		_leaves.append(leaf)
		_leaf_pos.append(rng.randf() * _lengths[_lengths.size() - 1])
		_leaf_side.append(rng.randf_range(-0.55, 0.55))
		leaf.rotation.y = rng.randf() * TAU


func _process(delta: float) -> void:
	if _leaves.is_empty():
		return
	var total := _lengths[_lengths.size() - 1]
	for i in _leaves.size():
		_leaf_pos[i] = fmod(_leaf_pos[i] + LEAF_SPEED * delta * (0.8 + 0.1 * (i % 4)), total)
		var p := _point_at(_leaf_pos[i])
		var d := _dir_at(clampi(_index_at(_leaf_pos[i]), 0, path.size() - 1))
		var side := Vector3(-d.z, 0, d.x)
		_leaves[i].position = p + side * _leaf_side[i] * HALF_WIDTH + Vector3(0, 0.05, 0)
		_leaves[i].rotate_y(delta * 0.3 * (1.0 if i % 2 == 0 else -1.0))


func _index_at(dist: float) -> int:
	var lo := 0
	var hi := _lengths.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _lengths[mid] <= dist:
			lo = mid
		else:
			hi = mid
	return lo


func _point_at(dist: float) -> Vector3:
	var i := _index_at(dist)
	var j := mini(i + 1, path.size() - 1)
	var span := maxf(_lengths[j] - _lengths[i], 1e-4)
	return path[i].lerp(path[j], clampf((dist - _lengths[i]) / span, 0.0, 1.0))
