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


func _on_body_entered(body: Node3D) -> void:
	if used or not body.is_in_group("player"):
		return
	used = true
	match kind:
		Kind.CHEST:
			create_tween().tween_property(_lid, "rotation:x", deg_to_rad(-110), 0.25)
		Kind.FOUNTAIN:
			_glow_mat.emission_energy_multiplier = 0.2
			_glow_mat.albedo_color = _glow_mat.albedo_color.darkened(0.5)
	activated.emit(self)


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
