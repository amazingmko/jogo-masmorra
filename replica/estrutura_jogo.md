# Estrutura do jogo: hub e portais por bioma (ideia da Samantha, 24/10/2026)

O jogo não fica só na Amazônia: será feito com vários biomas do Brasil e talvez expanda para fora
do país. O nome do jogo ainda não está definido (não amarrar o nome a um bioma só).

## Como se desenha
- **Hub com portais**: cada portal leva o nome de uma região (ex.: "Terra Firme") e as que forem
  criadas depois. O grupo (até 4) se forma no hub e entra junto no portal para farmar os itens
  daquela região.
- **Itens por região**: cada região tem os seus reagentes/itens próprios; ir a um portal é escolher
  o que farmar.

## Hierarquia (proposta para nomear sem confusão)
- Mundo/país (Brasil; depois, fora) > Bioma (Amazônia, Cerrado, Caatinga...) > Região/zona
  (Terra Firme, Várzea e Igapó, Cidade das Urnas). Um portal por região, agrupados por bioma.

## Recomendações (a aprovar)
1. Portal por região, agrupado por bioma no hub; região seguinte libera ao vencer o chefe da
   anterior (no Normal). Portais ainda fechados aparecem com silhueta e o que falta para abrir.
2. Receitas que misturam reagentes de regiões diferentes, para valer a pena voltar às regiões
   antigas (e dar motivo para grupos farmarem juntos).
3. No multiplayer: o saguão é o grupo; o anfitrião escolhe o portal e a dificuldade; todos veem.
4. Começar com o painel de portais (UI) e, mais tarde, portais como arcos 3D no hub (cada um com a
   cara do seu bioma).
5. Lançar com a Amazônia completa; os outros biomas entram como atualizações.

Ver também: replica/mundo_amazonia.md (zonas da Amazônia) e replica/multiplayer.md.

## Online com busca por função (ideia da Samantha, 24/10/2026)
- No futuro o jogo será online, com busca de partida por função, sozinho ou já em grupo
  (como a busca de masmorra de MMORPG).
- Composição para entrar: **2 DPS** (inteligência ou agilidade), **1 healer/suporte** e **1 tank**.
- O grupo escolhe o mundo/região e entra para farmar.
- Consequência para os talentos: cada jogador entra com uma especialização ativa (a função
  dele na fila). Ver a proposta de "uma especialização ativa por vez" (talentos estilo WoW).
- Técnico: hoje o multijogador é na mesma rede Wi-Fi (anfitrião no celular). Online pede um
  servidor (de partida e de fila) e conta de jogador; planejar quando o 1º mundo estiver pronto.

## Economia e progressão (aprovado em 24/10/2026; números em game/scripts/systems/economy.gd)
- Bicho comum: só ouro (sobe com a dificuldade; igual com ou sem energia). Furioso: ouro ×3 e 12% de
  chance de reagente. Mini-chefe e chefe: reagentes garantidos. Baús: alguns reagentes.
- Reagente que sobra pode ser vendido (Comum 2, Raro 6, Épico 15, Lendário 40 de ouro cada);
  o detalhe mostra "Usado em". Fabricar custa ouro (Comum 20, Raro 80, Épico 250, Lendário 800).
- Proteção contra azar: cada vitória no chefe sem o troféu mais raro soma +10% de chance na próxima.
- Dificuldade abre por conjunto mínimo (não mais por soma de Poder): Difícil = 6 peças Comuns,
  Heroico = 6 Raras, Mítico = 6 Épicas, e vencer a anterior. O Poder fica só como número.
- Reagente de cada raridade preso à dificuldade: Pena de Arara (peças Raras) só do Difícil para
  cima; Pelo de Mapinguari (Épicas) do Heroico; Muiraquitã (Lendárias) só no Mítico.
- Grupo: cada jogador precisa cumprir o requisito (a sala mostra ✓/✗; Começar só libera quando todos
  podem); Sincronia de Poder (dentro da masmorra, peça acima da raridade da dificuldade vale como
  ela); reagentes do chefe só para quem participou da luta; Mentor: +25% de ouro em grupo com
  alguém 5+ níveis abaixo. Itens e reagentes ficam com quem pegou (não há troca).
- Provações do Folclore (feito): nos níveis 10/20/30 o herói para (barra cheia) até vencer a
  prova dele, sozinho, numa clareira fechada de 60 s. Entrar é grátis, mas precisa ter o ouro
  (500/2000/6000), cobrado só na 1ª vitória; 1 a 3 estrelas, dá para repetir. Bichos da prova não
  dão XP nem ouro. Icamiaba: A Muralha da Aldeia (defender o totem). Mateira: A Caçada (10
  acertos no macaco-prego que foge e pula). Encantado: A Cheia (só as ilhas são seguras e mudam a
  cada 12 s). Druida: O Viveiro (3 de 5 mudas vivas; a cura dele cura as mudas por perto).
  Save antigo: herói já acima do teto conta como vencida.
- Bônus semanal do chefe: não feito (depende do relógio do celular, que dá para burlar).
