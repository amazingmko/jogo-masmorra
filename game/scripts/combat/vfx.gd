class_name Vfx
extends RefCounted
## Efeitos das magias (partículas, marcas no chão, cúpula). As imagens ficam em game/art/vfx/
## e podem ser trocadas por versões geradas por IA sem mexer aqui (ver tools/vfx_texturas.py).

const TEX_PATH := "res://game/art/vfx/%s.png"
const DOME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D hex_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.38, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform float hit = 0.0;
uniform float fade = 1.0;
uniform float appear = 1.0;     // 0 → 1: a cúpula sobe do chão até o topo
uniform float shatter = 0.0;    // 0 → 1: estilhaça em pedaços com borda acesa
uniform float radius = 1.7;
varying float v_h;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
	v_h = clamp(VERTEX.y / radius, 0.0, 1.0);
}
void fragment() {
	vec2 uv = UV * vec2(5.0, 2.5) + vec2(TIME * 0.025, 0.0);
	float plates = texture(hex_tex, uv).a;
	float n = noise(UV * vec2(18.0, 9.0));
	// subindo do chão: só aparece até a linha "appear", que brilha
	float line = appear * 1.12 - n * 0.1;
	if (v_h > line) discard;
	float front = smoothstep(line - 0.1, line, v_h) * step(appear, 0.999);
	// estilhaçando: placas somem pelo ruído, a borda de cada buraco acende
	float cell = noise(floor(uv * 2.0) + 0.5);
	if (cell < shatter) discard;
	float crack = smoothstep(shatter + 0.12, shatter, cell) * step(0.001, shatter);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	// faixa de energia que sobe pela cúpula sem parar
	float band = smoothstep(0.06, 0.0, abs(fract(v_h * 1.2 - TIME * 0.7) - 0.5) - 0.42);
	// casco: placas âmbar quase transparentes, emendas douradas, borda clara; pisca branco no golpe
	vec3 shell = mix(vec3(0.45, 0.28, 0.08), tint.rgb, plates);
	vec3 col = mix(shell, rim_color.rgb, rim * 0.8);
	col = mix(col, vec3(1.0, 0.97, 0.85), clamp(band * 0.4 + front + crack + hit * 0.6, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(0.06 + plates * 0.3 + rim * 0.55 + band * 0.25 + front + crack + hit * 0.4, 0.0, 1.0) * fade;
}
"""

static var _cache := {}
static var _dome_shader: Shader


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := TEX_PATH % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


# ---------- peças básicas ----------

static var _part_mats := {}
static var _part_quads := {}


## Material das partículas: um por imagem e mistura, reaproveitado (a cor vem da rampa de cada
## emissor). Criar material e malha novos a cada efeito pesava no celular.
static func _particle_material(texture_name: String, additive: bool) -> StandardMaterial3D:
	var key := texture_name + ("+" if additive else "")
	if _part_mats.has(key):
		return _part_mats[key]
	var m := StandardMaterial3D.new()
	_part_mats[key] = m
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex(texture_name)
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Partículas. one_shot: uma rajada só (some sozinha); senão, contínuas até alguém apagar.
static func particles(parent: Node, at: Vector3, texture_name: String, amount: int, lifetime: float,
		color: Color, size: float, speed: Vector2, spread: float, gravity: float,
		additive := true, one_shot := true, ring_radius := 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qkey := "%s%s|%.2f" % [texture_name, "+" if additive else "", size]
	var quad: QuadMesh = _part_quads.get(qkey)
	if quad == null:
		quad = QuadMesh.new()
		quad.size = Vector2.ONE * size
		quad.material = _particle_material(texture_name, additive)
		_part_quads[qkey] = quad
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.85 if one_shot else 0.0
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0, gravity, 0)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	if ring_radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = ring_radius
		p.emission_ring_inner_radius = ring_radius * 0.6
		p.emission_ring_height = 0.1
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	if p.is_inside_tree():
		p.global_position = at
	else:
		p.position = at
	p.emitting = true
	if one_shot:
		p.get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)
	return p


## Marca no chão que cresce e some (onda de choque). Agora é a onda "viva" do FxKit:
## "onda_choque" racha o chão e levanta poeira; "anel_som" é só o anel de som.
static func ground_ring(parent: Node, at: Vector3, texture_name: String, color: Color, to_size: float, time: float) -> void:
	var heavy := texture_name == "onda_choque"
	FxKit.ground_wave(parent, at, to_size * 0.5, Color(color.r, color.g, color.b, 1.0), maxf(time, 0.2),
			0.7 if heavy else 0.0, 0.8 if heavy else 0.0)


## Figura sempre virada para a câmera (símbolos sobre a cabeça).
static func icon(parent: Node3D, texture_name: String, height: float, size: float, color: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex(texture_name)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.modulate = color
	s.position = Vector3(0, height, 0)
	if s.texture:
		s.pixel_size = size / float(s.texture.get_width())
	parent.add_child(s)
	return s


## Imagem que aparece, cresce e some (impactos: mordida, respingo, cura...).
##  billboard: virada para a câmera; senão, deitada no chão girada por "yaw".
static func sprite(parent: Node, at: Vector3, texture_name: String, size: float, color: Color, life: float,
		grow := 1.35, billboard := true, yaw := 0.0, additive := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var t := tex(texture_name)
	var aspect := float(t.get_width()) / float(t.get_height()) if t else 1.0
	quad.size = Vector2(size * aspect, size) if aspect >= 1.0 else Vector2(size, size / aspect)
	if not billboard:
		quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = t
	m.albedo_color = color
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	if mesh.is_inside_tree():
		mesh.global_position = at
	else:
		mesh.position = at
	if not billboard:
		mesh.rotation.y = yaw
	mesh.scale = Vector3.ONE * 0.6
	var tw := mesh.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh, "scale", Vector3.ONE * grow, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(mesh.queue_free)
	return mesh


## Material de imagem para formas que duram (onda, disparo, armadilha).
static func sprite_material(texture_name: String, color: Color, billboard := false, additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex(texture_name)
	m.albedo_color = color
	return m


## Cura: brilho verde com folhinhas subindo do herói.
static func heal(owner: Node3D, big := false) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	var s := sprite(owner, owner.global_position + Vector3(0, 0.9, 0), "cura", 1.8 if big else 1.2, Color(1, 1, 1, 0.9), 0.7, 1.5)
	s.create_tween().tween_property(s, "position:y", 1.6, 0.7)
	particles(owner.get_parent(), owner.global_position + Vector3(0, 0.5, 0), "folha", 6 if big else 3, 1.0, Color(0.7, 1.0, 0.6, 0.9), 0.25, Vector2(0.5, 1.5), 40.0, 0.5, false, true, 0.5)
	if big:
		FxKit.ground_wave(owner.get_parent(), owner.global_position, 1.5, Color(0.45, 1.0, 0.5), 0.35)


# ---------- poderes da Icamiaba ----------

## Provocar: o grito racha o chão numa onda laranja (com poeira), estoura no escudo e um laço
## de energia corre até cada inimigo provocado.
static func provoke(parent: Node, at: Vector3, radius: float, targets: Array = []) -> void:
	FxKit.ground_wave(parent, at, radius, Color(1.0, 0.55, 0.2), 0.45, 1.0, 1.0)
	FxKit.ground_wave(parent, at, radius * 0.55, Color(1.0, 0.8, 0.45), 0.3)
	FxKit.impact(parent, at + Vector3(0, 1.3, 0), 2.4, Color(1.0, 0.62, 0.25), 0.3, 9.0)
	for e in targets:
		if is_instance_valid(e):
			FxKit.beam(parent, at + Vector3(0, 0.5, 0), (e as Node3D).global_position + Vector3(0, 0.5, 0), 0.45, Color(1.0, 0.55, 0.2), 0.4)
	particles(parent, at + Vector3(0, 0.2, 0), "poeira", 14, 0.8, Color(0.8, 0.68, 0.5, 0.55), 0.9, Vector2(2.0, 4.5), 80.0, -1.5, false, true, 1.0)
	particles(parent, at + Vector3(0, 0.4, 0), "folha", 12, 1.5, Color(1, 1, 1, 0.95), 0.45, Vector2(3.0, 6.0), 55.0, -7.0, false, true, 1.5)
	particles(parent, at + Vector3(0, 1.2, 0), "faisca", 12, 0.5, Color("ffb066"), 0.5, Vector2(2.0, 4.0), 180.0, 0.0)


## Símbolo de raiva sobre a cabeça do inimigo provocado, enquanto durar.
static func provoked_mark(enemy: Node3D, seconds: float, height: float) -> void:
	var old := enemy.get_node_or_null("MarcaProvocado")
	if old:
		old.queue_free()
	var s := icon(enemy, "simbolo_provocado", height, 0.55, Color("ff8a3d"))
	s.name = "MarcaProvocado"
	var bob := s.create_tween().set_loops()
	bob.tween_property(s, "position:y", height + 0.15, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(s, "position:y", height, 0.35).set_trans(Tween.TRANS_SINE)
	# O tempo corre num tween do próprio símbolo: se o bicho sumir antes, nada fica pendurado.
	var life := s.create_tween()
	life.tween_interval(seconds)
	life.tween_callback(s.queue_free)


## Muralha de Casco: cúpula com as placas do casco, borda verde, faíscas subindo.
## Some sozinha em "seconds", estilhaçando.
static func shell_dome(owner: Node3D, radius: float, seconds: float) -> MeshInstance3D:
	if _dome_shader == null:
		_dome_shader = Shader.new()
		_dome_shader.code = DOME_SHADER
	var mesh := MeshInstance3D.new()
	mesh.name = "MuralhaDeCasco"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius  # meia esfera: altura = raio
	sphere.is_hemisphere = true
	sphere.radial_segments = 32
	sphere.rings = 12
	mesh.mesh = sphere
	var m := ShaderMaterial.new()
	m.shader = _dome_shader
	m.set_shader_parameter("hex_tex", tex("casco_hex"))
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("appear", 0.0)
	mesh.material_override = m
	owner.add_child(mesh)
	mesh.scale = Vector3(0.85, 1.0, 0.85)
	if owner.is_inside_tree():
		FxKit.ground_wave(owner.get_parent(), owner.global_position, radius * 1.9, Color(1.0, 0.8, 0.4), 0.4, 1.0, 0.6)
	var rise := mesh.create_tween()
	rise.tween_method(func(v: float) -> void: m.set_shader_parameter("appear", v), 0.0, 1.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var sparks := particles(mesh, Vector3(0, 0.1, 0), "faisca", 18, 1.4, Color("ffd98a"), 0.35, Vector2(0.6, 1.4), 25.0, 0.4, true, false, radius * 0.9)
	var grow := mesh.create_tween()
	grow.tween_property(mesh, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var life := mesh.create_tween()
	life.tween_interval(maxf(seconds - 0.35, 0.1))
	life.tween_callback(func() -> void:
		if not is_instance_valid(owner) or not owner.is_inside_tree():
			return
		sparks.emitting = false
		var at := mesh.global_position
		particles(owner.get_parent(), at + Vector3(0, radius * 0.5, 0), "faisca", 26, 0.7, Color("e8c26a"), 0.55, Vector2(3.0, 6.0), 120.0, -9.0)
		particles(owner.get_parent(), at + Vector3(0, radius * 0.4, 0), "faisca", 14, 0.9, Color("fff1c2"), 0.4, Vector2(1.5, 3.5), 180.0, -4.0)
		var end := mesh.create_tween()
		end.tween_method(func(v: float) -> void: m.set_shader_parameter("shatter", v), 0.0, 1.05, 0.4)
		end.tween_callback(mesh.queue_free))
	return mesh


## A cúpula pisca quando segura um golpe.
static func shell_hit(dome: MeshInstance3D) -> void:
	if not is_instance_valid(dome):
		return
	var m := dome.material_override as ShaderMaterial
	if dome.is_inside_tree():
		FxKit.impact(dome.get_parent().get_parent(), dome.global_position + Vector3(0, 1.0, 0), 1.6, Color(1.0, 0.85, 0.45), 0.18)
	var t := dome.create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("hit", v), 1.0, 0.0, 0.3)


## Muiraquitã: sapinho verde sobe brilhando e faíscas verdes explodem.
static func muiraquita(owner: Node3D) -> void:
	var s := icon(owner, "sapo_muiraquita", 1.4, 1.7, Color(1.3, 1.3, 1.3, 1))
	var t := s.create_tween()
	t.set_parallel(true)
	t.tween_property(s, "position:y", 2.8, 1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "pixel_size", s.pixel_size * 1.6, 1.1)
	t.tween_property(s, "modulate:a", 0.0, 1.1).set_delay(0.4)
	t.chain().tween_callback(s.queue_free)
	particles(owner.get_parent(), owner.global_position + Vector3(0, 1.0, 0), "faisca", 30, 0.9, Color("6fdc7b"), 0.5, Vector2(3.0, 6.0), 180.0, -2.0)
	FxKit.ground_wave(owner.get_parent(), owner.global_position, 3.0, Color(0.4, 1.0, 0.55), 0.5)
	FxKit.impact(owner.get_parent(), owner.global_position + Vector3(0, 1.2, 0), 2.6, Color(0.45, 1.0, 0.55), 0.35, 6.0)
	heal(owner, true)


## Revide pronto: brilho dourado contínuo na mão da lança. Devolve as partículas (para apagar).
static func revide_glow(hand: Node3D) -> CPUParticles3D:
	return particles(hand, Vector3.ZERO, "faisca", 10, 0.5, Color("ffe08a"), 0.3, Vector2(0.2, 0.6), 180.0, 0.5, true, false)


## Revide gasto: estrela dourada à frente e o chão racha.
static func revide_strike(parent: Node, at: Vector3) -> void:
	FxKit.impact(parent, at, 2.2, Color(1.0, 0.82, 0.4), 0.25, 8.0)
	particles(parent, at, "faisca", 16, 0.45, Color("ffd36b"), 0.5, Vector2(3.0, 6.0), 70.0, 0.0)
	FxKit.ground_wave(parent, Vector3(at.x, 0.0, at.z), 1.6, Color(1.0, 0.8, 0.4), 0.3, 0.8)
