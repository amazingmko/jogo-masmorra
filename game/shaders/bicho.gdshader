shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back, shadows_disabled;  // não recebe a sombra do sol (ver Lighting)
// Bichos da mata (modelos da Tripo, sem esqueleto): o andar é feito aqui, mexendo os vértices.
//  modo 0 quadrúpede: patas em diagonal (trote), corpo sobe e desce
//  modo 1 bípede: pernas alternadas, braços balançando ao contrário
//  modo 2 cobra: o corpo serpenteia de lado (onda que corre do rabo para a cabeça)
//  modo 3 muitas patas (aranha, formiga): patas em onda em volta do corpo
// "fase" anda com a distância percorrida (script); "andando" de 0 a 1.
// Leve para o celular: só contas no vértice, nenhuma textura extra.

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform int modo = 0;
uniform vec3 caixa_min = vec3(-0.5, 0.0, -0.5);   // caixa da malha (espaço da malha)
uniform vec3 caixa_tam = vec3(1.0);
uniform vec3 frente = vec3(0.0, 0.0, 1.0);        // para onde a cabeça aponta, na malha
uniform float passada = 1.0;                       // multiplica o tamanho do passo

instance uniform float fase = 0.0;
instance uniform float andando = 0.0;
instance uniform vec4 cor : source_color = vec4(1.0);
instance uniform vec4 brilho : source_color = vec4(0.0);
instance uniform float pisca = 0.0;

void vertex() {
	vec3 centro = caixa_min + caixa_tam * 0.5;
	vec3 lado_v = normalize(cross(vec3(0.0, 1.0, 0.0), frente));
	vec3 d = VERTEX - centro;
	float h = (VERTEX.y - caixa_min.y) / max(caixa_tam.y, 0.001);   // 0 = pé, 1 = topo
	float comp = abs(dot(caixa_tam, abs(frente)));                    // comprimento
	float larg = abs(dot(caixa_tam, abs(lado_v)));                    // largura
	float ao_longo = dot(d, frente);
	float de_lado = dot(d, lado_v);
	float a = clamp(andando, 0.0, 1.0);
	vec3 desloca = vec3(0.0);

	if (modo == 0) {
		float pata = 1.0 - smoothstep(0.18, 0.5, h);
		float lado_s = clamp(de_lado / (0.18 * larg), -1.0, 1.0);
		float frente_s = clamp(ao_longo / (0.15 * comp), -1.0, 1.0);
		float par = lado_s * frente_s;                  // diagonais em fase oposta
		float s = sin(fase) * par;
		desloca += frente * s * 0.14 * comp * passada * pata * a;
		desloca.y += max(0.0, cos(fase) * par) * 0.10 * caixa_tam.y * pata * a;
		desloca.y += abs(sin(fase)) * 0.035 * caixa_tam.y * (1.0 - pata) * a;
		desloca += frente * sin(fase * 2.0) * 0.012 * comp * (1.0 - pata) * a;
	} else if (modo == 1) {
		float perna = 1.0 - smoothstep(0.28, 0.46, h);
		float lado_s = clamp(de_lado / (0.12 * larg), -1.0, 1.0);
		float s = sin(fase) * lado_s;
		desloca += frente * s * 0.17 * caixa_tam.y * passada * perna * (1.0 - h / 0.46 * 0.6) * a;
		desloca.y += max(0.0, cos(fase) * lado_s) * 0.06 * caixa_tam.y * perna * a;
		// braços: o que fica bem para fora do tronco, entre o quadril e o ombro
		float fora = smoothstep(0.30, 0.42, abs(de_lado) / max(larg, 0.001));
		float braco = fora * smoothstep(0.25, 0.45, h) * (1.0 - smoothstep(0.78, 0.92, h));
		float mao = clamp((0.85 - h) / 0.5, 0.0, 1.0);
		desloca += frente * (-s) * 0.12 * caixa_tam.y * braco * mao * a;
		// corpo: sobe e desce e gira um pouquinho no passo
		desloca.y += abs(sin(fase)) * 0.025 * caixa_tam.y * (1.0 - perna) * a;
		desloca += lado_v * sin(fase) * 0.015 * caixa_tam.y * h * a;
	} else if (modo == 2) {
		float t = ao_longo / max(comp, 0.001);         // -0,5 rabo ... +0,5 cabeça
		float forca = max(a, 0.25);                     // mesmo parada, respira um pouco
		float onda = sin(t * 9.0 - fase * 1.4) * (0.35 + 0.65 * (0.5 - t));
		desloca += lado_v * onda * 0.07 * comp * forca;
	} else {
		vec2 plano = vec2(de_lado / max(larg * 0.5, 0.001), ao_longo / max(comp * 0.5, 0.001));
		float raio = length(plano);
		float pata = smoothstep(0.38, 0.62, raio) * (1.0 - smoothstep(0.45, 0.75, h));
		float ang = atan(plano.x, plano.y);
		float s = sin(fase * 1.3 + ang * 3.0);
		desloca += frente * s * 0.07 * comp * passada * pata * a;
		desloca.y += max(0.0, cos(fase * 1.3 + ang * 3.0)) * 0.08 * caixa_tam.y * pata * a;
		desloca.y += sin(fase * 2.6) * 0.015 * caixa_tam.y * (1.0 - pata) * a;
	}
	VERTEX += desloca;
}

void fragment() {
	vec4 t = texture(textura, UV);
	ALBEDO = t.rgb * cor.rgb + vec3(pisca * 0.6);
	// aviso de ataque: contorno brilhante (borda virada para a câmera brilha mais)
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = brilho.rgb * brilho.a * (0.25 + borda * 1.6) + vec3(pisca * 0.5);
	ROUGHNESS = 0.95;
}
