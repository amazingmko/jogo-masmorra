# Jogo de masmorra (nome provisório)

Jogo mobile 3D low-poly de exploração de masmorras, com heróis de classe e elemento, itens que caem nas masmorras, crafting e runs roguelite em tempo real. Inspirado nas mecânicas de Soul Knight e da versão ARPG do Guild of Guardians, sem usar arte, personagens, nomes ou textos deles.

Feito em **Godot 4.7.2 (Standard, GDScript)**.

## Como abrir

1. Abra o Godot e clique em **Importar** (Import).
2. Escolha o arquivo `project.godot` desta pasta.
3. Clique em **Importar e Editar**. Na primeira vez o Godot leva alguns segundos preparando os arquivos.
4. Aperte **F5** (ou o botão ▶ no canto superior direito) para jogar.

### Como é uma run (fase 3)

5 andares gerados aleatoriamente. Em cada andar: entre nas salas; nas de combate as portas fecham até o último inimigo cair. Baús (amarelo no minimapa) dão loot, a fonte (verde) cura, e o portal azul leva ao próximo andar depois de escolher 1 entre 3 bênçãos (buffs). No 5º andar o Rei Ossudo espera na sala mais distante (vermelho). Todo loot vai para o inventário na hora, então até uma derrota rende progresso.

| ação | PC | celular / mouse |
| --- | --- | --- |
| andar | WASD ou setas | arrastar na metade esquerda da tela (joystick) |
| atacar (mira sozinho) | segurar Espaço ou J | segurar o botão ATACAR |
| trocar herói | 1 Guardião · 2 Batedora · 3 Arcanista | — |
| nova run | R | botão Nova run |
| forjar espada / salvar | C / G | — |

## Estrutura

```
game/
  autoload/      sistemas globais: ItemDB (catálogo), GameState (progresso), SaveSystem
  data/          dados do jogo — itens, heróis, drops, receitas, profissões, buffs (.tres)
  scripts/       moldes de dados, regras (inventário, drop, crafting, save), combate,
                 masmorra (planta, salas, baús/fonte/portal), jogabilidade e interface
  scenes/        cenas
tests/           testes automáticos das regras e simulação de combate
tools/           script que gerou os dados de exemplo
replica/         documentos do método: recon, matriz de features, arquitetura
.claude/ .kiro/  skills do replica-skill
```

Para criar um item novo: no painel **FileSystem** do Godot, abra `game/data/items/`, clique com o botão direito num item, **Duplicar**, e mude os campos no **Inspector**. Faça o mesmo para receitas e tabelas de drop.

## Testes

```bash
godot --headless --path . --script res://tests/run_tests.gd
# robô jogando uma run inteira (pega erros e dá noção de dificuldade):
godot --headless --fixed-fps 60 --path . --script res://tests/sim_run.gd -- hero=guardiao seed=123
```

## Ordem do método

recon ✓ → entrepreneur (preliminar) → architect ✓ → design → build → test → diff → brand → launch → deploy

Detalhes da arquitetura e da ordem de construção em `replica/architecture.md`.
