class_name Boiuna
extends Node3D
## Boiuna, a Cobra-Grande do rio (talento máximo do Encantado): no lugar da Pororoca, uma cobra
## de água circula em volta dele por alguns segundos, mordendo quem chega perto (dano, encharca e
## empurra para fora). No fim, mergulha e avança como uma Pororoca na direção em que ele mira.
##
## Visual: o corpo é um tubo que o shader enrola no círculo (a GPU faz o movimento, sem montar
## malha a cada quadro), com escamas de água, faixas de luz e espuma; a cabeça tem olhos acesos e
## mandíbula que abre no bote. Ela emerge do chão girando, deixa um canal de água no chão e
## mergulha no fim, num estouro de água.

const RING := 3.0          # raio do círculo da cobra
const REACH := 1.6         # quanto para dentro/fora do círculo ela pega
const TURN_SPEED := 2.6    # radianos por segundo
const BITE_EVERY := 0.5
const BODY_ANGLE := 4.2    # quanto do círculo o corpo ocupa (radianos)
const THICK := 0.5         # raio do corpo junto da cabeça

const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform float phase = 0.0;        // ângulo da cabeça no círculo
uniform float ring = 3.0;
uniform float body_angle = 4.2;
uniform float emerge = 1.0;       // 0 = dentro do chão, 1 = inteira para fora
uniform float t = 0.0;
uniform vec3 deep : source_color = vec3(0.03, 0.2, 0.45);
uniform vec3 body : source_color = vec3(0.1, 0.5, 0.88);
uniform vec3 light : source_color = vec3(0.55, 0.92, 1.0);
uniform vec3 foam : source_color = vec3(0.92, 0.99, 1.0);
uniform sampler2D scales : source_color, filter_linear_mipmap, repeat_enable;
varying float v_up;
varying float v_s;
varying vec3 v_n;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float height(float s) {
	// ondula subindo e descendo pelo corpo; o rabo fica mais baixo
	return 0.55 + sin(t * 6.0 - s * 9.0) * 0.28 * (0.4 + s) - s * 0.25;
}
void vertex() {
	float s = VERTEX.z;                 // 0 = cabeça, 1 = ponta do rabo
	float a = phase - s * body_angle;
	vec3 radial = vec3(cos(a), 0.0, sin(a));
	float h = height(s);
	// emergir: a parte de trás do corpo sai do chão por último
	float out_k = clamp(emerge * 1.6 - s * 0.6, 0.0, 1.0);
	h = mix(-0.8, h, out_k);
	float r = ring + sin(t * 3.0 - s * 6.0) * 0.18;
	vec3 center = radial * r + vec3(0.0, h, 0.0);
	VERTEX = center + radial * VERTEX.x + vec3(0.0, 1.0, 0.0) * VERTEX.y;
	NORMAL = normalize(radial * NORMAL.x + vec3(0.0, 1.0, 0.0) * NORMAL.y);
	v_up = NORMAL.y;
	v_s = s;
	v_n = NORMAL;
}
void fragment() {
	// escamas pintadas (imagem do Gemini) correndo pelo corpo, com luz de cima e espuma
	vec3 sc = texture(scales, vec2(UV.x * 20.0, UV.y * 3.0)).rgb;
	float flow = noise(vec2(UV.x * 18.0 + t * 5.0, UV.y * 4.0));
	float lit = v_up * 0.5 + 0.5;                     // de cima é mais claro (câmera de cima)
	vec3 c = sc * mix(0.55, 1.25, smoothstep(0.2, 0.95, lit + flow * 0.1));
	// barriga clara (embaixo)
	c = mix(c, light * 0.85, smoothstep(-0.2, -0.75, v_up));
	float spots = step(0.82, noise(vec2(UV.x * 30.0 - t * 4.0, UV.y * 6.0))) * step(0.55, v_up);
	c = mix(c, foam, spots * 0.8);
	float rim = pow(1.0 - abs(dot(normalize(v_n), VIEW)), 3.0);
	c = mix(c, foam, rim * 0.35);
	ALBEDO = c;
}
"""

## Canal de água no chão, embaixo do círculo: anel molhado com espuma correndo em volta.
const CHANNEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float fade = 0.0;
uniform float ring = 3.0;
uniform float half_size = 4.6;
uniform float t = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * half_size;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = noise(vec2(a * 6.0 - t * 2.6, r * 2.0));
	float band = 1.0 - smoothstep(0.55, 0.95, abs(r - ring) + n * 0.25);
	float m = noise(vec2(a * 22.0 - t * 5.2, r * 9.0));
	float foam_l = smoothstep(0.03, 0.0, abs(m - 0.5)) * band;      // só fiapos finos de espuma
	ALBEDO = mix(vec3(0.03, 0.16, 0.32), vec3(0.9, 0.98, 1.0), foam_l);
	ALPHA = band * fade * mix(0.35, 0.85, foam_l);
}
"""

static var _body_shader: Shader
static var _channel_shader: Shader
static var _tube: ArrayMesh

var owner_player: Player
var kit: MageKit
var duration := 6.0
var damage := 30
var _t := 0.0
var _bite := 0.0
var _phase := 0.0
var _emerge := 0.0
var _ending := false
var _body: MeshInstance3D
var _body_mat: ShaderMaterial
var _channel_mat: ShaderMaterial
var _head: Node3D
var _jaw: Node3D
var _lunge := 0.0          # 0..1: a cabeça avança no bote
var _lunge_dir := Vector3.ZERO
var _spray: CPUParticles3D


func _ready() -> void:
	add_to_group("floor_effects")
	_build_channel()
	_build_body()
	_build_head()
	# ela sai do chão girando, num esguicho
	var up := create_tween()
	up.tween_property(self, "_emerge", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var at := global_position if is_inside_tree() else position
	if is_inside_tree():
		FxKit.ground_wave(get_parent(), at, RING + 1.2, Color(0.45, 0.85, 1.0), 0.5)
		var gush := Vfx.particles(get_parent(), at + Vector3(0, 0.3, 0), "respingo", 26, 0.7, Color(1, 1, 1, 0.9), 0.9,
				Vector2(2.5, 5.0), 30.0, -10.0, false, true, RING)
		gush.emission_ring_inner_radius = RING - 0.3


func _build_body() -> void:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY_SHADER
		_tube = _make_tube(56, 10)
	_body = MeshInstance3D.new()
	_body.mesh = _tube
	_body_mat = ShaderMaterial.new()
	_body_mat.shader = _body_shader
	_body_mat.set_shader_parameter("ring", RING)
	_body_mat.set_shader_parameter("body_angle", BODY_ANGLE)
	_body_mat.set_shader_parameter("emerge", 0.0)
	_body_mat.set_shader_parameter("scales", Vfx.tex("escamas_boiuna"))
	_body.material_override = _body_mat
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a malha é mexida no shader: caixa grande para a câmera nunca a esconder
	_body.custom_aabb = AABB(Vector3(-RING - 2, -2, -RING - 2), Vector3(RING * 2 + 4, 5, RING * 2 + 4))
	add_child(_body)


## Tubo "reto": z = posição ao longo do corpo (0 cabeça, 1 rabo); x,y = volta do anel, já com a
## grossura (o shader só põe o anel no lugar do círculo).
static func _make_tube(length_steps: int, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in length_steps + 1:
		var s := float(i) / length_steps
		var r := THICK * lerpf(1.0, 0.12, pow(s, 1.3))
		if s < 0.05:
			r *= 0.8 + s * 4.0     # pescoço logo atrás da cabeça
		for j in sides + 1:
			var a := TAU * float(j) / sides
			var n := Vector3(cos(a), sin(a), 0.0)
			st.set_normal(n)
			st.set_uv(Vector2(s, float(j) / sides))
			st.add_vertex(Vector3(n.x * r, n.y * r * 0.85, s))
	for i in length_steps:
		for j in sides:
			var k := i * (sides + 1) + j
			st.add_index(k)
			st.add_index(k + 1)
			st.add_index(k + sides + 1)
			st.add_index(k + 1)
			st.add_index(k + sides + 2)
			st.add_index(k + sides + 1)
	return st.commit()


## Cabeça: crânio achatado, focinho, mandíbula que abre, olhos acesos.
const HEAD_MODEL := "res://game/art/herois/boiuna_cabeca.glb"
## A cabeça do modelo (Tripo) olha para este eixo do arquivo; o tamanho final é HEAD_LEN.
const HEAD_LEN := 1.5
var _head_model: Node3D


func _build_head() -> void:
	_head = Node3D.new()
	add_child(_head)
	if ResourceLoader.exists(HEAD_MODEL) and _build_head_model():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.16, 0.56, 0.92)
	var top := StandardMaterial3D.new()
	top.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	top.albedo_color = Color(0.5, 0.88, 1.0)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.6
	skull.mesh = sm
	skull.scale = Vector3(1.0, 0.8, 1.45)
	skull.position = Vector3(0, 0.05, 0.2)
	skull.material_override = mat
	_head.add_child(skull)
	var crest := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.36
	cm.height = 0.3
	crest.mesh = cm
	crest.scale = Vector3(0.9, 0.6, 1.5)
	crest.position = Vector3(0, 0.25, 0.25)
	crest.material_override = top
	_head.add_child(crest)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.05, -0.1)
	_head.add_child(_jaw)
	var jaw := MeshInstance3D.new()
	var jm := SphereMesh.new()
	jm.radius = 0.42
	jm.height = 0.3
	jaw.mesh = jm
	jaw.scale = Vector3(0.95, 0.6, 1.5)
	jaw.position = Vector3(0, -0.1, 0.4)
	var belly := StandardMaterial3D.new()
	belly.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	belly.albedo_color = Color(0.75, 0.95, 1.0)
	jaw.material_override = belly
	_jaw.add_child(jaw)
	# boca por dentro (escura) e presas
	var mouth := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.34
	mm.height = 0.2
	mouth.mesh = mm
	mouth.scale = Vector3(0.85, 0.5, 1.4)
	mouth.position = Vector3(0, -0.08, 0.35)
	var inside := StandardMaterial3D.new()
	inside.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inside.albedo_color = Color(0.03, 0.08, 0.2)
	mouth.material_override = inside
	_head.add_child(mouth)
	var fang_mat := StandardMaterial3D.new()
	fang_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fang_mat.albedo_color = Color(0.95, 1.0, 1.0)
	for side in [-1.0, 1.0]:
		var fang := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = 0.045
		fm.bottom_radius = 0.0
		fm.height = 0.22
		fang.mesh = fm
		fang.position = Vector3(0.17 * side, -0.12, 0.72)
		fang.material_override = fang_mat
		_head.add_child(fang)
	# olhos acesos (amarelo-esverdeado, como bicho do fundo do rio)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eye_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	eye_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	eye_mat.albedo_texture = Vfx.tex("faisca")
	eye_mat.albedo_color = Color(2.0, 2.2, 0.8)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.38
		eye.mesh = q
		eye.material_override = eye_mat
		eye.position = Vector3(0.28 * side, 0.3, 0.35)
		_head.add_child(eye)
	for c in _head.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spray = Vfx.particles(_head, Vector3(0, -0.2, -0.2), "respingo", 12, 0.5, Color(1, 1, 1, 0.8), 0.6,
			Vector2(1.0, 2.5), 60.0, -8.0, false, false)
	Vfx.particles(_head, Vector3.ZERO, "faisca", 10, 0.5, Color(0.85, 0.95, 1.0), 0.25, Vector2(0.5, 1.5), 180.0, -3.0, true, false)


## A cabeça de verdade: o modelo, com o focinho para a frente (+Z da cabeça) e o pescoço
## encostando no começo do corpo. Olhos acesos por cima, para ler de longe.
func _build_head_model() -> bool:
	var scene: Node3D = load(HEAD_MODEL).instantiate()
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		scene.free()
		return false
	var aabb: AABB = (meshes[0] as MeshInstance3D).get_aabb()
	var k := HEAD_LEN / maxf(aabb.size.x, 0.001)
	# o modelo vem de perfil olhando para +X (como a imagem): gira para olhar para +Z
	scene.rotation.y = -PI * 0.5
	scene.scale = Vector3.ONE * k
	scene.position = (Basis(Vector3.UP, -PI * 0.5) * (-aabb.get_center() * k)) + Vector3(0, 0.05, HEAD_LEN * 0.3)
	for mi: MeshInstance3D in meshes:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(scene)
	_head_model = scene
	_jaw = Node3D.new()  # sem mandíbula separada: o bote mexe a cabeça inteira
	_head.add_child(_jaw)
	_spray = Vfx.particles(_head, Vector3(0, -0.2, -0.2), "respingo", 12, 0.5, Color(1, 1, 1, 0.8), 0.6,
			Vector2(1.0, 2.5), 60.0, -8.0, false, false)
	Vfx.particles(_head, Vector3(0, 0.3, 0), "faisca", 10, 0.5, Color(0.85, 0.95, 1.0), 0.25, Vector2(0.5, 1.5), 180.0, -3.0, true, false)
	return true


func _build_channel() -> void:
	if _channel_shader == null:
		_channel_shader = Shader.new()
		_channel_shader.code = CHANNEL_SHADER
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	var half := RING + 1.6
	q.size = Vector2.ONE * half * 2.0
	q.orientation = PlaneMesh.FACE_Y
	m.mesh = q
	_channel_mat = ShaderMaterial.new()
	_channel_mat.shader = _channel_shader
	_channel_mat.set_shader_parameter("ring", RING)
	_channel_mat.set_shader_parameter("half_size", half)
	_channel_mat.render_priority = 1
	m.material_override = _channel_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 0.06, 0)
	add_child(m)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(owner_player):
		global_position = owner_player.global_position
	_phase += TURN_SPEED * delta
	_body_mat.set_shader_parameter("phase", _phase)
	_body_mat.set_shader_parameter("t", _t)
	_body_mat.set_shader_parameter("emerge", _emerge)
	_channel_mat.set_shader_parameter("t", _t)
	_channel_mat.set_shader_parameter("fade", clampf(_emerge, 0.0, 1.0))
	_place_head(delta)
	if _ending:
		return
	_bite -= delta
	if _bite <= 0.0:
		_bite = BITE_EVERY
		_bite_around()
	if _t >= duration:
		_dive()


## A cabeça na ponta do corpo (mesma conta do shader), olhando para a frente do giro;
## no bote, avança na direção de quem mordeu e a mandíbula abre.
func _place_head(delta: float) -> void:
	var a := _phase
	var radial := Vector3(cos(a), 0, sin(a))
	var h := 0.55 + sin(_t * 6.0) * 0.28 * 0.4
	h = lerpf(-0.8, h, clampf(_emerge * 1.6, 0.0, 1.0))
	var r := RING + sin(_t * 3.0) * 0.18
	var forward := Vector3(-sin(a), 0, cos(a))  # o giro vai no sentido do ângulo crescendo
	var pos := radial * r + Vector3(0, h + 0.12, 0)
	if _lunge > 0.0:
		pos += _lunge_dir * _lunge * 1.1 + Vector3(0, _lunge * 0.3, 0)
		forward = forward.lerp(_lunge_dir, _lunge).normalized()
	_head.position = pos
	if forward.length() > 0.01:
		_head.basis = Basis.looking_at(forward, Vector3.UP, true)
	_jaw.rotation.x = deg_to_rad(10.0 + 45.0 * _lunge)
	if _head_model:
		# no bote a cabeça empina e cresce um pouco (sem mandíbula separada no modelo)
		_head.scale = Vector3.ONE * (1.0 + 0.18 * _lunge)
		_head.rotate_object_local(Vector3.RIGHT, -0.35 * _lunge)
	_lunge = move_toward(_lunge, 0.0, delta * 3.5)


func _bite_around() -> void:
	var bit: Node3D = null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health.is_dead:
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if absf(d - RING) <= REACH:
			if kit:
				kit.soak_enemy(enemy)
			enemy.take_hit(damage, false, to)
			if enemy.has_method("push"):
				enemy.push(to, 1.2)
			FxKit.impact(get_parent(), enemy.global_position + Vector3(0, 0.9, 0), 1.3, Color(0.5, 0.85, 1.0), 0.2)
			Vfx.particles(get_parent(), enemy.global_position + Vector3(0, 0.6, 0), "respingo", 6, 0.4, Color(1, 1, 1, 0.85), 0.5,
					Vector2(1.5, 3.0), 120.0, -8.0, false)
			if bit == null or _head.global_position.distance_to(enemy.global_position) < _head.global_position.distance_to(bit.global_position):
				bit = enemy
	if bit:
		# o bote: a cabeça avança em quem estiver mais perto dela
		var dir: Vector3 = bit.global_position - _head.global_position
		dir.y = 0.0
		_lunge_dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
		_lunge = 1.0
		Vfx.sprite(get_parent(), bit.global_position + Vector3(0, 1.0, 0), "mordida", 1.4, Color(0.75, 0.95, 1.0, 0.95), 0.25)


## Fim: mergulha no chão num estouro de água e vira a onda.
func _dive() -> void:
	_ending = true
	if is_instance_valid(_spray):
		_spray.emitting = false
	if kit and is_instance_valid(owner_player):
		kit.launch_wave(owner_player.facing(), owner_player.global_position)
	var at := global_position
	Vfx.particles(get_parent(), at + Vector3(0, 0.4, 0), "respingo", 24, 0.7, Color(1, 1, 1, 0.9), 0.9, Vector2(2.0, 4.5),
			40.0, -10.0, false, true, RING)
	var t := create_tween()
	t.tween_property(self, "_emerge", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
