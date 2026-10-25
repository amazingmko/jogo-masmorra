"""Prepara as artes do Gemini (arte/bruto/) para o jogo.

- especializacoes/<ramo>.jpg -> game/ui/icones/s_spec_<ramo>.png (igual às funções)
- itens/<id do item>.jpg -> game/ui/icones/item_<id>.png (ícone na bolsa, oficina e loot)
- funcoes/<nome>.jpg  -> game/ui/icones/s_funcao_<nome>.png (128 px, fundo preto recortado:
  a forma fica opaca e o brilho em volta fica semitransparente)
- retratos/<heroi>.jpg -> game/ui/retratos/<heroi>.png (384 px, com a moldura, fora do círculo
  transparente) e <heroi>_rosto.png (128 px, só o miolo, recortado em círculo, para tamanhos pequenos)

Rodar: python3 tools/processar_arte.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRUTO = os.path.join(RAIZ, "arte", "bruto")


def recorta_preto(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    # cor do fundo (quase preto ou azul-noite): a mediana da borda da imagem
    borda = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    fundo = np.median(borda, axis=0)
    mx = np.abs(a - fundo).max(axis=2)
    solido = ndimage.binary_fill_holes(ndimage.binary_closing(mx > 0.35, iterations=3))
    solido = ndimage.binary_opening(solido, iterations=2)
    brilho = np.clip((mx - 0.05) / 0.6, 0, 1)
    alfa = np.where(solido, 1.0, brilho)
    alfa = ndimage.gaussian_filter(alfa, 0.8)
    alfa = np.maximum(alfa, solido.astype(np.float32))
    sem_fundo = (a - fundo * (1.0 - alfa[..., None])) / np.maximum(alfa[..., None], 1e-3)
    rgb = np.where(solido[..., None], a, np.clip(sem_fundo, 0, 1))
    out = Image.fromarray((np.dstack([rgb, alfa]) * 255).astype(np.uint8), "RGBA")
    box = out.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    if box:
        x0, y0, x1, y1 = box
        lado = max(x1 - x0, y1 - y0)
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        m = int(lado * 0.04)
        h = lado // 2 + m
        out = out.crop((cx - h, cy - h, cx + h, cy + h))
    return out


def circulo(img: Image.Image, raio_frac: float, tam: int, cy_frac: float = 0.5) -> Image.Image:
    w, h = img.size
    r = int(w * raio_frac)
    c = w // 2
    cy = int(h * cy_frac)
    rec = img.crop((c - r, cy - r, c + r, cy + r)).convert("RGBA").resize((tam, tam), Image.LANCZOS)
    m = Image.new("L", (tam * 4, tam * 4), 0)
    ImageDraw.Draw(m).ellipse((2, 2, tam * 4 - 3, tam * 4 - 3), fill=255)
    rec.putalpha(m.resize((tam, tam), Image.LANCZOS))
    return rec


def main() -> None:
    pasta = os.path.join(BRUTO, "funcoes")
    for f in sorted(os.listdir(pasta)) if os.path.isdir(pasta) else []:
        nome, ext = os.path.splitext(f)
        if ext.lower() not in (".jpg", ".jpeg", ".png"):
            continue
        out = recorta_preto(Image.open(os.path.join(pasta, f))).resize((128, 128), Image.LANCZOS)
        out.save(os.path.join(RAIZ, "game", "ui", "icones", "s_funcao_%s.png" % nome.lower()))
        print("função", nome)
    pasta = os.path.join(BRUTO, "especializacoes")
    for f in sorted(os.listdir(pasta)) if os.path.isdir(pasta) else []:
        nome, ext = os.path.splitext(f)
        if ext.lower() not in (".jpg", ".jpeg", ".png"):
            continue
        out = recorta_preto(Image.open(os.path.join(pasta, f))).resize((128, 128), Image.LANCZOS)
        out.save(os.path.join(RAIZ, "game", "ui", "icones", "s_spec_%s.png" % nome.lower()))
        print("especialização", nome)
    pasta = os.path.join(BRUTO, "itens")
    for f in sorted(os.listdir(pasta)) if os.path.isdir(pasta) else []:
        nome, ext = os.path.splitext(f)
        if ext.lower() not in (".jpg", ".jpeg", ".png"):
            continue
        out = recorta_preto(Image.open(os.path.join(pasta, f))).resize((128, 128), Image.LANCZOS)
        out.save(os.path.join(RAIZ, "game", "ui", "icones", "item_%s.png" % nome.lower()))
        print("item", nome)
    pasta = os.path.join(BRUTO, "retratos")
    destino = os.path.join(RAIZ, "game", "ui", "retratos")
    os.makedirs(destino, exist_ok=True)
    for f in sorted(os.listdir(pasta)) if os.path.isdir(pasta) else []:
        nome, ext = os.path.splitext(f)
        if ext.lower() not in (".jpg", ".jpeg", ".png"):
            continue
        img = Image.open(os.path.join(pasta, f)).convert("RGB")
        circulo(img, 0.49, 384).save(os.path.join(destino, "%s.png" % nome.lower()))
        circulo(img, 0.25, 128, 0.42).save(os.path.join(destino, "%s_rosto.png" % nome.lower()))
        print("retrato", nome)


if __name__ == "__main__":
    main()
