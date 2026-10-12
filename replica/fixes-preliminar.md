# O que os jogadores reclamam — versão preliminar

**Status: amostra fina. Não é ainda a análise completa do replica-entrepreneur.**

O método pede 100+ reviews reais, copiadas palavra por palavra, cada uma com link, de pelo menos três fontes. Não consegui coletar isso automaticamente: o feed público de reviews da App Store bloqueia acesso automatizado, e o método proíbe raspar sites de review. Então este arquivo usa só **resumos secundários** (análises e reviews publicados por terceiros), e por isso nenhum tema aqui deve ser tratado como tendência confirmada.

Para fechar a análise, veja "Como completar" no fim.

## Fontes usadas

| fonte | o que cobre | tamanho |
| --- | --- | --- |
| [JustUseApp — reviews do Soul Knight](https://justuseapp.com/en/app/1184159988/soul-knight/reviews) | 20 reviews da App Store exibidas, agrupadas por tema | 20 |
| [TouchArcade — review do Soul Knight](https://toucharcade.com/2017/03/10/soul-knight-review/) | crítica especializada (2017, versão antiga) | 1 |
| [Kimola — análise de reviews do Guild of Guardians no Google Play](https://kimola.com/reports/unlock-insights-guild-of-guardians-game-review-analysis-google-play-en-153283) | prévia de 30 reviews (ago–set 2024) | 30 |
| [Decrypt — review do Guild of Guardians](https://decrypt.co/231790/guild-guardians-review-perfect-ethereum-game-taking-poo) | crítica especializada (mai 2024, versão idle atual) | 1 |
| [App Store — Guild of Guardians](https://apps.apple.com/app/id1574135647) | reviews em destaque na página | poucas |

Atenção: as reviews do Guild of Guardians são da **versão idle atual**, não da versão ARPG que te inspira. Elas valem para os sistemas que continuaram (gacha, energia, guilda, gear), não para o combate.

## 1. O que eles odeiam

| problema | jogo | evidência | força |
| --- | --- | --- | --- |
| Bugs, travamentos e perda de progresso (crash que apaga save, backup na nuvem que restaura dados velhos) | SK e GoG | ~7 de 20 reviews do SK citam bugs; ~2 citam perda de save; no GoG aparecem tela preta e perda de heróis ao entrar | média — aparece nos dois jogos e em fontes diferentes |
| Energia que limita quantas vezes se pode jogar | GoG | análise do Google Play (Kimola) | fina — 1 fonte |
| Pay-to-win / compras demais | SK e GoG | ~5 de 20 no SK (mas outros dizem que é justo); GoG: tema negativo recorrente na Kimola | média |
| Banimento sem explicação e perda de conta | GoG | Kimola e review em destaque na App Store | fina |
| Controles: só dá para mirar andando; auto-mira atrapalha em barris e objetos | SK | TouchArcade | fina — 1 fonte, versão antiga |
| Progressão lenta e upgrades que mudam pouco; informação confusa (atributos, ícones) | SK | TouchArcade | fina |
| Sinergias de elemento escondidas e parecidas entre si | GoG | Decrypt | fina |
| Lojas repetem armas que você já tem | SK | TouchArcade | fina |
| Anúncio que fecha antes do fim e não dá a recompensa | SK | 1 review | fina |

## 2. O que está faltando (pedidos)

- Multiplayer online de verdade (o local exige a mesma rede Wi-Fi) — SK, ~4–5 de 20
- Modo história, modo infinito, boss rush, mais fases e pets — SK
- Mais personalização de personagem — GoG
- Opção de controle "twin-stick" (mirar com o outro polegar) — SK, crítica especializada

## 3. O que ninguém resolve (ângulo)

O que os dois jogos têm em comum como ponto fraco é **respeito ao tempo e ao progresso do jogador**: save que some, energia que trava a sessão, banimento sem explicação, compras que parecem obrigatórias.

## Plano de correção sugerido para o seu jogo

| # | o que fazer | tamanho | etapa do método | evidência |
| --- | --- | --- | --- | --- |
| 1 | Salvar o estado da run automaticamente e ao sair do app; save local + nuvem com versão | M | replica-architect / replica-backend | perda de progresso nos dois jogos |
| 2 | Sem energia: jogue quanto quiser | S | design | GoG |
| 3 | Monetização só cosmética (skins), sem vender poder | S | replica-launch | p2w nos dois |
| 4 | Opção de mira manual com segundo joystick, além da auto-mira | M | replica-build | SK |
| 5 | Tela de atributos clara e sinergias de classe/elemento explicadas no jogo | S | replica-design | SK e GoG |
| 6 | Loja da run evita repetir armas já equipadas | S | replica-build | SK |

Esses itens já entraram no `features.csv` quando faziam sentido (salvar a run, backup na nuvem, e "energia" marcada como algo que **não** vamos ter).

## Ângulo de posicionamento (rascunho, para validar com mais reviews)

> Para quem gosta de masmorras roguelite no celular mas cansou de energia, pay-to-win e save perdido, **[seu jogo]** é uma run de tempo real com heróis de classe e elemento, que você joga quanto quiser e nunca perde o progresso.
> Evidência: perda de progresso e monetização aparecem nos dois jogos, em fontes diferentes — mas a amostra ainda é pequena.

## Como completar (o que você pode fazer)

O método do replica-entrepreneur foi feito para uma pessoa ler as reviews como leitora comum e copiar para a planilha. Isso você consegue fazer no celular:

1. Abra a página do Soul Knight e do Guild of Guardians no **Google Play**, vá em "Classificações e resenhas", ordene por "Mais recentes" e filtre por 1 a 3 estrelas também.
2. Para cada review útil, adicione uma linha em `replica/reviews.csv` com: fonte (`google-play`), o link da página do jogo, a data, as estrelas e o texto **exatamente como está**.
3. Mire em 50+ por jogo. Reviews de 3 e 4 estrelas ("adoro, mas...") costumam ser as melhores.
4. Me mande o arquivo e eu rodo:

```bash
python3 .claude/skills/replica-entrepreneur/reviews.py replica/reviews.csv --themes replica/themes-jogos.json --out replica/feedback.md
```

O `themes-jogos.json` já reconhece reclamações em inglês e português.
