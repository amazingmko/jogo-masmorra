# Jogo de masmorra (nome provisório)

Jogo mobile 3D low-poly de exploração de masmorras, com heróis de classe e elemento, itens que caem nas masmorras, crafting e runs roguelite em tempo real. Inspirado nas mecânicas de Soul Knight e da versão ARPG do Guild of Guardians, sem usar arte, personagens, nomes ou textos deles.

Feito em **Godot 4.7.2 (Standard, GDScript)**.

## Como abrir

1. Abra o Godot e clique em **Importar** (Import).
2. Escolha o arquivo `project.godot` desta pasta.
3. Clique em **Importar e Editar**. Na primeira vez o Godot leva alguns segundos preparando os arquivos.
4. Aperte **F5** (ou o botão ▶ no canto superior direito) para jogar.

### Base (hub)

O jogo abre na base. Ande até um ponto e toque no botão azul (PC: **E**):

- **Portal da Masmorra** — escolher a dificuldade, decidir se gasta energia e começar a run
- **Baú e Equipamento** — vestir e tirar peças, ver atributos e reagentes
- **Quadro de Heróis** — trocar de herói (Icamiaba: tanque, lança e escudo, força/placa · Mateira: agilidade/couro · Encantado do Rio: inteligência/tecido · Druida da Mata: agilidade/couro)
- **Oficina dos Artesãos** — fabricar equipamento e garrafadas

### Druida da Mata

Troca de forma com o botão verde **FORMA** (PC: **Q**). A troca é instantânea, com uma pausa curta entre uma e outra.

| forma | jeito de lutar |
| --- | --- |
| **Onça** | corpo a corpo, golpes rápidos (+35% de velocidade de ataque) e anda mais rápido |
| **Sucuri** | corpo a corpo com alcance maior; cada golpe **aperta** o inimigo e o segura no lugar por 0,8 s (o chefe, bem menos); recebe 25% menos dano |
| **Boto** | jatos d'água de longe (dano menor), anda mais rápido e **recupera 1,5% da vida por segundo** |

Arma: **Cajado de Raiz**, feito pelo Curtidor. Os números das formas ficam no começo de `game/scripts/gameplay/player.gd`.

### Crafting (Oficina dos Artesãos)

Nada de equipamento cai nas masmorras: **tudo é fabricado**. Cada profissão sobe do nível 1 ao 100 fabricando.

| profissão | fabrica | reagentes principais |
| --- | --- | --- |
| Ferreiro | lança, escudo (só tanques) e armadura de placa | Minério de Ferro, Madeira de Lei, Couro de Jacaré |
| Curtidor | arco, Cajado de Raiz e armadura de couro | Couro de Jacaré, Látex de Seringueira, Madeira de Lei |
| Tecelã | cajado e armadura de tecido | Fibra de Tucum, Látex de Seringueira, Madeira de Lei |
| Erveira | Garrafada de Cura | Óleo de Andiroba |

Cada peça tem uma **cadeia de raridade**: a Rara pede a peça Comum, a Épica pede a Rara, a Lendária pede a Épica.

| raridade | chance base | nível de profissão | Poder da peça | atributos | reagentes extras |
| --- | --- | --- | --- | --- | --- |
| Comum | 90% | 1 | 10 | ×1 | — |
| Raro | 65% | 5 | 20 | ×1,6 | 3× a Comum + Pena de Arara |
| Épico | 40% | 20 | 35 | ×2,4 | 6× + Pena + **Pelo de Mapinguari** (chefe) |
| Lendário | 15% | 40 | 55 | ×3,5 | 10× + Pena + Pelo + **Muiraquitã** (chefe no Mítico) |

Os itens **não têm nível**: a força vem da raridade. O **Poder** do herói é a soma das 6 peças vestidas (um conjunto Comum = 60) e aparece na base, no baú e no portal.

- A chance sobe +1% (Comum/Raro) ou +0,5% (Épico/Lendário) por nível de profissão acima do exigido, e **+10% por falha seguida** na mesma receita (zera ao acertar). Teto: 95%.
- **Na falha:** perde metade dos reagentes, a peça-base volta e a profissão ganha 30% da XP.
- Se a peça-base estava vestida, a peça nova é vestida no lugar dela.

### Dificuldades e energia

| dificuldade | inimigos (vida / dano) | XP | reagentes | para liberar |
| --- | --- | --- | --- | --- |
| Normal | ×1 / ×1 | ×1 | ×1 | — |
| Difícil | ×1,8 / ×1,5 | ×2 | ×1,5 | vencer o Normal + Poder 80 (conjunto Comum + 2 Raras) |
| Heroico | ×3,2 / ×2,2 | ×4 | ×2 | vencer o Difícil + Poder 140 (4 Raras + 2 Épicas) |
| Mítico | ×5,6 / ×3,2 | ×8 | ×3 + Muiraquitã | vencer o Heroico + Poder 200 (quase tudo Épico) |

Em dificuldades maiores os inimigos também ficam mais agressivos, com mais ondas e mais furiosos.

**Mundos:** o 2º mundo (Igapó) ainda não existe, mas o portal já mostra o requisito: vencer a Terra Firme no Normal e ter Poder 90. A ideia é que a Terra Firme seja onde se fabrica o conjunto Comum, que é o que permite vencê-la, e que ninguém chegue ao mundo 2 sem equipamento para avançar lá.

**Energia:** até 5, recarrega 1 por hora. Jogar é sempre liberado; gastar 1 energia faz a run render a recompensa completa. Sem energia, a run rende 35% dos reagentes e nenhum troféu do chefe (XP não muda). Os números ficam em `game/scripts/systems/difficulty.gd` e `crafting.gd`.

### A run

**Tanque (Icamiaba):** mais vida, escudo maior e armadura própria; golpes de lança mais lentos e com menos dano. Só o tanque **bloqueia**: 12% de base mais o Escudo de Casco equipado (4/6/8/11% por raridade, até 50%). Golpe bloqueado perde 70% do dano (veneno e mega magia não são bloqueáveis).
**Sem escudo:** quando a barra de escudo zera, qualquer herói toma +25% de dano até ela voltar.

A **Terra Firme**: 5 andares de mata fechada gerados aleatoriamente. Nas salas de combate as portas fecham até o último inimigo cair. Baús (amarelo no minimapa) dão reagentes, a fonte (verde) cura, o portal azul leva ao próximo andar (sem bênçãos: a força vem do equipamento fabricado). No 5º andar, o Mapinguari, que deixa muitos reagentes e o Pelo de Mapinguari. XP e reagentes ficam com o herói, mesmo perdendo.

### Ondas e furiosos

Ao matar todos os bichos de uma sala, **podem chegar mais ondas** (de 1 a 4), avisadas por círculos laranja no chão onde vão aparecer. As portas só abrem quando a última onda cai.

| | 1º andar, Normal | 5º andar, Normal | Mítico |
| --- | --- | --- | --- |
| chance de ter ondas extras | 35% | 67% | até 95% |
| quantas | 1–2 | 1–4 | 1–4 |
| chance de furioso por onda | 6% (+6% por onda) | 26% (+6% por onda) | bem maior, às vezes 2 |

**Furioso (elite):** maior, avermelhado, com um anel vermelho e o nome em cima. Tem 2,5× a vida, 1,5× o dano, é mais rápido e agressivo, e deixa o dobro de reagentes e o triplo de XP. Os números ficam no começo de `game/scripts/gameplay/main.gd`.

### Covil Furioso (sala rara)

Às vezes um andar tem um **Covil Furioso**: uma sala fora do caminho principal (de preferência um beco sem saída), marcada em **vermelho** no minimapa e com o chão avermelhado. Um aviso aparece quando o andar começa. Entrar é escolha sua; lá dentro as portas fecham.

- **Tudo furioso**, em 2 ondas.
- Vencendo: um **baú grande** no meio da sala (reagentes de chefe + **Pelo de Mapinguari**; no Mítico, chance de Muiraquitã) e 5× a XP de uma sala.
- Chance por andar: 4% no 1º andar até 8% no 5º, +2% por dificuldade (cerca de 1 run em 4 no Normal tem um).

### Inimigos

Todo ataque inimigo mostra um **aviso no chão** antes de acontecer (o preenchimento cresce até o impacto): saia da área para desviar. Cada inimigo tem vários ataques, editáveis em `game/data/enemies/` (lista "Ataques" no Inspector).

Os inimigos alternam entre **pressionar** (partem para cima e emendam uma sequência de ataques) e **recuar** (abrem distância, rodeiam e soltam magias de longe). Também **esquivam**: saem da frente de disparos e às vezes escapam de um golpe (aparece "esquiva"). Quem apanha muito de uma vez pode recuar para se recompor. O movimento é sorteado entre manobras (direto, arco pelo lado, arrancada, finta, pulo lateral, rodear, recuar), sempre puxando para o herói.

Cada sala tem um **perigo** de 0 a 1, que sobe com o andar e com a distância da entrada. Quanto maior, mais longas as sequências, mais esquivas e recuos e mais magias: alguns ataques só aparecem em salas perigosas (campo "Min Threat" no Inspector). O **chefe** fica mais rápido, ataca mais seguido e solta mais magias quanto menos vida tem.

### Terra Firme: os bichos e o Mapinguari

Cada habilidade vem do comportamento real do bicho ou da lenda.

| inimigo | aparece | comportamento real → habilidade |
| --- | --- | --- |
| **Queixada** | andar 1+ | anda em bando (2–3) → **Investida do Bando**: quando um investe, os outros por perto investem junto; dentada · salas perigosas: **Estouro da Manada** |
| **Formiga-de-Fogo** | andar 1+ | pequena, em grupo (3–4), ferroada dolorida → **Ferroada** que **envenena** · salas perigosas: **Ataque do Formigueiro** (chama as outras) |
| **Macaco-Prego** | andar 1+ | usa pedras como ferramenta e derruba castanhas → **Pedrada** de longe e **Ouriço de Castanha** caindo do alto |
| **Aranha-Caranguejeira** | andar 2+ | picada, solta seda e os pelos que irritam a pele → **Teia** que **prende**, **Pelos Urticantes** (leque que deixa **lento**) · salas perigosas: **Armadilha de Teia** no chão |
| **Jararaca** | andar 2+ | caça de tocaia → fica **parada e apagada** até você chegar perto e dá o **Bote** venenoso |
| **Onça-Pintada** | andar 3+ | caçadora de emboscada, mordida mais forte dos felinos → **camuflada** (quase invisível de longe), **Bote** longo, **Mordida no Crânio** · salas perigosas: **Esturro** que dá **medo** |
| **Mapinguari** (chefe) | andar 5 | cinco olhos, boca na barriga, fedor e grito que assusta caçadores → veja abaixo |

**Couro que bala não fura:** o Mapinguari toma **metade do dano** (números em cinza). Depois da **Bocarra do Ventre**, a barriga brilha e fica **exposta por 3 segundos**: aí ele toma o **dobro** (números em laranja). Desviar da Bocarra e contra-atacar na hora é o jeito de vencê-lo.

**Mapinguari, por fases:** Garras, **Bocarra do Ventre** (se acertar, ele **recupera vida**; acertando ou não, expõe a barriga) e **Investida Devastadora** → abaixo de 85%: **Olhar dos Cinco Olhos** (5 disparos em leque, um por olho) → abaixo de 75%: **Estouro de Queixadas** (o bando chega correndo) → abaixo de 70%: **Fedor do Mapinguari** (nuvens venenosas que ficam no chão) → abaixo de 60%: **Grito Estrondoso** (área grande em volta dele: quem estiver dentro fica **com medo**, sem andar nem atacar) e **Árvores Derrubadas** → abaixo de 45%: **Bafo do Mapinguari** (a sala inteira; só as zonas verdes são seguras; envenena) → abaixo de 30%: **enfurecido**.

**Medo** (efeito novo): o herói não anda nem ataca por um instante. Aparece como "Com medo" na tela.

| ação | PC | celular / mouse |
| --- | --- | --- |
| andar | WASD ou setas | arrastar na metade esquerda da tela (joystick) |
| atacar (mira sozinho) | segurar Espaço ou J | segurar o botão ATACAR |
| trocar de forma (Druida) | Q ou K | botão FORMA |
| interagir na base | E | botão azul |
| nova run / salvar | R / G | — |

## Estrutura

```
game/
  autoload/      sistemas globais: ItemDB (catálogo), GameState (progresso), SaveSystem
  data/          dados do jogo — reagentes e moldes de itens, heróis, drops, receitas, profissões, buffs (.tres)
  scripts/       moldes de dados, regras (inventário, itens, atributos, XP, drop, crafting, save),
                 combate, masmorra (planta, salas, baús/fonte/portal), hub, jogabilidade e interface
  scenes/        cenas
tests/           testes automáticos das regras e simulação de combate
tools/           script que gerou os dados de exemplo
replica/         documentos do método e de design: recon, matriz de features, arquitetura,
                 direção de arte e progressão
.claude/ .kiro/  skills do replica-skill
```

Para criar um item novo: no painel **FileSystem** do Godot, abra `game/data/items/`, clique com o botão direito num item, **Duplicar**, e mude os campos no **Inspector**. Faça o mesmo para receitas (`game/data/recipes/`, uma por peça e raridade) e tabelas de drop.

## Testes

```bash
godot --headless --path . --script res://tests/run_tests.gd
# fluxo base -> masmorra -> base:
godot --headless --path . --script res://tests/flow_hub.gd
# foto de todos os inimigos lado a lado (precisa de tela):
godot --path . --script res://tests/shot_bestiary.gd -- shot=/caminho/foto.png
# robô indo a um Covil Furioso em todo andar:
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=mateira seed=44 den
# robô jogando uma run inteira (pega erros e dá noção de dificuldade):
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=icamiaba seed=123
# só o chefe (pula para o 5º andar com as outras salas limpas):
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=mateira seed=7 floor=5 boss_only
```

## Ordem do método

recon ✓ → entrepreneur (preliminar) → architect ✓ → design → build → test → diff → brand → launch → deploy

Detalhes da arquitetura e da ordem de construção em `replica/architecture.md`.
