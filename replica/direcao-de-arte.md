# Direção de arte e identidade do jogo (rascunho para a autora revisar)

## A ideia em uma frase

Um ARPG de masmorras para celular com **alma de MMORPG de fantasia épica**: muitas classes com papéis claros, progressão longa (níveis, talentos, equipamento, profissões) e masmorras cada vez mais difíceis, jogado em runs curtas.

## Inspiração e limite

A referência de **clima** é a fantasia épica estilizada dos MMORPGs (World of Warcraft é o exemplo citado): cores fortes, formas exageradas, heróis robustos, magia brilhante. Isso é um gênero, não uma propriedade.

O que **não** entra: nomes de raças, facções, personagens, lugares ou classes exclusivas de outros jogos; ícones, interface, logos e trilha sonora de terceiros; lore copiada. Classes como guerreiro, mago, sacerdote, druida, ranger, ladino, berserker e vampiro são arquétipos clássicos da fantasia e podem ser usadas livremente, com mecânicas e nomes de habilidades próprios.

## Pilares visuais

1. **Silhueta antes de detalhe.** Cada classe precisa ser reconhecível só pela sombra, vista de cima e no tamanho de um celular: escudo grande, capuz, cajado, chifres, asas, garras.
2. **Proporções heroicas.** Mãos, ombros, armas e cabeças maiores que o real; pernas mais curtas. Lê bem de longe e dá personalidade.
3. **Low-poly com cor pintada.** Poucos polígonos e cor vinda de uma única textura de paleta (gradientes), sem texturas detalhadas. Leve no celular e fácil de manter consistente.
4. **Cor conta a história.** O ambiente é mais escuro e dessaturado; heróis, inimigos, magias e loot são saturados e claros. O olho sempre acha o que importa.
5. **Magia brilha.** Efeitos de habilidade usam brilho (emissão) e partículas simples, na cor do elemento.

## Paleta proposta

| papel | cor | uso |
| --- | --- | --- |
| fundo profundo | `#1A1526` | céu, vazio, fundo da interface |
| pedra escura | `#3B3350` | paredes e chão das masmorras |
| pedra clara | `#6E6488` | detalhes, bordas, pilares |
| madeira e couro | `#8A5A3C` | portas, baús, equipamento leve |
| ouro heroico | `#E8C26A` | destaques, moldura da interface, guerreiro |
| texto claro | `#F2ECFF` | textos e ícones |
| perigo | `#E05555` | vida, aviso de golpe inimigo |

### Elementos (proposta: de 4 para 6)

Para as classes novas fazerem sentido, sugiro ampliar os elementos:

| elemento | cor | classes ligadas |
| --- | --- | --- |
| fogo | `#FF8A3D` | mago, berserker |
| gelo/água | `#4DB8FF` | mago |
| natureza | `#7FC97A` | druida, ranger |
| sombra | `#8B5CF6` | ladino, vampiro |
| sagrado | `#FFE08A` | sacerdote, guerreiro |
| neutro/físico | `#D9D4E6` | todos |

### Raridade dos itens

comum `#D9D4E6` · incomum `#6FDC7B` · raro `#4DA3FF` · épico `#C06BFF` · lendário `#FFA53D`

## Elenco de classes (proposta)

Cada classe tem um **papel**, um **recurso** próprio e uma **mecânica-assinatura** que muda o jeito de jogar.

| classe | papel | arma | recurso | mecânica-assinatura | silhueta |
| --- | --- | --- | --- | --- | --- |
| **Guerreiro** | tank | espada e escudo | fúria (sobe ao apanhar) | bloqueio frontal e provocação | escudo enorme, ombreiras |
| **Berserker** | dano corpo a corpo | machado de duas mãos | fúria (sobe ao bater) | quanto menos vida, mais dano | massivo, sem elmo, cabelo selvagem |
| **Ladino** | dano em explosão | adagas duplas | energia (recarrega rápido) | furtividade e golpe pelas costas | capuz, capa curta, curvado |
| **Ranger** | dano à distância | arco | foco | companheiro animal e armadilhas | arco longo, aljava, capuz verde |
| **Mago** | dano mágico em área | cajado | mana | combina fogo e gelo | chapéu ou capuz pontudo, cajado com cristal |
| **Sacerdote** | cura e suporte | maça e símbolo sagrado | mana | cura e escudos que salvam a run | manto longo, auréola de luz |
| **Druida** | híbrido | cajado de madeira | mana / fúria animal | troca de forma (urso, felino) | chifres de galho, manto de folhas |
| **Vampiro** | dano sustentado | garras ou lâmina curva | sangue (vem de causar dano) | roubo de vida, morcegos | colarinho alto, capa, olhos brilhantes |

Mapeamento com o protótipo atual: **Guardião → Guerreiro**, **Batedora → Ranger**, **Arcanista → Mago**.

**Recomendação de ordem:** implementar 3 classes bem feitas antes de abrir as outras (Guerreiro, Ranger e Mago, que já existem). Depois, uma por vez: Sacerdote (para testar cura num jogo solo), Ladino, Berserker, Druida e Vampiro. Cada classe nova pede modelo, animações, habilidades e balanceamento, então é melhor que entre polida do que todas pela metade.

## Progressão estilo MMORPG (como encaixa em runs)

- **Nível do herói** sobe com XP de cada run (sempre ganha algo, mesmo perdendo).
- **Talentos:** a cada nível, um ponto numa árvore com 2–3 caminhos por classe (ex.: Mago de fogo ou de gelo).
- **Equipamento com nível de item:** cada masmorra tem uma faixa de nível de item; o próximo tier pede equipamento do anterior.
- **Profissões:** ferreiro, alquimista, costureiro, encantador... craftam o que as masmorras não dão.
- **Masmorras em níveis (tiers)**, com chefes que dão os melhores itens: o "raid" vira o andar final de cada área.

## Interface

Moldura em **ouro heroico** sobre fundo escuro, cantos levemente arredondados, ícones grandes e legíveis no celular. Os tokens de cor, fonte e espaçamento da interface serão gerados com o `replica-design`, com checagem de contraste.

## Para decidir

- [ ] Nome provisório do mundo e tom da história (épico sério? com humor?)
- [ ] Concorda com os 6 elementos?
- [ ] Ajustes no elenco de classes (tirar, juntar, adicionar)?
- [ ] Proporções: heroicas e robustas (como proposto) ou mais "fofinhas"?
