shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
// A Cheia (Provação do Encantado): a sala alagada, com buracos redondos onde ficam as ilhas.
// ilhas[i] = (x, z, raio, 0) em coordenadas do mundo; raio 0 = ilha desligada.
// Na beira de cada ilha, espuma clara; a água corre devagar em duas camadas.

uniform sampler2D agua : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 ilhas[4];
uniform vec3 tom : source_color = vec3(0.46, 0.62, 0.6);
uniform float brilho = 0.6;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float perto = 99.0;
	for (int i = 0; i < 4; i++) {
		if (ilhas[i].z > 0.0) {
			perto = min(perto, distance(mundo.xz, ilhas[i].xy) - ilhas[i].z);
		}
	}
	if (perto < 0.0) {
		discard;
	}
	float t = TIME * 0.08;
	vec3 a = texture(agua, mundo.xz * 0.11 + vec2(t, t * 0.4)).rgb;
	vec3 b = texture(agua, mundo.xz * 0.07 + vec2(-t * 0.6, t)).rgb;
	vec3 cor = mix(a, b, 0.5) * tom;
	float onda = smoothstep(0.024, 0.045, dot(b, vec3(0.33)));
	cor += vec3(0.5, 0.65, 0.6) * onda * 0.3;
	// espuma na beira das ilhas (pulsa de leve, como a água batendo)
	float espuma = 1.0 - smoothstep(0.0, 0.35 + 0.08 * sin(TIME * 2.5 + mundo.x), perto);
	cor = mix(cor, vec3(0.86, 0.9, 0.84), espuma * 0.75);
	ALBEDO = cor;
	ROUGHNESS = 0.2;
	SPECULAR = brilho;
}
