# Jogo de masmorra (nome provisório)

Jogo mobile 3D low-poly de exploração de masmorras, com heróis de classe e elemento, itens que caem nas masmorras, crafting e runs roguelite em tempo real. Inspirado nas mecânicas de Soul Knight e da versão ARPG do Guild of Guardians, sem usar arte, personagens, nomes ou textos deles.

Feito em **Godot 4.7.2 (Standard, GDScript)**.

## Como abrir

1. Abra o Godot e clique em **Importar** (Import).
2. Escolha o arquivo `project.godot` desta pasta.
3. Clique em **Importar e Editar**. Na primeira vez o Godot leva alguns segundos preparando os arquivos.
4. Aperte **F5** (ou o botão ▶ no canto superior direito) para jogar a cena de teste.

Controles da cena de teste: **WASD/setas** andam · **L** sorteia o loot de um esqueleto · **C** tenta forjar uma espada · **G** salva.

## Estrutura

```
game/
  autoload/      sistemas globais: ItemDB (catálogo), GameState (progresso), SaveSystem
  data/          dados do jogo — itens, heróis, drops, receitas, profissões, buffs (.tres)
  scripts/       moldes de dados, regras (inventário, drop, crafting, save) e jogabilidade
  scenes/        cenas
tests/           testes automáticos das regras
tools/           script que gerou os dados de exemplo
replica/         documentos do método: recon, matriz de features, arquitetura
.claude/ .kiro/  skills do replica-skill
```

Para criar um item novo: no painel **FileSystem** do Godot, abra `game/data/items/`, clique com o botão direito num item, **Duplicar**, e mude os campos no **Inspector**. Faça o mesmo para receitas e tabelas de drop.

## Testes

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

## Ordem do método

recon ✓ → entrepreneur (preliminar) → architect ✓ → design → build → test → diff → brand → launch → deploy

Detalhes da arquitetura e da ordem de construção em `replica/architecture.md`.
