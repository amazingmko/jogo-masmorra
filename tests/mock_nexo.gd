extends SceneTree
## Propostas do hub "neutro" (sem bioma): um lugar limpo de encontro, com os portais para os
## biomas, a oficina e a troca de herói. Tudo feito de formas simples + materiais próprios
## (pedra azul-noite, frisos dourados, luz azul-clara: a mesma cara da interface Abissal).
##   godot --path . --fixed-fps 60 --script res://tests/mock_nexo.gd -- out=/pasta
## Variações: A "Santuário Flutuante", B "Salão dos Portais", C "Anfiteatro dos Portais".

var _out := "/tmp"
var _root: Node3D
var _cam: Camera3D
var _font: Font
var _stone: StandardMaterial3D
var _stone2: StandardMaterial3D
var _gold: StandardMaterial3D
var _glow: StandardMaterial3D
var _label_i := 0

const REGIONS := [["Terra Firme", true, Color("7fc97a")], ["Várzea e Igapó", false, Color("4db8ff")],
	["Cidade das Urnas", false, Color("e8a050")], ["Cerrado", false, Color("e8d29a")]]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_font = load("res://game/ui/fontes/marcellus_sc.ttf")
	_stone = _mat(Color("27344a"), 0.55)
	_stone2 = _mat(Color("1b2536"), 0.6)
	_gold = _mat(Color("d9b066"), 0.35, 0.85)
	_glow = _mat(Color("8fdcff"), 0.3, 0.0, 2.2)
	for v in ["A", "B", "C"]:
		_build(v)
		await _frames(25)
		await _shot(Vector3(0, 25, 19), Vector3(0, 0, -2.0), "%s_cima" % v, 55.0)
		await _shot(Vector3(0, 15.0, 9.0), Vector3(0, 0, -2.5), "%s_jogo" % v, 50.0)
		_root.queue_free()
		await _frames(3)
	quit(0)


func _shot(pos: Vector3, look: Vector3, name: String, fov: float) -> void:
	_cam.global_position = pos
	_cam.fov = fov
	_cam.look_at(look, Vector3.UP)
	await _frames(3)
	root.get_viewport().get_texture().get_image().save_png("%s/nexo_%s.png" % [_out, name])


# ---------- cena ----------

const SKY := """
shader_type sky;
// Céu de crepúsculo profundo: azul-noite com um véu de nebulosa e estrelas pequenas.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 c = mix(vec3(0.03, 0.05, 0.10), vec3(0.06, 0.10, 0.20), h);
	float neb = sin(d.x * 3.0 + d.z * 2.0) * sin(d.y * 4.0 - d.x * 1.5);
	c += vec3(0.10, 0.08, 0.20) * smoothstep(0.3, 1.0, neb) * 0.6;
	vec2 g = floor(d.xz / (abs(d.y) + 0.35) * 160.0);
	float s = step(0.996, hash(g));
	c += vec3(0.9, 0.95, 1.0) * s * (0.5 + 0.5 * hash(g + 3.1));
	COLOR = c;
}
"""


func _build(v: String) -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_label_i = 0
	var world := WorldEnvironment.new()
	var env := Environment.new()
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
	world.environment = env
	_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_color = Color("e8eeff")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	_root.add_child(sun)
	_cam = Camera3D.new()
	_root.add_child(_cam)
	_cam.current = true
	match v:
		"A":
			_santuario()
		"B":
			_salao()
		"C":
			_anfiteatro()


## A: plataforma redonda flutuando no céu; os portais em volta da borda, as estações no meio.
func _santuario() -> void:
	_floor_disc(Vector3(0, 0, 0), 15.0, 1.6, true)
	# pedras soltas flutuando em volta (dá a ideia de "lugar fora do mundo")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(18.0, 26.0)
		var s := rng.randf_range(0.6, 1.8)
		_rock(Vector3(cos(a) * r, rng.randf_range(-4.0, 1.5), sin(a) * r), s, rng)
	_meeting_stone(Vector3(0, 0, 0))
	for i in 5:
		var a := lerpf(-PI * 0.42, PI * 0.42, i / 4.0) - PI * 0.5
		var at := Vector3(cos(a), 0, sin(a)) * 12.5
		var reg: Array = REGIONS[i] if i < REGIONS.size() else ["Em breve", false, Color("6a7a90")]
		_portal(at, reg[0], reg[1], reg[2], atan2(-at.x, -at.z))
	_chest_station(Vector3(-7.0, 0, 3.5))
	_heroes_station(Vector3(7.0, 0, 3.5), 0.0)
	_craft_station(Vector3(0, 0, 8.0))
	_hero(Vector3(0, 0, 4.0))


## B: salão comprido, de piso polido e colunas; os portais grandes na parede do fundo, lado a lado;
## as estações nas laterais; o encontro do grupo num círculo no meio.
func _salao() -> void:
	_box(Vector3(0, -0.3, 0), Vector3(24, 0.6, 30), _stone2)
	_floor_rect(Vector3(0, 0.01, 0), Vector2(22, 28))
	for z in [-9.0, -3.0, 3.0, 9.0]:
		for x in [-11.0, 11.0]:
			_column(Vector3(x, 0, z), 5.0)
	# parede do fundo, baixa (a câmera vê de cima) e muretas dos lados
	_box(Vector3(0, 1.0, -14.6), Vector3(24, 2.0, 0.8), _stone)
	_box(Vector3(0, 2.05, -14.6), Vector3(24, 0.12, 0.9), _gold)
	for x in [-12.4, 12.4]:
		_box(Vector3(x, 0.6, 0), Vector3(0.8, 1.2, 30), _stone)
		_box(Vector3(x, 1.25, 0), Vector3(0.9, 0.1, 30), _gold)
	for i in 4:
		var at := Vector3(-8.4 + i * 5.6, 0, -12.0)
		_portal(at, REGIONS[i][0], REGIONS[i][1], REGIONS[i][2], 0.0, 1.15)
	_meeting_stone(Vector3(0, 0, -1.0))
	_chest_station(Vector3(-8.0, 0, 3.5))
	_heroes_station(Vector3(7.2, 0, 4.0), -PI * 0.5)
	_craft_station(Vector3(0, 0, 9.0))
	_hero(Vector3(0, 0, 4.5))


## C: anfiteatro: praça redonda embaixo (estações e o espelho d'água do encontro) e degraus que
## sobem até um terraço em meia-lua com os portais.
func _anfiteatro() -> void:
	_box(Vector3(0, -0.3, 2), Vector3(40, 0.6, 40), _stone2)
	_floor_disc(Vector3(0, 0, 3.0), 10.0, 0.0, false)
	# degraus em meia-lua e o terraço
	for k in 3:
		_arc_step(Vector3(0, 0, 3.0), 10.5 + k * 1.1, 13.2 + k * 1.1, 0.35 * (k + 1))
	_arc_step(Vector3(0, 0, 3.0), 13.8, 19.0, 1.05, true)
	for i in 5:
		var a := lerpf(-PI * 0.42, PI * 0.42, i / 4.0) - PI * 0.5
		var at := Vector3(0, 1.05, 3.0) + Vector3(cos(a), 0, sin(a)) * 16.0
		var reg: Array = REGIONS[i] if i < REGIONS.size() else ["Em breve", false, Color("6a7a90")]
		_portal(at, reg[0], reg[1], reg[2], atan2(-(at.x), -(at.z - 3.0)))
	_pool(Vector3(0, 0, 1.5), 2.6)
	_chest_station(Vector3(-6.0, 0, 5.5))
	_heroes_station(Vector3(6.0, 0, 5.5), 0.0)
	_craft_station(Vector3(0, 0, 10.0))
	_hero(Vector3(0, 0, 6.0))


# ---------- peças ----------

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


func _mesh(mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	_root.add_child(mi)
	return mi


func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, at, mat)


func _cyl(at: Vector3, r: float, h: float, mat: Material, segs := 48) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	return _mesh(c, at, mat)


func _ring(at: Vector3, r: float, thick: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r - thick
	t.outer_radius = r + thick
	t.rings = 64
	t.ring_segments = 12
	return _mesh(t, at, mat, rot)


const FLOOR_SHADER := """
shader_type spatial;
// Piso do hub: pedra azul-noite em lajotas, com frisos dourados em anéis e raios (rosa dos
// ventos) e linhas de luz azul bem finas.
uniform float raio = 15.0;
uniform bool redondo = true;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
varying vec3 w;
void vertex() { w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = w.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	float r = length(p);
	float a = atan(p.y, p.x);
	vec3 base = vec3(0.022, 0.034, 0.065);
	// lajotas (anéis x setores) com tom levemente diferente
	float ring_i = floor(r / 2.2);
	float sec_i = floor((a + 3.1416) / 6.2832 * (8.0 + ring_i * 4.0));
	base *= 0.9 + 0.2 * hash(vec2(ring_i, sec_i));
	float joint = smoothstep(0.04, 0.0, abs(fract(r / 2.2) - 0.5) - 0.46);
	base *= 1.0 - 0.25 * joint;
	vec3 c = base;
	float gold = 0.0;
	for (int i = 1; i < 4; i++) {
		gold = max(gold, smoothstep(0.09, 0.0, abs(r - raio * float(i) * 0.27)));
	}
	float rays = smoothstep(0.035, 0.0, abs(sin(a * 4.0)) * r * 0.25) * step(raio * 0.27, r) * step(r, raio * 0.81);
	gold = max(gold, rays);
	c = mix(c, vec3(0.62, 0.40, 0.14), gold);
	float glow = smoothstep(0.05, 0.0, abs(r - raio * 0.4)) + smoothstep(0.05, 0.0, abs(r - raio * 0.93));
	ALBEDO = c;
	METALLIC = gold * 0.7;
	ROUGHNESS = mix(0.5, 0.3, gold);
	EMISSION = vec3(0.3, 0.7, 1.0) * glow * 1.4;
}
"""
var _floor_shader: Shader


func _floor_mat(radius: float) -> ShaderMaterial:
	if _floor_shader == null:
		_floor_shader = Shader.new()
		_floor_shader.code = FLOOR_SHADER
	var m := ShaderMaterial.new()
	m.shader = _floor_shader
	m.set_shader_parameter("raio", radius)
	return m


## Disco do chão; thickness > 0: plataforma flutuante (com a borda dourada e a base afunilando).
func _floor_disc(at: Vector3, r: float, thickness: float, floating: bool) -> void:
	var top := CylinderMesh.new()
	top.top_radius = r
	top.bottom_radius = r
	top.height = 0.1
	top.radial_segments = 96
	_mesh(top, at + Vector3(0, -0.05, 0), _floor_mat(r))
	_ring(at + Vector3(0, 0.02, 0), r, 0.12, _gold)
	if floating:
		var under := CylinderMesh.new()
		under.top_radius = r
		under.bottom_radius = r * 0.35
		under.height = thickness * 3.0
		under.radial_segments = 64
		_mesh(under, at + Vector3(0, -0.1 - thickness * 1.5, 0), _stone2)
		_cyl(at + Vector3(0, -0.35, 0), r + 0.05, 0.5, _stone, 96)
		var crystal := CylinderMesh.new()
		crystal.top_radius = 1.2
		crystal.bottom_radius = 0.0
		crystal.height = 3.0
		crystal.radial_segments = 6
		_mesh(crystal, at + Vector3(0, -thickness * 3.0 - 1.8, 0), _glow)


func _floor_rect(at: Vector3, size: Vector2) -> void:
	var p := PlaneMesh.new()
	p.size = size
	var m := _floor_mat(size.y * 0.5)
	_mesh(p, at, m)
	_box(at + Vector3(0, 0.02, size.y * 0.5), Vector3(size.x, 0.05, 0.15), _gold)


func _arc_step(c: Vector3, r0: float, r1: float, h: float, terrace := false) -> void:
	# meia-lua do lado de trás (z < c.z), em pedaços
	var n := 28
	for i in n:
		var a0 := lerpf(PI * 1.03, PI * 1.97, float(i) / n)
		var a1 := lerpf(PI * 1.03, PI * 1.97, float(i + 1) / n)
		var am := (a0 + a1) * 0.5
		var rm := (r0 + r1) * 0.5
		var len := rm * (a1 - a0) + 0.05
		var b := _box(c + Vector3(cos(am) * rm, h * 0.5, sin(am) * rm), Vector3(r1 - r0, h, len), _stone if not terrace else _stone2)
		b.rotation.y = -am
	if terrace:
		for i in n:
			var am := lerpf(PI * 1.03, PI * 1.97, (i + 0.5) / n)
			var g := _box(c + Vector3(cos(am) * r0, h + 0.03, sin(am) * r0), Vector3(0.14, 0.06, r0 * (PI * 0.94 / n) + 0.05), _gold)
			g.rotation.y = -am


func _column(at: Vector3, h: float) -> void:
	_cyl(at + Vector3(0, 0.2, 0), 0.75, 0.4, _stone2, 24)
	_cyl(at + Vector3(0, h * 0.5, 0), 0.5, h, _stone, 24)
	_cyl(at + Vector3(0, h, 0), 0.75, 0.3, _gold, 24)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("8fdcff")
	lamp.light_energy = 0.7
	lamp.omni_range = 5.0
	lamp.position = at + Vector3(0, 2.5, 0)
	_root.add_child(lamp)


func _rock(at: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var c := CylinderMesh.new()
	c.top_radius = s
	c.bottom_radius = s * 0.2
	c.height = s * 1.6
	c.radial_segments = 6
	var mi := _mesh(c, at, _stone2)
	mi.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
	_cyl(at + Vector3(0, s * 0.8 + 0.03, 0), s * 0.98, 0.06, _stone, 6).rotation = mi.rotation


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
var _swirl: Shader


## Portal: arco de pedra com friso dourado, base em degrau, miolo de luz na cor do bioma e o nome.
func _portal(at: Vector3, name: String, open: bool, color: Color, yaw: float, s := 1.0) -> void:
	var p := Node3D.new()
	p.position = at
	p.rotation.y = yaw
	p.scale = Vector3.ONE * s
	_root.add_child(p)
	var add := func(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = pos
		mi.rotation = rot
		mi.material_override = mat
		p.add_child(mi)
	var step := BoxMesh.new()
	step.size = Vector3(3.8, 0.3, 1.8)
	add.call(step, Vector3(0, 0.15, 0), _stone)
	var step2 := BoxMesh.new()
	step2.size = Vector3(3.4, 0.08, 1.5)
	add.call(step2, Vector3(0, 0.33, 0), _gold)
	var arch := TorusMesh.new()
	arch.inner_radius = 1.25
	arch.outer_radius = 1.7
	arch.rings = 48
	add.call(arch, Vector3(0, 2.0, 0), _stone, Vector3(PI * 0.5, 0, 0))
	var trim := TorusMesh.new()
	trim.inner_radius = 1.22
	trim.outer_radius = 1.32
	trim.rings = 48
	add.call(trim, Vector3(0, 2.0, 0.05), _gold, Vector3(PI * 0.5, 0, 0))
	for x in [-1.5, 1.5]:
		var post := BoxMesh.new()
		post.size = Vector3(0.5, 2.0, 0.6)
		add.call(post, Vector3(x, 1.0, 0), _stone)
	var gem := SphereMesh.new()
	gem.radius = 0.22
	gem.height = 0.44
	add.call(gem, Vector3(0, 3.75, 0.1), _mat(color, 0.2, 0.0, 2.5 if open else 0.4))
	if _swirl == null:
		_swirl = Shader.new()
		_swirl.code = SWIRL
	var sm := ShaderMaterial.new()
	sm.shader = _swirl
	sm.set_shader_parameter("cor", color)
	sm.set_shader_parameter("vivo", 1.0 if open else 0.0)
	var disc := QuadMesh.new()
	disc.size = Vector2(2.5, 2.5)
	add.call(disc, Vector3(0, 2.0, 0), sm)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5 if open else 0.4
	light.omni_range = 5.0
	light.position = Vector3(0, 1.8, 1.2)
	p.add_child(light)
	_label(name + ("" if open or name == "Em breve" else "\n(em breve)"), at + Vector3(0, 4.6 * s + 1.1 * (_label_i % 2), 0), color.lerp(Color.WHITE, 0.2) if open else Color(0.62, 0.68, 0.78), 64)
	_label_i += 1


## Pedra do Encontro: onde o grupo se reúne; um cristal girando sobre um círculo de luz.
func _meeting_stone(at: Vector3) -> void:
	_cyl(at + Vector3(0, 0.12, 0), 2.6, 0.24, _stone)
	_ring(at + Vector3(0, 0.25, 0), 2.6, 0.08, _gold)
	_ring(at + Vector3(0, 0.26, 0), 1.9, 0.04, _glow)
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.55
	c.height = 1.4
	c.radial_segments = 6
	_mesh(c, at + Vector3(0, 2.6, 0), _glow)
	var c2 := CylinderMesh.new()
	c2.top_radius = 0.55
	c2.bottom_radius = 0.0
	c2.height = 0.9
	c2.radial_segments = 6
	_mesh(c2, at + Vector3(0, 1.45, 0), _glow)
	var light := OmniLight3D.new()
	light.light_color = Color("8fdcff")
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = at + Vector3(0, 2.2, 0)
	_root.add_child(light)
	_label("Pedra do Encontro", at + Vector3(0, 4.0, 0), Color("cfe9ff"), 60)


func _chest_station(at: Vector3) -> void:
	_cyl(at + Vector3(0, 0.1, 0), 1.8, 0.2, _stone)
	_ring(at + Vector3(0, 0.21, 0), 1.8, 0.05, _gold)
	_box(at + Vector3(0, 0.65, 0), Vector3(1.8, 0.9, 1.1), _mat(Color("3a2a4a"), 0.6))
	_box(at + Vector3(0, 1.22, 0), Vector3(1.86, 0.3, 1.16), _mat(Color("3a2a4a"), 0.6))
	for x in [-0.6, 0.6]:
		_box(at + Vector3(x, 0.8, 0), Vector3(0.14, 0.95, 1.18), _gold)
	_box(at + Vector3(0, 0.85, 0.57), Vector3(0.28, 0.32, 0.06), _glow)
	_label("Baú e Equipamento", at + Vector3(0, 2.6, 0), Color("ffd98a"), 60)


## Heróis: um pedestal com o modelo de cada herói (toca e troca).
func _heroes_station(at: Vector3, yaw: float) -> void:
	var ids := ["icamiaba", "mateira", "encantado", "druida"]
	var dir := Vector3(cos(yaw), 0, -sin(yaw))
	for i in 4:
		var pos: Vector3 = at + dir * (-2.4 + i * 1.6)
		_cyl(pos + Vector3(0, 0.25, 0), 0.62, 0.5, _stone, 24)
		_ring(pos + Vector3(0, 0.51, 0), 0.62, 0.04, _gold)
		_ring(pos + Vector3(0, 0.52, 0), 0.45, 0.025, _glow)
		var h := _model("res://game/art/herois/%s.glb" % ids[i], 1.6)
		h.position = pos + Vector3(0, 0.52, 0)
		h.rotation.y = yaw * 0.0
	_label("Heróis", at + Vector3(0, 2.9, 0), Color("ffd98a"), 60)


## Oficina: bigorna e bancada, com um círculo de fabricação aceso no chão.
func _craft_station(at: Vector3) -> void:
	_cyl(at + Vector3(0, 0.03, 0), 2.2, 0.06, _stone)
	_ring(at + Vector3(0, 0.07, 0), 2.2, 0.05, _gold)
	_ring(at + Vector3(0, 0.08, 0), 1.6, 0.03, _glow)
	_box(at + Vector3(-0.9, 0.45, 0), Vector3(0.6, 0.9, 0.6), _stone2)
	_box(at + Vector3(-0.9, 1.0, 0), Vector3(1.3, 0.25, 0.55), _mat(Color("5b6578"), 0.3, 0.9))
	_box(at + Vector3(1.0, 0.5, -0.2), Vector3(1.6, 0.1, 0.9), _mat(Color("4a3a2e"), 0.7))
	for x in [0.35, 1.65]:
		_box(at + Vector3(x, 0.25, -0.2), Vector3(0.12, 0.5, 0.8), _mat(Color("4a3a2e"), 0.7))
	_box(at + Vector3(1.0, 0.65, -0.2), Vector3(0.4, 0.2, 0.3), _glow)
	_label("Oficina", at + Vector3(0, 2.4, 0), Color("ffd98a"), 60)


func _pool(at: Vector3, r: float) -> void:
	_cyl(at + Vector3(0, 0.15, 0), r + 0.35, 0.3, _stone)
	_ring(at + Vector3(0, 0.31, 0), r + 0.35, 0.07, _gold)
	var water := _mat(Color("0d2238"), 0.05, 0.6)
	water.emission_enabled = true
	water.emission = Color("2b6fa0")
	water.emission_energy_multiplier = 0.5
	_cyl(at + Vector3(0, 0.25, 0), r, 0.12, water)
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.45
	c.height = 1.2
	c.radial_segments = 6
	_mesh(c, at + Vector3(0, 2.3, 0), _glow)
	var c2 := CylinderMesh.new()
	c2.top_radius = 0.45
	c2.bottom_radius = 0.0
	c2.height = 0.8
	c2.radial_segments = 6
	_mesh(c2, at + Vector3(0, 1.3, 0), _glow)
	var light := OmniLight3D.new()
	light.light_color = Color("8fdcff")
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = at + Vector3(0, 2.0, 0)
	_root.add_child(light)
	_label("Espelho do Encontro", at + Vector3(0, 3.6, 0), Color("cfe9ff"), 60)


func _hero(at: Vector3) -> void:
	var h := _model("res://game/art/herois/icamiaba.glb", 1.8)
	h.position = at


func _model(path: String, height: float) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	_root.add_child(n)
	var box := Ward._bounds(n, Transform3D.IDENTITY)
	var k := height / maxf(box.size.y, 0.01)
	n.scale = Vector3.ONE * k
	return n


func _label(text: String, at: Vector3, color: Color, size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = 0.0095
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.03, 0.05, 0.1, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	_root.add_child(l)
