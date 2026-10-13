# Jogo de masmorra (nome provisório)

Jogo mobile 3D low-poly de exploração de masmorras, com heróis de classe e elemento, itens que caem nas masmorras, crafting e runs roguelite em tempo real. Inspirado nas mecânicas de Soul Knight e da versão ARPG do Guild of Guardians, sem usar arte, personagens, nomes ou textos deles.

Feito em **Godot 4.7.2 (Standard, GDScript)**.

## Como abrir

1. Abra o Godot e clique em **Importar** (Import).
2. Escolha o arquivo `project.godot` desta pasta.
3. Clique em **Importar e Editar**. Na primeira vez o Godot leva alguns segundos preparando os arquivos.
4. Aperte **F5** (ou o botão ▶ no canto superior direito) para jogar.

### Base (hub) — fase 4a

O jogo abre na base. Ande até um ponto e toque no botão azul (PC: **E**):

- **Portal da Masmorra** — começa a run (por enquanto só Normal)
- **Baú e Equipamento** — vestir e tirar peças, ver atributos e materiais
- **Quadro de Heróis** — trocar de herói (Guardião: força/placa · Batedora: agilidade/couro · Arcanista: inteligência/tecido)
- **Artesão** — crafting chega na fase 4b

### A run

5 andares gerados aleatoriamente. Nas salas de combate as portas fecham até o último inimigo cair. Baús (amarelo no minimapa) dão loot, a fonte (verde) cura, o portal azul leva ao próximo andar depois de escolher 1 entre 3 bênçãos. No 5º andar, o Rei Ossudo. Inimigos e baús deixam cair **equipamento com raridade (Comum, Raro, Épico), nível de item e atributos**; metade das peças vem no tipo de armadura do herói atual. Todo loot e XP ficam com o herói, mesmo perdendo.

### Inimigos

Todo ataque inimigo mostra um **aviso no chão** antes de acontecer (o preenchimento cresce até o impacto): saia da área para desviar. Cada inimigo tem vários ataques, editáveis em `game/data/enemies/` (lista "Ataques" no Inspector).

O movimento é sorteado a cada fração de segundo entre manobras (ir direto, arco pelo lado, arrancada, finta, pulo lateral, rodear, recuar), sempre puxando para o herói. Quanto mais tempo um inimigo fica sem atacar, mais agressivo ele fica. Cada inimigo também nasce com velocidade e agressividade levemente diferentes.

| inimigo | aparece | estilo |
| --- | --- | --- |
| Esqueleto | andar 1+ | avança em arcos e arrancadas; golpe em cone e estocada |
| Rato Gigante | andar 1+ | manobras curtas e nervosas, fintas; mordida e salto |
| Esqueleto Arqueiro | andar 1+ | mantém distância; flecha e leque de 3 |
| Aranha da Cripta | andar 2+ | picada **venenosa** e cuspe que deixa poça |
| Xamã de Ossos | andar 3+ | **raízes** que prendem, raio e nuvem tóxica |
| Esqueleto Bruto | andar 3+ | esmagar em área e investida longa |
| **Rei Ossudo** (chefe) | andar 5 | varredura e investida → abaixo de 85%: invoca esqueletos → abaixo de 60%: onda de ossos e espinhos → abaixo de 45%: **Juízo do Rei** (a sala inteira; só as luzes verdes são seguras) → abaixo de 30%: **enfurecido** |

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
  data/          dados do jogo — itens, heróis, drops, receitas, profissões, buffs (.tres)
  scripts/       moldes de dados, regras (inventário, itens, atributos, XP, drop, crafting, save),
                 combate, masmorra (planta, salas, baús/fonte/portal), hub, jogabilidade e interface
  scenes/        cenas
tests/           testes automáticos das regras e simulação de combate
tools/           script que gerou os dados de exemplo
replica/         documentos do método e de design: recon, matriz de features, arquitetura,
                 direção de arte e progressão
.claude/ .kiro/  skills do replica-skill
```

Para criar um item novo: no painel **FileSystem** do Godot, abra `game/data/items/`, clique com o botão direito num item, **Duplicar**, e mude os campos no **Inspector**. Faça o mesmo para receitas e tabelas de drop.

## Testes

```bash
godot --headless --path . --script res://tests/run_tests.gd
# fluxo base -> masmorra -> base:
godot --headless --path . --script res://tests/flow_hub.gd
# robô jogando uma run inteira (pega erros e dá noção de dificuldade):
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=guardiao seed=123
# só o chefe (pula para o 5º andar com as outras salas limpas):
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=batedora seed=7 floor=5 boss_only
```

## Ordem do método

recon ✓ → entrepreneur (preliminar) → architect ✓ → design → build → test → diff → brand → launch → deploy

Detalhes da arquitetura e da ordem de construção em `replica/architecture.md`.
