shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Chão da Terra Firme, em coordenadas do mundo (sem emendas entre clareiras e trilhas):
//  - terra com folhas (pintada à mão), em duas escalas misturadas para não repetir à vista;
//  - manchas de musgo onde o ruído é alto;
//  - trilha batida e barro da margem do igarapé, pelo "mapa" do andar (R = trilha, G = barro).

uniform sampler2D terra_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D musgo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D trilha_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D barro_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform sampler2D mapa : filter_linear, repeat_disable;
uniform vec2 mapa_origem = vec2(0.0);
uniform vec2 mapa_tamanho = vec2(1.0);
uniform float metros_terra = 3.2;    // uma repetição da textura = N metros
uniform float metros_musgo = 5.0;
uniform float metros_trilha = 4.0;
uniform float metros_barro = 3.5;
uniform float escala_manchas = 0.05;
// Chão da sala do chefe / covil: tom mais escuro ou avermelhado por cima.
uniform vec3 tom : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float manchas = texture(ruido, p * escala_manchas).r;
	float variacao = texture(ruido, p * escala_manchas * 0.37 + vec2(0.31, 0.77)).r;
	// terra: a mesma pintura em duas escalas (e girada), trocando devagar pelo ruído
	vec3 t1 = texture(terra_tex, p / metros_terra).rgb;
	vec3 t2 = texture(terra_tex, vec2(p.y, -p.x) / (metros_terra * 1.37) + 0.5).rgb;
	vec3 cor = mix(t1, t2, smoothstep(0.35, 0.65, variacao));
	vec3 musgo = texture(musgo_tex, p / metros_musgo).rgb;
	cor = mix(cor, musgo, smoothstep(0.55, 0.75, manchas) * 0.85);
	vec4 m = texture(mapa, (p - mapa_origem) / mapa_tamanho);
	vec3 trilha = texture(trilha_tex, p / metros_trilha).rgb;
	cor = mix(cor, trilha * 0.78, smoothstep(0.05, 0.6, m.r) * 0.9);
	vec3 barro = texture(barro_tex, p / metros_barro).rgb;
	cor = mix(cor, barro, smoothstep(0.05, 0.55, m.g));
	cor *= 0.92 + variacao * 0.16;
	// a pintura veio bem saturada e alaranjada: puxa um pouco para o marrom de mata fechada
	float lum = dot(cor, vec3(0.3, 0.55, 0.15));
	cor = mix(vec3(lum), cor, 0.72) * vec3(0.88, 0.9, 0.82);
	ALBEDO = cor * tom;
	ROUGHNESS = mix(1.0, 0.55, smoothstep(0.3, 0.8, m.g));  // barro molhado brilha um pouco
}
