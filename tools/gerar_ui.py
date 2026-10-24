#!/usr/bin/env python3
"""Gera as texturas da interface em game/ui/<paleta>/ e os ícones em game/ui/icones/.

Interface neutra (igual em todos os biomas), com cara de MMORPG: moldura de metal com relevo,
cantos ornamentados com pedra preciosa, placa de título, casas de item com borda de raridade,
botões e abas. Um grafismo geométrico discreto (inspirado na cerâmica marajoara) aparece gravado
no metal, como assinatura do jogo, sem pintar a interface com a cor de um bioma.

Paletas (para escolher):
  obsidiana   - preto azulado + ouro (clássico de MMORPG)
  pedra_lunar - ardósia azul + prata, detalhe turquesa
  abissal     - azul-marinho translúcido + linhas claras que brilham (lembra o Aion)

Uso: python3 tools/gerar_ui.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "game", "ui")
SS = 4

PALETAS = {
    "obsidiana": {
        "bg_top": (26, 28, 36), "bg_bot": (14, 15, 20), "alpha": 255,
        "metal": [(255, 236, 170), (232, 192, 104), (196, 148, 62), (150, 104, 38), (96, 64, 22)],
        "gem": (64, 196, 214), "line": (232, 192, 104), "glow": None,
        "btn": [(56, 58, 70), (34, 36, 44)], "btn_hi": [(74, 76, 92), (44, 46, 56)],
        "gold": [(250, 214, 120), (196, 140, 46)],
        "slot": [(20, 22, 28), (8, 9, 12)],
    },
    "pedra_lunar": {
        "bg_top": (40, 50, 68), "bg_bot": (24, 30, 42), "alpha": 255,
        "metal": [(245, 249, 255), (200, 210, 224), (150, 162, 182), (104, 116, 138), (62, 70, 88)],
        "gem": (96, 222, 214), "line": (200, 210, 224), "glow": None,
        "btn": [(62, 76, 98), (40, 50, 66)], "btn_hi": [(80, 96, 122), (50, 62, 80)],
        "gold": [(140, 236, 226), (52, 156, 160)],
        "slot": [(26, 32, 44), (14, 18, 26)],
    },
    "abissal": {
        "bg_top": (14, 30, 54), "bg_bot": (6, 12, 26), "alpha": 255,
        "metal": [(236, 250, 255), (176, 226, 248), (110, 180, 220), (60, 116, 160), (26, 54, 84)],
        "gem": (255, 204, 96), "line": (150, 220, 255), "glow": (90, 200, 255),
        "btn": [(24, 52, 86), (12, 28, 50)], "btn_hi": [(34, 70, 112), (16, 38, 66)],
        "gold": [(255, 222, 140), (214, 150, 52)],
        "slot": [(8, 20, 38), (3, 8, 18)],
    },
}

RARITY = [(200, 200, 210), (77, 163, 255), (192, 107, 255), (255, 165, 61)]


# ---------- auxiliares ----------

def vgrad(w, h, top, bot, alpha=255):
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (alpha,)
        for x in range(w):
            px[x, y] = c
    return im


def bevel_rect(d, box, cols, width):
    """Retângulo com relevo: linhas concêntricas do claro (fora) ao escuro (dentro)."""
    x0, y0, x1, y1 = box
    n = len(cols)
    for i in range(width):
        c = cols[min(int(i * n / width), n - 1)]
        d.rectangle([x0 + i, y0 + i, x1 - i, y1 - i], outline=c)


def bevel_poly(im, pts, cols, steps):
    """Polígono de metal: encolhe em direção ao centro trocando a cor (relevo)."""
    d = ImageDraw.Draw(im)
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    for i in range(steps):
        k = 1.0 - i / steps * 0.9
        c = cols[min(int(i * len(cols) / steps), len(cols) - 1)]
        d.polygon([(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts], fill=c)


def gem(im, cx, cy, r, color):
    d = ImageDraw.Draw(im)
    dark = tuple(int(v * 0.35) for v in color)
    d.ellipse([cx - r - SS, cy - r - SS, cx + r + SS, cy + r + SS], fill=(10, 10, 12))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=dark)
    d.ellipse([cx - r * 0.8, cy - r * 0.8, cx + r * 0.8, cy + r * 0.8], fill=color)
    hl = tuple(min(255, int(v * 0.5 + 140)) for v in color)
    d.ellipse([cx - r * 0.5, cy - r * 0.6, cx - r * 0.05, cy - r * 0.15], fill=hl)


def glow_layer(size, draw_fn, color, radius):
    g = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(g), color + (255,))
    return g.filter(ImageFilter.GaussianBlur(radius))


# ---------- peças ----------

def corner_piece(P, size):
    """Canto: cantoneira de metal em L com pontas em degrau (assinatura geométrica), losango e pedra."""
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = P["metal"]
    d = ImageDraw.Draw(im)
    aw = S * 0.20   # largura do braço
    def arm(horizontal):
        # braço com a ponta em 3 degraus
        L = S
        st = [(L * 0.66, aw), (L * 0.80, aw * 0.68), (L * 0.92, aw * 0.38)]
        pts = [(0, 0), (L, 0), (L, aw * 0.38)]
        for x, h in reversed(st):
            pts += [(x, h)]
            pts += [(x - L * 0.0001, h)]
        pts = [(0, 0), (L, 0), (L, st[2][1]), (st[2][0], st[2][1]), (st[2][0], st[1][1]), (st[1][0], st[1][1]), (st[1][0], st[0][1]), (st[0][0], st[0][1]), (0, aw)]
        if not horizontal:
            pts = [(y, x) for x, y in pts]
        return pts
    for horiz in (True, False):
        pts = arm(horiz)
        d.polygon([(x + (0 if horiz else 0), y) for x, y in pts], fill=(6, 6, 8))
        inner = [(x * 0.985 + SS, y * 0.9 + SS) if horiz else (x * 0.9 + SS, y * 0.985 + SS) for x, y in pts]
        bevel_poly(im, inner, [m[0], m[1], m[2], m[3]], 5)
        # sulco gravado ao longo do braço
        if horiz:
            d.line([(aw * 1.2, aw * 0.5), (S * 0.62, aw * 0.5)], fill=m[4], width=SS)
        else:
            d.line([(aw * 0.5, aw * 1.2), (aw * 0.5, S * 0.62)], fill=m[4], width=SS)
    # losango sobre o canto
    c = S * 0.27
    r = S * 0.25
    d.polygon([(c, c - r - 2 * SS), (c + r + 2 * SS, c), (c, c + r + 2 * SS), (c - r - 2 * SS, c)], fill=(6, 6, 8))
    bevel_poly(im, [(c, c - r), (c + r, c), (c, c + r), (c - r, c)], m, 10)
    for k in range(2):
        rr = r * (0.72 - k * 0.2)
        d.polygon([(c, c - rr), (c + rr, c), (c, c + rr), (c - rr, c)], outline=m[4])
    gem(im, c, c, r * 0.34, P["gem"])
    return im


def panel(P, size=320, band=11):
    S = size * SS
    a = P["alpha"]
    im = vgrad(S, S, P["bg_top"], P["bg_bot"], a)
    # textura leve (pedra/tecido) e vinheta por dentro
    noise = Image.effect_noise((S // 6, S // 6), 22).resize((S, S)).convert("L")
    lighter = vgrad(S, S, tuple(min(255, v + 14) for v in P["bg_top"]), tuple(min(255, v + 8) for v in P["bg_bot"]), a)
    im = Image.composite(lighter, im, noise.point(lambda v: int(v * 0.4)))
    vign = Image.new("L", (S, S), 0)
    vd = ImageDraw.Draw(vign)
    for i in range(30):
        vd.rectangle([i * SS, i * SS, S - i * SS, S - i * SS], outline=int(120 * (1 - i / 30)))
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 255))
    im = Image.composite(shade, im, vign.point(lambda v: int(v * 0.8)))
    im.putalpha(Image.new("L", (S, S), a))
    d = ImageDraw.Draw(im)
    m = P["metal"]
    o = 3 * SS
    bw = band * SS
    # sombra externa + aro de metal com relevo (claro fora, escuro dentro)
    d.rectangle([0, 0, S - 1, S - 1], outline=(4, 4, 6, 255), width=o)
    bevel_rect(d, (o, o, S - o - 1, S - o - 1), [m[0], m[1], m[1], m[2], m[2], m[3], m[3], m[4]], bw)
    # grafismo gravado no aro: losangos escalonados em fila (discreto)
    step = 14 * SS
    mid = o + bw / 2
    for t in range(int(o + bw + step), int(S - o - bw - step / 2), step):
        for (x, y) in [(t, mid), (t, S - mid), (mid, t), (S - mid, t)]:
            r = bw * 0.26
            d.polygon([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], fill=m[4])
            d.polygon([(x, y - r * 0.45), (x + r * 0.45, y), (x, y + r * 0.45), (x - r * 0.45, y)], fill=m[1])
    # filete por dentro (linha de destaque) e sombra do aro sobre o fundo
    g = o + bw
    d.rectangle([g, g, S - g - 1, S - g - 1], outline=(0, 0, 0, 255), width=SS)
    d.rectangle([g + 3 * SS, g + 3 * SS, S - g - 3 * SS - 1, S - g - 3 * SS - 1], outline=P["line"] + (150,), width=SS)
    if P["glow"]:
        gl = glow_layer((S, S), lambda dd, c: dd.rectangle([g + 3 * SS, g + 3 * SS, S - g - 3 * SS, S - g - 3 * SS], outline=c, width=2 * SS), P["glow"], 5 * SS)
        im.alpha_composite(gl)
    # cantos
    cp = corner_piece(P, 84)
    for rot, (x, y) in [(0, (0, 0)), (270, (S - cp.width, 0)), (90, (0, S - cp.height)), (180, (S - cp.width, S - cp.height))]:
        im.alpha_composite(cp.rotate(rot), (x, y))
    return im.resize((size, size), Image.LANCZOS)


def plate(P, w=440, h=64, gem_ends=True):
    """Placa do título / faixa dos avisos: pontas chanfradas, aro de metal, pedras nas pontas."""
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    n = H * 0.5
    outer = [(0, H / 2), (n, 0), (W - n, 0), (W, H / 2), (W - n, H), (n, H)]
    d.polygon(outer, fill=(4, 4, 6, 255))
    m = P["metal"]
    for i, c in enumerate([m[0], m[1], m[2], m[3]]):
        k = (i + 1) * 1.2 * SS
        d.polygon([(k * 1.6, H / 2), (n + k * 0.4, k), (W - n - k * 0.4, k), (W - k * 1.6, H / 2), (W - n - k * 0.4, H - k), (n + k * 0.4, H - k)], fill=c)
    k = 6 * SS
    inner = [(k * 1.6, H / 2), (n + k * 0.4, k), (W - n - k * 0.4, k), (W - k * 1.6, H / 2), (W - n - k * 0.4, H - k), (n + k * 0.4, H - k)]
    body = vgrad(W, H, tuple(min(255, v + 20) for v in P["bg_top"]), P["bg_bot"], 250)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(inner, fill=255)
    im.paste(body, (0, 0), mask)
    d.line(inner + [inner[0]], fill=(0, 0, 0, 255), width=SS)
    if gem_ends:
        gem(im, n * 0.62, H / 2, H * 0.17, P["gem"])
        gem(im, W - n * 0.62, H / 2, H * 0.17, P["gem"])
    return im.resize((w, h), Image.LANCZOS)


def button(P, w=120, h=52, fill=None, pressed=False, disabled=False):
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = P["metal"] if not disabled else [(150, 150, 150), (120, 120, 120), (96, 96, 96), (70, 70, 70), (44, 44, 44)]
    r = 6 * SS
    d.rounded_rectangle([0, 0, W - 1, H - 1], r, fill=(4, 4, 6, 255))
    for i, c in enumerate([m[1], m[2], m[3]]):
        k = (i + 1) * SS
        d.rounded_rectangle([k, k, W - 1 - k, H - 1 - k], r - k / 2, fill=c)
    top, bot = fill if fill else P["btn"]
    if disabled:
        top, bot = (58, 58, 62), (38, 38, 42)
    if pressed:
        top, bot = bot, top
    k = 4 * SS
    body = vgrad(W, H, top, bot)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([k, k, W - 1 - k, H - 1 - k], r - 2 * SS, fill=255)
    im.paste(body, (0, 0), mask)
    if not pressed:
        d.line([(k + r, k + SS), (W - k - r, k + SS)], fill=(255, 255, 255, 60), width=SS)
    return im.resize((w, h), Image.LANCZOS)


def tab(P, active, w=150, h=48):
    W, H = w * SS, h * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = P["metal"]
    r = 8 * SS
    top, bot = (P["btn_hi"] if active else P["btn"])
    d.rounded_rectangle([0, 0, W - 1, H + r], r, fill=(4, 4, 6, 255))
    body = vgrad(W, H, top, bot)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([2 * SS, 2 * SS, W - 2 * SS, H + r], r, fill=255)
    im.paste(body, (0, 0), mask)
    if active:
        d.rounded_rectangle([2 * SS, 2 * SS, W - 2 * SS, H + r], r, outline=m[1], width=2 * SS)
        d.line([(r, 3 * SS), (W - r, 3 * SS)], fill=m[0], width=SS)
    else:
        d.rounded_rectangle([2 * SS, 2 * SS, W - 2 * SS, H + r], r, outline=m[3], width=SS)
    return im.resize((w, h), Image.LANCZOS)


def slot(P, rarity=None, size=80):
    """Casa de item: fundo afundado, aro de metal; com raridade, o aro e um brilho na cor dela."""
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = P["metal"]
    r = 7 * SS
    if rarity is not None and rarity > 0:
        col = RARITY[rarity]
        gl = glow_layer((S, S), lambda dd, c: dd.rounded_rectangle([5 * SS, 5 * SS, S - 5 * SS, S - 5 * SS], r, outline=c, width=4 * SS), col, 4 * SS)
        im.alpha_composite(gl)
    d.rounded_rectangle([2 * SS, 2 * SS, S - 2 * SS, S - 2 * SS], r, fill=(4, 4, 6, 255))
    if rarity is None:
        rim = [m[3], m[4], (20, 20, 24)]   # casa vazia: aro discreto
    elif rarity == 0:
        rim = [(176, 178, 186), (128, 130, 140), (70, 72, 80)]   # comum: cinza (não confunde com lendário)
    else:
        rim = [tuple(min(255, int(v * 1.1) + 30) for v in RARITY[rarity]), RARITY[rarity], tuple(int(v * 0.6) for v in RARITY[rarity])]
    for i, c in enumerate(rim):
        k = (3 + i) * SS
        d.rounded_rectangle([k, k, S - k, S - k], r, outline=c, width=SS)
    k = 6 * SS
    body = vgrad(S, S, P["slot"][0], P["slot"][1])
    # fundo afundado: sombra em cima, luz em baixo
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([k, k, S - k, S - k], r - SS, fill=255)
    im.paste(body, (0, 0), mask)
    d.line([(k + r, k + SS), (S - k - r, k + SS)], fill=(0, 0, 0, 200), width=2 * SS)
    d.line([(k + r, S - k - SS), (S - k - r, S - k - SS)], fill=(255, 255, 255, 30), width=SS)
    return im.resize((size, size), Image.LANCZOS)


def ring(P, size=200):
    """Círculo de luz no chão do pedestal do herói (na cor de destaque)."""
    S = size * SS
    col = P["gem"]
    g = glow_layer((S, S), lambda dd, c: dd.ellipse([S * 0.12, S * 0.12, S * 0.88, S * 0.88], outline=c, width=5 * SS), col, 6 * SS)
    d = ImageDraw.Draw(g)
    d.ellipse([S * 0.12, S * 0.12, S * 0.88, S * 0.88], outline=col + (255,), width=2 * SS)
    for k in range(12):
        a = k / 12 * math.tau
        cx, cy = S / 2 + math.cos(a) * S * 0.38, S / 2 + math.sin(a) * S * 0.38
        rr = 2.5 * SS
        d.polygon([(cx, cy - rr), (cx + rr, cy), (cx, cy + rr), (cx - rr, cy)], fill=col + (255,))
    return g.resize((size, size), Image.LANCZOS)


# ---------- ícones (iguais em todas as paletas) ----------

def _icon_canvas():
    S = 96 * SS
    return Image.new("RGBA", (S, S), (0, 0, 0, 0)), S


def _finish(im):
    # contorno escuro e leve sombra: o ícone lê em qualquer fundo
    S = im.width
    alpha = im.split()[3]
    outline = alpha.filter(ImageFilter.MaxFilter(9))
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh.putalpha(outline.point(lambda v: int(v * 0.95)))
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow = sh.copy()
    base.alpha_composite(shadow, (0, 2 * SS))
    base.alpha_composite(sh)
    base.alpha_composite(im)
    return base.resize((96, 96), Image.LANCZOS)


def _shade(im, light=(255, 255, 255, 70)):
    """Luz de cima-esquerda por cima da forma (volume)."""
    S = im.width
    g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    for i in range(0, S, SS * 2):
        a = max(0, int(light[3] * (1 - i / (S * 0.7))))
        gd.line([(0, i), (i, 0)], fill=light[:3] + (a,), width=SS * 2)
    alpha = im.split()[3]
    out = im.copy()
    g.putalpha(Image.composite(g.split()[3], Image.new("L", (S, S), 0), alpha))
    out.alpha_composite(g)
    return out


STEEL = [(220, 226, 236), (160, 170, 186), (98, 106, 122)]
CLOTH = (126, 82, 168)
LEATHER = (150, 96, 54)


def icon_items():
    icons = {}
    U = SS
    # Cabeça: elmo
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.chord([S * .18, S * .14, S * .82, S * .84], 180, 360, fill=STEEL[1])
    d.rectangle([S * .18, S * .48, S * .82, S * .74], fill=STEEL[1])
    d.rectangle([S * .30, S * .50, S * .70, S * .60], fill=(30, 32, 40))
    d.rectangle([S * .47, S * .50, S * .53, S * .74], fill=STEEL[0])
    d.polygon([(S * .5, S * .06), (S * .58, S * .2), (S * .42, S * .2)], fill=(200, 60, 50))
    icons["cabeca"] = _finish(_shade(im))
    # Peito: couraça
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(S * .2, S * .2), (S * .38, S * .14), (S * .5, S * .22), (S * .62, S * .14), (S * .8, S * .2), (S * .78, S * .55), (S * .68, S * .86), (S * .32, S * .86), (S * .22, S * .55)], fill=STEEL[1])
    d.line([(S * .5, S * .24), (S * .5, S * .84)], fill=STEEL[2], width=3 * U)
    d.arc([S * .3, S * .3, S * .7, S * .6], 20, 160, fill=STEEL[0], width=3 * U)
    icons["peito"] = _finish(_shade(im))
    # Mãos: luva
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([S * .28, S * .42, S * .70, S * .86], 8 * U, fill=LEATHER)
    for i, x in enumerate([.29, .39, .49, .59]):
        d.rounded_rectangle([S * x, S * (.14 + abs(i - 1.5) * .04), S * (x + .095), S * .5], 5 * U, fill=LEATHER)
    d.rounded_rectangle([S * .66, S * .40, S * .82, S * .62], 6 * U, fill=LEATHER)
    d.rectangle([S * .26, S * .76, S * .72, S * .86], fill=(110, 70, 38))
    icons["maos"] = _finish(_shade(im))
    # Pernas: calça
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(S * .26, S * .14), (S * .74, S * .14), (S * .8, S * .88), (S * .58, S * .88), (S * .5, S * .42), (S * .42, S * .88), (S * .2, S * .88)], fill=CLOTH)
    d.rectangle([S * .26, S * .14, S * .74, S * .22], fill=(90, 56, 124))
    icons["pernas"] = _finish(_shade(im))
    # Pés: bota
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(S * .3, S * .12), (S * .58, S * .12), (S * .6, S * .6), (S * .86, S * .7), (S * .86, S * .86), (S * .28, S * .86)], fill=LEATHER)
    d.rectangle([S * .28, S * .80, S * .86, S * .88], fill=(70, 44, 24))
    d.rectangle([S * .3, S * .12, S * .58, S * .2], fill=(110, 70, 38))
    icons["pes"] = _finish(_shade(im))
    # Escudo: casco
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.polygon([(S * .5, S * .1), (S * .84, S * .22), (S * .78, S * .62), (S * .5, S * .9), (S * .22, S * .62), (S * .16, S * .22)], fill=(112, 120, 70))
    for k in range(3):
        rr = .24 - k * .07
        d.polygon([(S * .5, S * (.5 - rr)), (S * (.5 + rr), S * .5), (S * .5, S * (.5 + rr)), (S * (.5 - rr), S * .5)], outline=(60, 66, 34), width=2 * U)
    d.ellipse([S * .44, S * .44, S * .56, S * .56], fill=STEEL[0])
    icons["escudo"] = _finish(_shade(im))
    # Lança
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.line([(S * .2, S * .84), (S * .68, S * .32)], fill=(150, 100, 56), width=6 * U)
    d.polygon([(S * .66, S * .26), (S * .88, S * .1), (S * .74, S * .36)], fill=STEEL[0])
    d.polygon([(S * .6, S * .32), (S * .7, S * .4), (S * .66, S * .26)], fill=STEEL[1])
    d.line([(S * .6, S * .42), (S * .68, S * .5)], fill=(200, 60, 50), width=4 * U)
    icons["lanca"] = _finish(_shade(im))
    # Arco
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.arc([S * .1, S * .1, S * .9, S * .9], 225, 45, fill=(160, 108, 60), width=7 * U)
    d.line([(S * .22, S * .78), (S * .78, S * .22)], fill=(235, 230, 210), width=2 * U)
    d.line([(S * .3, S * .7), (S * .74, S * .26)], fill=(200, 60, 50), width=3 * U)
    icons["arco"] = _finish(_shade(im))
    # Cajado
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)
    d.line([(S * .26, S * .9), (S * .58, S * .3)], fill=(120, 82, 50), width=6 * U)
    d.arc([S * .44, S * .08, S * .8, S * .44], 0, 300, fill=(120, 82, 50), width=5 * U)
    d.ellipse([S * .54, S * .17, S * .7, S * .33], fill=(90, 210, 255))
    d.ellipse([S * .57, S * .2, S * .62, S * .25], fill=(230, 250, 255))
    icons["cajado"] = _finish(_shade(im))
    # ---- reagentes ----
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # madeira
    d.rounded_rectangle([S * .12, S * .36, S * .78, S * .66], 10 * U, fill=(120, 76, 40))
    d.ellipse([S * .66, S * .34, S * .9, S * .68], fill=(214, 168, 110))
    d.ellipse([S * .72, S * .43, S * .84, S * .59], outline=(150, 100, 56), width=2 * U)
    d.line([(S * .2, S * .45), (S * .6, S * .45)], fill=(90, 56, 30), width=2 * U)
    icons["madeira"] = _finish(_shade(im))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # fibra
    for i in range(7):
        x = S * (.3 + i * .06)
        d.line([(x, S * .12), (S * .5 + (x - S * .5) * .3, S * .88)], fill=(214, 196, 140), width=3 * U)
    d.rectangle([S * .38, S * .52, S * .62, S * .6], fill=(150, 100, 56))
    icons["fibra"] = _finish(_shade(im))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # couro
    d.polygon([(S * .2, S * .2), (S * .4, S * .26), (S * .6, S * .2), (S * .82, S * .3), (S * .76, S * .56), (S * .84, S * .8), (S * .5, S * .72), (S * .18, S * .82), (S * .26, S * .52)], fill=(96, 112, 60))
    for x, y in [(.4, .4), (.56, .5), (.44, .62), (.62, .36)]:
        d.ellipse([S * x, S * y, S * (x + .08), S * (y + .06)], fill=(66, 80, 40))
    icons["couro"] = _finish(_shade(im))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # minério
    d.polygon([(S * .14, S * .7), (S * .3, S * .36), (S * .56, S * .28), (S * .84, S * .5), (S * .76, S * .82), (S * .3, S * .86)], fill=(110, 100, 96))
    d.polygon([(S * .4, S * .5), (S * .5, S * .38), (S * .56, S * .56)], fill=(200, 120, 80))
    d.polygon([(S * .6, S * .66), (S * .7, S * .54), (S * .72, S * .72)], fill=(200, 120, 80))
    icons["minerio"] = _finish(_shade(im))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # pena
    d.ellipse([S * .32, S * .08, S * .64, S * .78], fill=(220, 50, 40))
    d.ellipse([S * .38, S * .3, S * .6, S * .78], fill=(40, 110, 220))
    d.line([(S * .48, S * .12), (S * .48, S * .92)], fill=(250, 220, 120), width=3 * U)
    icons["pena"] = _finish(_shade(im))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # látex
    d.polygon([(S * .5, S * .1), (S * .74, S * .52), (S * .26, S * .52)], fill=(240, 236, 220))
    d.ellipse([S * .26, S * .36, S * .74, S * .86], fill=(240, 236, 220))
    icons["latex"] = _finish(_shade(im, (255, 255, 255, 120)))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # óleo (frasco)
    d.rectangle([S * .42, S * .1, S * .58, S * .3], fill=(140, 96, 60))
    d.ellipse([S * .22, S * .28, S * .78, S * .88], fill=(200, 160, 40))
    d.ellipse([S * .3, S * .5, S * .7, S * .84], fill=(226, 180, 50))
    icons["oleo"] = _finish(_shade(im, (255, 255, 255, 110)))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # semente de guaraná
    d.ellipse([S * .2, S * .2, S * .8, S * .8], fill=(200, 40, 40))
    d.ellipse([S * .34, S * .3, S * .7, S * .7], fill=(250, 250, 245))
    d.ellipse([S * .42, S * .38, S * .64, S * .62], fill=(20, 18, 18))
    icons["semente"] = _finish(_shade(im, (255, 255, 255, 110)))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # pelo do Mapinguari
    for i in range(9):
        a = -0.9 + i * 0.22
        d.line([(S * .5, S * .86), (S * (.5 + math.sin(a) * .4), S * (.86 - math.cos(a) * .7))], fill=(120, 72, 40), width=5 * U)
    icons["pelo"] = _finish(_shade(im))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # muiraquitã (sapinho de pedra verde)
    d.ellipse([S * .24, S * .26, S * .76, S * .78], fill=(60, 170, 110))
    for x, y in [(.16, .56), (.7, .56), (.2, .2), (.66, .2)]:
        d.ellipse([S * x, S * y, S * (x + .16), S * (y + .2)], fill=(60, 170, 110))
    d.ellipse([S * .36, S * .32, S * .44, S * .4], fill=(20, 60, 40))
    d.ellipse([S * .56, S * .32, S * .64, S * .4], fill=(20, 60, 40))
    icons["muiraquita"] = _finish(_shade(im, (255, 255, 255, 120)))
    im, S = _icon_canvas(); d = ImageDraw.Draw(im)  # poção
    d.rectangle([S * .42, S * .1, S * .58, S * .32], fill=(220, 220, 230))
    d.ellipse([S * .22, S * .3, S * .78, S * .88], fill=(210, 50, 70))
    icons["pocao"] = _finish(_shade(im, (255, 255, 255, 120)))
    return icons


def small_icons():
    """Ícones dos selos (atributos, armadura, poder, energia...): 48 px, traço simples e cor forte."""
    out = {}

    def canvas():
        S = 96 * SS
        return Image.new("RGBA", (S, S), (0, 0, 0, 0)), S

    def done(im):
        S = im.width
        a = im.split()[3]
        ol = Image.new("RGBA", (S, S), (6, 8, 14, 255))
        ol.putalpha(a.filter(ImageFilter.MaxFilter(13)))
        base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        base.alpha_composite(ol)
        base.alpha_composite(_shade(im, (255, 255, 255, 90)))
        return base.resize((48, 48), Image.LANCZOS)

    im, S = canvas(); d = ImageDraw.Draw(im)  # força: punho
    d.rounded_rectangle([S * .22, S * .3, S * .78, S * .78], 14 * SS, fill=(232, 96, 72))
    for i in range(4):
        d.rounded_rectangle([S * (.22 + i * .14), S * .2, S * (.35 + i * .14), S * .44], 6 * SS, fill=(250, 130, 100))
    d.rectangle([S * .3, S * .78, S * .7, S * .9], fill=(190, 70, 52))
    out["forca"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # agilidade: pena verde
    d.ellipse([S * .3, S * .08, S * .7, S * .8], fill=(110, 220, 120))
    d.line([(S * .5, S * .14), (S * .42, S * .94)], fill=(230, 255, 230), width=4 * SS)
    out["agilidade"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # inteligência: orbe azul
    d.ellipse([S * .16, S * .16, S * .84, S * .84], fill=(80, 150, 255))
    d.ellipse([S * .3, S * .26, S * .52, S * .48], fill=(220, 240, 255))
    out["inteligencia"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # tecido: dobras roxas
    d.polygon([(S * .16, S * .2), (S * .84, S * .2), (S * .74, S * .84), (S * .5, S * .7), (S * .26, S * .84)], fill=(170, 110, 230))
    d.line([(S * .5, S * .2), (S * .5, S * .7)], fill=(120, 70, 180), width=4 * SS)
    out["tecido"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # couro: pele
    d.polygon([(S * .2, S * .16), (S * .5, S * .26), (S * .8, S * .16), (S * .72, S * .5), (S * .82, S * .84), (S * .5, S * .74), (S * .18, S * .84), (S * .28, S * .5)], fill=(196, 132, 72))
    out["couro"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # placa: placa de metal com rebites
    d.polygon([(S * .5, S * .1), (S * .84, S * .24), (S * .78, S * .66), (S * .5, S * .9), (S * .22, S * .66), (S * .16, S * .24)], fill=(196, 206, 222))
    d.line([(S * .5, S * .14), (S * .5, S * .86)], fill=(130, 140, 160), width=4 * SS)
    out["placa"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # poder: cristal
    d.polygon([(S * .5, S * .06), (S * .82, S * .4), (S * .5, S * .94), (S * .18, S * .4)], fill=(90, 220, 255))
    d.polygon([(S * .5, S * .06), (S * .62, S * .4), (S * .5, S * .94), (S * .38, S * .4)], fill=(190, 245, 255))
    out["poder"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # nível: estrela
    pts = []
    for k in range(10):
        r = S * (.44 if k % 2 == 0 else .19)
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((S * .5 + math.cos(a) * r, S * .54 + math.sin(a) * r))
    d.polygon(pts, fill=(255, 210, 80))
    out["nivel"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # energia: raio
    d.polygon([(S * .58, S * .06), (S * .22, S * .56), (S * .48, S * .56), (S * .4, S * .94), (S * .8, S * .4), (S * .54, S * .4)], fill=(255, 220, 70))
    out["energia"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # vida: coração
    d.ellipse([S * .14, S * .2, S * .52, S * .58], fill=(240, 80, 90))
    d.ellipse([S * .48, S * .2, S * .86, S * .58], fill=(240, 80, 90))
    d.polygon([(S * .16, S * .46), (S * .84, S * .46), (S * .5, S * .88)], fill=(240, 80, 90))
    out["vida"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # escudo
    d.polygon([(S * .5, S * .08), (S * .84, S * .2), (S * .8, S * .58), (S * .5, S * .92), (S * .2, S * .58), (S * .16, S * .2)], fill=(130, 170, 255))
    out["escudo"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # cadeado
    d.arc([S * .28, S * .1, S * .72, S * .56], 180, 360, fill=(200, 205, 215), width=9 * SS)
    d.line([(S * .28, S * .33), (S * .28, S * .5)], fill=(200, 205, 215), width=9 * SS)
    d.line([(S * .72, S * .33), (S * .72, S * .5)], fill=(200, 205, 215), width=9 * SS)
    d.rounded_rectangle([S * .18, S * .44, S * .82, S * .9], 8 * SS, fill=(220, 170, 70))
    d.ellipse([S * .44, S * .56, S * .56, S * .68], fill=(60, 40, 10))
    out["cadeado"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # coroa (anfitrião)
    d.polygon([(S * .14, S * .74), (S * .14, S * .3), (S * .34, S * .5), (S * .5, S * .22), (S * .66, S * .5), (S * .86, S * .3), (S * .86, S * .74)], fill=(255, 205, 80))
    out["coroa"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # chefe: caveira
    d.ellipse([S * .2, S * .12, S * .8, S * .66], fill=(236, 230, 214))
    d.rectangle([S * .32, S * .56, S * .68, S * .84], fill=(236, 230, 214))
    d.ellipse([S * .3, S * .34, S * .46, S * .5], fill=(30, 20, 20))
    d.ellipse([S * .54, S * .34, S * .7, S * .5], fill=(30, 20, 20))
    out["chefe"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # mapa / áreas
    d.polygon([(S * .12, S * .2), (S * .38, S * .12), (S * .62, S * .22), (S * .88, S * .14), (S * .88, S * .8), (S * .62, S * .88), (S * .38, S * .78), (S * .12, S * .86)], fill=(214, 190, 140))
    d.line([(S * .25, S * .7), (S * .45, S * .45), (S * .7, S * .55)], fill=(200, 60, 50), width=4 * SS)
    out["mapa"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # espada (dano)
    d.polygon([(S * .78, S * .1), (S * .9, S * .22), (S * .4, S * .7), (S * .3, S * .6)], fill=(214, 222, 236))
    d.line([(S * .22, S * .52), (S * .48, S * .78)], fill=(200, 160, 70), width=6 * SS)
    d.line([(S * .3, S * .7), (S * .14, S * .86)], fill=(120, 80, 40), width=7 * SS)
    out["espada"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # chance: trevo
    for cx, cy in [(.36, .36), (.64, .36), (.36, .64), (.64, .64)]:
        d.ellipse([S * (cx - .17), S * (cy - .17), S * (cx + .17), S * (cy + .17)], fill=(100, 210, 110))
    out["chance"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # xp: orbe verde com seta
    d.ellipse([S * .14, S * .14, S * .86, S * .86], fill=(110, 220, 140))
    d.polygon([(S * .5, S * .26), (S * .72, S * .52), (S * .58, S * .52), (S * .58, S * .74), (S * .42, S * .74), (S * .42, S * .52), (S * .28, S * .52)], fill=(240, 255, 240))
    out["xp"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # controle: redemoinho
    for k in range(3):
        r = .38 - k * .11
        d.arc([S * (.5 - r), S * (.5 - r), S * (.5 + r), S * (.5 + r)], 30 + k * 60, 300 + k * 60, fill=(190, 140, 255), width=7 * SS)
    out["controle"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # suporte: aura (cruz luminosa num círculo)
    d.ellipse([S * .12, S * .12, S * .88, S * .88], outline=(255, 230, 140), width=6 * SS)
    d.rectangle([S * .42, S * .24, S * .58, S * .76], fill=(255, 230, 140))
    d.rectangle([S * .24, S * .42, S * .76, S * .58], fill=(255, 230, 140))
    out["suporte"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # mobilidade: asa
    for k in range(4):
        d.ellipse([S * (.14 + k * .08), S * (.2 + k * .12), S * (.86 - k * .02), S * (.44 + k * .12)], fill=(120, 230, 230) if k % 2 == 0 else (90, 200, 210))
    out["mobilidade"] = done(im)
    im, S = canvas(); d = ImageDraw.Draw(im)  # arco (selo)
    d.arc([S * .12, S * .1, S * .88, S * .9], 225, 45, fill=(220, 160, 90), width=8 * SS)
    d.line([(S * .25, S * .76), (S * .75, S * .24)], fill=(240, 236, 220), width=3 * SS)
    out["arco"] = done(im)
    return out


def watermarks():
    """Fundos de janela (marca d'água): brancos com transparência, o jogo aplica bem fraco e
    tingido. 1280x720 (proporção da tela)."""
    W, H = 1280, 720
    out = {}
    # 1) emblema geométrico (losangos escalonados e raios), centrado
    S = 2
    im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = W * S / 2, H * S / 2
    for k in range(9):
        r = (60 + k * 34) * S
        w = (3 if k % 3 == 0 else 1) * S
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], outline=(255, 255, 255, 200 - k * 12), width=w)
    for k in range(24):
        a = k / 24 * math.tau
        r0, r1 = 360 * S, (420 if k % 2 == 0 else 390) * S
        d.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)], fill=(255, 255, 255, 150), width=2 * S)
    d.ellipse([cx - 440 * S, cy - 440 * S, cx + 440 * S, cy + 440 * S], outline=(255, 255, 255, 120), width=2 * S)
    for k in range(3):
        r = (24 + k * 14) * S
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=(255, 255, 255, 230 - k * 60))
    out["emblema"] = im.resize((W, H), Image.LANCZOS)
    # 2) folhagem: silhuetas de folhas grandes saindo dos cantos
    im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    rng = random.Random(4)
    def leaf(cx, cy, length, ang, width):
        g = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        pts = []
        for i in range(21):
            t = i / 20
            x = t * length
            y = math.sin(t * math.pi) * width * (1 - t * 0.3)
            pts.append((x, y))
        pts += [(x, -y) for x, y in reversed(pts)]
        ca, sa = math.cos(ang), math.sin(ang)
        gd.polygon([(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts], fill=(255, 255, 255, 200))
        gd.line([(cx, cy), (cx + length * ca, cy + length * sa)], fill=(0, 0, 0, 0), width=3 * S)
        return g
    for (ox, oy, base) in [(0, 0, 0.6), (W * S, 0, math.pi - 0.6), (0, H * S, -0.6), (W * S, H * S, math.pi + 0.6)]:
        for k in range(6):
            a = base + rng.uniform(-0.7, 0.7)
            im.alpha_composite(leaf(ox, oy, rng.uniform(260, 420) * S, a, rng.uniform(40, 70) * S))
    out["folhas"] = im.resize((W, H), Image.LANCZOS)
    # 3) constelação: estrelas, linhas finas e um círculo de mapa celeste
    im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rng = random.Random(9)
    for i in range(120):
        x, y = rng.uniform(0, W * S), rng.uniform(0, H * S)
        r = rng.choice([1, 1, 1, 2, 3]) * S
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rng.randint(90, 220)))
    for c in range(5):
        pts = [(rng.uniform(0.1, 0.9) * W * S, rng.uniform(0.1, 0.9) * H * S)]
        for i in range(rng.randint(3, 5)):
            px, py = pts[-1]
            pts.append((px + rng.uniform(-140, 140) * S, py + rng.uniform(-90, 90) * S))
        d.line(pts, fill=(255, 255, 255, 130), width=S)
        for x, y in pts:
            d.ellipse([x - 4 * S, y - 4 * S, x + 4 * S, y + 4 * S], fill=(255, 255, 255, 220))
    for k, r in enumerate([300, 330]):
        d.ellipse([W * S / 2 - r * S, H * S / 2 - r * S, W * S / 2 + r * S, H * S / 2 + r * S], outline=(255, 255, 255, 90), width=S)
    for k in range(72):
        a = k / 72 * math.tau
        r0, r1 = 300 * S, (330 if k % 6 == 0 else 312) * S
        d.line([(W * S / 2 + math.cos(a) * r0, H * S / 2 + math.sin(a) * r0), (W * S / 2 + math.cos(a) * r1, H * S / 2 + math.sin(a) * r1)], fill=(255, 255, 255, 90), width=S)
    out["constelacao"] = im.resize((W, H), Image.LANCZOS)
    return out


## Só a paleta escolhida é gerada (a Abissal); as outras ficam aqui para comparar no futuro.
PALETA_ATIVA = ["abissal"]


def main():
    for name, P in PALETAS.items():
        if name not in PALETA_ATIVA:
            continue
        out = os.path.join(ROOT, name)
        os.makedirs(out, exist_ok=True)
        panel(P).save(os.path.join(out, "moldura.png"))
        plate(P).save(os.path.join(out, "placa.png"))
        button(P).save(os.path.join(out, "botao.png"))
        button(P, fill=P["btn_hi"]).save(os.path.join(out, "botao_hover.png"))
        button(P, pressed=True).save(os.path.join(out, "botao_press.png"))
        button(P, disabled=True).save(os.path.join(out, "botao_off.png"))
        button(P, fill=P["gold"]).save(os.path.join(out, "botao_ouro.png"))
        button(P, fill=[tuple(min(255, v + 24) for v in P["gold"][0]), tuple(min(255, v + 24) for v in P["gold"][1])]).save(os.path.join(out, "botao_ouro_hover.png"))
        tab(P, False).save(os.path.join(out, "aba.png"))
        tab(P, True).save(os.path.join(out, "aba_ativa.png"))
        slot(P).save(os.path.join(out, "casa.png"))
        for r in range(4):
            slot(P, r).save(os.path.join(out, "casa_%d.png" % r))
        ring(P).save(os.path.join(out, "anel.png"))
    ic = os.path.join(ROOT, "icones")
    os.makedirs(ic, exist_ok=True)
    for k, im in icon_items().items():
        im.save(os.path.join(ic, k + ".png"))
    for k, im in watermarks().items():
        im.save(os.path.join(ROOT, "fundo_%s.png" % k))
    for k, im in small_icons().items():
        im.save(os.path.join(ic, "s_" + k + ".png"))
    print("ok")


if __name__ == "__main__":
    main()
