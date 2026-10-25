class_name HubHall
extends Node3D
## Salão dos Portais (o hub): um lugar neutro, fora de qualquer bioma, com a cara da interface
## (pedra azul-noite, frisos dourados, linhas de luz azul-clara) e céu estrelado por cima.
##  - fundo: os portais dos biomas lado a lado (o aberto gira e brilha; os "em breve" apagados);
##  - meio: a Pedra do Encontro (cristal girando), onde o grupo se reúne;
##  - esquerda: Baú e Equipamento; direita: Altar dos Heróis (o herói escolhido em forma de
##    espírito de luz, girando devagar); frente: a Oficina.
## As estações (HubStation) são criadas aqui; hub.gd só liga os sinais.

signal station_created(station: HubStation)

const SIZE := Vector2(24, 30)
const PORTAL_Z := -12.0
const REGION_COLOR := {"terra_firme": Color("7fc97a"), "igapo": Color("4db8ff"), "urnas": Color("e8a050"), "cerrado": Color("e8d29a")}
const HERO_COLOR := {"icamiaba": Color("e8a050"), "mateira": Color("7fc97a"), "encantado": Color("4db8ff"), "druida": Color("c49bff")}

var _stone: StandardMaterial3D
var _stone2: StandardMaterial3D
var _gold: StandardMaterial3D
var _glow: StandardMaterial3D
var _crystal: Node3D
var _altar_spot := Vector3.ZERO
var _spirit: Node3D
var _spirit_hero: StringName = &""
var _hero_gems := {}
var _t := 0.0


func _ready() -> void:
	name = "Salao"
	_stone = _mat(Color("27344a"), 0.55)
	_stone2 = _mat(Color("1b2536"), 0.6)
	_gold = _mat(Color("d9b066"), 0.35, 0.85)
	_glow = _mat(Color("8fdcff"), 0.3, 0.0, 2.2)
	_build_room()
	var regions: Array = HubUI.REGIONS
	var n := regions.size()
	for i in n:
		var r: Dictionary = regions[i]
		var open: bool = int(r.world) >= 0 and not r.get("soon", false)
		var title: String = r.name if r.name != "Em breve" else String(r.biome)
		_portal(Vector3(-8.4 + i * (16.8 / maxf(n - 1, 1)), 0, PORTAL_Z), String(r.id), title, open)
	_meeting_stone(Vector3(0, 0, -1.5))
	_chest_station(Vector3(-7.5, 0, 3.5))
	_altar_station(Vector3(7.5, 0, 3.5))
	_craft_station(Vector3(0, 0, 9.0))


func _process(delta: float) -> void:
	_t += delta
	if _crystal:
		_crystal.rotation.y += delta * 0.8
		_crystal.position.y = 2.1 + sin(_t * 1.6) * 0.12
	if GameState.selected_hero != _spirit_hero:
		_make_spirit(GameState.selected_hero)
	if _spirit:
		_spirit.rotation.y += delta * 0.6


## Céu do hub (chamado pelo hub.gd com o WorldEnvironment da cena).
static func apply_environment(world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var env := world.environment
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY
	sm.shader = sh
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8fa8d0")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_color = Color("e8eeff")
	sun.light_energy = 1.1
	sun.shadow_enabled = true


const SKY := """
shader_type sky;
// Céu de crepúsculo profundo: azul-noite, um véu de nebulosa e estrelas pequenas que cintilam.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 c = mix(vec3(0.03, 0.05, 0.10), vec3(0.06, 0.10, 0.20), h);
	float neb = sin(d.x * 3.0 + d.z * 2.0) * sin(d.y * 4.0 - d.x * 1.5);
	c += vec3(0.10, 0.08, 0.20) * smoothstep(0.3, 1.0, neb) * 0.6;
	vec2 g = floor(d.xz / (abs(d.y) + 0.35) * 160.0);
	float s = step(0.996, hash(g));
	float tw = 0.6 + 0.4 * sin(TIME * (1.5 + 3.0 * hash(g + 7.0)) + hash(g) * 30.0);
	c += vec3(0.9, 0.95, 1.0) * s * (0.5 + 0.5 * hash(g + 3.1)) * tw;
	COLOR = c;
}
"""


# ---------- salão ----------

func _build_room() -> void:
	# base e piso
	_box(Vector3(0, -0.3, 0), Vector3(SIZE.x, 0.6, SIZE.y), _stone2, true)
	var p := PlaneMesh.new()
	p.size = SIZE - Vector2(2, 2)
	_mesh(p, Vector3(0, 0.01, 0), _floor_mat(SIZE.y * 0.5 - 1.0))
	_box(Vector3(0, 0.03, SIZE.y * 0.5 - 1.0), Vector3(SIZE.x - 2, 0.05, 0.15), _gold, false)
	# colunas dos lados
	for z in [-9.0, -3.0, 3.0, 9.0]:
		for x in [-SIZE.x * 0.5 + 1.0, SIZE.x * 0.5 - 1.0]:
			_column(Vector3(x, 0, z), 5.0)
	# parede do fundo (baixa: a câmera vê de cima) e muretas dos lados e da frente
	_box(Vector3(0, 1.0, -SIZE.y * 0.5 + 0.4), Vector3(SIZE.x, 2.0, 0.8), _stone, true)
	_box(Vector3(0, 2.05, -SIZE.y * 0.5 + 0.4), Vector3(SIZE.x, 0.12, 0.9), _gold, false)
	for x in [-SIZE.x * 0.5 + 0.4, SIZE.x * 0.5 - 0.4]:
		_box(Vector3(x, 0.6, 0), Vector3(0.8, 1.2, SIZE.y), _stone, true)
		_box(Vector3(x, 1.25, 0), Vector3(0.9, 0.1, SIZE.y), _gold, false)
	for x in [-7.0, 7.0]:
		_box(Vector3(x, 0.3, SIZE.y * 0.5 - 0.4), Vector3(SIZE.x * 0.5 - 4.0, 0.6, 0.8), _stone, true)
	_box(Vector3(0, 0.3, SIZE.y * 0.5 + 0.2), Vector3(SIZE.x, 0.6, 0.4), null, true)  # invisível: não sai pela frente


# ---------- estações ----------

func _station(id: StringName, title: String, action: String, at: Vector3, color: Color, region := "", height := 3.2) -> HubStation:
	var s := HubStation.create(id, title, action)
	s.region = region
	s.label_height = height
	s.label_color = color
	s.show_label = false  # o nome vai numa placa fixa (ver _plaque)
	s.position = at
	add_child(s)
	station_created.emit(s)
	return s


## Portal: arco de pedra com friso dourado, base em degrau, miolo de luz na cor do bioma.
func _portal(at: Vector3, region: String, title: String, open: bool) -> void:
	var color: Color = REGION_COLOR.get(region, Color("8fa0b8"))
	var p := Node3D.new()
	p.position = at
	p.scale = Vector3.ONE * 1.15
	add_child(p)
	_sub(p, _boxm(Vector3(3.8, 0.3, 1.8)), Vector3(0, 0.15, 0), _stone)
	_sub(p, _boxm(Vector3(3.4, 0.08, 1.5)), Vector3(0, 0.33, 0), _gold)
	var arch := TorusMesh.new()
	arch.inner_radius = 1.25
	arch.outer_radius = 1.7
	arch.rings = 48
	_sub(p, arch, Vector3(0, 2.0, 0), _stone, Vector3(PI * 0.5, 0, 0))
	var trim := TorusMesh.new()
	trim.inner_radius = 1.22
	trim.outer_radius = 1.32
	trim.rings = 48
	_sub(p, trim, Vector3(0, 2.0, 0.05), _gold, Vector3(PI * 0.5, 0, 0))
	for x in [-1.5, 1.5]:
		_sub(p, _boxm(Vector3(0.5, 2.0, 0.6)), Vector3(x, 1.0, 0), _stone)
	var gem := SphereMesh.new()
	gem.radius = 0.22
	gem.height = 0.44
	_sub(p, gem, Vector3(0, 4.95, 0.1), _mat(color, 0.2, 0.0, 2.5 if open else 0.4))
	# placa com o nome presa no alto do arco
	_sub(p, _boxm(Vector3(0.14, 0.6, 0.14)), Vector3(0, 3.95, 0), _gold)
	_plaque(p, Vector3(0, 4.35, 0.12), title, "" if open else "em breve",
		color.lerp(Color.WHITE, 0.25) if open else Color(0.7, 0.76, 0.86), -0.35, 0.87)
	var sm := ShaderMaterial.new()
	sm.shader = _shader("swirl", SWIRL)
	sm.set_shader_parameter("cor", color)
	sm.set_shader_parameter("vivo", 1.0 if open else 0.0)
	var disc := QuadMesh.new()
	disc.size = Vector2(2.5, 2.5)
	_sub(p, disc, Vector3(0, 2.0, 0), sm)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5 if open else 0.4
	light.omni_range = 5.0
	light.position = Vector3(0, 1.8, 1.2)
	p.add_child(light)
	# o ponto de entrar fica na frente do portal (pisando no degrau)
	_station(&"portal", title if open else "%s\n(em breve)" % title, "ENTRAR" if open else "VER",
		at + Vector3(0, 0, 1.6), color.lerp(Color.WHITE, 0.2) if open else Color(0.62, 0.68, 0.78), region)


## Pedra do Encontro: onde o grupo se reúne; cristal girando sobre um círculo de luz.
func _meeting_stone(at: Vector3) -> void:
	_cyl(at + Vector3(0, 0.12, 0), 2.6, 0.24, _stone)
	_ring(at + Vector3(0, 0.25, 0), 2.6, 0.08, _gold)
	_ring(at + Vector3(0, 0.26, 0), 1.9, 0.04, _glow)
	_crystal = Node3D.new()
	_crystal.position = at + Vector3(0, 2.1, 0)
	add_child(_crystal)
	var up := CylinderMesh.new()
	up.top_radius = 0.0
	up.bottom_radius = 0.55
	up.height = 1.4
	up.radial_segments = 6
	_sub(_crystal, up, Vector3(0, 0.5, 0), _glow)
	var down := CylinderMesh.new()
	down.top_radius = 0.55
	down.bottom_radius = 0.0
	down.height = 0.9
	down.radial_segments = 6
	_sub(_crystal, down, Vector3(0, -0.65, 0), _glow)
	var light := OmniLight3D.new()
	light.light_color = Color("8fdcff")
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = at + Vector3(0, 2.2, 0)
	add_child(light)
	_box(at + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.4), null, true)  # não atravessa o cristal
	_post_sign(at + Vector3(0, 0, -2.9), "Pedra do Encontro", Color("cfe9ff"))


func _chest_station(at: Vector3) -> void:
	_cyl(at + Vector3(0, 0.1, 0), 1.8, 0.2, _stone)
	_ring(at + Vector3(0, 0.21, 0), 1.8, 0.05, _gold)
	var wood := _mat(Color("3a2a4a"), 0.6)
	var chest := Node3D.new()
	chest.position = at + Vector3(0, 0, -0.6)
	add_child(chest)
	_sub(chest, _boxm(Vector3(1.8, 0.9, 1.1)), Vector3(0, 0.65, 0), wood)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.58
	lid.bottom_radius = 0.58
	lid.height = 1.86
	lid.radial_segments = 16
	_sub(chest, lid, Vector3(0, 1.1, 0), wood, Vector3(0, 0, PI * 0.5))
	for x in [-0.6, 0.6]:
		_sub(chest, _boxm(Vector3(0.14, 0.95, 1.18)), Vector3(x, 0.66, 0), _gold)
		var band := TorusMesh.new()
		band.inner_radius = 0.56
		band.outer_radius = 0.64
		_sub(chest, band, Vector3(x, 1.1, 0), _gold, Vector3(0, 0, PI * 0.5))
	_sub(chest, _boxm(Vector3(0.3, 0.34, 0.06)), Vector3(0, 0.95, 0.57), _glow)
	_box(at + Vector3(0, 0.6, -0.6), Vector3(1.9, 1.2, 1.2), null, true)
	_post_sign(at + Vector3(0, 0, -1.7), "Baú e Equipamento", Color("ffd98a"))
	_station(&"bau", "Baú e Equipamento", "ABRIR", at + Vector3(0, 0, 0.5), Color("ffd98a"))


## Altar dos Heróis: no meio, o herói escolhido em forma de espírito de luz, girando devagar;
## em volta, uma pedra acesa para cada herói (a do escolhido brilha mais).
func _altar_station(at: Vector3) -> void:
	_cyl(at + Vector3(0, 0.15, 0), 2.0, 0.3, _stone)
	_ring(at + Vector3(0, 0.31, 0), 2.0, 0.06, _gold)
	_cyl(at + Vector3(0, 0.45, 0), 1.1, 0.3, _stone2)
	_ring(at + Vector3(0, 0.61, 0), 1.1, 0.04, _glow)
	_altar_spot = at + Vector3(0, 0.62, 0)
	var ids: Array = GameState.STARTING_HEROES
	for i in ids.size():
		var a := TAU * i / ids.size() + PI * 0.25
		var pos := at + Vector3(cos(a), 0, sin(a)) * 1.6
		_cyl(pos + Vector3(0, 0.45, 0), 0.16, 0.3, _gold, 12)
		var gem := SphereMesh.new()
		gem.radius = 0.15
		gem.height = 0.3
		var m := _mat(HERO_COLOR.get(ids[i], Color.WHITE), 0.2, 0.0, 0.6)
		_mesh(gem, pos + Vector3(0, 0.75, 0), m)
		_hero_gems[StringName(ids[i])] = m
	var light := OmniLight3D.new()
	light.light_color = Color("8fdcff")
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position = at + Vector3(0, 2.4, 0.6)
	add_child(light)
	_box(at + Vector3(0, 0.6, 0), Vector3(2.2, 1.2, 2.2), null, true)
	_post_sign(at + Vector3(0, 0, -2.4), "Altar dos Heróis", Color("ffd98a"))
	_station(&"herois", "Altar dos Heróis", "ABRIR", at + Vector3(0, 0, 1.4), Color("ffd98a"), "", 3.9)


func _make_spirit(hero_id: StringName) -> void:
	_spirit_hero = hero_id
	if is_instance_valid(_spirit):
		_spirit.queue_free()
	for id in _hero_gems:
		var m: StandardMaterial3D = _hero_gems[id]
		m.emission_energy_multiplier = 3.0 if id == hero_id else 0.5
	var path := "res://game/art/herois/%s.glb" % hero_id
	if not ResourceLoader.exists(path):
		return
	_spirit = (load(path) as PackedScene).instantiate()
	add_child(_spirit)
	var box := Ward._bounds(_spirit, Transform3D.IDENTITY)
	var k := 2.1 / maxf(box.size.y, 0.01)
	_spirit.scale = Vector3.ONE * k
	_spirit.position = _altar_spot - Vector3(0, box.position.y * k, 0)
	var sm := ShaderMaterial.new()
	sm.shader = _shader("spirit", SPIRIT)
	sm.set_shader_parameter("cor", HERO_COLOR.get(hero_id, Color("8fdcff")).lerp(Color("8fdcff"), 0.5))
	_override(_spirit, sm)


func _override(n: Node, m: Material) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_override = m
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_override(c, m)


## Oficina: bigorna e bancada, com um círculo de fabricação aceso no chão.
func _craft_station(at: Vector3) -> void:
	_cyl(at + Vector3(0, 0.03, 0), 2.2, 0.06, _stone)
	_ring(at + Vector3(0, 0.07, 0), 2.2, 0.05, _gold)
	_ring(at + Vector3(0, 0.08, 0), 1.6, 0.03, _glow)
	var metal := _mat(Color("5b6578"), 0.3, 0.9)
	var wood := _mat(Color("4a3a2e"), 0.7)
	# bigorna: pé, corpo e o bico
	_box(at + Vector3(-1.0, 0.35, 0.2), Vector3(0.5, 0.7, 0.5), _stone2, false)
	_box(at + Vector3(-1.0, 0.82, 0.2), Vector3(1.0, 0.28, 0.5), metal, false)
	var horn := CylinderMesh.new()
	horn.top_radius = 0.0
	horn.bottom_radius = 0.2
	horn.height = 0.5
	_mesh(horn, at + Vector3(-1.72, 0.84, 0.2), metal, Vector3(0, 0, PI * 0.5))
	_box(at + Vector3(1.0, 0.62, -0.4), Vector3(1.8, 0.1, 0.9), wood, false)
	for x in [0.25, 1.75]:
		_box(at + Vector3(x, 0.3, -0.4), Vector3(0.12, 0.6, 0.8), wood, false)
	_box(at + Vector3(0.7, 0.75, -0.4), Vector3(0.36, 0.16, 0.28), _glow, false)
	var vial := CylinderMesh.new()
	vial.top_radius = 0.08
	vial.bottom_radius = 0.12
	vial.height = 0.3
	_mesh(vial, at + Vector3(1.4, 0.82, -0.3), _mat(Color("e8a050"), 0.2, 0.0, 1.5))
	_box(at + Vector3(0, 0.5, -0.2), Vector3(3.6, 1.0, 1.2), null, true)
	_post_sign(at + Vector3(0, 0, -1.4), "Oficina", Color("ffd98a"))
	_station(&"artesao", "Oficina", "FALAR", at + Vector3(0, 0, 1.0), Color("ffd98a"))


# ---------- ajudantes ----------

func _mat(c: Color, rough := 0.6, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _mesh(mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	add_child(mi)
	return mi


func _sub(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)


## Caixa; solid: com colisão (mat null = só colisão, invisível).
func _box(at: Vector3, size: Vector3, mat: Material, solid: bool) -> void:
	if mat:
		_mesh(_boxm(size), at, mat)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		body.position = at
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		add_child(body)


func _cyl(at: Vector3, r: float, h: float, mat: Material, segs := 48) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	_mesh(c, at, mat)


func _ring(at: Vector3, r: float, thick: float, mat: Material) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r + thick
	t.rings = 64
	t.ring_segments = 12
	_mesh(t, at, mat)


func _column(at: Vector3, h: float) -> void:
	_cyl(at + Vector3(0, 0.2, 0), 0.75, 0.4, _stone2, 24)
	_cyl(at + Vector3(0, h * 0.5, 0), 0.5, h, _stone, 24)
	_cyl(at + Vector3(0, h, 0), 0.75, 0.3, _gold, 24)
	_box(at + Vector3(0, h * 0.5, 0), Vector3(1.0, h, 1.0), null, true)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("8fdcff")
	lamp.light_energy = 0.7
	lamp.omni_range = 5.0
	lamp.position = at + Vector3(0, 2.5, 0)
	add_child(lamp)


## Placa fixa com o nome: moldura dourada, face de pedra e o nome gravado (não flutua nem gira).
## tilt: inclinada para trás, para ler bem com a câmera de cima.
func _plaque(parent: Node3D, at: Vector3, text: String, sub: String, color: Color, tilt := -0.45, scale_k := 1.0) -> void:
	var n := Node3D.new()
	n.position = at
	n.rotation.x = tilt
	n.scale = Vector3.ONE * scale_k
	parent.add_child(n)
	var chars := maxi(text.length(), sub.length())
	var w := chars * 0.2 + 0.8
	var h := 0.62 if sub == "" else 0.86
	_sub(n, _boxm(Vector3(w + 0.14, h + 0.14, 0.08)), Vector3(0, 0, -0.03), _gold)
	_sub(n, _boxm(Vector3(w, h, 0.1)), Vector3.ZERO, _stone2)
	for x in [-w * 0.5 - 0.02, w * 0.5 + 0.02]:
		var tip := SphereMesh.new()
		tip.radius = 0.09
		tip.height = 0.18
		_sub(n, tip, Vector3(x, 0, 0.04), _gold)
	var l := Label3D.new()
	l.text = text
	l.font = UiStyle.title_font()
	l.font_size = 48
	l.pixel_size = 0.0075
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.02, 0.03, 0.06, 1.0)
	l.position = Vector3(0, 0.0 if sub == "" else 0.13, 0.065)
	l.double_sided = false
	n.add_child(l)
	if sub != "":
		var s := Label3D.new()
		s.text = sub
		s.font = UiStyle.title_font()
		s.font_size = 34
		s.pixel_size = 0.0075
		s.modulate = Color(0.62, 0.68, 0.78)
		s.outline_size = 8
		s.outline_modulate = Color(0.02, 0.03, 0.06, 1.0)
		s.position = Vector3(0, -0.2, 0.065)
		n.add_child(s)


## Poste dourado com a placa em cima (estações do salão).
func _post_sign(at: Vector3, text: String, color: Color) -> void:
	_cyl(at + Vector3(0, 0.08, 0), 0.32, 0.16, _stone, 16)
	_cyl(at + Vector3(0, 0.95, 0), 0.07, 1.8, _gold, 12)
	_plaque(self, at + Vector3(0, 2.05, 0), text, "", color)


func _world_label(text: String, at: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UiStyle.title_font()
	l.font_size = 56
	l.pixel_size = 0.009
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.03, 0.05, 0.1, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	add_child(l)


static var _shaders := {}


func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = code
		_shaders[key] = s
	return _shaders[key]


func _floor_mat(radius: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("piso", FLOOR)
	m.set_shader_parameter("raio", radius)
	return m


const FLOOR := """
shader_type spatial;
// Piso do salão: lajotas azul-noite em anéis, frisos dourados (anéis e raios, como uma rosa dos
// ventos) e duas linhas finas de luz azul-clara.
uniform float raio = 14.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
varying vec3 w;
void vertex() { w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = w.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz - vec2(0.0, -1.5);
	float r = length(p);
	float a = atan(p.y, p.x);
	vec3 base = vec3(0.022, 0.034, 0.065);
	float ring_i = floor(r / 2.2);
	float sec_i = floor((a + 3.1416) / 6.2832 * (8.0 + ring_i * 4.0));
	base *= 0.9 + 0.2 * hash(vec2(ring_i, sec_i));
	float joint = smoothstep(0.04, 0.0, abs(fract(r / 2.2) - 0.5) - 0.46);
	base *= 1.0 - 0.25 * joint;
	float gold = 0.0;
	for (int i = 1; i < 4; i++) {
		gold = max(gold, smoothstep(0.09, 0.0, abs(r - raio * float(i) * 0.27)));
	}
	float rays = smoothstep(0.035, 0.0, abs(sin(a * 4.0)) * r * 0.25) * step(raio * 0.27, r) * step(r, raio * 0.81);
	gold = max(gold, rays);
	vec3 c = mix(base, vec3(0.62, 0.40, 0.14), gold);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.2 - r * 0.4);
	float glow = smoothstep(0.05, 0.0, abs(r - raio * 0.4)) + smoothstep(0.05, 0.0, abs(r - raio * 0.93));
	ALBEDO = c;
	METALLIC = gold * 0.7;
	ROUGHNESS = mix(0.5, 0.3, gold);
	EMISSION = vec3(0.3, 0.7, 1.0) * glow * 1.4 * pulse;
}
"""

const SWIRL := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// Miolo do portal: redemoinho de luz na cor do bioma (fechado: quase apagado e parado).
uniform vec3 cor : source_color = vec3(0.5, 0.8, 0.5);
uniform float vivo = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float a = atan(p.y, p.x) + r * 6.0 - TIME * 2.0 * vivo;
	float s = 0.5 + 0.5 * sin(a * 3.0);
	float core = 1.0 - smoothstep(0.0, 1.0, r);
	vec3 c = cor * (0.35 + 0.65 * s) * (0.4 + core) * mix(0.25, 1.0, vivo);
	ALBEDO = c * (1.0 - smoothstep(0.85, 1.0, r));
}
"""

const SPIRIT := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// Espírito de luz do herói: só a borda acende (fresnel), com faixas finas subindo.
uniform vec3 cor : source_color = vec3(0.56, 0.86, 1.0);
varying float h;
void vertex() { h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float bands = 0.75 + 0.25 * step(0.5, fract(h * 9.0 - TIME * 0.8));
	ALBEDO = cor * (0.3 + rim * 1.8) * bands;
}
"""
