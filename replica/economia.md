# Economia (passo 2) — proposta para aprovação

Números iniciais; depois de implementado, o robô (tests/sim_run.gd) mede o rendimento real e ajusto.

## Moedas
- **Ouro**: cai pouco de todo bicho. Abate 2 (×1 +8% por andar); furioso 12; baú 40; covil 120; Onça Alfa 150; Mapinguari 400.
  Dificuldade: Normal ×1 · Difícil ×1,3 · Heroico ×1,6 · Mítico ×2. Sem energia: 35%.
- **Essência da Mata**: furioso 15% de chance (1); covil 3; Alfa 2; Mapinguari 5; 1ª vitória do dia em cada dificuldade +5.
- **Bolsa do Garimpeiro**: ouro e essência da run ficam na bolsa; sair pela fogueira (andar 5) ou vencer guarda tudo; cair perde metade.

## Reagentes (mais raros)
- Bicho comum: 15% de chance, 1–2. Furioso: sempre 2–3. Baú: 2 sorteios de 3–5.
- Pena de Arara: furiosos (25%) e chefes. Pelo de Mapinguari: só do Mapinguari. Dente da Onça Alfa: novo, só da Alfa.
- Proteção contra azar: cada furioso sem item raro soma +5% no próximo.

## Rendimento estimado por run (Normal, com energia)
| | até a fogueira (andar 5, ~10 min) | completa (10 andares, ~20 min) |
|---|---|---|
| ouro | ~510 | ~1.370 |
| cada reagente comum | ~7 | ~17 |
| Pena de Arara | ~1,5 | ~5 |
| Pelo de Mapinguari | 0 | ~3 |
| Essência | ~3 | ~9 |
| XP | ~480 | ~970 |

## Onde o ouro vai
- **Treino do herói** (cada nível pede XP e ouro): 120 × 1,11^(nível−1). Até o 10: 1.700 · 20: 6.800 · 30: 21.400 · 40: 62.800.
- **Taxa de fabricação** (cobrada em toda tentativa, peça de peso 1): Comum 150 · Raro 800 · Épico 3.500 + 15 essências · Lendário 12.000 + 40 essências.
- **Estrelas** (fragmentos do herói + ouro): 2★ 2.000 · 3★ 6.000 · 4★ 15.000 + 30 ess. · 5★ 40.000 + 80 ess.
- Curva de XP nova: 300 × 1,15^(nível−1) por nível (nível 10 = 5.000 XP; 40 = 464.000).

## Tempo estimado (jogador casual: 3 runs por dia, ~1 hora)
| marco | quando |
|---|---|
| 1ª peça Comum | 1º dia (2 runs até a fogueira) |
| nível 10 | 2º–3º dia |
| conjunto Comum completo | ~4º dia |
| 1ª peça Rara | ~1 semana |
| conjunto Raro | ~2 semanas |
| nível 20 | ~2 semanas |
| 1ª peça Épica | ~3 semanas |
| conjunto Épico | ~1 mês e meio |
| 1ª peça Lendária | ~2 meses |
| nível 40 | ~2 meses |
| herói no máximo (40, 5★, tudo Lendário) | ~4 meses |
| os 4 heróis no máximo | ~1 ano (o ouro é dividido entre todos) |
