# Efeitos das magias: imagens para gerar no Gemini

Mesmo caminho da Muralha da Icamiaba: imagem quadrada com **fundo preto puro** → `arte/vfx/<nome>.png`
→ `python3 tools/vfx_texturas.py preparar arte/vfx` (o preto vira transparente, o brilho fica).
O fundo preto é obrigatório: o Gemini erra quando se pede fundo transparente.
As marcadas com (cor no jogo) devem vir **brancas/claras**: o jogo pinta cada uso com uma cor.

## 1. Texturas provisórias (desenhadas por código) — usadas por vários efeitos

| Arquivo | Onde aparece | Prompt |
|---|---|---|
| garra.png | Garras do Mapinguari, Patada da Onça | `Three parallel glowing claw slash marks, diagonal, sharp tapered ends, white-hot core with soft white glow, hand-painted fantasy game VFX sprite, World of Warcraft style, centered, pure black background, no text` (cor no jogo) |
| fumaca.png | Fedor e Bafo do Mapinguari, nuvens | `Single soft round puff of thick billowing smoke, fluffy cloud shape, light grey and white, hand-painted fantasy game VFX sprite, centered, pure black background, no text` (cor no jogo) |
| anel_som.png | Grito do Mapinguari, Esturro da Onça, Tapa do Macaco, impactos | `Top-down view of a thin circular sound wave ring, glowing white ring with faint ripple echoes inside, hand-painted fantasy game VFX, centered, pure black background, no text` (cor no jogo) |
| teia.png | Teia e Armadilha de Teia da Aranha | `Top-down view of a round spider web, radial threads and spiral, silvery white glowing strands, slightly irregular and organic, hand-painted fantasy game VFX, centered, pure black background, no text` |

## 2. Inimigos — efeitos feitos só com formas simples

| Arquivo | Onde aparece | Prompt |
|---|---|---|
| mordida.png | Dentada da Queixada, Mordida no Crânio da Onça, Bocarra do Mapinguari | `Bite impact effect, two curved rows of sharp fangs snapping shut, white energy arcs with small sparks, hand-painted fantasy game VFX sprite, centered, pure black background, no text` (cor no jogo) |
| gota_veneno.png | Picada da Aranha, Ferroada da Formiga, Picada e Veneno Forte da Jararaca | `Single glossy drop of venom, teardrop shape with a bright highlight, pale white-green glowing liquid, hand-painted fantasy game VFX sprite, centered, pure black background, no text` (cor no jogo) |
| olhar.png | Olhar dos Cinco Olhos do Mapinguari (o disparo) | `Glowing magical energy orb shaped like a fierce eye, golden and blood-red light with a dark slit pupil, wisps of energy around it, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| pelos.png | Pelos urticantes da Aranha (o disparo) | `Cluster of fine bristly spider hairs flying apart, thin sharp needles radiating from the center, pale white with soft glow, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| aviso_circulo.png | Aviso de ataque no chão (todos os bichos) — opcional | `Top-down magic warning circle on the ground, thin ornate ring border with Amazonian tribal patterns, white glowing lines, empty center, hand-painted fantasy game VFX, centered, pure black background, no text` (cor no jogo) |

## 3. Heróis — efeitos feitos só com formas simples

| Arquivo | Herói / poder | Prompt |
|---|---|---|
| corte.png | Icamiaba: golpe da lança | `Curved crescent slash arc of energy, thick at the middle and tapering to sharp ends, white core with golden edges, motion streaks, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| cipo_armadilha.png | Mateira: Armadilha de Cipó | `Top-down view of a round snare made of twisted jungle vines with small thorns and leaves, bright green with soft magical glow, empty center, hand-painted fantasy game VFX, centered, pure black background, no text` |
| bola_agua.png | Encantado: disparo | `Swirling orb of magical river water, bright blue and white foam spiraling inside, small droplets around it, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| respingo.png | Encantado: acerto, explosão do Espelho do Rio | `Burst of water splash, droplets and foam flying outward in a ring, bright blue and white, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| onda_pororoca.png | Encantado: Pororoca | `Side view of a big curling river wave (tidal bore), foamy white crest, translucent blue water, wide horizontal shape, hand-painted fantasy game VFX, centered, pure black background, no text` |
| escamas_agua.png | Encantado: Boiuna (Cobra-Grande) | `Seamless tileable texture of glowing water serpent scales, translucent blue and teal with white highlights, hand-painted fantasy game VFX style, top view, pure black background, no text` |
| semente.png | Druida: Semente (ataque) | `Small glowing magical seed with a tiny green sprout, emerald green glow and golden sparkles, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| flor.png | Druida: Florescer | `Top-down view of an open passion flower blossom (maracuja flower), pink and white petals with purple filaments, glowing center, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| onda_canto.png | Druida: Canto do Boto | `Concentric crescent sonic waves of a dolphin song, soft pink and lilac glowing arcs, musical feeling, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |
| bolha.png | Druida: bolha do Despertar do Boto | `Front view of a translucent water bubble sphere, thin iridescent pink and blue rim, small highlights, mostly empty inside, hand-painted fantasy game VFX, centered, pure black background, no text` |
| cura.png | Curas (Florescer, Canto, Muiraquitã) | `Soft burst of green healing light with small leaves and sparkles rising, gentle and warm, hand-painted fantasy game VFX sprite, centered, pure black background, no text` |

## 4. Não é imagem do Gemini (modelo 3D)

- Árvores Derrubadas (Mapinguari): usar o modelo `arvore_borda.glb` que já está no jogo.
- Cópia do Espelho do Rio: o próprio modelo do Encantado com material de água (por código).
- Tripo: pinguela, cajado da Druida, cajado do Encantado, harpia, pedra (Pedrada do Macaco), ouriço de castanha.
