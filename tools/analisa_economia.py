"""Panorama da economia: quantas runs até cada raridade de equipamento e até cada nível.

Lê as receitas (game/data/recipes), as curvas de XP (herói e profissão) e o que os robôs do
simulador (tests/sim_balance.gd) pegaram por run em cada dificuldade, e estima, por herói:
  - runs para fechar o conjunto Comum, Raro, Épico e Lendário (arma + 5 peças, + escudo da Icamiaba)
    contando a cadeia (o Raro consome o Comum...), a chance de falha da Oficina (falha perde metade
    dos reagentes) e o treino da profissão até o nível exigido (5, 20, 40);
  - runs para os níveis 10, 20, 30 e 40 do herói.

Uso: python3 tools/analisa_economia.py <pasta com r_*.log do simulador> [mais pastas...]
     (só usa as runs vencidas; a recompensa do grupo vem do próprio simulador)
"""
import glob
import json
import math
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAR = ["comum", "raro", "epico", "lendario"]
RAR_NOME = ["Comum", "Raro", "Épico", "Lendário"]
BASE_CHANCE = [0.90, 0.65, 0.40, 0.15]
LEVEL_BONUS = [0.01, 0.01, 0.005, 0.005]
STREAK = 0.10
MAX_CHANCE = 0.95
FAIL_XP = 0.3
CRAFT_GOLD = [20, 80, 250, 800]
SETS = {
    "icamiaba": ["lanca_ipe", "escudo_casco", "elmo_placa", "peitoral_placa", "manoplas_placa", "grevas_placa", "botas_placa"],
    "mateira": ["arco_simples", "capuz_couro", "armadura_couro", "luvas_couro", "calca_couro", "botas_couro"],
    "encantado": ["cajado_aprendiz", "capuz_tecido", "tunica_tecido", "luvas_tecido", "calca_tecido", "sandalias_tecido"],
    "druida": ["cajado_raiz", "capuz_couro", "armadura_couro", "luvas_couro", "calca_couro", "botas_couro"],
}
NOMES = {"Couro de Jacaré": "couro_jacare", "Fibra de Tucum": "fibra_tucum", "Látex de Seringueira": "latex_seringueira",
         "Madeira de Lei": "madeira_lei", "Minério de Ferro": "minerio_ferro", "Pelo de Mapinguari": "pelo_mapinguari",
         "Pena de Arara": "pena_arara", "Óleo de Andiroba": "oleo_andiroba", "Muiraquitã": "muiraquita"}
DIFS = ["Normal", "Difícil", "Heroico", "Mítico"]


def receita(item, r):
    txt = open(os.path.join(RAIZ, "game/data/recipes/%s_%s.tres" % (item, RAR[r]))).read()
    ing = dict((k, int(v)) for k, v in re.findall(r'"([a-z_]+)":\s*(\d+)', txt.split("ingredients", 1)[1].split("}", 1)[0]))
    lvl = int(re.search(r"required_level = (\d+)", txt).group(1)) if "required_level" in txt else 1
    xp = int(re.search(r"xp_reward = (\d+)", txt).group(1))
    prof = re.search(r'profession_id = &"([a-z]+)"', txt).group(1)
    return ing, lvl, xp, prof


def prof_xp_to(level):
    return sum(round(60 * 1.045 ** (l - 1)) for l in range(1, level))


def hero_xp_to(level):
    return sum(round(200 * 1.12 ** (l - 1)) for l in range(1, level))


def craft_esperado(r, prof_lvl, req):
    """Tentativas esperadas e fração de reagentes gasta (sucesso gasta 1, falha 0,5), com a sequência de falhas."""
    above = max(prof_lvl - req, 0)
    p0 = min(BASE_CHANCE[r] + above * LEVEL_BONUS[r], MAX_CHANCE)
    gasto, tent, chega = 0.0, 0.0, 1.0
    for k in range(40):
        p = min(p0 + k * STREAK, MAX_CHANCE)
        tent += chega
        gasto += chega * (p * 1.0 + (1 - p) * 0.5)
        chega *= (1 - p)
        if chega < 1e-6:
            break
    return tent, gasto


GROUP_PER_EXTRA = 0.15  # Força da Aldeia (main.gd GROUP_REWARD_PER_EXTRA)


def renda_base(pastas):
    """Renda por run VENCIDA de um jogador sozinho, por dificuldade: junta todos os tamanhos de
    grupo, tirando a Força da Aldeia (depois ela é posta de volta para cada tamanho)."""
    out = {}
    for pasta in pastas:
        for f in glob.glob(os.path.join(pasta, "r_*.log")):
            for linha in open(f):
                if "RESULTADO_JSON" not in linha:
                    continue
                r = json.loads(linha.split(" ", 1)[1])
                if r["result"] != "venceu":
                    continue
                k = 1.0 + GROUP_PER_EXTRA * (len(r["party"]) - 1)
                o = out.setdefault(r["diff"], {"n": 0, "mat": {}, "xp": 0, "gold": 0})
                o["n"] += 1
                o["xp"] += r["xp"]
                o["gold"] += r["gold"]
                for nome, q in r["loot"].items():
                    mid = NOMES.get(nome.split(" (")[0])
                    if mid:
                        o["mat"][mid] = o["mat"].get(mid, 0) + q / k
    for o in out.values():
        o["mat"] = {k: v / o["n"] for k, v in o["mat"].items()}
        o["xp"] /= o["n"]
        o["gold"] /= o["n"]
    return out


def renda(pastas):
    """Renda por dificuldade e tamanho do grupo (1 a 4), a partir da renda base."""
    base = renda_base(pastas)
    out = {}
    for d, o in base.items():
        for n in (1, 2, 3, 4):
            k = 1.0 + GROUP_PER_EXTRA * (n - 1)
            out[(d, n)] = {"n": o["n"], "mat": {m: v * k for m, v in o["mat"].items()}, "xp": o["xp"], "gold": o["gold"]}
    return out


def renda_antiga(pastas):
    """Média de reagentes, XP e ouro por run VENCIDA, por dificuldade e tamanho do grupo."""
    out = {}
    for pasta in pastas:
        for f in glob.glob(os.path.join(pasta, "r_*.log")):
            for linha in open(f):
                if "RESULTADO_JSON" not in linha:
                    continue
                r = json.loads(linha.split(" ", 1)[1])
                if r["result"] != "venceu":
                    continue
                key = (r["diff"], len(r["party"]))
                o = out.setdefault(key, {"n": 0, "mat": {}, "xp": 0, "gold": 0})
                o["n"] += 1
                o["xp"] += r["xp"]
                o["gold"] += r["gold"]
                for nome, q in r["loot"].items():
                    mid = NOMES.get(nome.split(" (")[0])
                    if mid:
                        o["mat"][mid] = o["mat"].get(mid, 0) + q
    for o in out.values():
        o["mat"] = {k: v / o["n"] for k, v in o["mat"].items()}
        o["xp"] /= o["n"]
        o["gold"] /= o["n"]
    return out


def custo_conjunto(hero, alvo, prof_lvl):
    """Reagentes, ouro e XP de profissão para levar o conjunto do herói de (alvo-1) para alvo."""
    mats, gold, xp = {}, 0.0, 0.0
    for item in SETS[hero]:
        ing, req, xpr, _ = receita(item, alvo)
        tent, gasto = craft_esperado(alvo, prof_lvl, req)
        for k, v in ing.items():
            mats[k] = mats.get(k, 0) + v * gasto
        gold += CRAFT_GOLD[alvo] * tent
        xp += xpr * (1 + (tent - 1) * FAIL_XP)
    return mats, gold, xp


def runs_para(mats, ganho):
    """Runs até juntar os reagentes, no ritmo de uma dificuldade (o reagente mais lento manda)."""
    pior, qual = 0.0, ""
    for k, v in mats.items():
        g = ganho.get(k, 0.0)
        n = math.inf if g <= 0 else v / g
        if n > pior:
            pior, qual = n, k
    return pior, qual


def main():
    pastas = sys.argv[1:]
    rend = renda(pastas)
    print("Renda média por run vencida de UM jogador (sem a Força da Aldeia; em grupo: +15% por parceiro):")
    for (d, n), o in sorted(rend.items()):
        if n != 1:
            continue
        mats = ", ".join("%s %.0f" % (k, v) for k, v in sorted(o["mat"].items()))
        print("  %s (%d runs): XP %.0f, ouro %.0f | %s" % (DIFS[d], o["n"], o["xp"], o["gold"], mats))
    # caminho: Comum farmando no Normal, Raro no Difícil, Épico no Heroico, Lendário no Mítico
    for tamanho in (1, 2, 4):
        print("\n=== Grupo de %d (o caminho: Comum no Normal, Raro no Difícil, Épico no Heroico, Lendário no Mítico) ===" % tamanho)
        for hero in SETS:
            linha = []
            prof_lvl, prof_xp = 1, 0.0
            total = 0.0
            for alvo, dif in ((0, 0), (1, 1), (2, 2), (3, 3)):
                key = (dif, tamanho) if (dif, tamanho) in rend else next((k for k in sorted(rend) if k[0] == dif), None)
                if key is None:
                    linha.append("%s: sem dados" % RAR_NOME[alvo])
                    continue
                _, req, _, _ = receita(SETS[hero][0], alvo)
                # treino de profissão até o nível exigido (fazendo Comuns, a receita mais barata)
                treino_mats = {}
                falta = max(prof_xp_to(req) - prof_xp, 0)
                if falta > 0:
                    ing, _, xpr, _ = receita(SETS[hero][0], 0)
                    vezes = falta / xpr
                    for k, v in ing.items():
                        treino_mats[k] = v * vezes
                    prof_xp += falta
                prof_lvl = max(prof_lvl, req)
                mats, gold, xp = custo_conjunto(hero, alvo, prof_lvl)
                for k, v in treino_mats.items():
                    mats[k] = mats.get(k, 0) + v
                prof_xp += xp
                while prof_xp >= prof_xp_to(prof_lvl + 1) and prof_lvl < 100:
                    prof_lvl += 1
                n, gargalo = runs_para(mats, rend[key]["mat"])
                total += n
                linha.append("%s: %.0f runs no %s (gargalo %s%s)" % (RAR_NOME[alvo], n, DIFS[dif], gargalo,
                    ", inclui treino da profissão" if treino_mats else ""))
            print("  %-9s %s | total ~%.0f runs" % (hero, " ; ".join(linha), total))
    print("\n=== Nível do herói (XP de runs vencidas) ===")
    for tamanho in (1, 2, 4):
        for nivel, dif in ((10, 0), (20, 1), (30, 2), (40, 3)):
            key = (dif, tamanho) if (dif, tamanho) in rend else next((k for k in sorted(rend) if k[0] == dif), None)
            if key is None:
                continue
            ant = {10: 1, 20: 10, 30: 20, 40: 30}[nivel]
            xp = hero_xp_to(nivel) - hero_xp_to(ant)
            print("  grupo de %d: nível %d -> %d: %.1f runs no %s (%.0f XP por run)" % (tamanho, ant, nivel, xp / rend[key]["xp"], DIFS[dif], rend[key]["xp"]))


if __name__ == "__main__":
    main()
