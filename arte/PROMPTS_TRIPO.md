# Modelos 3D que faltam: imagem (Gemini/ChatGPT) → Tripo

Caminho: gerar a imagem com o prompt → Tripo (imagem para 3D, **sem retopologia**) → exportar GLB
com o nome e a pasta da tabela. Fundo **branco** (não preto: aqui é objeto, não efeito).

| Ordem | Modelo | Salvar como |
|---|---|---|
| 1 | Cajado da Druida | `arte/bruto/armas/cajado_druida.glb` |
| 2 | Bengala do Encantado | `arte/bruto/armas/bengala_encantado.glb` |
| 3 | Harpia (Mateira) | `arte/bruto/harpia.glb` |
| 4 | Pinguela | `arte/bruto/ambiente/pinguela.glb` |
| 5 | Pedra da Pedrada | `arte/bruto/ambiente/pedra_pedrada.glb` |
| 6 | Ouriço de castanha | `arte/bruto/ambiente/ourico_castanha.glb` |

## 1. Cajado da Druida
```
Game asset, a single druid staff made from a living twisted tree root, dark brown gnarled wood spiraling upward, the top opens into a curled root cradle holding a glowing green seed with a small sprouting leaf, a passion flower blossom and a few small leaves growing along the shaft, natural fiber cord wrapped at the grip, stylized hand-painted World of Warcraft style, chunky proportions, side view, full object visible, vertical, isolated on plain white background, no hands, no character, no text
```

## 2. Bengala do Encantado
O Encantado é o boto da lenda, elegante de chapéu e roupa clara: em vez de cajado de mago, uma bengala de galã.
```
Game asset, exactly ONE single magic walking cane, only one object in the image, standing vertically in the center. Polished pale wood shaft with thin silver-blue water swirl inlays, the curved handle at the top carved as the head of a pink Amazon river dolphin (boto) with a long thin snout, a small glowing blue water orb held under the dolphin head, a tiny pink ribbon tied below the handle, a small silver tip at the bottom. Stylized hand-painted World of Warcraft style, chunky proportions, side view, full object visible from top to bottom, isolated on plain white background. Do not draw a second cane, no duplicates, no variations, no multiple views, no hands, no character, no text
```

## 3. Harpia (o gavião-real da ultimate da Mateira)
Asas abertas, de cima, que é como ela aparece no jogo (circulando e mergulhando).
```
Game asset, a single harpy eagle in flight with wings fully spread, grey and black feathers, white belly, distinctive double grey head crest, strong yellow talons, fierce look, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter top view, full body and full wingspan visible, symmetrical wings, isolated on plain white background, no rider, no text
```

## 4. Pinguela (passagem sobre o igarapé)
Ela atravessa o igarapé de barranco a barranco; mais larga do que comprida, baixa e reta.
```
Game asset, a single short and wide rustic jungle footbridge, six rough hand-cut wooden planks laid side by side on two log beams, planks tied with natural fiber rope, a little moss and a couple of small leaves on the wood, flat and low to the ground, no railings, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter top view, full object visible, isolated on plain white background, no water, no ground, no character, no text
```

## 5. Pedra da Pedrada (o Macaco-prego atira)
```
Game asset, a single small rough river stone, rounded but uneven shape, grey-brown with a few cracks and a small patch of green moss, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter view, full object visible, isolated on plain white background, no text
```

## 6. Ouriço de castanha (cai do alto no Ouriço e na Chuva de Ouriços)
```
Game asset, a single Brazil nut fruit pod (ourico de castanha), hard round woody brown shell like a small coconut with a small circular cap on top, rough fibrous texture, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter view, full object visible, isolated on plain white background, no text
```

---

# Lote 2: Boiuna e borda de masmorra

## Boiuna (Cobra-Grande do Encantado)
O corpo continua sendo feito pelo jogo (ele precisa dobrar e girar em volta do herói); do Tripo vem
só a **cabeça**, e do Gemini a **textura das escamas** do corpo.

### 7. Cabeça da Boiuna (Gemini → Tripo) — `arte/bruto/boiuna_cabeca.glb`
```
Game asset, the head of a giant mythical Amazon water serpent (Boiuna), only the head and a short piece of neck, mouth half open showing two long fangs, glowing yellow-green eyes, smooth dark blue and turquoise scales with lighter cyan belly, small fin-like crest on top of the head made of water, drops of water on the scales, stylized hand-painted World of Warcraft style, chunky proportions, side view facing right, full object visible, isolated on plain white background, no body, no text
```

### 8. Escamas do corpo (só Gemini, imagem) — `arte/vfx/escamas_boiuna.png`
```
Seamless tileable texture, top view of serpent skin made of water: rows of overlapping rounded scales in deep blue and turquoise, lighter cyan edges on each scale, subtle wet highlights, stylized hand-painted World of Warcraft style, flat even lighting, square image, no shadows, no perspective, no text
```

## Borda das salas com cara de masmorra (Gemini → Tripo)
Entram sozinhas na borda das clareiras quando o arquivo existe (o jogo sorteia trechos de mata,
pedras, tronco, ruína, raízes e paredão).

### 9. Muro em ruína — `arte/bruto/ambiente/muro_ruina.glb`
```
Game asset, a single short section of ancient ruined stone wall from a lost Amazonian civilization, about three times wider than tall, big carved stone blocks with worn geometric indigenous patterns, some blocks missing and broken on top, thick green moss and hanging vines on it, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter top view, full object visible, isolated on plain white background, no text
```

### 10. Pilar em ruína — `arte/bruto/ambiente/pilar_ruina.glb`
```
Game asset, a single broken ancient stone pillar from a lost Amazonian temple, square column with carved geometric indigenous patterns, top broken off, moss and small roots climbing it, a few fallen stone chunks at the base, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter top view, full object visible, isolated on plain white background, no text
```

### 11. Totem de pedra — `arte/bruto/ambiente/totem_pedra.glb`
```
Game asset, a single ancient carved stone totem of an Amazonian jaguar spirit face, tall and narrow, weathered grey-green stone, glowing faint turquoise runes in the carved eyes, moss on top, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter view, full object visible, isolated on plain white background, no text
```

### 12. Raiz gigante — `arte/bruto/ambiente/raiz_gigante.glb`
```
Game asset, a single giant twisted tree root arching out of the ground and back in, like a low natural wall, thick dark brown bark with moss and a few small mushrooms and ferns growing on it, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter top view, full object visible, isolated on plain white background, no tree, no text
```

### 13. Paredão de pedra — `arte/bruto/ambiente/rocha_paredao.glb`
```
Game asset, a single low rocky ridge, a wide cluster of large mossy grey boulders fused together forming a natural barrier, wider than tall, ferns and small plants in the cracks, stylized hand-painted World of Warcraft style, chunky proportions, three-quarter top view, full object visible, isolated on plain white background, no text
```
