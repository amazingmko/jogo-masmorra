class_name RoomProp
extends Area3D
## Objeto especial de uma sala: baú, fonte de cura ou portal de saída.
## Ativa uma vez quando o herói encosta e avisa com o sinal `activated`.

signal activated(prop: RoomProp)

enum Kind { CHEST, FOUNTAIN, PORTAL }

var kind: Kind = Kind.CHEST
var used := false

var _lid: Node3D
var _glow_mat: StandardMaterial3D
var _age := 0.0
var _swirl: Node3D
var _treasure: Node3D


static func create(prop_kind: Kind) -> RoomProp:
	var p := RoomProp.new()
	p.kind = prop_kind
	p.name = ["Bau", "Fonte", "Portal"][prop_kind]
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.1
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = 1.0
	add_child(shape)
	var art: String = ["bau", "fonte", "portal"][kind]
	if ResourceLoader.exists(RoomDecor.ART % art):
		match kind:
			Kind.CHEST:
				_build_chest_model()
			Kind.FOUNTAIN:
				_build_fountain_model()
			Kind.PORTAL:
				_build_portal_model()
	else:
		match kind:
			Kind.CHEST:
				_build_chest()
			Kind.FOUNTAIN:
				_build_fountain()
			Kind.PORTAL:
				_build_portal()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_age += delta
	if _glow_mat and not used:
		_glow_mat.emission_energy_multiplier = 1.2 + 0.6 * sin(_age * 3.0)
	if _swirl:
		_swirl.rotate_object_local(Vector3.FORWARD, delta * 1.2)


func _on_body_entered(body: Node3D) -> void:
	if used or not body.is_in_group("player"):
		return
	# No quadro em que o herói troca de andar, a física ainda o vê onde estava no andar velho: se um
	# baú/fonte/portal do andar novo nascer naquele ponto, dispararia sozinho (pulava um andar).
	var flat := Vector2(body.global_position.x - global_position.x, body.global_position.z - global_position.z)
	if flat.length() > 1.8:
		return
	used = true
	match kind:
		Kind.CHEST:
			create_tween().tween_property(_lid, "rotation:x", deg_to_rad(-110), 0.25)
			if _treasure:
				_treasure.visible = true
				Vfx.particles(self, _treasure.position + Vector3(0, 0.1, 0), "faisca", 16, 0.9, Color(1.0, 0.85, 0.4), 0.18, Vector2(1.0, 2.5), 35.0, -2.0)
		Kind.FOUNTAIN:
			_glow_mat.emission_energy_multiplier = 0.2
			_glow_mat.albedo_color = _glow_mat.albedo_color.darkened(0.5)
			_glow_mat.albedo_color.a = 0.15
	activated.emit(self)


# ---------- modelos (lote 3) ----------

## Baú: o modelo é cortado em corpo e tampa (pela altura da emenda) para a tampa abrir.
const CHEST_SPLIT := 0.6   # fração da altura onde a tampa começa


func _build_chest_model() -> void:
	var piece := RoomDecor._piece("bau")
	var parts: Array = _split_chest(piece.mesh)
	var base: Transform3D = piece.base
	var aabb: AABB = piece.mesh.get_aabb()
	var body := MeshInstance3D.new()
	body.mesh = parts[0]
	body.transform = base
	add_child(body)
	# dobradiça: atrás (z mínimo), na altura da emenda
	var hinge_local := Vector3(aabb.get_center().x, aabb.position.y + aabb.size.y * CHEST_SPLIT, aabb.position.z)
	var hinge := base * hinge_local
	_lid = Node3D.new()
	_lid.position = hinge
	add_child(_lid)
	var lid := MeshInstance3D.new()
	lid.mesh = parts[1]
	lid.transform = Transform3D(base.basis, base.origin - hinge)
	_lid.add_child(lid)
	# "tesouro" lá dentro: tampa a boca do baú com um brilho dourado (aparece quando abre)
	var size: Vector3 = aabb.size * base.basis.get_scale()
	var gold := _mat(Color("d9a93a"))
	gold.metallic = 0.8
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color("e8b64a")
	gold.emission_energy_multiplier = 0.25
	var coin := CylinderMesh.new()
	coin.top_radius = 0.07
	coin.bottom_radius = 0.07
	coin.height = 0.025
	coin.radial_segments = 8
	coin.rings = 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crng := RandomNumberGenerator.new()
	crng.seed = 77
	for i in 46:  # monte de moedas, mais alto no meio
		var u := Vector2(crng.randf_range(-0.5, 0.5), crng.randf_range(-0.5, 0.5))
		var heap := (1.0 - u.length() * 1.6) * 0.12
		var at := Vector3(u.x * size.x * 0.8, maxf(heap, 0.0) + crng.randf() * 0.04, u.y * size.z * 0.75)
		var b := Basis(Vector3(crng.randf(), 0, crng.randf()).normalized(), crng.randf_range(0.0, 0.6))
		st.append_from(coin, 0, Transform3D(b, at))
	var inside := MeshInstance3D.new()
	inside.mesh = st.commit()
	inside.material_override = gold
	inside.position = (base * Vector3(aabb.get_center().x, aabb.position.y + aabb.size.y * CHEST_SPLIT * 0.8, aabb.get_center().z))
	add_child(inside)
	inside.visible = false
	_treasure = inside
	_glow_mat = _sparkle(Vector3(0, size.y + 0.2, 0), Color("e8c26a"), 0.6)


func _split_chest(mesh: Mesh) -> Array:
	var aabb := mesh.get_aabb()
	var cut := aabb.position.y + aabb.size.y * CHEST_SPLIT
	var low := SurfaceTool.new()
	var high := SurfaceTool.new()
	low.begin(Mesh.PRIMITIVE_TRIANGLES)
	high.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(mesh as ArrayMesh, 0)
	for f in mdt.get_face_count():
		var ys := 0.0
		for k in 3:
			ys += mdt.get_vertex(mdt.get_face_vertex(f, k)).y
		var st := high if ys / 3.0 > cut else low
		for k in 3:
			var v := mdt.get_face_vertex(f, k)
			st.set_normal(mdt.get_vertex_normal(v))
			st.set_uv(mdt.get_vertex_uv(v))
			st.add_vertex(mdt.get_vertex(v))
	# o modelo é uma casca: aberto, dá para ver por dentro (os dois lados das faces)
	var mat: Material = mesh.surface_get_material(0).duplicate()
	if mat is BaseMaterial3D:
		(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	low.set_material(mat)
	high.set_material(mat)
	return [low.commit(), high.commit()]


func _build_fountain_model() -> void:
	add_child(RoomDecor._instance("fonte"))
	# brilho verde por cima da água da fonte (apaga depois de usada)
	var size: Vector3 = RoomDecor._piece("fonte").mesh.get_aabb().size
	var k: float = RoomDecor.SIZE["fonte"][1] / maxf(size.x, size.z)
	var water := CylinderMesh.new()
	water.top_radius = size.x * k * 0.27
	water.bottom_radius = water.top_radius
	water.height = 0.02
	_glow_mat = _mat(Color(0.45, 1.0, 0.55, 0.45), true)
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh(water, Vector3(0, size.y * k * 0.62, 0), _glow_mat)
	Vfx.particles(self, Vector3(0, size.y * k * 0.7, 0), "faisca", 10, 1.6, Color(0.6, 1.0, 0.6, 0.8), 0.15, Vector2(0.2, 0.6), 25.0, 0.3, true, false)


func _build_portal_model() -> void:
	var arch := RoomDecor._instance("portal")
	add_child(arch)  # o arco fica de frente para a câmera (a passagem é de norte a sul)
	var size: Vector3 = RoomDecor._piece("portal").mesh.get_aabb().size
	var k: float = RoomDecor.SIZE["portal"][1] / maxf(size.x, size.z)
	var h: float = size.y * k
	_glow_mat = _mat(Color("4db8ff"), true)
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.albedo_texture = Vfx.tex("onda_choque")
	_glow_mat.albedo_color = Color(0.35, 0.75, 1.0, 0.85)
	_swirl = Node3D.new()
	_swirl.position = Vector3(0, h * 0.42, 0)
	add_child(_swirl)
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x * k * 0.42, h * 0.78)
	_mesh(quad, Vector3.ZERO, _glow_mat, _swirl)
	var fill := QuadMesh.new()  # névoa azul no meio do arco
	fill.size = quad.size * 0.9
	var fill_mat := _glow_mat.duplicate()
	fill_mat.albedo_texture = Vfx.tex("faisca")
	fill_mat.albedo_color = Color(0.25, 0.6, 1.0, 0.7)
	_mesh(fill, Vector3(0, h * 0.42, 0.01), fill_mat)
	# círculo no chão, como antes, para ler de longe que é a saída
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.05
	var ring_mat := _glow_mat.duplicate()
	ring_mat.albedo_texture = null
	ring_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	_mesh(ring, Vector3(0, 0.03, 0.9), ring_mat)
	Vfx.particles(self, Vector3(0, h * 0.4, 0), "faisca", 14, 1.2, Color(0.5, 0.85, 1.0, 0.9), 0.15, Vector2(0.2, 0.8), 180.0, 0.0, true, false)


## Brilhinho pulsando (indica que dá para pegar).
func _sparkle(pos: Vector3, color: Color, radius: float) -> StandardMaterial3D:
	var m := _mat(Color(color, 0.0), true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dot := SphereMesh.new()
	dot.radius = 0.01
	dot.height = 0.02
	_mesh(dot, pos, m)
	Vfx.particles(self, pos, "faisca", 8, 1.4, Color(color, 0.9), 0.12, Vector2(0.1, 0.4), 180.0, 0.2, true, false, radius)
	return m


# ---------- visual provisório ----------

func _mat(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.2
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_chest() -> void:
	var wood := _mat(Color("8a5a3c"))
	var gold := _mat(Color("e8c26a"), true)
	_glow_mat = gold
	var body := BoxMesh.new()
	body.size = Vector3(1.4, 0.7, 0.9)
	_mesh(body, Vector3(0, 0.35, 0), wood)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.7, -0.45)
	add_child(_lid)
	var lid := BoxMesh.new()
	lid.size = Vector3(1.45, 0.3, 0.95)
	_mesh(lid, Vector3(0, 0.15, 0.45), wood, _lid)
	var band := BoxMesh.new()
	band.size = Vector3(0.25, 0.32, 0.97)
	_mesh(band, Vector3(0, 0.15, 0.45), gold, _lid)


func _build_fountain() -> void:
	var basin := CylinderMesh.new()
	basin.top_radius = 1.2
	basin.bottom_radius = 1.3
	basin.height = 0.6
	_mesh(basin, Vector3(0, 0.3, 0), _mat(Color("6e6488")))
	var water := CylinderMesh.new()
	water.top_radius = 1.0
	water.bottom_radius = 1.0
	water.height = 0.05
	_glow_mat = _mat(Color("6fdc7b"), true)
	_mesh(water, Vector3(0, 0.62, 0), _glow_mat)


func _build_portal() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.2
	_glow_mat = _mat(Color("4db8ff"), true)
	_mesh(ring, Vector3(0, 0.05, 0), _glow_mat)
	var core := CylinderMesh.new()
	core.top_radius = 0.9
	core.bottom_radius = 0.9
	core.height = 0.04
	var core_mat := _mat(Color(0.3, 0.7, 1.0, 0.6), true)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(core, Vector3(0, 0.04, 0), core_mat)
