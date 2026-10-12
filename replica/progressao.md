# Progressão, equipamento e crafting

Decisões da autora (12/10/2026) e números iniciais. Os números serão calibrados com a planilha de economia e com testes jogando.

**Decidido:** energia de recompensa (opção B, seção 7) · regras de falha no crafting (seção 6) · Druida e Vampiro em couro/agilidade · pet de energia (seção 8).

**Construção:** fase 4a = seções 2–5 e 9 (atributos, armaduras, raridades, itens, nível, hub) · fase 4b = seções 1, 6 e 7 (dificuldades, crafting, energia).

## 1. Níveis de dificuldade

| dificuldade | vida dos inimigos | dano dos inimigos | nível de item que cai | para liberar |
| --- | --- | --- | --- | --- |
| **Normal** | 100% | 100% | 1–10 | — |
| **Difícil** | 180% | 150% | 11–20 | vencer o Normal + nível de item médio 8 |
| **Heroico** | 320% | 220% | 21–30 | vencer o Difícil + nível de item médio 18 |
| **Mítico** | 560% | 320% | 31–40 | vencer o Heroico + nível de item médio 28 |

O "nível de item médio" é a média do equipamento vestido. Como os melhores itens vêm do crafting (seção 6), **o crafting é a chave para subir de dificuldade**, como a autora pediu.

## 2. Raridades

| raridade | cor | poder do item | como se consegue |
| --- | --- | --- | --- |
| **Comum** | `#D9D4E6` (branco/cinza) | 100% | drop frequente, crafting fácil |
| **Raro** | `#4DA3FF` (azul) | 130% | drop ocasional, crafting médio |
| **Épico** | `#C06BFF` (roxo) | 170% | drop raro de chefe, crafting difícil |
| **Lendário** | `#FFA53D` (laranja) | 220% | **só por crafting**, com material de chefe Mítico |

O "Incomum" (verde) sai do jogo.

## 3. Atributos

Hoje os números são pequenos (vida 8, dano 6). Para os itens terem espaço para crescer como num MMORPG, a proposta é **multiplicar a escala por ~10**: vida em centenas, dano em dezenas.

**Primários** (cada classe usa um):

| atributo | efeito | classes |
| --- | --- | --- |
| **Força** | +1% de dano por ponto (classes de força) | Guerreiro, Berserker |
| **Agilidade** | +1% de dano por ponto (classes de agilidade) | Ladino, Ranger, Druida*, Vampiro* |
| **Inteligência** | +1% de dano por ponto (classes de inteligência) | Mago, Sacerdote |

**Gerais:** **Vigor** (+10 de vida por ponto) e **Armadura** (reduz o dano recebido; vem principalmente do tipo de armadura).

**Secundários** (aparecem a partir do Raro): **Crítico** (chance de dano dobrado), **Aceleração** (ataques e recargas mais rápidos), **Sorte** (mais recursos no fim da masmorra).

\* Druida e Vampiro: agilidade e couro (decidido).

## 4. Tipos de armadura e slots

| atributo | armadura | armadura base | quem usa |
| --- | --- | --- | --- |
| Inteligência | **Tecido** | baixa | Mago, Sacerdote |
| Agilidade | **Couro** | média | Ladino, Ranger, Druida, Vampiro |
| Força | **Placa** | alta | Guerreiro, Berserker |

**Slots (6):** arma, cabeça, peito, mãos, pernas, pés. Mais tarde: anel e amuleto, que servem para todos.

Um herói só veste o próprio tipo de armadura. Armas também são por classe (espada e escudo, machado, adagas, arco, cajado, maça...).

## 5. Nível do herói

- Do nível 1 ao **40**. Cada nível dá +2 no atributo primário e +1 em vigor, e a cada 5 níveis libera um ponto de talento (talentos ficam para uma fase posterior).
- XP vem de inimigos, salas limpas e do chefe, e é multiplicada pela dificuldade (Difícil ×2, Heroico ×4, Mítico ×8).
- **Mesmo perdendo, a run dá a XP já ganha.**
- Curva: o próximo nível pede 15% a mais de XP que o anterior. Meta de ritmo: nível 10 em ~1 semana de jogo casual; nível 40 em ~2 meses.

## 6. Crafting (crucial e difícil)

**Profissões** (cada uma com nível de 1 a 100, que sobe craftando):

| profissão | faz |
| --- | --- |
| Ferreiro | armadura de placa e armas de metal |
| Coureiro | armadura de couro, arcos |
| Alfaiate | armadura de tecido |
| Alquimista | poções e frascos (bônus para uma run) |
| Joalheiro (depois) | anéis e amuletos |

**Chance de sucesso:**

| raridade | chance base | + por nível de profissão acima do exigido |
| --- | --- | --- |
| Comum | 90% | +1% |
| Raro | 65% | +1% |
| Épico | 40% | +0,5% |
| Lendário | 15% | +0,5% |

Somam-se os bônus de pets e de poções do Alquimista (limite de 95%).

**Regras da falha (decidido):**
- a falha consome **metade** dos materiais (a outra metade volta);
- cada falha seguida na mesma receita dá **+10%** na próxima tentativa (zera ao acertar);
- a falha ainda dá **um pouco de XP** de profissão.

## 7. Energia — decidido: opção B (energia de recompensa)

A autora propôs energia que recarrega a cada hora, para limitar quantas vezes se entra nas masmorras. Um alerta honesto: na pesquisa (`fixes-preliminar.md`), **limite de energia foi uma das reclamações mais citadas** no Guild of Guardians, e o recon tinha marcado energia como algo a não ter. O ritmo lento é um bom objetivo; a questão é **o que** limitar.

| opção | como funciona | vantagem | risco |
| --- | --- | --- | --- |
| **A. Energia para entrar** (proposta da autora) | máx. 5, +1 por hora; cada run gasta 1 | limita de forma clara | o jogador quer jogar e não pode; é o padrão mais criticado |
| **B. Energia de recompensa** (recomendada) | jogar é ilimitado; com energia, a run dá **recursos de crafting completos**; sem energia, dá XP e loot comum reduzido | o recurso raro continua limitado (o crafting fica lento), mas ninguém é impedido de jogar | precisa explicar bem na tela |
| **C. Baú do chefe com limite** | o baú do chefe (onde vêm os materiais raros) só abre X vezes por dia | parecido com os "travamentos" semanais de MMORPG | ritmo depende só do chefe |

**Minha recomendação é a B**: mantém a progressão lenta onde importa (os materiais de crafting) sem bloquear quem quer jogar mais um pouco, e conversa com a ideia original de que toda run rende algum avanço.

Seja qual for a escolha, a recomendação é **nunca vender energia com dinheiro real**, porque é o caminho mais curto para o "pague para ganhar" criticado nos dois jogos.

## 8. Pets (fase futura — ideias para ir pensando)

Os pets acompanham na masmorra, têm raridade e sobem de nível com o uso. Cada um dá **um bônus principal**:

| pet (nome provisório) | bônus | para quem |
| --- | --- | --- |
| Raposa Farejadora | +recursos no fim da masmorra | quem quer acelerar o crafting |
| Coruja Sábia | +chance de sucesso no crafting | artesãos |
| Mula de Carga | +1 item extra no baú do chefe | caçadores de loot |
| Gato Preto | +sorte (mais crítico e drops raros) | quem joga no limite |
| Golem de Bolso | absorve um golpe a cada 20 s | heróis frágeis |
| Fada da Fonte | cura um pouco ao limpar uma sala | runs longas |
| Morcego | pequeno roubo de vida | combate agressivo |
| Besouro Minerador | chance de minério extra por inimigo | ferreiros |
| Vaga-lume Incansável | energia recarrega mais rápido, ou +2 de energia máxima por dia (ideia da autora) | quem joga muitas runs |

A escolha do pet vira uma decisão de estratégia: ir atrás de recursos ou de chance de crafting.

## 9. Hub (a base entre as runs)

Uma vila ou acampamento em 3D, por onde o herói anda:

| ponto | função |
| --- | --- |
| **Portal da masmorra** | escolher a dificuldade e começar a run |
| **Baú pessoal** | inventário e equipar itens |
| **Artesãos (NPCs)** | um por profissão: craftar, ver receitas e chance de sucesso |
| **Quadro de heróis** | trocar de herói, ver nível e atributos |
| **Mestre dos pets** (futuro) | escolher e evoluir pets |
| **Mercador** (futuro) | vender sobras e comprar materiais básicos |

## 10. Ordem sugerida de construção

1. Escala de números ×10, atributos e tipos de armadura nos heróis e itens
2. Raridades novas e itens com atributos gerados (drop com nível de item)
3. Hub com baú/inventário e tela de equipamento
4. Nível do herói e XP
5. Artesãos, profissões e crafting com chance de falha
6. Dificuldades com requisitos de liberação
7. Energia (conforme a decisão da seção 7)
8. Planilha de economia para calibrar tudo; depois, pets

## Pendências

- [x] Druida e Vampiro em couro/agilidade
- [x] Regras de falha no crafting
- [x] Energia: opção B
- [ ] Calibrar números com a planilha de economia (depois da fase 4b)
