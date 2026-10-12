# Arquitetura: jogo de masmorra 3D (nome provisório)

O método do replica-architect foi pensado para apps web (banco SQL, API, servidor). Um jogo mobile offline não precisa de nada disso no começo. Por isso a estrutura abaixo segue as mesmas perguntas do método (que tecnologia, onde ficam os dados, quais as partes de risco, em que ordem construir), mas com respostas de jogo.

## Tecnologia

| camada | escolha | por quê |
| --- | --- | --- |
| engine | **Godot 4.7.2 (Standard)** | gratuita, sem taxa sobre faturamento, exporta app nativo para Android e iOS, editor 3D visual |
| linguagem | **GDScript** | linguagem própria do Godot, parecida com Python, mais documentação e exportação mobile mais simples que C# |
| renderizador | **Mobile** | feito para celular; o modo "Forward+" é pesado demais para aparelhos simples |
| arte | **pacotes low-poly CC0** (KayKit, Kenney, Quaternius) e depois arte própria | licença livre para uso comercial, animações prontas |
| dados do jogo | **Resources do Godot** (arquivos `.tres`) | itens, heróis, receitas e drops editáveis no próprio editor, sem programar |
| progresso do jogador | **arquivo de save local** (JSON) com gravação segura e backup | joga offline; resolve a reclamação nº 1 dos dois jogos de referência (save perdido) |
| servidor | **nenhum por enquanto** | backup na nuvem entra depois (Google Play Games / iCloud ou um backend simples) |
| versionamento | **GitHub** (`amazingmko/jogo-masmorra`) | histórico, e qualquer conversa ou IDE continua de onde parou |

## Pastas do projeto

```
project.godot              configuração do Godot
game/
  autoload/                sistemas globais, sempre carregados
    item_db.gd             catálogo: lê todos os itens, receitas, drops...
    game_state.gd          estado do jogador em memória (inventário, moedas, profissões)
    save_system.gd         grava e carrega o progresso
  data/                    DADOS do jogo (editáveis no Inspector do Godot)
    items/  heroes/  drop_tables/  recipes/  professions/  buffs/
  scripts/
    resources/             o "molde" de cada tipo de dado (ItemData, HeroData...)
    systems/               regras puras: inventário, sorteio de drop, crafting, arquivo de save
    gameplay/              código de cena: jogador, câmera
  scenes/                  cenas (.tscn)
tests/                     testes automáticos das regras
tools/                     scripts de apoio (gerar dados de exemplo)
replica/                   documentos do método (recon, matriz, esta arquitetura)
```

A separação mais importante: **dados** (`game/data/`) ficam separados de **regras** (`game/scripts/systems/`). Para criar uma espada nova, você não programa: duplica um item no editor e muda os números.

## Modelo de dados

São dois tipos de informação:

**1. Moldes (fixos, fazem parte do jogo)** — ficam em `.tres`:

| molde | campos principais | uso |
| --- | --- | --- |
| `ItemData` | id, nome, tipo (material, arma, armadura, acessório, consumível), raridade, faixa de poder (tier), máximo por pilha, atributos | todo item do jogo |
| `HeroData` | id, nome, classe (tank, ranger, mago), elemento, vida, armadura, energia, velocidade, crítico | heróis jogáveis |
| `DropEntry` / `DropTable` | item, peso (chance relativa), quantidade mín/máx; nº de sorteios, peso de "nada" | o que cada inimigo, chefe ou baú deixa cair |
| `RecipeData` | item resultante, ingredientes, profissão exigida, nível mínimo, XP ganho | crafting |
| `ProfessionData` | id, nome, nível máximo, curva de XP | profissões (fase posterior, mas o molde já existe) |
| `BuffData` | id, nome, atributo afetado, valor, modo (somar/multiplicar) | buffs escolhidos entre fases |

Elementos e classes ficam centralizados em `GameEnums` (um único lugar para mudar).

**2. Progresso (muda com o jogo)** — fica no save:

```
versão do save
moedas permanentes
inventário: materiais empilhados {id: quantidade} + equipamentos únicos [{uid, id, nível, atributos}]
heróis desbloqueados e nível de cada um
profissões: {id: {nível, xp}}
run em andamento (para continuar se o app fechar)
```

Equipamento é guardado como "instância" (cada espada tem um `uid` próprio), porque no futuro duas espadas iguais podem ter atributos diferentes.

## Sistemas (no lugar da "API" do método)

| sistema | faz | quem chama | fluxo |
| --- | --- | --- | --- |
| `ItemDB.get_item(id)` | devolve o molde de um item | todo o jogo | todos |
| `DropTable.roll(rng)` | sorteia o loot | inimigo morrendo, baú abrindo | F01, F04 |
| `Inventory.add / remove / has` | guarda e consome itens | loot, crafting, loja | F01, F06 |
| `Crafting.craft(receita, ...)` | confere ingredientes e profissão, consome e entrega o item, dá XP | tela de forja | F06 |
| `SaveFile.write / read` | grava com segurança e recupera do backup se corromper | `GameState` | todos |
| `GameState` | guarda o progresso e salva sozinho ao pausar/fechar o app | todo o jogo | todos |

## As partes que podem dar problema

- **Save corrompido ou perdido.** A gravação é feita em arquivo temporário e só depois troca o principal, mantendo uma cópia de backup. Se o principal corromper, o jogo carrega o backup. O save também é gravado quando o app vai para segundo plano (no celular, o sistema pode fechar o app sem aviso).
- **Desempenho no celular.** Renderizador Mobile, modelos low-poly, poucas luzes dinâmicas e limite de inimigos simultâneos por sala. Testar cedo num Android simples.
- **Sorteio reproduzível.** Toda run tem uma "semente" (seed). Com a mesma semente, a mesma masmorra e os mesmos drops — essencial para reproduzir bugs.
- **Movimento independente de FPS.** Todo movimento usa o tempo do quadro (`delta`), para o jogo ter a mesma velocidade em aparelhos rápidos e lentos.
- **Controles de toque.** Joystick virtual e botões grandes o bastante para o polegar. É a parte que mais define se o combate é gostoso.
- **Mudança de versão do save.** O save tem número de versão desde o primeiro dia, para que atualizações futuras convertam saves antigos em vez de apagá-los.
- **Balanceamento.** Os números (drop, XP, custo de receitas) vão sair da planilha de economia, não de chute.

## Ordem de construção

1. **Fundação (este passo):** projeto Godot, moldes de dados, inventário, drops, crafting, save seguro, testes automáticos e uma cena 3D de teste (andar com o teclado, sortear loot, craftar).
2. **Protótipo de combate:** joystick de toque, ataque com auto-mira, um inimigo, dano e morte. Telas: S05. Só avança quando estiver gostoso.
3. **Primeira run:** geração de salas, 5 fases, chefe, buffs, baús, resumo. Telas: S05, S06, S07, S09, S11, S12, S20.
4. **Progressão (must da matriz):** hub, seleção de herói, 3 classes, evolução com moeda. Telas: S02, S03, S13.
5. **Itens e crafting (should):** equipamento, raridade, elementos, forja. Telas: S14, S15.
6. **Profissões e o restante dos should/could.**
7. **Correções do replica-entrepreneur** quando a análise completa de reviews rodar.

Próximo passo do método: `replica-design` (estilo visual, cores, interface) — que pode andar junto com a fase 2.
