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
