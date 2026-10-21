class_name FxKit
extends RefCounted
## Peças de efeito "vivas" (mesmo método da Pororoca nova): formas simples com shader animado,
## em três tempos — nasce, age, se desfaz — em vez de uma imagem parada que cresce e some.
##
##  ground_wave   onda que corre pelo chão: anel com borda quebrada por ruído, rachaduras e poeira
##  impact        estrela de impacto (clarão com raios) virada para a câmera
##  RibbonTrail   rastro de fita atrás de algo que voa (lança, harpia, disparos)
##  dissolve      material que aparece/some "desmanchando" com borda brilhante
## Tudo procedural (sem imagem), pronto para o celular: um quadrado ou uma fita por efeito.

const NOISE := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.6 + noise(p * 2.3 + 7.1) * 0.3 + noise(p * 5.1 + 3.3) * 0.1; }
"""

## Onda no chão. progress 0 → 1: o anel sai do centro até a borda e afina; fade apaga tudo.
const GROUND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float progress = 0.0;
uniform float fade = 1.0;
uniform vec4 color : source_color = vec4(1.0, 0.6, 0.25, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float cracks = 0.0;      // 1 = racha o chão (golpes pesados)
uniform float dust = 0.0;        // 1 = anel de poeira por fora
uniform float seed = 0.0;
#NOISE
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = fbm(vec2(a * 3.0 + seed, r * 4.0 - progress * 3.0));
	float edge = progress;                                  // onde está a frente da onda
	float thick = mix(0.22, 0.05, progress);
	float d = edge - r + (n - 0.5) * 0.12;
	float ring = smoothstep(0.0, 0.02, d) * (1.0 - smoothstep(thick * 0.4, thick, d));
	float hot = smoothstep(0.0, 0.02, d) * (1.0 - smoothstep(0.0, thick * 0.35, d));
	// rastro fraco por dentro (o chão "sente" a onda)
	float inner = (1.0 - smoothstep(0.0, edge, r)) * 0.18 * (1.0 - progress) * step(r, edge);
	// rachaduras: linhas radiais que crescem com a onda
	float lines = 0.0;
	if (cracks > 0.0) {
		float k = abs(fract(a * 2.2 + fbm(vec2(r * 3.0 + seed, a)) * 0.9) - 0.5);
		lines = smoothstep(0.035, 0.0, k) * step(r, edge * 0.95) * smoothstep(1.0, 0.3, r) * cracks;
	}
	float puff = 0.0;
	if (dust > 0.0) {
		puff = smoothstep(0.55, 0.85, fbm(p * 3.0 + seed + progress)) * smoothstep(edge + 0.25, edge, r) * step(edge - 0.2, r) * dust;
	}
	vec3 c = mix(color.rgb, core.rgb, hot);
	c = mix(c, vec3(0.12, 0.08, 0.05), lines * (1.0 - ring));
	c = mix(c, vec3(0.75, 0.66, 0.52), puff * (1.0 - ring));
	float alpha = max(max(ring, inner), max(lines * 0.85, puff * 0.6));
	ALBEDO = c;
	ALPHA = alpha * fade * step(r, 1.0);
}
"""

## Estrela de impacto: clarão com raios irregulares que abre e some.
const IMPACT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, blend_add;
uniform float progress = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform float spikes = 7.0;
uniform float seed = 0.0;
#NOISE
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float len = 0.45 + 0.55 * noise(vec2(floor((a + 3.1416) / 6.2832 * spikes) + seed, seed));
	float ray = pow(abs(cos(a * spikes * 0.5 + seed)), 14.0) * smoothstep(len * (0.35 + progress * 0.75), 0.0, r);
	float disc = smoothstep(0.38 * (1.0 - progress), 0.0, r);
	float ring = smoothstep(0.06, 0.0, abs(r - progress * 0.9)) * (1.0 - progress);
	float v = max(ray * (1.0 - progress * 0.8), max(disc, ring));
	ALBEDO = mix(color.rgb, vec3(1.0), disc) * v * 1.4;
}
"""

## Fita do rastro: some na ponta velha e nas bordas, com listras correndo.
const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float fade = 1.0;
#NOISE
void fragment() {
	// UV.x: 0 = ponta nova (junto do objeto), 1 = ponta velha; UV.y: de uma borda à outra
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float streak = noise(vec2(UV.x * 6.0 - TIME * 8.0, UV.y * 5.0));
	float a = smoothstep(1.0, 0.0, UV.x) * smoothstep(0.0, 0.5, across) * (0.6 + streak * 0.6);
	ALBEDO = mix(color.rgb, vec3(1.0), smoothstep(0.6, 1.0, across) * (1.0 - UV.x)) * a * fade;
}
"""

## Aparece/some desmanchando: dissolve 0 = inteiro, 1 = sumiu; borda brilhando na cor.
const DISSOLVE_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float dissolve = 0.0;
uniform vec4 edge_color : source_color = vec4(0.5, 1.0, 0.4, 1.0);
uniform float uv_scale = 1.0;
#NOISE
void fragment() {
	vec4 t = texture(albedo_tex, UV * uv_scale) * albedo;
	float n = fbm(UV * 7.0);
	if (n < dissolve * 1.1 - 0.05) discard;
	float e = smoothstep(dissolve * 1.1 + 0.06, dissolve * 1.1 - 0.05, n) * step(0.001, dissolve);
	ALBEDO = mix(t.rgb, edge_color.rgb, e);
	EMISSION = edge_color.rgb * e * 2.0;
	ROUGHNESS = 0.9;
}
"""

## Golpe giratório: um arco que varre o círculo em volta (rastro que afina para trás).
const SPIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform float sweep = 0.0;       // ângulo da ponta do golpe (radianos, cresce com o tempo)
uniform float tail = 3.6;        // tamanho do rastro (radianos)
uniform float fade = 1.0;
uniform float inner = 0.55;
uniform vec4 color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
#NOISE
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float behind = mod(sweep - a, 6.2832);            // quanto atrás da ponta este ponto está
	float k = 1.0 - behind / tail;
	k = clamp(k, 0.0, 1.0);
	float n = noise(vec2(a * 5.0 - sweep * 2.0, r * 7.0));
	float band = smoothstep(inner - 0.05, inner + 0.1, r + n * 0.08) * (1.0 - smoothstep(0.88, 1.0, r + n * 0.05));
	float edge = smoothstep(0.84, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float v = band * pow(k, 1.6) + edge * pow(k, 3.0) * 1.5;
	ALBEDO = mix(color.rgb, vec3(1.0), pow(k, 6.0)) * v * fade * 1.3;
}
"""

## Laço de energia de um ponto a outro (ex.: o grito da Icamiaba "puxando" cada provocado).
## UV.y: 0 = origem, 1 = alvo. Um pulso corre da origem ao alvo e o laço some.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform float progress = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.6, 0.25, 1.0);
#NOISE
void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float wob = noise(vec2(UV.y * 8.0 - TIME * 10.0, 0.0)) * 0.5;
	float core = smoothstep(0.35 + wob * 0.3, 1.0, across);
	float head = smoothstep(0.25, 0.0, abs(UV.y - progress * 1.2)) * 1.5;
	float reach = step(UV.y, progress * 1.2);
	float v = core * reach * (0.5 + head) * (1.0 - smoothstep(0.7, 1.0, progress));
	ALBEDO = mix(color.rgb, vec3(1.0), core * head * 0.6) * v * 1.4;
}
"""

static var _shaders := {}


static func shader(key: String) -> Shader:
	if not _shaders.has(key):
		var code: String = {"ground": GROUND_SHADER, "impact": IMPACT_SHADER, "trail": TRAIL_SHADER,
				"dissolve": DISSOLVE_SHADER, "spin": SPIN_SHADER, "beam": BEAM_SHADER}[key]
		var s := Shader.new()
		s.code = code.replace("#NOISE", NOISE)
		_shaders[key] = s
	return _shaders[key]


static func material(key: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(key)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


## Onda que corre pelo chão a partir de "at" até "radius". cracks/dust: 0..1.
static func ground_wave(parent: Node, at: Vector3, radius: float, color: Color, time := 0.45,
		cracks := 0.0, dust := 0.0, core := Color(1, 0.96, 0.85)) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var m := material("ground", {"color": color, "core": core, "cracks": cracks, "dust": dust, "seed": randf() * 40.0})
	m.render_priority = 1
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = Vector3(at.x, at.y + 0.07, at.z)
	var tw := mesh.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.05, 1.0, time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# as rachaduras ficam um pouco no chão depois que a onda passa
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 1.0, 0.0, 0.25 + cracks * 0.6)
	tw.tween_callback(mesh.queue_free)
	return mesh


## Clarão de impacto (estrela com raios), virado para a câmera.
static func impact(parent: Node, at: Vector3, size: float, color: Color, time := 0.22, spikes := 7.0) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	mesh.mesh = quad
	var m := material("impact", {"color": color, "spikes": spikes, "seed": randf() * 20.0})
	m.render_priority = 4
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = at
	var tw := mesh.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mesh.queue_free)


## Golpe giratório em volta de "at" (deitado no chão, um pouco acima): o arco dá uma volta.
static func spin_slash(parent: Node, at: Vector3, radius: float, color: Color, time := 0.28, height := 0.6) -> void:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.0
	quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var m := material("spin", {"color": color})
	m.render_priority = 3
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = at + Vector3(0, height, 0)
	var start := randf() * TAU
	var tw := mesh.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("sweep", v), start, start + TAU * 1.15, time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 1.0, 0.0, 0.15)
	tw.tween_callback(mesh.queue_free)


## Laço que sai de "from" e chega em "to" (deitado, um pouco acima do chão) e some.
static func beam(parent: Node, from: Vector3, to: Vector3, width: float, color: Color, time := 0.35) -> void:
	var d := to - from
	d.y = 0.0
	if d.length() < 0.2:
		return
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, d.length())
	quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var m := material("beam", {"color": color})
	m.render_priority = 3
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	var mid := from + d * 0.5
	mesh.global_position = Vector3(mid.x, from.y, mid.z)
	# a fita deitada: comprimento no eixo Z do quadrado; UV.y cresce de -Z para +Z
	mesh.global_basis = Basis.looking_at(-d.normalized(), Vector3.UP)
	var tw := mesh.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, time)
	tw.tween_callback(mesh.queue_free)


## Material de "desmanchar" com a imagem de um modelo (para aparecer/sumir).
static func dissolve_material(texture: Texture2D, edge: Color, tint := Color.WHITE) -> ShaderMaterial:
	return material("dissolve", {"albedo_tex": texture, "albedo": tint, "edge_color": edge})


## Para o aquecimento: um de cada.
static func warm(parent: Node3D, at: Vector3) -> void:
	ground_wave(parent, at, 1.0, Color.WHITE, 0.2, 1.0, 1.0)
	impact(parent, at + Vector3(0, 1, 0), 1.0, Color.WHITE, 0.2)
	spin_slash(parent, at, 1.0, Color.WHITE, 0.2)
	beam(parent, at, at + Vector3(2, 0, 0), 0.4, Color.WHITE, 0.2)
	var t := RibbonTrail.new()
	parent.add_child(t)
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	m.material_override = dissolve_material(null, Color.WHITE)
	parent.add_child(m)
	m.position = at + Vector3(1, 0.5, 0)
