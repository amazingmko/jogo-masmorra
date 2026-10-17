shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
// Água de igarapé: cor de chá escuro, correnteza descendo (duas camadas em velocidades
// diferentes para não parecer uma imagem deslizando), bordas se fundindo com o barro.
// UV.x: 0..1 de uma margem à outra. UV.y: distância ao longo do igarapé (em larguras).

uniform sampler2D agua : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tom : source_color = vec3(0.62, 0.78, 0.82);
uniform vec3 ceu : source_color = vec3(0.55, 0.7, 0.62);
uniform float velocidade = 0.12;
uniform float brilho = 0.6;

void fragment() {
	vec2 uv = UV;
	float t = TIME * velocidade;
	vec3 a = texture(agua, vec2(uv.x * 0.9, uv.y * 0.45 - t)).rgb;
	vec3 b = texture(agua, vec2(uv.x * 0.6 + 0.37, uv.y * 0.3 - t * 0.6)).rgb;
	vec3 cor = mix(a, b, 0.45) * tom;
	// mais escura no meio (mais funda), mais clara e barrenta perto da margem
	float margem = 1.0 - abs(uv.x - 0.5) * 2.0;
	cor = mix(cor * vec3(1.25, 1.15, 0.95), cor * 0.8, smoothstep(0.0, 0.7, margem));
	// reflexo da copa/céu nas ondinhas claras da pintura, andando junto com a correnteza
	float onda = smoothstep(0.024, 0.042, dot(b, vec3(0.33)));
	float onda2 = smoothstep(0.026, 0.045, dot(a, vec3(0.33)));
	cor += ceu * (onda * 0.35 + onda2 * 0.2);
	ALBEDO = cor;
	ROUGHNESS = 0.18;
	SPECULAR = brilho;
	ALPHA = smoothstep(0.0, 0.22, margem);
}
