shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back, shadows_disabled;  // não recebe a sombra do sol (ver Lighting)
// Bichos da mata (modelos da Tripo, sem esqueleto): toda a animação é feita aqui, mexendo os vértices.
//  modo 0 quadrúpede · modo 1 bípede · modo 2 cobra · modo 3 muitas patas (aranha, formiga)
// Andar: "fase" anda com a distância percorrida; "andando" de 0 a 1 (parado = respira, olha em volta,
// balança o rabo). Ataque: "ataque" vai de 0 a -1 na preparação (recua, ergue os braços, empina) e
// dispara até +1 no golpe; "golpe" escolhe o movimento:
//  0 bote/mordida · 1 patada/garrada de lado · 2 pancada (empina e bate / ergue os braços e esmaga)
//  3 arremesso/cuspe · 5 rugido (abre os braços e incha)
// Leve para o celular: só contas no vértice.

uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform int modo = 0;
uniform vec3 caixa_min = vec3(-0.5, 0.0, -0.5);   // caixa da malha (espaço da malha)
uniform vec3 caixa_tam = vec3(1.0);
uniform vec3 frente = vec3(0.0, 0.0, 1.0);        // para onde a cabeça aponta, na malha
uniform float passada = 1.0;                       // multiplica o tamanho do passo

instance uniform float fase = 0.0;
instance uniform float andando = 0.0;
instance uniform float ataque = 0.0;
instance uniform float golpe = 0.0;
instance uniform float semente = 0.0;
instance uniform vec4 cor : source_color = vec4(1.0);
instance uniform vec4 brilho : source_color = vec4(0.0);
instance uniform float pisca = 0.0;

// gira o ponto p em volta do pivô c, no eixo k (unitário), pelo ângulo t
vec3 girar(vec3 p, vec3 c, vec3 k, float t) {
	vec3 v = p - c;
	return c + v * cos(t) + cross(k, v) * sin(t) + k * dot(k, v) * (1.0 - cos(t));
}

void vertex() {
	vec3 cima = vec3(0.0, 1.0, 0.0);
	vec3 F = normalize(frente);
	vec3 R = normalize(cross(cima, F));
	vec3 centro = caixa_min + caixa_tam * 0.5;
	vec3 base = vec3(centro.x, caixa_min.y, centro.z);
	vec3 d = VERTEX - centro;
	float H = max(caixa_tam.y, 0.001);
	float h = (VERTEX.y - caixa_min.y) / H;           // 0 = pé, 1 = topo
	float L = max(abs(dot(caixa_tam, abs(F))), 0.001); // comprimento
	float W = max(abs(dot(caixa_tam, abs(R))), 0.001); // largura
	float al = dot(d, F) / L;                          // -0,5 rabo ... +0,5 focinho
	float sd = dot(d, R) / W;                          // -0,5 ... +0,5
	float a = clamp(andando, 0.0, 1.0);
	float parado = 1.0 - a;
	float t = TIME + semente;
	float prep = max(-ataque, 0.0);                     // preparação
	float bate = max(ataque, 0.0);                      // golpe
	int g = int(golpe + 0.5);
	vec3 p = VERTEX;
	vec3 desloca = vec3(0.0);

	if (modo == 0) {
		// ---------------- quadrúpede
		float pata = 1.0 - smoothstep(0.16, 0.48, h);
		float lado_s = clamp(sd / 0.16, -1.0, 1.0);
		float frente_s = clamp(al / 0.13, -1.0, 1.0);
		float par = lado_s * frente_s;                  // diagonais em fase oposta (trote)
		float s = sin(fase) * par;
		desloca += F * s * 0.20 * L * passada * pata * a;
		desloca.y += max(0.0, cos(fase) * par) * 0.15 * H * pata * a;
		float corpo = 1.0 - pata;
		float cabeca = smoothstep(0.18, 0.45, al);
		float rabo = smoothstep(0.30, 0.5, -al);
		desloca.y += abs(sin(fase)) * 0.05 * H * corpo * a;                         // sobe e desce
		desloca += R * sin(fase - al * 3.0) * 0.035 * L * corpo * a;                // coluna ondula
		desloca.y += sin(fase * 2.0) * 0.04 * H * cabeca * a;                       // cabeça balança
		desloca += R * sin(t * 0.8) * 0.05 * L * cabeca * parado;                   // olha em volta
		desloca.y += sin(t * 2.1) * 0.015 * H * h * corpo * parado;                // respira
		desloca += R * sin(t * 3.2 + fase) * 0.10 * L * rabo;                       // rabo
		// ataques
		float dianteira = smoothstep(-0.15, 0.4, al);
		if (g == 0 || g == 3) {
			desloca += -F * 0.12 * L * dianteira * prep + cima * 0.10 * H * cabeca * prep;   // recua e ergue
			desloca += F * 0.26 * L * dianteira * bate - cima * 0.06 * H * cabeca * bate;   // bote
		} else if (g == 1) {
			float pata_ataque = pata * smoothstep(0.0, 0.12, al) * smoothstep(0.0, 0.1, sd);
			desloca += cima * 0.35 * H * pata_ataque * prep - F * 0.08 * L * pata_ataque * prep;
			desloca += F * 0.25 * L * pata_ataque * bate - R * 0.2 * W * pata_ataque * bate;
			desloca += F * 0.08 * L * dianteira * bate;
		}
		p += desloca;
		if (g == 2 || g == 5) {
			// empina sobre as patas de trás e bate com as da frente
			vec3 piv = base - F * 0.3 * L;
			p = girar(p, piv, R, -0.55 * prep + 0.10 * bate);
		}
	} else if (modo == 1) {
		// ---------------- bípede
		float perna = 1.0 - smoothstep(0.26, 0.45, h);
		float lado_s = clamp(sd / 0.1, -1.0, 1.0);
		float s = sin(fase) * lado_s;
		desloca += F * s * 0.22 * H * passada * perna * (1.0 - h / 0.45 * 0.65) * a;
		desloca.y += max(0.0, cos(fase) * lado_s) * 0.08 * H * perna * a;
		float tronco = smoothstep(0.38, 0.55, h);
		desloca.y += abs(sin(fase)) * 0.035 * H * (1.0 - perna) * a;
		desloca += R * sin(fase) * 0.02 * H * h * a;
		desloca += d * vec3(1.0, 0.0, 1.0) * 0.025 * sin(t * 2.0) * tronco * parado;  // peito respira
		desloca.y += sin(t * 2.0) * 0.01 * H * tronco * parado;
		p += desloca;
		// braços: o que fica bem para fora do tronco, entre o quadril e o ombro
		float fora = smoothstep(0.24, 0.36, abs(sd));
		float braco = fora * smoothstep(0.22, 0.42, h) * (1.0 - smoothstep(0.8, 0.93, h))
			* smoothstep(-0.32, -0.18, al);   // o que fica bem atrás (rabo) não é braço
		float direito = step(0.0, sd);
		vec3 ombro_d = base + R * 0.22 * W + cima * 0.76 * H;
		vec3 ombro_e = base - R * 0.22 * W + cima * 0.76 * H;
		vec3 ombro = mix(ombro_e, ombro_d, direito);
		float lado_braco = mix(-1.0, 1.0, direito);
		// balanço do andar (ao contrário das pernas) e de parado
		float balanco = -sin(fase) * lado_braco * 0.45 * a + sin(t * 1.3 + lado_braco) * 0.06 * parado;
		float giro_braco = balanco;     // em volta do eixo do lado (para frente/para trás)
		float abre = 0.0;               // em volta do eixo da frente (abre para fora)
		float varre = 0.0;              // em volta do eixo vertical (garrada de lado)
		float torce = sin(fase) * 0.10 * a;   // o tronco gira no passo
		float inclina = 0.0;
		if (g == 1) {
			// garrada com o braço direito: puxa para trás e varre na frente
			varre = direito * (0.9 * prep - 1.5 * bate);
			giro_braco += direito * (-0.6 * prep - 0.5 * bate);
			torce += 0.35 * prep - 0.5 * bate;
		} else if (g == 2) {
			// ergue os dois braços e esmaga para a frente
			giro_braco += -2.3 * prep + 0.9 * bate;
			inclina = -0.18 * prep + 0.30 * bate;
		} else if (g == 3) {
			// arremesso: braço direito vai para trás e por cima, e lança
			giro_braco += direito * (-2.4 * prep + 1.2 * bate);
			torce += 0.45 * prep - 0.55 * bate;
			inclina = -0.08 * prep + 0.15 * bate;
		} else if (g == 5) {
			abre = 1.1 * (prep + bate * 0.6);
			inclina = -0.2 * prep + 0.12 * bate;
		} else if (g == 0) {
			giro_braco += -0.9 * prep - 1.3 * bate;
			inclina = -0.1 * prep + 0.25 * bate;
		}
		vec3 q = p;
		q = girar(q, ombro, R, -giro_braco);
		q = girar(q, ombro, F, abre * lado_braco);
		q = girar(q, ombro, cima, varre);
		p = mix(p, q, braco);
		// tronco: torce e inclina (a partir do quadril)
		vec3 quadril = base + cima * 0.45 * H;
		vec3 r = girar(p, quadril, cima, torce);
		r = girar(r, quadril, R, inclina);
		p = mix(p, r, tronco);
		if (g == 5) {
			p += (p - quadril) * 0.06 * prep * tronco;   // incha no rugido
		}
		p.y -= 0.06 * H * bate * h;   // amassa um pouco no impacto
	} else if (modo == 2) {
		// ---------------- cobra
		float forca = max(a, 0.3);
		float cabeca = smoothstep(0.15, 0.45, al);
		float onda = sin(al * 10.0 - fase * 1.5 - t * 0.6 * parado) * (0.4 + 0.6 * (0.5 - al));
		desloca += R * onda * 0.09 * L * forca * (1.0 - cabeca * 0.6);
		desloca += R * sin(t * 1.1) * 0.04 * L * cabeca * parado;      // cabeça procura
		// bote: encolhe e ergue a cabeça, depois estica para a frente
		desloca += (-F * 0.14 * L + cima * 0.18 * L) * cabeca * prep;
		desloca += F * 0.32 * L * smoothstep(-0.2, 0.45, al) * bate - cima * 0.05 * L * cabeca * bate;
		p += desloca;
	} else {
		// ---------------- muitas patas
		vec2 plano = vec2(sd * 2.0, al * 2.0);
		float raio = length(plano);
		float pata = smoothstep(0.36, 0.6, raio) * (1.0 - smoothstep(0.45, 0.75, h));
		float ang = atan(plano.x, plano.y);
		float s = sin(fase * 1.4 + ang * 3.0);
		desloca += F * s * 0.11 * L * passada * pata * a;
		desloca.y += max(0.0, cos(fase * 1.4 + ang * 3.0)) * 0.14 * H * pata * a;
		desloca.y += sin(fase * 2.8) * 0.03 * H * (1.0 - pata) * a;
		desloca.y += sin(t * 2.5) * 0.02 * H * (1.0 - pata) * parado;
		desloca += F * sin(t * 4.0 + ang * 2.0) * 0.012 * L * pata * parado;   // patas inquietas
		float dianteira = smoothstep(0.05, 0.35, al);
		float pata_frente = pata * dianteira;
		if (g == 2 || g == 5) {
			// agacha e salta
			desloca.y += -0.25 * H * (1.0 - pata) * prep + 0.35 * H * bate;
			desloca += cima * 0.3 * H * pata * prep;
		} else {
			// ergue as patas da frente e dá o bote
			desloca += cima * 0.55 * H * pata_frente * prep - F * 0.06 * L * prep;
			desloca += F * 0.18 * L * bate + F * 0.12 * L * pata_frente * bate;
		}
		p += desloca;
	}
	VERTEX = p;
}

void fragment() {
	vec4 tx = texture(textura, UV);
	ALBEDO = tx.rgb * cor.rgb + vec3(pisca * 0.6);
	// aviso de ataque: contorno brilhante (borda virada para a câmera brilha mais)
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = brilho.rgb * brilho.a * (0.2 + borda * 1.4) + vec3(pisca * 0.5);
	ROUGHNESS = 0.95;
}
