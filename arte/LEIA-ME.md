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
