"""Prepara as artes do Gemini (arte/bruto/) para o jogo.

- especializacoes/<ramo>.jpg -> game/ui/icones/s_spec_<ramo>.png (igual às funções)
- itens/<id do item>.jpg -> game/ui/icones/item_<id>.png (ícone na bolsa, oficina e loot)
- funcoes/<nome>.jpg  -> game/ui/icones/s_funcao_<nome>.png (128 px, fundo preto recortado:
  a forma fica opaca e o brilho em volta fica semitransparente)
- interface/<peça>.jpg -> game/ui/encante/ (paleta "encante" da UiStyle): moldura, placa, botões
  (com as versões acesa/apertada/desligada feitas aqui), casa de item (+ borda em cada raridade),
  abas, anel, selo (só o losango), barra, botões redondos da luta e joystick
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


def _alfa(img: Image.Image, preencher: bool = True):
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    borda = np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3), a[:, :8].reshape(-1, 3), a[:, -8:].reshape(-1, 3)])
    fundo = np.median(borda, axis=0)
    mx = np.abs(a - fundo).max(axis=2)
    solido = ndimage.binary_closing(mx > 0.12, iterations=3)
    if preencher:
        solido = ndimage.binary_fill_holes(solido)
    solido = ndimage.binary_opening(solido, iterations=2)
    # só o maior pedaço (some poeira solta no fundo)
    lab, n = ndimage.label(solido)
    if n > 1:
        tam = ndimage.sum(solido, lab, range(1, n + 1))
        solido = lab == (int(np.argmax(tam)) + 1) if not preencher else np.isin(lab, [i + 1 for i in range(n) if tam[i] > tam.max() * 0.02])
    alfa = ndimage.gaussian_filter(solido.astype(np.float32), 1.0)
    alfa = np.maximum(alfa, ndimage.binary_erosion(solido, iterations=1).astype(np.float32))
    return a, alfa


def recorta_ui(img: Image.Image, preencher: bool = True) -> Image.Image:
    """Peça de interface: tira o fundo preto e recorta justo (sem deixar quadrado)."""
    a, alfa = _alfa(img, preencher)
    out = Image.fromarray((np.dstack([a, alfa]) * 255).astype(np.uint8), "RGBA")
    box = out.getchannel("A").point(lambda v: 255 if v > 30 else 0).getbbox()
    return out.crop(box) if box else out


def _brilho(img: Image.Image, k: float, sat: float = 1.0) -> Image.Image:
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb = a[..., :3]
    if sat != 1.0:
        g = rgb.mean(axis=2, keepdims=True)
        rgb = g + (rgb - g) * sat
    rgb = np.clip(rgb * k, 0, 1)
    return Image.fromarray((np.dstack([rgb, a[..., 3]]) * 255).astype(np.uint8), "RGBA")


def _tinge_borda(img: Image.Image, cor, largura: float) -> Image.Image:
    """Pinta a borda (faixa de fora, `largura` em fração do lado) na cor da raridade."""
    a = np.asarray(img).astype(np.float32) / 255.0
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / float(min(w, h))
    m = np.clip((largura - d) / (largura * 0.35), 0, 1)[..., None]
    rgb = a[..., :3]
    lum = rgb.mean(axis=2, keepdims=True)
    alvo = np.clip(np.array(cor)[None, None, :] * (0.45 + lum * 1.3), 0, 1)
    rgb = rgb * (1 - m * 0.85) + alvo * m * 0.85
    return Image.fromarray((np.dstack([rgb, a[..., 3]]) * 255).astype(np.uint8), "RGBA")


def _losango(img: Image.Image) -> Image.Image:
    """Do selo quadrado, só o losango de dentro (as pontas encostam no meio de cada lado)."""
    w, h = img.size
    m = Image.new("L", (w * 4, h * 4), 0)
    ImageDraw.Draw(m).polygon([(w * 2, 0), (w * 4, h * 2), (w * 2, h * 4), (0, h * 2)], fill=255)
    m = m.resize((w, h), Image.LANCZOS)
    out = img.copy()
    out.putalpha(Image.fromarray(np.minimum(np.asarray(img.getchannel("A")), np.asarray(m))))
    return out


def _cabe(img: Image.Image, largura: int = 0, altura: int = 0) -> Image.Image:
    w, h = img.size
    if largura and altura:
        return img.resize((largura, altura), Image.LANCZOS)
    if largura:
        return img.resize((largura, max(int(round(h * largura / w)), 1)), Image.LANCZOS)
    return img.resize((max(int(round(w * altura / h)), 1), altura), Image.LANCZOS)


def interface() -> None:
    pasta = os.path.join(BRUTO, "interface")
    if not os.path.isdir(pasta):
        return
    dest = os.path.join(RAIZ, "game", "ui", "encante")
    os.makedirs(dest, exist_ok=True)

    def abre(nome, preencher=True):
        for ext in (".jpg", ".jpeg", ".png"):
            f = os.path.join(pasta, nome + ext)
            if os.path.exists(f):
                return recorta_ui(Image.open(f), preencher)
        return None

    def salva(img, nome):
        img.save(os.path.join(dest, nome + ".png"))
        print("interface", nome, img.size)

    if (m := abre("moldura")) is not None:
        salva(_cabe(m, 320, 320), "moldura")
    if (p := abre("placa")) is not None:
        salva(_cabe(p, 0, 76), "placa")
    if (b := abre("botao")) is not None:
        b = _cabe(b, 0, 60)
        salva(b, "botao")
        salva(_brilho(b, 1.18), "botao_hover")
        salva(_brilho(b, 0.78), "botao_press")
        salva(_brilho(b, 0.62, 0.25), "botao_off")
        salva(_cabe(_brilho(b, 0.72), 150, 48), "aba")
        salva(_cabe(_brilho(b, 1.3), 150, 48), "aba_ativa")
    if (g := abre("botao_ouro")) is not None:
        g = _cabe(g, 0, 60)
        salva(g, "botao_ouro")
        salva(_brilho(g, 1.15), "botao_ouro_hover")
    if (c := abre("casa")) is not None:
        c = _cabe(c, 80, 80)
        salva(c, "casa")
        for i, cor in enumerate([(0.85, 0.83, 0.9), (0.3, 0.64, 1.0), (0.75, 0.42, 1.0), (1.0, 0.65, 0.24)]):
            salva(_tinge_borda(c, cor, 0.13), "casa_%d" % i)
    if (r := abre("anel_portal", False)) is not None:
        salva(_cabe(r, 256, 256), "anel")
    if (s := abre("selo")) is not None:
        salva(_cabe(_losango(s), 48, 48), "selo_losango")
    if (br := abre("moldura_barra")) is not None:
        salva(_cabe(br, 0, 24), "barra")
    for nome in ("botao_ataque", "botao_habilidade", "joystick_base", "joystick_pino"):
        if (r := abre(nome)) is not None:
            salva(_cabe(r, 256, 256), nome)
    # peças pequenas que não vieram do Gemini: as da paleta antiga
    antiga = os.path.join(RAIZ, "game", "ui", "abissal")
    for nome in ("conta", "conta_vazia", "selo_brilho", "selo_ponto", "selo_placa"):
        if not os.path.exists(os.path.join(dest, nome + ".png")):
            Image.open(os.path.join(antiga, nome + ".png")).save(os.path.join(dest, nome + ".png"))


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
    interface()
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
