# Arte (arquivos de entrada)

Pastas para entregar a arte gerada com IA. O Godot ignora estas pastas (arquivo `.gdignore`):
o Claude limpa cada modelo e coloca a versão final do jogo em `game/`.

| pasta | o que vai | exemplo |
| --- | --- | --- |
| `referencias/` | a imagem escolhida de cada personagem (.png) | `icamiaba.png` |
| `bruto/` | o modelo que a IA gerou, sem mexer (.glb) | `icamiaba.glb`, `icamiaba_lanca.glb` |
| `animacoes/` | animações baixadas do Mixamo (.fbx) | `icamiaba_run.fbx` |
| `mixamo/` | cópia do modelo pronta para enviar ao Mixamo (o Claude gera) | `icamiaba.fbx` |

Nomes em minúsculas, sem acento e sem espaço (use `_`). O passo a passo completo está no
documento "Guia de arte 3D com IA".

## Já no jogo

| personagem | modelo final | triângulos | textura |
| --- | --- | --- | --- |
| Icamiaba | `game/art/herois/icamiaba.glb` (gerado na Tripo em multivisões) | 8.000 | 1024 px |

Como o Claude prepara: reduz os triângulos mantendo o mapeamento da textura (o rosto não deforma),
reduz a textura para 1024 px, coloca 1,7 m de altura com os pés no chão. Na Tripo, **não usar a
retopologia**: exportar o modelo original em GLB.

## Animações (padrão: Mixamo) e armas

Exemplo pronto: a Icamiaba. Repetir igual para os outros heróis.

1. **Modelo sem esqueleto**: o modelo reduzido do jogo (8 mil triângulos) em OBJ + textura num .zip.
2. **Mixamo** (mixamo.com, conta Adobe grátis): Upload Character → posicionar queixo, pulsos, cotovelos, joelhos e virilha → Skeleton LOD Standard.
3. Baixar as animações do pacote da arma da classe (ex.: "sword and shield"), cada uma em **FBX Binary, With Skin, 30 fps** ("In Place" quando houver), e salvar em `arte/animacoes/<heroi>/` com estes nomes:
   `parada, andar, corrida, golpe1, golpe2, golpe3 (até golpe4), impacto, bloquear, morte` e os poderes `provocar, muralha` (.fbx).
4. **Armas**: imagem (ChatGPT/Gemini) → Tripo, sem retopologia → GLB em `arte/bruto/armas/<arma>_<heroi>.glb`.
5. Preparar para o jogo (feito pelo Claude):
   - FBX → GLB: `FBX2glTF -b -i arquivo.fbx -o arquivo` (npm i fbx2gltf)
   - juntar: `node tools/mixamo_merge.mjs <pasta dos .glb> game/art/herois/<heroi>.glb [opções]` (Mateira: `armadilha=0.9:2.9 ataque1=golpe1@0.5:1.0+golpe2@0:0.45 -golpe2`, e o quadro do dano/soltura em `HeroGear.IMPACT`) (escala, nomes, sem deslocamento, material fosco; corte opcional de animações longas, ex.: Mateira `armadilha=0.9:2.9`)
   - golpes com passos (os pés patinam com o quadril travado): `node tools/hip_motion.mjs <pasta dos .glb> game/art/herois/<heroi>.glb livre=golpe1:ataque1 raiz=golpe3:ataque3` (Icamiaba: `livre=golpe1:ataque1 livre=golpe2:ataque2 raiz=golpe3:ataque3`). "livre" = o golpe vai e volta; "raiz" = o golpe avança e o jogo move o herói junto
   - armas: reduzir para ~2.500 triângulos e textura 512 → `game/art/armas/`
   - encaixe nas mãos: tabela `GEAR` em `game/scripts/gameplay/hero_gear.gd`
   - conferir: `tests/shot_anims.gd -- model=... hero=<heroi> shot=...`

No jogo (`hero_animator.gd`): pernas (parada/andar/correr) e tronco (golpes, dano) em camadas; combo de golpes em sequência; atingido parado levanta o escudo; morte no corpo todo.

O caminho antigo (rig e animações do Tripo, `tools/prep_anim.mjs`) ficou como alternativa: as animações do Tripo são genéricas e sem arma.

## Efeitos das magias (texturas)

Os efeitos já funcionam com texturas provisórias desenhadas por código (`game/art/vfx/`).
Para trocar pelas versões pintadas por IA:

1. Gerar cada imagem no Gemini/ChatGPT com **fundo preto puro**, quadrada, sem texto (prompts no chat / abaixo).
2. Salvar em `arte/vfx/` com o nome exato: `casco_hex.png`, `onda_choque.png`, `poeira.png`, `folha.png`,
   `faisca.png`, `sapo_muiraquita.png`, `simbolo_provocado.png` (pode ser .jpg; pode mandar só algumas).
3. Preparar (o preto vira transparente): `python3 tools/vfx_texturas.py preparar arte/vfx`

Efeitos no código: `game/scripts/combat/vfx.gd`. Fotos para conferir: `tests/shot_powers.gd`.

## Inimigos (lote 4)

Modelos da Tripo em `arte/bruto/inimigos/` → reduzidos com `tools/reduzir_modelo.py` para `game/art/inimigos/<id>.glb`
(o nome é o id do inimigo, ex.: `onca_pintada.glb`). Sem esqueleto: o andar é feito no shader `game/shaders/bicho.gdshader`
(quadrúpede, bípede, cobra ou muitas patas). Tamanho, modo e para onde a cabeça aponta: tabela `ART` em `enemy.gd`.
Conferir o andar: folha de contato com 4 momentos do passo de cada bicho.
