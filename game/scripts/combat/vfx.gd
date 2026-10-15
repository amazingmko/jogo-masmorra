class_name Vfx
extends RefCounted
## Efeitos das magias (partículas, marcas no chão, cúpula). As imagens ficam em game/art/vfx/
## e podem ser trocadas por versões geradas por IA sem mexer aqui (ver tools/vfx_texturas.py).

const TEX_PATH := "res://game/art/vfx/%s.png"
const DOME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D hex_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.95, 0.78, 0.38, 1.0);
uniform vec4 rim_color : source_color = vec4(0.45, 1.0, 0.6, 1.0);
uniform float hit = 0.0;
uniform float fade = 1.0;
void fragment() {
	vec2 uv = UV * vec2(5.0, 2.5) + vec2(TIME * 0.025, 0.0);
	float plates = texture(hex_tex, uv).a;
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	vec3 col = tint.rgb * plates * (0.45 + hit * 1.6) + rim_color.rgb * rim * (0.8 + hit);
	ALBEDO = col * fade;
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

static func _particle_material(texture_name: String, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
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
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = _particle_material(texture_name, additive)
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


## Marca no chão que cresce e some (onda de choque).
static func ground_ring(parent: Node, at: Vector3, texture_name: String, color: Color, to_size: float, time: float) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex(texture_name)
	m.albedo_color = color
	mesh.material_override = m
	parent.add_child(mesh)
	mesh.global_position = at + Vector3(0, 0.06, 0)
	mesh.scale = Vector3.ONE * 0.6
	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ONE * to_size, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(m, "albedo_color:a", 0.0, time * 1.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mesh.queue_free)


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


# ---------- poderes da Icamiaba ----------

## Provocar: onda laranja que racha o chão, poeira e folhas subindo, faíscas no escudo.
static func provoke(parent: Node, at: Vector3, radius: float) -> void:
	ground_ring(parent, at, "onda_choque", Color(1.0, 0.62, 0.3, 0.55), radius * 2.0, 0.5)
	particles(parent, at + Vector3(0, 0.2, 0), "poeira", 26, 0.9, Color(0.8, 0.68, 0.5, 0.7), 1.3, Vector2(2.0, 4.5), 80.0, -1.5, false, true, 1.0)
	particles(parent, at + Vector3(0, 0.4, 0), "folha", 14, 1.5, Color(1, 1, 1, 0.95), 0.45, Vector2(3.0, 6.0), 55.0, -7.0, false, true, 1.5)
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
	enemy.get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if is_instance_valid(s):
			s.queue_free())


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
	mesh.material_override = m
	owner.add_child(mesh)
	mesh.scale = Vector3.ONE * 0.2
	var sparks := particles(mesh, Vector3(0, 0.1, 0), "faisca", 18, 1.4, Color("8dffb0"), 0.35, Vector2(0.6, 1.4), 25.0, 0.4, true, false, radius * 0.9)
	var grow := mesh.create_tween()
	grow.tween_property(mesh, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	owner.get_tree().create_timer(maxf(seconds - 0.35, 0.1), false).timeout.connect(func() -> void:
		if not is_instance_valid(mesh):
			return
		sparks.emitting = false
		var at := mesh.global_position
		particles(owner.get_parent(), at + Vector3(0, radius * 0.5, 0), "faisca", 26, 0.7, Color("e8c26a"), 0.55, Vector2(3.0, 6.0), 120.0, -9.0)
		particles(owner.get_parent(), at + Vector3(0, radius * 0.4, 0), "faisca", 14, 0.9, Color("8dffb0"), 0.4, Vector2(1.5, 3.5), 180.0, -4.0)
		var end := mesh.create_tween()
		end.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 1.0, 0.0, 0.35)
		end.tween_callback(mesh.queue_free))
	return mesh


## A cúpula pisca quando segura um golpe.
static func shell_hit(dome: MeshInstance3D) -> void:
	if not is_instance_valid(dome):
		return
	var m := dome.material_override as ShaderMaterial
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


## Revide pronto: brilho dourado contínuo na mão da lança. Devolve as partículas (para apagar).
static func revide_glow(hand: Node3D) -> CPUParticles3D:
	return particles(hand, Vector3.ZERO, "faisca", 10, 0.5, Color("ffe08a"), 0.3, Vector2(0.2, 0.6), 180.0, 0.5, true, false)


## Revide gasto: explosão dourada à frente.
static func revide_strike(parent: Node, at: Vector3) -> void:
	particles(parent, at, "faisca", 20, 0.45, Color("ffd36b"), 0.6, Vector2(3.0, 6.0), 70.0, 0.0)
	ground_ring(parent, Vector3(at.x, 0.0, at.z), "onda_choque", Color("ffe08a"), 2.2, 0.3)
