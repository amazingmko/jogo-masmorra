shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Chão da Terra Firme: terra escura com manchas de musgo e folhas secas, em coordenadas do mundo
// (sem emendas entre salas e corredores). Leve para o celular: duas leituras de ruído.

uniform vec3 terra : source_color = vec3(0.24, 0.21, 0.15);
uniform vec3 musgo : source_color = vec3(0.21, 0.29, 0.14);
uniform vec3 folha : source_color = vec3(0.42, 0.28, 0.14);
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform sampler2D detalhe : filter_linear_mipmap, repeat_enable;
uniform float escala = 0.06;
uniform float escala_detalhe = 0.45;
// Chão da sala do chefe / covil: tom mais escuro ou avermelhado por cima.
uniform vec3 tom : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float manchas = texture(ruido, p * escala).r;
	float grao = texture(detalhe, p * escala_detalhe).r;
	vec3 cor = mix(terra, musgo, smoothstep(0.55, 0.8, manchas) * 0.75);
	// folhas secas: pintinhas onde o detalhe é alto e não há musgo
	float folhas = smoothstep(0.62, 0.7, grao) * (1.0 - smoothstep(0.6, 0.75, manchas));
	cor = mix(cor, folha, folhas * 0.8);
	cor *= 0.85 + grao * 0.3;
	ALBEDO = cor * tom;
	ROUGHNESS = 1.0;
}
