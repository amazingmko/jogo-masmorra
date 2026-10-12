# Recon: Soul Knight + Guild of Guardians (versão ARPG) — Android/iOS

Escopo: o loop de uma "run" de masmorra (explorar salas, lutar em tempo real, pegar itens e buffs, enfrentar o chefe) e a progressão de heróis com classes e equipamento entre as runs.
Para: um jogo mobile original e autoral da Samantha, inspirado nos dois, não uma cópia.
Data: 2026-10-12

> Regra do método (replica-recon): estudamos **o que os jogos fazem e como o jogador se move por eles**. Nada de código, arte, personagens, nomes, música ou textos dos originais entra no seu jogo. As referências servem só para entender mecânicas.

## Aviso importante sobre o Guild of Guardians

A versão **ARPG isométrica** do Guild of Guardians **não existe mais publicamente**. Em maio de 2023 o estúdio mudou o jogo de RPG de ação para "Roguelite Squad RPG" com batalha automática, e a movimentação isométrica foi removida. O motivo declarado pelo diretor do jogo foi que a versão original não atingia as metas de retenção. O jogo que está hoje na App Store é um RPG idle com gacha.

Consequência: tudo que está aqui sobre a versão ARPG vem de artigos e guias da época (2021–2023), não de jogar. A confiança nesses pontos é **média**. Se você tiver vídeos de gameplay da época (alpha/closed beta 2022) que goste, eles são a melhor fonte para completar este mapa.

## Fontes

| # | fonte | URL | o que deu |
| --- | --- | --- | --- |
| 1 | Soul Knight — App Store | https://apps.apple.com/app/soul-knight/id1184159988 | features oficiais: 20+ heróis, 400+ armas, masmorras geradas, auto-mira, co-op online e LAN, modo offline, nota 4.8 (~127 mil avaliações), versão 8.6.0 |
| 2 | Soul Knight Wiki — Game Mechanics | https://soul-knight.fandom.com/wiki/Game_Mechanics | vida, armadura, energia, armas, habilidades, moedas, controles |
| 3 | Soul Knight Wiki — Buffs | https://soul-knight.fandom.com/wiki/Buffs | quando e como se escolhem buffs na run |
| 4 | TouchArcade — review do Soul Knight | https://toucharcade.com/2017/03/10/soul-knight-review/ | estrutura de 5 fases por área com chefe, críticas a controles e progressão |
| 5 | Guild of Guardians — App Store (versão atual) | https://apps.apple.com/app/id1574135647 | heróis por raridade e domínio, papéis (tank, ranger, mago, healer), gear, guildas, gacha |
| 6 | Coin Bureau — review do Guild of Guardians | https://coinbureau.com/review/guild-of-guardians-review | design original: classes, raridades, elementos, habilidade ativa/passiva, pets, energia, loot, crafting, guildas |
| 7 | DappRadar — guia do Guild of Guardians | https://dappradar.com/blog/guild-of-guardians-play-earn-rewards-immutable-game-guide | confirma a remoção da movimentação isométrica; esquadrão, gear, crafting |
| 8 | games.gg — mudanças de desenvolvimento (2023) | https://games.gg/zh-CN/news/guild-of-guardians-reveals-major-development-changes/ | a troca de ARPG para squad RPG |
| 9 | GamesTx — lições do Guild of Guardians | https://gamestx.substack.com/p/lessons-from-guild-of-guardians | motivo da mudança (retenção) |
| 10 | Stepico — página do projeto | https://stepico.com/projects/guild-of-guardians/ | versão original feita em Unity |

## Visão da autora (definida em 2026-10-12)

- **Progressão lenta, mas sem travar:** o jogador sempre avança um pouco a cada run; nada de energia, muros de pagamento ou espera obrigatória.
- **Duração longa:** o endgame não deve chegar cedo.
- **Itens no centro:** equipamentos, itens que caem nas masmorras e crafting são parte essencial do jogo.
- **Profissões para craftar** (ex.: ferreiro, alquimista): desejado, para uma fase posterior.
- O primeiro jogo enxuto continua como está; crafting e profissões entram depois, mas o modelo de dados já nasce preparado para eles.
- **Visual: 3D low-poly com câmera fixa de cima** (estilo Archero), feito com calma e cuidado. Engine a definir na etapa de arquitetura.

## O loop principal (core loop)

**Entrar na masmorra com um herói (ou esquadrão), limpar sala por sala em combate de tempo real, montar a "build" da run com armas e buffs aleatórios, derrotar o chefe; ao sair, converter o que ganhou em progresso permanente (heróis, equipamento).**

O Soul Knight dá o formato da run (curta, roguelite, controle direto). O Guild of Guardians ARPG dá a camada de fora da run (heróis com classe, elemento e raridade; equipamento; crafting; guilda).

## Telas

| ID | tela | como chegar | propósito | componentes principais | estados | fonte |
| --- | --- | --- | --- | --- | --- | --- |
| S01 | Abertura / carregamento | abrir o app | carregar, login opcional | logo, barra de progresso | carregando, erro de rede, offline | ambos |
| S02 | Hub / lobby | após carregar | base do jogador entre runs | personagem andando, NPCs/objetos interativos, moedas no topo | primeira vez (tutorial), normal | SK (sala de estar) |
| S03 | Seleção de herói | interagir no hub | escolher quem entra na run | carrossel de heróis, atributos, skin, botão comprar/desbloquear | bloqueado, desbloqueado, selecionado | SK |
| S04 | Montar esquadrão | hub (variante GoG) | escolher até N heróis ativos | slots de esquadrão, filtros por classe/elemento | vazio, incompleto, completo | GoG |
| S05 | HUD da run | iniciar run | jogar | joystick, botão atacar/interagir, botão habilidade, troca de arma, barras de vida/armadura/energia, minimapa, pausa | normal, sem energia, habilidade em recarga, interação disponível | SK |
| S06 | Mapa da fase (minimapa expandido) | tocar no minimapa | ver salas visitadas | grade de salas, ícones de baú/loja/chefe | parcial, completo | SK |
| S07 | Escolha de buff | entre fases | escolher 1 de 3 buffs | 3 cartas de buff, descrição | 3 opções, slots cheios | SK |
| S08 | Loja / mercador da run | sala de loja | trocar ouro por item | lista de itens, preço, ouro atual | sem ouro suficiente, esgotado | SK |
| S09 | Baú / loot | abrir baú, matar chefe | receber arma/item | item no chão, comparação com arma atual | arma melhor, pior, slots cheios | ambos |
| S10 | Pausa | botão pausa | sair, configurações, buffs ativos | lista de buffs, botões | — | SK |
| S11 | Morte / revive | vida chega a 0 | reviver ou encerrar | botão reviver (moeda ou anúncio), botão desistir | pode reviver, não pode | SK |
| S12 | Resumo da run | fim da run | mostrar o que ganhou | fase alcançada, inimigos, ouro→gemas, recompensas | vitória, derrota | SK |
| S13 | Detalhe do herói | hub / seleção | evoluir herói | nível, atributos, habilidades ativa/passiva, classe, elemento, raridade | pode evoluir, falta recurso, nível máximo | ambos |
| S14 | Inventário / equipamento | hub | equipar armas e armaduras | slots de equipamento, lista filtrável, comparação | vazio, cheio | GoG |
| S15 | Crafting / forja | hub | criar e melhorar itens | receita, recursos, botão criar | recurso suficiente, faltando | GoG |
| S16 | Invocação (gacha) | hub | obter heróis | banner, botão invocar, animação | moeda suficiente, faltando | ambos (decisão sua se terá) |
| S17 | Guilda | hub | social, contribuição, raides | membros, contribuições, eventos | sem guilda, em guilda | GoG |
| S18 | Multiplayer / co-op | hub | jogar com amigos | criar sala, entrar, lista de jogadores | procurando, conectado, erro | SK |
| S19 | Configurações | pausa / hub | som, controles, idioma, conta | toggles, sliders | — | ambos |
| S20 | Introdução do chefe | entrar na sala do chefe | apresentar o chefe | nome, barra de vida do chefe | — | ambos |

## Fluxos

```
F01 Fazer uma run (o loop principal)
    S02 hub -> S03 escolher herói -> S05 fase 1-1 -> salas de combate -> S07 buff
    -> ... -> S20 chefe na fase X-5 -> S07 buff -> próxima área -> ... -> S12 resumo
    caminho feliz: 1 área = 5 fases; o chefe fica na 5ª fase de cada área (fonte 4)
    borda: morrer no meio (F03), slots de arma cheios, sem energia para atirar,
           sair do app no meio da run (precisa salvar estado?)

F02 Escolher um buff
    fim da fase -> S07 três opções aleatórias -> escolher 1 -> ocupa um slot
    no Soul Knight acontece depois das fases 1-1, 1-3, 1-5, 2-3 e 2-5 (fonte 3)
    borda: buff já escolhido não reaparece; slots cheios

F03 Morrer e reviver
    vida = 0 -> S11 -> reviver (gasta moeda/anúncio) -> volta à sala
                    -> desistir -> S12 resumo
    borda: o anúncio fecha antes do fim (reclamação real em reviews do SK)

F04 Pegar e trocar arma
    S09 arma no chão -> aproximar -> botão vira "interagir" -> pegar
    -> se 2 slots cheios, solta a arma atual (fonte 2)

F05 Evoluir herói
    S02 -> S13 -> gastar recurso -> nível sobe -> habilidade melhora

F06 Equipar e criar item (camada GoG)
    S14 escolher slot -> comparar -> equipar
    S15 escolher receita -> gastar recursos do loot -> item novo

F07 Co-op
    S18 criar sala -> amigo entra -> F01 juntos
    borda: queda de conexão, um jogador não consegue pegar item (bug citado em reviews)
```

## Componentes

| componente | variantes | estados | usado em |
| --- | --- | --- | --- |
| Joystick virtual | fixo, flutuante | parado, movendo | S05, S02 |
| Botão de ação contextual | atacar, interagir | normal, desabilitado | S05 |
| Botão de habilidade | — | pronta, recarregando (contador) | S05 |
| Barras de status | vida, armadura, energia | cheia, baixa, vazia | S05 |
| Carta de buff | comum, rara | normal, selecionada | S07 |
| Card de item/arma | por raridade (comum → lendário) | equipado, comparação melhor/pior | S08, S09, S14 |
| Card de herói | por raridade, classe e elemento | bloqueado, disponível, selecionado | S03, S04, S13, S16 |
| Contador de moeda | ouro (na run), gemas (fora) | normal, insuficiente | S02, S05, S08 |
| Minimapa | compacto, expandido | sala atual, visitada, desconhecida | S05, S06 |
| Barra de vida do chefe | — | normal, fase 2 | S20, S05 |
| Modal de confirmação | — | — | vários |
| Toast / aviso curto | info, erro | — | vários |

## Modelo de dados inferido

```
Heroi      id, nome, classe (tank|ranger|mago|healer|...), elemento, raridade,
           nivel, vida_base, armadura_base, energia_base, critico_base,
           habilidade_ativa_id, habilidade_passiva_id
           evidência: S13; fontes 2, 5, 6     confiança: alta

Habilidade id, nome, tipo (ativa|passiva), recarga_s, nivel
           evidência: fontes 2 e 6 (ativa + passiva por herói)   confiança: alta

Arma       id, nome, tipo (corpo-a-corpo|disparo), dano, custo_energia,
           critico, imprecisao, raridade
           evidência: fonte 2 (atributos das armas no SK)   confiança: alta

Equipamento id, slot (arma|armadura|acessorio), raridade, atributos, nivel
           evidência: fontes 6 e 7 (cada herói precisa de arma e armadura)
           confiança: média (versão ARPG não está mais acessível)

Buff       id, nome, efeito, raridade
           evidência: fonte 3    confiança: alta

Run        id, heroi_id(s), seed, area, fase, ouro, buffs[], armas[], status
           evidência: F01; fonte 3     confiança: média (estado interno é palpite)

Sala       tipo (inicio|combate|bau|loja|estatua|chefe|portal), inimigos[]
           evidência: fonte 2 (limpar todos os inimigos para avançar)
           confiança: média — tipos além de combate/chefe são palpite pela experiência de jogo

Inimigo    id, vida, dano, padrao_ataque, elemento
           confiança: palpite

Jogador    id, gemas, herois_desbloqueados[], inventario[], recursos{}, guilda_id
           confiança: média

Receita    id, item_resultado_id, recursos{}, profissao_id, nivel_profissao_min
           evidência: fontes 6 e 7 (crafting); profissão é pedido da autora
           confiança: média

Profissao  id, nome (ferreiro|alquimista|...), nivel, xp      (fase posterior)
           evidência: visão da autora     confiança: decisão de design

TabelaDrop id, origem (inimigo|chefe|bau), itens[{item_id, chance, qtd}]
           evidência: fontes 2, 6 (loot e recursos nas masmorras)   confiança: alta
```

Relações: Jogador 1-n Heroi; Heroi 1-n Equipamento; Run n-1 Jogador; Run 1-n Buff; Run 1-n Arma; Sala 1-n Inimigo; Jogador n-1 Guilda.

Regra de dano por elemento (GoG original): elemento forte causa 30% a mais contra o fraco (fonte 6).

## Matriz de features

Veja `features.csv`. Contagem: must 18, should 15, could 10, skip 4.

## Fora do escopo (não pode ou não deve ser copiado)

- **Personagens, armas com nome, arte em pixel, músicas e textos dos dois jogos.** Tudo será criado do zero.
- **NFTs, token GOG e economia em blockchain do Guild of Guardians.** Não fazem parte da mecânica de jogo e trazem risco regulatório.
- **A comunidade e as guildas existentes** — é a rede deles, não uma feature.
- **O catálogo de 400+ armas e 20+ heróis** — você constrói o seu, começando pequeno.

## Tamanho

Telas 20, fluxos 7, entidades 10.

Partes difíceis:
1. **Combate em tempo real que seja gostoso no celular** (controles, auto-mira, feedback de acerto). É o que faz ou quebra o jogo.
2. **Geração procedural de masmorras** (salas conectadas, com dificuldade crescente).
3. **Multiplayer co-op** — de longe a parte mais cara; deixar para depois.

Tamanho do conjunto todo: **XL — precisa recortar.** Para uma pessoa só, a sugestão é um MVP de tamanho **M**:

- 3 heróis (uma classe de cada: tank, ranger, mago), com habilidade ativa
- 1 área com 5 fases e 1 chefe
- 10–15 armas, 15–20 buffs
- hub simples, resumo da run, evolução de herói com uma moeda
- sem gacha, guilda, crafting e multiplayer nesta primeira versão

Próximo passo do método: `replica-architect` (escolher tecnologia e estrutura de dados), depois de você revisar a matriz.
