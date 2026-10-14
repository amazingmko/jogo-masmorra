extends Node3D
## Hub: a base entre as runs. Uma praça com quatro pontos de interação:
##   Portal da Masmorra (norte) · Baú e Equipamento (oeste) · Quadro de Heróis (leste) · Oficina dos Artesãos (sul)
## A praça é montada por código (visual provisório até a etapa de arte).

const DUNGEON_SCENE := "res://game/scenes/main.tscn"

@onready var _player: Player = $Player
@onready var _town: Node3D = $Town
@onready var _camera: Camera3D = $Camera
@onready var _ui: HubUI = $HubUI


func _ready() -> void:
	get_tree().paused = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_player.combat_enabled = false
	_player.global_position = Vector3(0, 0.1, -1)
	_player.reset_physics_interpolation()
	# Câmera um pouco mais alta que na masmorra, para ver a praça inteira.
	_camera.offset = Vector3(0, 15.0, 10.5)
	_camera.snap()
	_build_town()
	_ui.setup(_player)
	_ui.enter_dungeon_requested.connect(_enter_dungeon)


func _process(_delta: float) -> void:
	_player.touch_move = _ui.move_vector()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
		_ui.activate_current_station()


func _enter_dungeon() -> void:
	GameState.save()
	var err := get_tree().change_scene_to_file(DUNGEON_SCENE)
	if err != OK:
		push_error("Não foi possível abrir a masmorra (erro %d)." % err)


# ---------- praça ----------

func _build_town() -> void:
	var stone := _mat(Color("4a4458"))
	var wall := _mat(Color("5c5470"))
	DungeonBuilder.box(_town, Vector3(30, 0.5, 30), Vector3(0, -0.25, 0), stone)
	for spec in [[Vector3(30, 1.2, 0.6), Vector3(0, 0.6, -15)], [Vector3(30, 1.2, 0.6), Vector3(0, 0.6, 15)],
			[Vector3(0.6, 1.2, 30), Vector3(-15, 0.6, 0)], [Vector3(0.6, 1.2, 30), Vector3(15, 0.6, 0)]]:
		DungeonBuilder.box(_town, spec[0], spec[1], wall)
	# Caminho de pedra clara em cruz, ligando as estações.
	var path := _mat(Color("6e6488"))
	DungeonBuilder.box(_town, Vector3(3, 0.52, 26), Vector3(0, -0.24, 0), path)
	DungeonBuilder.box(_town, Vector3(26, 0.52, 3), Vector3(0, -0.24, 0), path)

	_add_station(&"portal", "Portal da Masmorra", "ENTRAR", Vector3(0, 0, -8), _portal_visual())
	_add_station(&"bau", "Baú e Equipamento", "ABRIR", Vector3(-7.5, 0, 0), _chest_visual())
	_add_station(&"herois", "Quadro de Heróis", "ABRIR", Vector3(7.5, 0, 0), _board_visual())
	_add_station(&"artesao", "Oficina dos Artesãos", "FALAR", Vector3(0, 0, 7.5), _artisan_visual())

	for pos in [Vector3(-12, 2.5, -12), Vector3(12, 2.5, -12), Vector3(-12, 2.5, 12), Vector3(12, 2.5, 12)]:
		var light := OmniLight3D.new()
		light.light_color = Color("ffb35c")
		light.light_energy = 1.4
		light.omni_range = 9.0
		light.position = pos
		_town.add_child(light)
		DungeonBuilder.box(_town, Vector3(0.5, 2.2, 0.5), Vector3(pos.x, 1.1, pos.z), wall)


func _add_station(id: StringName, title: String, action: String, pos: Vector3, visual: Node3D) -> void:
	var station := HubStation.create(id, title, action)
	station.position = pos
	station.add_child(visual)
	_town.add_child(station)
	station.presence_changed.connect(_ui.on_station_presence)


func _mat(color: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.3
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _portal_visual() -> Node3D:
	var n := Node3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.3
	ring.outer_radius = 1.7
	var r := MeshInstance3D.new()
	r.mesh = ring
	r.rotation_degrees = Vector3(90, 0, 0)
	r.position = Vector3(0, 1.8, 0)
	r.material_override = _mat(Color("4db8ff"), true)
	n.add_child(r)
	var base := BoxMesh.new()
	base.size = Vector3(4, 0.3, 1.4)
	_mesh(n, base, Vector3(0, 0.15, 0), _mat(Color("6e6488")))
	return n


func _chest_visual() -> Node3D:
	var n := Node3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(1.8, 0.9, 1.1)
	_mesh(n, body, Vector3(0, 0.45, 0), _mat(Color("8a5a3c")))
	var lid := BoxMesh.new()
	lid.size = Vector3(1.85, 0.35, 1.15)
	_mesh(n, lid, Vector3(0, 1.07, 0), _mat(Color("8a5a3c")))
	var band := BoxMesh.new()
	band.size = Vector3(0.3, 1.3, 1.18)
	_mesh(n, band, Vector3(0, 0.65, 0), _mat(Color("e8c26a"), true))
	return n


func _board_visual() -> Node3D:
	var n := Node3D.new()
	var board := BoxMesh.new()
	board.size = Vector3(0.2, 1.6, 2.4)
	_mesh(n, board, Vector3(0, 1.5, 0), _mat(Color("8a5a3c")))
	for z in [-0.9, 0.0, 0.9]:
		var paper := BoxMesh.new()
		paper.size = Vector3(0.22, 0.7, 0.55)
		_mesh(n, paper, Vector3(-0.02, 1.5, z), _mat(Color("f2ecff")))
	for z in [-1.1, 1.1]:
		var post := BoxMesh.new()
		post.size = Vector3(0.2, 2.4, 0.2)
		_mesh(n, post, Vector3(0, 1.2, z), _mat(Color("5a3c28")))
	return n


func _artisan_visual() -> Node3D:
	var n := Node3D.new()
	var anvil := BoxMesh.new()
	anvil.size = Vector3(1.2, 0.6, 0.6)
	_mesh(n, anvil, Vector3(1.2, 0.5, 0), _mat(Color("3b3350")))
	var npc := CapsuleMesh.new()
	npc.radius = 0.45
	npc.height = 1.7
	_mesh(n, npc, Vector3(-0.4, 0.85, 0), _mat(Color("c98a5b")))
	var apron := BoxMesh.new()
	apron.size = Vector3(0.7, 0.8, 0.12)
	_mesh(n, apron, Vector3(-0.4, 0.8, 0.42), _mat(Color("5a3c28")))
	return n
