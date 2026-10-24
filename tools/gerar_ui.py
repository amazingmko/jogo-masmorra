#!/usr/bin/env python3
"""Gera as texturas da interface (moldura dos painéis, botões, faixa de aviso) em game/ui/.

Identidade "Terra Firme": madeira escura, faixa com grafismo de inspiração marajoara (degraus e
triângulos escalonados em terracota e preto sobre creme) e filete dourado. Tudo desenhado aqui,
em código, para poder ajustar cor e tamanho sem gastar créditos de geração de imagem.

Uso: python3 tools/gerar_ui.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "ui")
SS = 4  # supersampling: desenha 4x maior e reduz (bordas lisas)

# paleta
ESCURO = (18, 12, 8, 255)
MADEIRA = (92, 58, 34, 255)
MADEIRA_ESC = (61, 39, 22, 255)
MADEIRA_CLARA = (128, 86, 52, 255)
TERRACOTA = (181, 83, 46, 255)
CREME = (236, 217, 176, 255)
OURO = (214, 160, 62, 255)
FUNDO = (30, 21, 17, 238)


def _wood(draw, box, rng, base=MADEIRA, dark=MADEIRA_ESC, light=MADEIRA_CLARA, vertical=False):
    """Retângulo de madeira com veios."""
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=base)
    length = (y1 - y0) if vertical else (x1 - x0)
    across = (x1 - x0) if vertical else (y1 - y0)
    for i in range(int(across / (1.5 * SS)) + 1):
        c = dark if rng.random() < 0.6 else light
        off = i * 1.5 * SS + rng.uniform(-0.5, 0.5) * SS
        pts = []
        phase = rng.uniform(0, math.tau)
        amp = rng.uniform(0.2, 0.9) * SS
        for k in range(0, int(length) + 8, 4 * SS):
            w = off + math.sin(k / (14.0 * SS) + phase) * amp
            pts.append((x0 + w, y0 + k) if vertical else (x0 + k, y0 + w))
        draw.line(pts, fill=c[:3] + (110,), width=max(1, SS // 2))


def marajoara_tile(w, h):
    """Um módulo da faixa: pirâmide escalonada terracota (com contorno preto) apontando para cima,
    e a invertida em preto entre elas, sobre creme. Repete sem emenda na horizontal."""
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), CREME)
    d = ImageDraw.Draw(im)
    steps = 4
    sh = H / (steps + 1.2)
    pad = H * 0.08
    # pirâmide para cima (terracota) no meio do módulo
    for s in range(steps):
        inset = (s + 0.5) * (W / (2 * steps + 1))
        y1 = H - pad - s * sh
        d.rectangle([inset, y1 - sh, W - inset, y1], fill=TERRACOTA)
    # pirâmide invertida (preta) nas pontas (metade em cada lado: emenda com o vizinho)
    for s in range(steps - 1):
        half = (steps - 1 - s) * (W / (2 * steps + 1)) * 0.5
        y0 = pad + s * sh
        d.rectangle([0, y0, half, y0 + sh], fill=ESCURO)
        d.rectangle([W - half, y0, W, y0 + sh], fill=ESCURO)
    # filetes de cima e de baixo
    d.rectangle([0, 0, W, pad * 0.6], fill=ESCURO)
    d.rectangle([0, H - pad * 0.6, W, H], fill=ESCURO)
    return im


def corner(size):
    """Canto: losango escalonado concêntrico (preto, terracota, creme, ouro)."""
    S = size * SS
    im = Image.new("RGBA", (S, S), ESCURO)
    d = ImageDraw.Draw(im)
    d.rectangle([SS, SS, S - SS, S - SS], fill=MADEIRA_ESC)
    c = S / 2
    for r, col in [(0.46, CREME), (0.38, ESCURO), (0.30, TERRACOTA), (0.18, ESCURO), (0.10, OURO)]:
        R = r * S
        d.polygon([(c, c - R), (c + R, c), (c, c + R), (c - R, c)], fill=col)
    d.rectangle([0, 0, S - 1, S - 1], outline=OURO, width=SS)
    return im


def panel(size=256, band=12, wood=8, corner_sz=30):
    rng = random.Random(7)
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # fundo do painel com vinheta leve
    inner = Image.new("RGBA", (S, S), FUNDO)
    noise = Image.effect_noise((S // 8, S // 8), 18).resize((S, S)).convert("L")
    tint = Image.new("RGBA", (S, S), (46, 32, 24, 255))
    inner = Image.composite(tint, inner, noise.point(lambda v: int(v * 0.35)))
    inner.putalpha(FUNDO[3])
    im.alpha_composite(inner)
    # moldura de madeira (4 lados)
    o = 2 * SS
    w = wood * SS
    d.rectangle([0, 0, S - 1, S - 1], outline=ESCURO, width=o)
    for box, vert in [((o, o, S - o, o + w), False), ((o, S - o - w, S - o, S - o), False),
                      ((o, o, o + w, S - o), True), ((S - o - w, o, S - o, S - o), True)]:
        _wood(d, box, rng, vertical=vert)
    # faixa marajoara
    b0 = o + w + SS
    bh = band * SS
    d.rectangle([o + w, o + w, S - o - w, S - o - w], outline=ESCURO, width=SS)
    tile = marajoara_tile(16, band)
    tv = tile.rotate(90, expand=True)
    for x in range(b0, S - b0, tile.width):
        im.alpha_composite(tile.crop((0, 0, min(tile.width, S - b0 - x), tile.height)), (x, b0))
        im.alpha_composite(tile.rotate(180).crop((0, 0, min(tile.width, S - b0 - x), tile.height)), (x, S - b0 - bh))
    for y in range(b0, S - b0, tv.height):
        im.alpha_composite(tv.crop((0, 0, tv.width, min(tv.height, S - b0 - y))), (b0, y))
        im.alpha_composite(tv.rotate(180).crop((0, 0, tv.width, min(tv.height, S - b0 - y))), (S - b0 - bh, y))
    # filete dourado por dentro
    g = b0 + bh
    d.rectangle([g, g, S - g, S - g], outline=ESCURO, width=SS)
    d.rectangle([g + SS, g + SS, S - g - SS, S - g - SS], outline=OURO, width=SS)
    # cantos
    c = corner(corner_sz)
    for x, y in [(0, 0), (S - c.width, 0), (0, S - c.height), (S - c.width, S - c.height)]:
        im.alpha_composite(c, (x, y))
    return im.resize((size, size), Image.LANCZOS)


def button(w=96, h=48, base=MADEIRA, light=MADEIRA_CLARA, dark=MADEIRA_ESC, edge=OURO, pressed=False, seed=3):
    rng = random.Random(seed)
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = 7 * SS
    d.rounded_rectangle([0, 0, W - 1, H - 1], r, fill=ESCURO)
    top = 2 * SS if not pressed else 3 * SS
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    _wood(bd, (0, 0, W, H), rng, base=base, dark=dark, light=light)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([2 * SS, top, W - 2 * SS, H - (4 * SS if not pressed else 2 * SS)], r - SS, fill=255)
    im.paste(body, (0, 0), mask)
    # brilho em cima (madeira envernizada) e sombra embaixo
    if not pressed:
        d.line([(r, top + SS), (W - r, top + SS)], fill=(255, 235, 200, 70), width=SS)
    d.rounded_rectangle([2 * SS, top, W - 2 * SS, H - (4 * SS if not pressed else 2 * SS)], r - SS, outline=edge[:3] + (200,), width=SS)
    return im.resize((w, h), Image.LANCZOS)


def ribbon(w=512, h=88):
    """Faixa de aviso (toast): fita terracota com pontas recortadas e a faixa marajoara fina."""
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    notch = 26 * SS
    poly = [(0, 0), (W, 0), (W - notch, H / 2), (W, H), (0, H), (notch, H / 2)]
    d.polygon(poly, fill=ESCURO)
    m = 3 * SS
    inner = [(m * 2.2, m), (W - m * 2.2, m), (W - notch - m * 0.3, H / 2), (W - m * 2.2, H - m), (m * 2.2, H - m), (notch + m * 0.3, H / 2)]
    d.polygon(inner, fill=(120, 48, 26, 255))
    # brilho de cima
    d.polygon([(m * 2.2, m), (W - m * 2.2, m), (W - notch * 0.6, H * 0.3), (notch * 0.6, H * 0.3)], fill=(160, 70, 38, 255))
    # faixas marajoara em cima e embaixo (finas)
    tile = marajoara_tile(10, 7).resize((10 * SS, 7 * SS))
    for x in range(notch + 6 * SS, W - notch - 6 * SS, tile.width):
        cw = min(tile.width, W - notch - 6 * SS - x)
        im.alpha_composite(tile.crop((0, 0, cw, tile.height)), (x, m + SS))
        im.alpha_composite(tile.rotate(180).crop((0, 0, cw, tile.height)), (x, H - m - SS - tile.height))
    d.line(inner + [inner[0]], fill=OURO, width=SS)
    return im.resize((w, h), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    panel().save(os.path.join(OUT, "moldura_painel.png"))
    button().save(os.path.join(OUT, "botao.png"))
    button(base=(112, 74, 44, 255), light=(150, 104, 64, 255)).save(os.path.join(OUT, "botao_hover.png"))
    button(pressed=True, base=(72, 46, 27, 255)).save(os.path.join(OUT, "botao_press.png"))
    button(base=(70, 70, 70, 255), light=(95, 95, 95, 255), dark=(50, 50, 50, 255), edge=(120, 120, 120, 255)).save(os.path.join(OUT, "botao_off.png"))
    button(base=(176, 122, 38, 255), light=(222, 170, 70, 255), dark=(130, 86, 24, 255), edge=CREME, seed=5).save(os.path.join(OUT, "botao_ouro.png"))
    button(base=(200, 142, 52, 255), light=(240, 192, 96, 255), dark=(150, 100, 30, 255), edge=CREME, seed=5).save(os.path.join(OUT, "botao_ouro_hover.png"))
    ribbon().save(os.path.join(OUT, "faixa_aviso.png"))
    print("ok:", sorted(f for f in os.listdir(OUT) if f.endswith(".png")))


if __name__ == "__main__":
    main()
