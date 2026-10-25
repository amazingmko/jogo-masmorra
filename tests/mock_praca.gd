extends SceneTree
## Propostas da praça (hub) montadas com as peças 3D que o jogo já tem, para escolher o layout.
## Não mexe no jogo: só monta a cena e tira as fotos (de cima e da câmera do jogo).
##   godot --path . --fixed-fps 60 --script res://tests/mock_praca.gd -- out=/pasta
## Variações: A "Aldeia da Sumaúma", B "Porto do Igarapé", C "Ruínas Antigas".

const ART := "res://game/art/ambiente/%s.glb"
const HALF := 17.0
var _out := "/tmp"
var _root: Node3D
var _ground_mat: ShaderMaterial
var _map: Image
var _cam: Camera3D
var _font: Font
var _portal_i := 0


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
	for v in ["A", "B", "C"]:
		_build(v)
		await _frames(25)
		_shot_from(Vector3(0, 25, 19), Vector3(0, 0, -2.0), "%s_cima" % v, 55.0)
		await _frames(4)
		_shot_from(Vector3(0, 15.0, 10.5) + Vector3(0, 0, -1.5), Vector3(0, 0, -2.5), "%s_jogo" % v, 50.0)
		await _frames(4)
		_root.queue_free()
		await _frames(3)
	quit(0)


func _shot_from(pos: Vector3, look: Vector3, name: String, fov := 50.0) -> void:
	_cam.global_position = pos
	_cam.fov = fov
	_cam.look_at(look, Vector3.UP)
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/praca_%s.png" % [_out, name])


# ---------- base: chão, luz, mata em volta ----------

func _build(v: String) -> void:
	_root = Node3D.new()
	root.add_child(_root)
	_portal_i = 0
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	_root.add_child(world)
	_root.add_child(sun)
	BiomeAmbience.apply(world, sun)
	_cam = Camera3D.new()
	_root.add_child(_cam)
	_cam.current = true
	_ground_mat = DungeonBuilder._ground(Color.WHITE)
	_map = Image.create(int(HALF * 2 * 4), int(HALF * 2 * 4), false, Image.FORMAT_RGB8)
	_map.fill(Color.BLACK)
	var g := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(HALF * 2 + 80, 0.5, HALF * 2 + 80)
	g.mesh = bm
	g.material_override = _ground_mat
	g.position.y = -0.25
	_root.add_child(g)
	match v:
		"A":
			_aldeia()
		"B":
			_porto()
		"C":
			_ruinas()
	_hero(Vector3(0, 0, 4.0) if v == "A" else (Vector3(-4, 0, 2.0) if v == "B" else Vector3(0, 0, 3.0)))
	_forest_ring(15.5 if v != "B" else 16.5, v)
	var tex := ImageTexture.create_from_image(_map)
	_ground_mat.set_shader_parameter("mapa", tex)
	_ground_mat.set_shader_parameter("mapa_origem", Vector2(-HALF, -HALF))
	_ground_mat.set_shader_parameter("mapa_tamanho", Vector2(HALF * 2, HALF * 2))


func _forest_ring(r: float, v: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var a := 0.0
	while a < TAU:
		var rr := r + rng.randf_range(0.0, 3.0)
		var p := Vector3(cos(a) * rr, 0, sin(a) * rr)
		# a frente (perto da câmera, z > 10) fica baixa para não tampar a praça
		if p.z > 9.0:
			_put("moita" if rng.randf() < 0.6 else "samambaia", p, rng.randf_range(0.9, 1.4), rng.randf() * TAU)
		elif v == "B" and p.x > 9.0 and absf(p.z) < 13.0:
			pass
		else:
			_put("arvore_borda" if rng.randf() < 0.55 else "palmeira", p, rng.randf_range(0.85, 1.15), rng.randf() * TAU)
			if rng.randf() < 0.5:
				_put("moita", p * 0.93, rng.randf_range(0.9, 1.3), rng.randf() * TAU)
		if p.z < 9.0 and rng.randf() < 0.8:
			var p2 := p * (1.0 + rng.randf_range(0.25, 0.45))
			_put("arvore_borda" if rng.randf() < 0.6 else "palmeira", p2, rng.randf_range(0.9, 1.25), rng.randf() * TAU)
		a += rng.randf_range(0.16, 0.28)
	for i in 26:
		var p := Vector3(rng.randf_range(-13, 13), 0, rng.randf_range(-13, 13))
		if p.length() > 6.0 and p.length() < 14.0:
			_put("samambaia" if rng.randf() < 0.6 else "bromelia", p, rng.randf_range(0.8, 1.3), rng.randf() * TAU)


# ---------- variações ----------

## A: clareira redonda; a sumaúma gigante no meio (ponto de encontro do grupo); as estações em
## volta, ligadas por trilhas; os portais dos biomas em arco no fundo.
func _aldeia() -> void:
	_trail_circle(Vector3.ZERO, 6.5, 1.3, false)
	_put("sumauma", Vector3(0, 0, 0), 2.0)
	_put("raiz_gigante", Vector3(-2.2, 0, 1.6), 0.8, 0.6)
	_put("raiz_gigante", Vector3(2.4, 0, -1.2), 0.7, 2.6)
	_label("Sumaúma (grupo)", Vector3(0, 6.2, 0), Color("cfe8b0"))
	_station("bau", Vector3(-8.5, 0, 1.5), "Baú e Equipamento", 1.2)
	_station("herois", Vector3(8.5, 0, 1.5), "Heróis", 1.2)
	_station("artesao", Vector3(0, 0, 8.0), "Oficina", 1.2)
	_portal_arc(Vector3(0, 0, -11.0), 10.0, 0.0)
	_trail(Vector3(-6.5, 0, 1.0), Vector3(-8.5, 0, 1.5), 1.2)
	_trail(Vector3(6.5, 0, 1.0), Vector3(8.5, 0, 1.5), 1.2)
	_trail(Vector3(0, 0, 6.5), Vector3(0, 0, 8), 1.2)
	_torch(Vector3(-4.6, 0, 4.6))
	_torch(Vector3(4.6, 0, 4.6))
	_torch(Vector3(-4.6, 0, -4.6))
	_torch(Vector3(4.6, 0, -4.6))


## B: aldeia na beira do igarapé; cada portal é um "porto" no fim de uma pinguela (viajar pelo rio
## até a região); as estações ficam na margem de cá.
func _porto() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.0, HALF * 2 + 20)
	water.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/agua_cheia.gdshader")
	m.set_shader_parameter("agua", load("res://game/art/chao/agua_igarape.jpg"))
	m.set_shader_parameter("tom", Vector3(0.5, 0.62, 0.55))
	water.material_override = m
	_root.add_child(water)
	water.position = Vector3(6.5, 0.05, 0)
	_mud_line(Vector3(6.5, 0, -HALF), Vector3(6.5, 0, HALF), 5.2)
	_trail(Vector3(-6, 0, 9), Vector3(-6, 0, -9), 1.4)
	_trail(Vector3(-6, 0, 0), Vector3(3.2, 0, 0), 1.3)
	_station("bau", Vector3(-10, 0, -3), "Baú e Equipamento", 1.2)
	_station("herois", Vector3(-10, 0, 4.5), "Heróis", 1.2)
	_station("artesao", Vector3(-2.5, 0, 6.5), "Oficina", 1.2)
	_put("fonte", Vector3(-4, 0, -0.5), 0.8)
	_label("Ponto do grupo", Vector3(-4, 2.4, -0.5), Color("cfe8b0"))
	var regions := [["Terra Firme", true, Color("7fc97a")], ["Várzea e Igapó", false, Color("4db8ff")],
		["Cidade das Urnas", false, Color("e8a050")], ["Cerrado", false, Color("e8d29a")]]
	# uma pinguela só até o porto do outro lado; os portais em arco na margem de lá
	_put("pinguela", Vector3(6.5, 0.05, 0), 1.0, 0.0)
	_mud_line(Vector3(9.8, 0, 0), Vector3(11.0, 0, 0), 2.6)
	for i in 4:
		var a := lerpf(-1.05, 1.05, i / 3.0)
		var at := Vector3(10.5 + cos(a) * 3.2, 0, sin(a) * 8.0)
		_portal(at, regions[i][0], regions[i][1], regions[i][2], -0.55 - a * 0.25)
		_mud_line(Vector3(11.0, 0, 0), at, 0.9)
	_torch(Vector3(-7.5, 0, -6))
	_torch(Vector3(-7.5, 0, 6))
	_torch(Vector3(2.8, 0, -3))
	_torch(Vector3(2.8, 0, 3))


## C: praça de ruínas antigas (muros, pilares, itacoatiaras gravadas); os portais ficam dentro de
## arcos de pedra, em fila no fundo; as estações em nichos dos lados.
func _ruinas() -> void:
	_trail_square(Vector3(0, 0, 0), 7.0, 1.4, false)
	_trail(Vector3(0, 0, 9), Vector3(0, 0, 7), 1.4)
	_trail(Vector3(0, 0, -7), Vector3(0, 0, -7.5), 1.4)
	for x in [-8.5, 8.5]:
		for z in [-5.5, 5.5]:
			_put("pilar_ruina", Vector3(x, 0, z), 1.0)
	for spec in [[Vector3(-13, 0, -2), PI * 0.5], [Vector3(-13, 0, 3), PI * 0.5], [Vector3(13, 0, -2), PI * 0.5], [Vector3(13, 0, 3), PI * 0.5]]:
		_put("muro_ruina", spec[0], 1.0, spec[1])
	_put("itacoatiara", Vector3(-3.5, 0, -3.0), 1.0, 0.4)
	_put("itacoatiara", Vector3(3.8, 0, 3.0), 0.9, 2.2)
	_put("totem_pedra", Vector3(0, 0, 0.5), 1.0)
	_label("Totem do grupo", Vector3(0, 3.0, 0.5), Color("cfe8b0"))
	_station("bau", Vector3(-10.5, 0, 0.5), "Baú e Equipamento", 1.2)
	_station("herois", Vector3(10.5, 0, 0.5), "Heróis", 1.2)
	_station("artesao", Vector3(0, 0, 8.0), "Oficina", 1.2)
	var regions := [["Terra Firme", true, Color("7fc97a")], ["Várzea e Igapó", false, Color("4db8ff")],
		["Cidade das Urnas", false, Color("e8a050")], ["Cerrado", false, Color("e8d29a")]]
	for i in 4:
		var x := -9.0 + i * 6.0
		var at := Vector3(x, 0, -11.0)
		_put("pilar_ruina", at + Vector3(-2.0, 0, 0.4), 0.9)
		_put("pilar_ruina", at + Vector3(2.0, 0, 0.4), 0.9)
		_portal(at, regions[i][0], regions[i][1], regions[i][2], 0.0)
		_trail(Vector3(x, 0, -8.5), at + Vector3(0, 0, 1.5), 1.0)
	_trail(Vector3(-9, 0, -8.5), Vector3(9, 0, -8.5), 1.2)
	_trail(Vector3(0, 0, -7), Vector3(0, 0, -8.5), 1.2)
	_torch(Vector3(-5, 0, 7))
	_torch(Vector3(5, 0, 7))


# ---------- peças ----------

func _station(kind: String, at: Vector3, name: String, s := 1.0) -> void:
	match kind:
		"bau":
			_put("bau", at, s, 0.3 if at.x < 0 else -0.3)
		"herois":
			# os outros heróis esperando ali (quem escolher, troca)
			for i in 3:
				var id: String = ["mateira", "encantado", "druida"][i]
				var hero := _model("res://game/art/herois/%s.glb" % id, 1.75)
				hero.position = at + Vector3(-1.4 + i * 1.4, 0, 0)
				hero.rotation.y = PI * 0.15 * (1 - i)
		"artesao":
			_put("toco_oco", at + Vector3(-1.2, 0, 0), 0.9)
			_put("tronco_caido", at + Vector3(1.0, 0, 0.3), 0.8, 0.3)
			_put("cupinzeiro", at + Vector3(2.6, 0, -0.6), 0.7)
	_label(name, at + Vector3(0, 2.7, 0), Color("ffd98a"))


func _portal_arc(center: Vector3, radius: float, _yaw: float) -> void:
	var regions := [["Terra Firme", true, Color("7fc97a")], ["Várzea e Igapó", false, Color("4db8ff")],
		["Cidade das Urnas", false, Color("e8a050")], ["Cerrado", false, Color("e8d29a")]]
	for i in 4:
		var a := lerpf(-0.55, 0.55, i / 3.0)
		var at := center + Vector3(sin(a) * radius, 0, cos(a) * radius * 0.25)
		_portal(at, regions[i][0], regions[i][1], regions[i][2], -a * 0.6)
		_trail(at * Vector3(0.55, 0, 0) + Vector3(0, 0, -6.2), at + Vector3(0, 0, 1.4), 1.0)


func _portal(at: Vector3, name: String, open: bool, color: Color, yaw: float) -> void:
	var p := _put("portal", at, 1.25, yaw)
	if not open and p:
		_tint(p, Color(0.45, 0.45, 0.5))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0 if open else 0.5
	light.omni_range = 5.0
	light.position = at + Vector3(0, 1.6, 0.8)
	_root.add_child(light)
	# nomes em duas alturas, alternando (não encavalam)
	_label(name + ("" if open else "\n(em breve)"), at + Vector3(0, 4.2 + 1.3 * (_portal_i % 2), 0), color if open else Color(0.7, 0.7, 0.72))
	_portal_i += 1


func _torch(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.1
	c.height = 1.8
	post.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("5a3c28")
	post.material_override = m
	post.position = at + Vector3(0, 0.9, 0)
	_root.add_child(post)
	var flame := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.18
	s.height = 0.36
	flame.mesh = s
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color("ffb35c")
	flame.material_override = fm
	flame.position = at + Vector3(0, 1.9, 0)
	_root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color("ffb35c")
	light.light_energy = 1.3
	light.omni_range = 6.0
	light.position = at + Vector3(0, 2.0, 0)
	_root.add_child(light)


func _hero(at: Vector3) -> void:
	var h := _model("res://game/art/herois/icamiaba.glb", 1.8)
	h.position = at


func _label(text: String, at: Vector3, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 64
	l.pixel_size = 0.0095
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.04, 0.06, 0.1, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	_root.add_child(l)


func _put(kind: String, at: Vector3, s := 1.0, yaw := 0.0) -> Node3D:
	var path := ART % kind
	if not ResourceLoader.exists(path):
		return null
	var spec: Array = {"pinguela": ["w", 8.5]}.get(kind, RoomDecor.SIZE.get(kind, ["h", 1.0]))
	var n: Node3D = (load(path) as PackedScene).instantiate()
	_root.add_child(n)
	var box := Ward._bounds(n, Transform3D.IDENTITY)
	var size: float = box.size.y if spec[0] == "h" else maxf(box.size.x, box.size.z)
	var k: float = float(spec[1]) / maxf(size, 0.01) * s
	n.scale = Vector3.ONE * k
	n.rotation.y = yaw
	n.position = at - Vector3(0, box.position.y * k, 0)
	return n


func _model(path: String, height: float) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	_root.add_child(n)
	var box := Ward._bounds(n, Transform3D.IDENTITY)
	var k := height / maxf(box.size.y, 0.01)
	n.scale = Vector3.ONE * k
	return n


func _tint(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var base := mi.mesh.surface_get_material(i)
			if base is StandardMaterial3D:
				var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = m.albedo_color * c
				m.emission_energy_multiplier *= 0.2
				mi.set_surface_override_material(i, m)
	for ch in n.get_children():
		_tint(ch, c)


# ---------- trilhas no chão (mapa do shader: R = trilha, G = barro) ----------

func _px(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) + Vector2(HALF, HALF)) * 4.0


func _stamp(p: Vector3, r: float, ch: int) -> void:
	var c := _px(p)
	var rp := r * 4.0
	for y in range(int(c.y - rp), int(c.y + rp) + 1):
		for x in range(int(c.x - rp), int(c.x + rp) + 1):
			if x < 0 or y < 0 or x >= _map.get_width() or y >= _map.get_height():
				continue
			var d := Vector2(x, y).distance_to(c) / rp
			if d > 1.0:
				continue
			var v := 1.0 - smoothstep(0.6, 1.0, d)
			var old := _map.get_pixel(x, y)
			if ch == 0:
				old.r = maxf(old.r, v)
			else:
				old.g = maxf(old.g, v)
			_map.set_pixel(x, y, old)


func _trail(a: Vector3, b: Vector3, w: float) -> void:
	var n := int(a.distance_to(b) / 0.5) + 1
	for i in n + 1:
		_stamp(a.lerp(b, float(i) / n), w, 0)


func _mud_line(a: Vector3, b: Vector3, w: float) -> void:
	var n := int(a.distance_to(b) / 0.6) + 1
	for i in n + 1:
		_stamp(a.lerp(b, float(i) / n), w, 1)


func _trail_circle(c: Vector3, r: float, w: float, fill := true) -> void:
	for i in 80:
		var a := TAU * i / 80.0
		_stamp(c + Vector3(cos(a), 0, sin(a)) * r, w, 0)
	if fill:
		_stamp(c, r * 0.55, 0)


func _trail_square(c: Vector3, half: float, w: float, fill := true) -> void:
	for corner in [[Vector3(-1, 0, -1), Vector3(1, 0, -1)], [Vector3(1, 0, -1), Vector3(1, 0, 1)],
			[Vector3(1, 0, 1), Vector3(-1, 0, 1)], [Vector3(-1, 0, 1), Vector3(-1, 0, -1)]]:
		_trail(c + corner[0] * half, c + corner[1] * half, w)
	if fill:
		_stamp(c, half * 0.6, 0)
