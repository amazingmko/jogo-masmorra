class_name WaveMesh
extends RefCounted
## Onda de água "de verdade" para os poderes (Pororoca e afins): uma lâmina curva — costas
## inclinadas, crista que enrola para a frente — com um shader de desenho estilizado:
##  - faixas de cor (fundo escuro, corpo azul, topo claro) e espuma branca na crista e na base,
##    recortada por ruído que corre (a água sobe pela onda);
##  - a malha ondula de lado e respira (vértices mexem com o tempo);
##  - `rise` levanta a onda do chão (0 → 1) e `fade` a desfaz (crista some antes).
## Tudo procedural: não precisa de imagem.

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float rise = 1.0;
uniform float fade = 1.0;
uniform float width = 7.0;
uniform float seed = 0.0;
uniform vec3 deep : source_color = vec3(0.04, 0.22, 0.52);
uniform vec3 body : source_color = vec3(0.12, 0.52, 0.92);
uniform vec3 light : source_color = vec3(0.55, 0.9, 1.0);
uniform vec3 foam : source_color = vec3(0.95, 0.99, 1.0);
varying float v_side;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.6 + noise(p * 2.3 + 7.1) * 0.3 + noise(p * 5.1 + 3.3) * 0.1; }

void vertex() {
	float t = UV.y;           // 0 = base de trás, 1 = ponta da crista
	float x = VERTEX.x;
	// ondula de lado (a crista corre como água) e respira
	VERTEX.z += sin(x * 1.1 + TIME * 7.0 + seed) * 0.16 * t;
	VERTEX.y += sin(x * 2.3 - TIME * 5.0 + seed) * 0.1 * t;
	// levanta do chão: as costas aparecem primeiro, a crista sobe por último
	float r = clamp(rise * 1.25 - t * 0.25, 0.0, 1.0);
	VERTEX.y *= r;
	VERTEX.z = mix(VERTEX.z * 0.4, VERTEX.z, r);
	v_side = abs(x) / (width * 0.5);
}

void fragment() {
	float t = UV.y;
	vec2 flow = vec2(UV.x * width * 0.55 + seed, t * 2.6 - TIME * 2.2);
	float n = fbm(flow);
	float streak = fbm(vec2(UV.x * width * 1.4, t * 1.2 - TIME * 1.4));
	// corpo: faixas duras (desenho de jogo), não degradê de foto
	vec3 c = deep;
	if (t + n * 0.18 > 0.28) c = body;
	if (t + n * 0.22 > 0.6) c = light;
	c = mix(c, light, step(0.68, streak) * 0.5);           // listras claras subindo
	// espuma: crista (recortada por ruído) e a linha da base no chão
	float crest = step(0.8 - n * 0.22, t);
	float base_foam = step(t, 0.07 + n * 0.09);
	float bubbles = step(0.83, fbm(flow * 2.7)) * step(0.45, t);
	c = mix(c, foam, max(max(crest, base_foam), bubbles));
	// lados se desfazem em respingos; a crista some primeiro quando desmancha
	float side = 1.0 - smoothstep(0.82, 1.0, v_side + n * 0.25);
	float gone = step(fade, t * 0.6 + n * 0.4);
	ALBEDO = c;
	ALPHA = side * (1.0 - gone) * (0.9 + 0.1 * crest);
}
"""

## Rastro de espuma no chão atrás da onda (some com o tempo).
const WAKE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float fade = 1.0;
uniform float width = 7.0;
uniform float length_m = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	// age: 0 = onde a onda já passou faz tempo, 1 = logo atrás dela
	float age = 1.0 - UV.y;
	vec2 p = vec2(UV.x * width * 2.2, UV.y * length_m * 2.0 + TIME * 0.8);
	float n = noise(p) * 0.6 + noise(p * 2.3 + 4.0) * 0.4;
	float side = 1.0 - smoothstep(0.75, 1.0, abs(UV.x - 0.5) * 2.0 + n * 0.25);
	// chão molhado (escurece de leve) e só fiapos de espuma, mais fortes logo atrás da onda
	float lines = smoothstep(0.03, 0.0, abs(n - 0.55)) * smoothstep(0.15, 0.9, age);
	float wet = smoothstep(0.0, 0.35, age) * 0.32;
	ALBEDO = mix(vec3(0.02, 0.1, 0.2), vec3(0.9, 0.97, 1.0), lines);
	ALPHA = side * fade * max(wet, lines * 0.85);
}
"""

static var _shader: Shader
static var _wake_shader: Shader


## Lâmina da onda: largura (eixo X), altura, profundidade (costas para trás, -Z; crista para +Z).
static func build(width: float, height: float, depth: float, cols := 28, rows := 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# perfil (y, z) de trás para a frente: curva de Bézier cúbica que sobe e enrola
	var p0 := Vector2(-depth, 0.0)
	var p1 := Vector2(-depth * 0.25, height * 0.15)
	var p2 := Vector2(-depth * 0.05, height * 1.05)
	var p3 := Vector2(depth * 0.32, height * 0.78)
	for j in rows + 1:
		var t := float(j) / rows
		var a := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var b := p1.lerp(p2, t).lerp(p2.lerp(p3, t), t)
		var q := a.lerp(b, t)
		for i in cols + 1:
			var u := float(i) / cols
			st.set_uv(Vector2(u, t))
			# as pontas dos lados ficam um pouco para trás e mais baixas (onda em arco)
			var edge := pow(absf(u - 0.5) * 2.0, 2.0)
			st.add_vertex(Vector3((u - 0.5) * width, q.y * (1.0 - edge * 0.35), q.x - edge * depth * 0.35))
	for j in rows:
		for i in cols:
			var k := j * (cols + 1) + i
			st.add_index(k)
			st.add_index(k + cols + 1)
			st.add_index(k + 1)
			st.add_index(k + 1)
			st.add_index(k + cols + 1)
			st.add_index(k + cols + 2)
	return st.commit()


static func material(width: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("seed", randf() * 50.0)
	m.render_priority = 3
	return m


static func wake_material(width: float) -> ShaderMaterial:
	if _wake_shader == null:
		_wake_shader = Shader.new()
		_wake_shader.code = WAKE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _wake_shader
	m.set_shader_parameter("width", width)
	m.render_priority = 2
	return m
