"""Texturas dos efeitos (magias) do jogo.

Dois usos:
  python3 tools/vfx_texturas.py provisorias
      desenha versões simples por código em game/art/vfx/ (para os efeitos funcionarem já).
  python3 tools/vfx_texturas.py preparar arte/vfx
      pega as imagens geradas por IA (fundo PRETO) em arte/vfx/<nome>.png/.jpg e grava em game/art/vfx/
      com transparência: o preto vira transparente, o brilho fica.

Nomes (os efeitos procuram por estes arquivos):
  casco_hex, onda_choque, poeira, folha, faisca, sapo_muiraquita, simbolo_provocado,
  garra (três rasgos de garra), fumaca (nuvem macia), anel_som (anel fino de grito), teia (teia de aranha)
  python3 tools/vfx_texturas.py provisorias garra fumaca   -> só essas (não mexe nas outras)
"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', 'game', 'art', 'vfx')
SIZES = {'casco_hex': 512, 'onda_choque': 512, 'poeira': 128, 'folha': 128, 'faisca': 64,
         'sapo_muiraquita': 256, 'simbolo_provocado': 128,
         'garra': 256, 'fumaca': 128, 'anel_som': 256, 'teia': 256}


def save_rgba(name, rgb, alpha):
    img = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha, 0, 255)]).astype(np.uint8)
    Image.fromarray(img, 'RGBA').save(os.path.join(OUT, name + '.png'))


def from_black(img):
    """Imagem com fundo preto -> RGBA: alfa = brilho; a cor é 'desmultiplicada' para não escurecer."""
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    lum = a.max(axis=2)
    alpha = np.clip((lum - 12) * 255.0 / 200.0, 0, 255)
    rgb = np.where(alpha[..., None] > 0, a * 255.0 / np.maximum(lum[..., None], 1), 0)
    return rgb, alpha


def draw(name, s):
    img = Image.new('RGB', (s, s), 'black')
    d = ImageDraw.Draw(img)
    c = s / 2
    if name == 'casco_hex':
        # placas de casco: hexágonos com borda dourada-esverdeada e centro levemente aceso
        r = s / 8
        h = math.sqrt(3) * r
        for col in range(-1, 12):
            for row in range(-1, 12):
                x = col * 1.5 * r
                y = row * h + (h / 2 if col % 2 else 0)
                pts = [(x + r * math.cos(math.radians(60 * k)), y + r * math.sin(math.radians(60 * k))) for k in range(6)]
                d.polygon(pts, fill=(18, 40, 22), outline=(235, 205, 110))
                inner = [(x + 0.72 * r * math.cos(math.radians(60 * k)), y + 0.72 * r * math.sin(math.radians(60 * k))) for k in range(6)]
                d.polygon(inner, outline=(120, 200, 120))
        img = img.filter(ImageFilter.GaussianBlur(1.2))
        bright = Image.eval(img, lambda v: min(255, int(v * 1.6)))
        img = Image.blend(img, bright, 0.5)
    elif name == 'onda_choque':
        for i in range(40):
            t = i / 40
            rr = c * (0.62 + 0.33 * t)
            col = (255, int(150 + 80 * (1 - abs(t - 0.6))), int(60 + 120 * (1 - t)))
            w = int(3 + 6 * (1 - abs(t - 0.6) * 1.6))
            d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col if abs(t - 0.6) < 0.5 else (0, 0, 0), width=max(w, 1))
        img = img.filter(ImageFilter.GaussianBlur(4))
        # rachaduras saindo do anel
        d = ImageDraw.Draw(img)
        rng = np.random.default_rng(3)
        for k in range(14):
            ang = rng.uniform(0, math.tau)
            x, y = c + math.cos(ang) * c * 0.55, c + math.sin(ang) * c * 0.55
            for _ in range(5):
                ang += rng.uniform(-0.5, 0.5)
                nx, ny = x + math.cos(ang) * c * 0.08, y + math.sin(ang) * c * 0.08
                d.line([x, y, nx, ny], fill=(255, 190, 90), width=2)
                x, y = nx, ny
        img = img.filter(ImageFilter.GaussianBlur(1))
    elif name == 'poeira':
        rng = np.random.default_rng(5)
        for _ in range(26):
            x, y = rng.normal(c, s * 0.12, 2)
            rr = rng.uniform(s * 0.12, s * 0.25)
            v = int(rng.uniform(90, 170))
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(v + 30, v + 10, v - 20))
        img = img.filter(ImageFilter.GaussianBlur(s * 0.08))
    elif name == 'folha':
        d.ellipse([c - s * 0.18, s * 0.08, c + s * 0.18, s * 0.92], fill=(70, 170, 70))
        d.line([c, s * 0.1, c, s * 0.95], fill=(150, 230, 120), width=3)
        for k in range(5):
            y = s * (0.25 + 0.13 * k)
            d.line([c, y, c - s * 0.15, y - s * 0.07], fill=(120, 210, 100), width=2)
            d.line([c, y, c + s * 0.15, y - s * 0.07], fill=(120, 210, 100), width=2)
        img = img.filter(ImageFilter.GaussianBlur(0.8))
    elif name == 'faisca':
        a = np.zeros((s, s, 3), np.float32)
        yy, xx = np.mgrid[0:s, 0:s] - c
        dist = np.hypot(xx, yy)
        glow = np.exp(-(dist / (s * 0.12)) ** 2) + 0.6 * np.exp(-np.abs(xx) / 2.0) * np.exp(-(yy / (s * 0.4)) ** 2) \
            + 0.6 * np.exp(-np.abs(yy) / 2.0) * np.exp(-(xx / (s * 0.4)) ** 2)
        a[..., 0] = a[..., 1] = a[..., 2] = np.clip(glow, 0, 1) * 255
        img = Image.fromarray(a.astype(np.uint8))
    elif name == 'sapo_muiraquita':
        g = (90, 230, 140)
        d.ellipse([c - s * 0.22, c - s * 0.12, c + s * 0.22, c + s * 0.3], fill=g)  # corpo
        d.ellipse([c - s * 0.17, c - s * 0.3, c + s * 0.17, c - s * 0.02], fill=g)  # cabeça
        for sx in (-1, 1):
            d.ellipse([c + sx * s * 0.11 - s * 0.06, c - s * 0.33, c + sx * s * 0.11 + s * 0.06, c - s * 0.21], fill=(180, 255, 200))  # olhos
            d.ellipse([c + sx * s * 0.3 - s * 0.1, c + s * 0.12, c + sx * s * 0.3 + s * 0.1, c + s * 0.36], fill=g)  # pernas
            d.ellipse([c + sx * s * 0.26 - s * 0.06, c - s * 0.08, c + sx * s * 0.26 + s * 0.06, c + s * 0.1], fill=g)  # braços
        d.ellipse([c - s * 0.42, c - s * 0.42, c + s * 0.42, c + s * 0.42], outline=(120, 255, 170), width=4)
        img = img.filter(ImageFilter.GaussianBlur(2))
        sharp = Image.new('RGB', (s, s), 'black')
        img = Image.blend(img, img.filter(ImageFilter.GaussianBlur(10)), 0.3)
    elif name == 'simbolo_provocado':
        # marca de raiva (quatro traços curvos) em laranja
        col = (255, 120, 40)
        for k in range(4):
            ang = math.radians(45 + 90 * k)
            x, y = c + math.cos(ang) * s * 0.2, c + math.sin(ang) * s * 0.2
            d.arc([x - s * 0.2, y - s * 0.2, x + s * 0.2, y + s * 0.2], math.degrees(ang) + 90, math.degrees(ang) + 270, fill=col, width=int(s * 0.08))
        img = img.filter(ImageFilter.GaussianBlur(1.5))
    elif name == 'garra':
        # três rasgos curvos de garra, finos nas pontas
        for k in (-1, 0, 1):
            pts = []
            for i in range(41):
                t = i / 40
                x = c + k * s * 0.17 + math.sin(t * math.pi) * s * 0.07 - s * 0.03
                y = s * (0.08 + 0.84 * t)
                pts.append((x, y, math.sin(t * math.pi)))
            for (x0, y0, w0), (x1, y1, w1) in zip(pts, pts[1:]):
                w = max(1, int(s * 0.055 * (w0 + w1) / 2))
                d.line([x0, y0, x1, y1], fill=(255, 240, 225), width=w)
        img = img.filter(ImageFilter.GaussianBlur(1.6))
    elif name == 'fumaca':
        rng = np.random.default_rng(11)
        for _ in range(18):
            x, y = rng.normal(c, s * 0.1, 2)
            rr = rng.uniform(s * 0.14, s * 0.26)
            v = int(rng.uniform(150, 230))
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(v, v, v))
        img = img.filter(ImageFilter.GaussianBlur(s * 0.1))
    elif name == 'anel_som':
        for i, (rr, w) in enumerate([(0.44, 6), (0.36, 3), (0.29, 2)]):
            v = 255 - i * 60
            d.ellipse([c - s * rr, c - s * rr, c + s * rr, c + s * rr], outline=(v, v, v), width=w)
        img = img.filter(ImageFilter.GaussianBlur(2))
    elif name == 'teia':
        # raios e espirais de teia, um pouco tortos
        rng = np.random.default_rng(7)
        n = 12
        angs = [k * math.tau / n + rng.uniform(-0.12, 0.12) for k in range(n)]
        for a in angs:
            d.line([c, c, c + math.cos(a) * c * 0.95, c + math.sin(a) * c * 0.95], fill=(235, 235, 235), width=2)
        for ring in range(1, 9):
            rr = c * 0.11 * ring
            pts = [(c + math.cos(a) * rr * rng.uniform(0.93, 1.05), c + math.sin(a) * rr * rng.uniform(0.93, 1.05)) for a in angs]
            pts.append(pts[0])
            d.line(pts, fill=(220, 220, 220), width=2)
        img = img.filter(ImageFilter.GaussianBlur(0.8))
    return img


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    mode = sys.argv[1] if len(sys.argv) > 1 else 'provisorias'
    if mode == 'provisorias':
        only = sys.argv[2:]
        for name, s in SIZES.items():
            if only and name not in only:
                continue
            rgb, alpha = from_black(draw(name, s))
            save_rgba(name, rgb, alpha)
            print('provisória:', name)
    elif mode == 'preparar':
        src = sys.argv[2]
        for name, s in SIZES.items():
            # aceita .png, .jpg, .jpeg ou .webp (o Gemini costuma entregar .jpg)
            path = next((os.path.join(src, name + ext) for ext in ('.png', '.jpg', '.jpeg', '.webp')
                         if os.path.exists(os.path.join(src, name + ext))), None)
            if path is None:
                continue
            img = Image.open(path)
            w, h = img.size
            if w != h:  # IA às vezes entrega retangular: usa o quadrado do centro
                m = min(w, h)
                img = img.crop(((w - m) // 2, (h - m) // 2, (w + m) // 2, (h + m) // 2))
            img = img.resize((s, s), Image.LANCZOS)
            rgb, alpha = from_black(img)
            save_rgba(name, rgb, alpha)
            print('preparada:', name)
