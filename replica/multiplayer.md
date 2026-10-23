# Multiplayer (plano técnico)

Objetivo: até 4 jogadores na mesma masmorra, primeiro na mesma rede Wi-Fi (sem servidor na
internet), com dificuldade maior que no solo. Depois, internet.

## Arquitetura

- **Anfitrião com autoridade.** Um celular cria a partida e roda a "verdade": geração do andar,
  inimigos, dano, loot, portas, baús, portal. Os outros só mandam os comandos (andar, atacar,
  habilidade, ultimate) e recebem o estado.
- **Rede do Godot**: `ENetMultiplayerPeer` (UDP) + `MultiplayerSpawner` / `MultiplayerSynchronizer`
  e RPCs. Porta fixa (ex.: 7777).
- **Achar a partida no Wi-Fi**: o anfitrião anuncia por broadcast UDP (porta 7778) a cada segundo
  "nome, herói, vagas"; o convidado lista o que ouve e entra com um toque (sem digitar IP).
  Opção de digitar o IP como reserva.
- **Mesmo mapa em todos**: o anfitrião manda a semente do andar; cada aparelho monta o mesmo
  cenário localmente (o gerador já é determinístico pela semente). Só o que muda viaja pela rede.

## O que viaja pela rede

| Coisa | Como |
|---|---|
| Heróis | posição/direção/animação a ~20 por segundo (interpolado); quem controla é o dono |
| Comandos do convidado | RPC para o anfitrião: movimento (a cada quadro), atacar, habilidade, ultimate |
| Inimigos | criados pelo anfitrião (spawner); posição/estado/vida a ~15 por segundo, interpolado |
| Ataques dos inimigos | RPC "aviso começou" (forma, posição, tempo) — cada aparelho desenha o aviso |
| Dano / morte | RPC com o número (cada aparelho mostra o número e o efeito) |
| Habilidades | RPC "usou X em Y" — cada aparelho toca o efeito; o anfitrião aplica o resultado |
| Portas, baús, portal, acampamento | RPC de estado |
| Loot | **separado por jogador**: cada um vê e pega o seu (sem briga por item) |

## Mudanças no código atual

- O jogo hoje supõe **um** herói em ~10 lugares (`get_first_node_in_group("player")`, `_player`
  em `main.gd`/`enemy.gd`/`telegraph.gd`/`loot_pickup.gd`). Vira "herói mais perto / alvo
  escolhido" (`Players.nearest(pos)`, `Players.all()`).
- Inimigos escolhem alvo: mais perto, quem provocou (Icamiaba), ou quem bateu mais.
- Avisos no chão e ataques acertam **qualquer** herói dentro da área.
- Câmera e HUD seguem o herói local.
- Morte: herói caído pode ser **revivido** por um parceiro (segurar perto dele 3 s). A partida
  só acaba se todos caírem.
- Portal/porta de sala: a sala fecha quando o primeiro entra; quem ficar fora é puxado para
  dentro (evita alguém preso do lado de fora).

## Dificuldade por número de jogadores

| Jogadores | Vida dos inimigos | Dano | Bichos por onda | Chance de furioso |
|---|---|---|---|---|
| 1 | 100% | 100% | 100% | base |
| 2 | 170% | 115% | 140% | +10 pp |
| 3 | 240% | 125% | 175% | +15 pp |
| 4 | 310% | 135% | 210% | +20 pp |

Chefes: +90% de vida por jogador extra. Recompensa por jogador igual ao solo (cada um ganha o seu).

## Ordem de construção (fatias testáveis)

1. **Saguão**: criar partida / achar partida no Wi-Fi / entrar; escolher herói; "pronto".
2. **Andar compartilhado**: semente, os heróis andando juntos (sem inimigos).
3. **Inimigos e combate**: anfitrião controla; ataques e dano sincronizados; alvo por herói.
4. **Habilidades e efeitos** dos 4 heróis na rede.
5. **Portas, baús, loot por jogador, portal, acampamento, noite**.
6. **Cair e reviver**, fim da partida, dificuldade por número de jogadores.

Cada fatia é testada aqui rodando **2 a 4 jogos ao mesmo tempo na máquina** (um anfitrião e
convidados) com testes automáticos que conferem se todos veem o mesmo; depois APK para o teste
no Wi-Fi.
