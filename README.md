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
- **Quadro de Heróis** — trocar de herói (Icamiaba: força/placa · Mateira: agilidade/couro · Encantado do Rio: inteligência/tecido)
- **Oficina dos Artesãos** — fabricar equipamento e garrafadas

### Crafting (Oficina dos Artesãos)

Nada de equipamento cai nas masmorras: **tudo é fabricado**. Cada profissão sobe do nível 1 ao 100 fabricando.

| profissão | fabrica | reagentes principais |
| --- | --- | --- |
| Ferreiro | espada e armadura de placa | Minério de Ferro, Madeira de Lei |
| Curtidor | arco e armadura de couro | Couro de Jacaré, Látex de Seringueira, Madeira de Lei |
| Tecelã | cajado e armadura de tecido | Fibra de Tucum, Látex de Seringueira, Madeira de Lei |
| Erveira | Garrafada de Cura | Óleo de Andiroba |

Cada peça tem uma **cadeia de raridade**: a Rara pede a peça Comum, a Épica pede a Rara, a Lendária pede a Épica.

| raridade | chance base | nível de profissão | nível de item | reagentes extras |
| --- | --- | --- | --- | --- |
| Comum | 90% | 1 | 5 | — |
| Raro | 65% | 5 | 10 | 3× a Comum + Pena de Arara |
| Épico | 40% | 20 | 16 | 6× + Pena + **Pelo de Mapinguari** (chefe) |
| Lendário | 15% | 40 | 24 | 10× + Pena + Pelo + **Muiraquitã** (chefe no Mítico) |

- A chance sobe +1% (Comum/Raro) ou +0,5% (Épico/Lendário) por nível de profissão acima do exigido, e **+10% por falha seguida** na mesma receita (zera ao acertar). Teto: 95%.
- **Na falha:** perde metade dos reagentes, a peça-base volta e a profissão ganha 30% da XP.
- Se a peça-base estava vestida, a peça nova é vestida no lugar dela.

### Dificuldades e energia

| dificuldade | inimigos (vida / dano) | XP | reagentes | para liberar |
| --- | --- | --- | --- | --- |
| Normal | ×1 / ×1 | ×1 | ×1 | — |
| Difícil | ×1,8 / ×1,5 | ×2 | ×1,5 | vencer o Normal + nível de item médio 8 |
| Heroico | ×3,2 / ×2,2 | ×4 | ×2 | vencer o Difícil + nível de item médio 12 |
| Mítico | ×5,6 / ×3,2 | ×8 | ×3 + Muiraquitã | vencer o Heroico + nível de item médio 16 |

Em dificuldades maiores os inimigos também ficam mais agressivos. O nível de item médio é a média das 6 peças vestidas (slot vazio conta 0).

**Energia:** até 5, recarrega 1 por hora. Jogar é sempre liberado; gastar 1 energia faz a run render a recompensa completa. Sem energia, a run rende 35% dos reagentes e nenhum troféu do chefe (XP não muda). Os números ficam em `game/scripts/systems/difficulty.gd` e `crafting.gd`.

### A run

A **Terra Firme**: 5 andares de mata fechada gerados aleatoriamente. Nas salas de combate as portas fecham até o último inimigo cair. Baús (amarelo no minimapa) dão reagentes, a fonte (verde) cura, o portal azul leva ao próximo andar depois de escolher 1 entre 3 bênçãos. No 5º andar, o Mapinguari, que deixa muitos reagentes e o Pelo de Mapinguari. XP e reagentes ficam com o herói, mesmo perdendo.

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

**Mapinguari, por fases:** Garras, **Bocarra do Ventre** (se acertar, ele **recupera vida**) e **Investida Devastadora** → abaixo de 85%: **Olhar dos Cinco Olhos** (5 disparos em leque, um por olho) → abaixo de 75%: **Estouro de Queixadas** (o bando chega correndo) → abaixo de 70%: **Fedor do Mapinguari** (nuvens venenosas que ficam no chão) → abaixo de 60%: **Grito Estrondoso** (área grande em volta dele: quem estiver dentro fica **com medo**, sem andar nem atacar) e **Árvores Derrubadas** → abaixo de 45%: **Bafo do Mapinguari** (a sala inteira; só as zonas verdes são seguras; envenena) → abaixo de 30%: **enfurecido**.

**Medo** (efeito novo): o herói não anda nem ataca por um instante. Aparece como "Com medo" na tela.

| ação | PC | celular / mouse |
| --- | --- | --- |
| andar | WASD ou setas | arrastar na metade esquerda da tela (joystick) |
| atacar (mira sozinho) | segurar Espaço ou J | segurar o botão ATACAR |
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
# robô jogando uma run inteira (pega erros e dá noção de dificuldade):
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=icamiaba seed=123
# só o chefe (pula para o 5º andar com as outras salas limpas):
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=mateira seed=7 floor=5 boss_only
```

## Ordem do método

recon ✓ → entrepreneur (preliminar) → architect ✓ → design → build → test → diff → brand → launch → deploy

Detalhes da arquitetura e da ordem de construção em `replica/architecture.md`.
