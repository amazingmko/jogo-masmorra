class_name Talents
extends RefCounted
## Árvore de talentos de cada herói: 3 ramos com 4 fileiras.
##  - 1 ponto a cada 2 níveis (20 no nível 40).
##  - A fileira abre com pontos gastos no MESMO ramo: 0, 3, 6 e 10.
##  - A fileira 4 é o talento máximo (1 ponto, muda o jeito de jogar).
##  - Redistribuir é grátis (no hub).
## Os pontos gastos ficam no progresso do herói: {"talents": {"couro_anta": 2, ...}}.
## Quem usa cada talento (kits, HeroStats, Player) só pergunta o nível dele: rank(talents, id).

const ROW_REQUIREMENT := [0, 3, 6, 10]
const LEVELS_PER_POINT := 2

## hero_id -> lista de ramos {id, name, role, talents: [{id, name, row, max, desc}]}
## Em "desc", {v} é trocado pelo valor do nível atual (ou do 1º, se ainda não tem ponto).
const TREES := {
	&"icamiaba": [
		{"id": "protecao", "name": "Proteção", "role": "aguentar a pancada", "talents": [
			{"id": "couro_anta", "name": "Couro de Anta", "row": 0, "max": 3, "per": 4, "desc": "+{v}% de armadura"},
			{"id": "escudo_firme", "name": "Escudo Firme", "row": 0, "max": 3, "per": 3, "desc": "+{v}% de chance de bloqueio"},
			{"id": "casco_vivo", "name": "Casco Vivo", "row": 1, "max": 2, "per": 1.5, "desc": "Muralha de Casco dura +{v} s"},
			{"id": "pele_pedra", "name": "Pele de Pedra Verde", "row": 1, "max": 1, "per": 30, "desc": "Quando o escudo zera: {v}% menos dano por 3 s (no máximo a cada 20 s)"},
			{"id": "guarda_imovel", "name": "Guarda Imóvel", "row": 2, "max": 2, "per": 5, "desc": "Parada, bloqueia +{v}%"},
			{"id": "muiraquita_ancestral", "name": "Muiraquitã Ancestral", "row": 2, "max": 1, "per": 2, "desc": "O Muiraquitã salva {v} vezes por andar"},
			{"id": "muralha_espelhada", "name": "Muralha Espelhada", "row": 3, "max": 1, "per": 40, "desc": "Durante a Muralha, cada golpe segurado devolve {v}% do dano ao atacante"},
		]},
		{"id": "furia", "name": "Fúria", "role": "bater forte", "talents": [
			{"id": "ponta_pedra", "name": "Ponta de Pedra Verde", "row": 0, "max": 3, "per": 4, "desc": "+{v}% de dano da lança"},
			{"id": "golpe_largo", "name": "Golpe Largo", "row": 0, "max": 2, "per": 15, "desc": "O golpe abre +{v}° e acerta mais inimigos"},
			{"id": "revide_feroz", "name": "Revide Feroz", "row": 1, "max": 2, "per": 25, "desc": "O Revide dá +{v}% de dano extra"},
			{"id": "terceiro_golpe", "name": "Terceiro Golpe", "row": 1, "max": 1, "per": 50, "desc": "O 3º golpe do combo causa +{v}% e atordoa por 0,8 s"},
			{"id": "sede_batalha", "name": "Sede de Batalha", "row": 2, "max": 2, "per": 3, "desc": "Cada abate cura {v}% da vida máxima"},
			{"id": "lanca_certeira", "name": "Lança Certeira", "row": 2, "max": 1, "per": 150, "desc": "O Provocar arremessa a lança no inimigo mais distante ({v}% de dano) e o puxa para perto"},
			{"id": "furia_icamiaba", "name": "Fúria Icamiaba", "row": 3, "max": 1, "per": 15, "desc": "Ao bloquear, {v}% de chance de um contragolpe giratório em todos em volta"},
		]},
		{"id": "guardia", "name": "Guardiã", "role": "controlar os inimigos", "talents": [
			{"id": "grito_forte", "name": "Grito Forte", "row": 0, "max": 3, "per": 1, "desc": "Raio do Provocar +{v} m"},
			{"id": "voz_tribo", "name": "Voz da Tribo", "row": 0, "max": 2, "per": 5, "desc": "Provocados batem mais {v}% mais fraco"},
			{"id": "chao_tremido", "name": "Chão Tremido", "row": 1, "max": 2, "per": 20, "desc": "O Provocar deixa os inimigos {v}% mais lentos por 3 s"},
			{"id": "folego_curto", "name": "Fôlego Curto", "row": 1, "max": 1, "per": 3, "desc": "O Provocar recarrega {v} s mais rápido"},
			{"id": "guarda_vingativa", "name": "Guarda Vingativa", "row": 2, "max": 2, "per": 3, "desc": "+{v}% de armadura por inimigo provocado, enquanto durar"},
			{"id": "muralha_avancada", "name": "Muralha Avançada", "row": 2, "max": 1, "per": 4, "desc": "Ao ativar a Muralha, empurra para longe os inimigos a até {v} m"},
			{"id": "grito_amazonas", "name": "Grito das Amazonas", "row": 3, "max": 1, "per": 20, "desc": "Provocados recebem +{v}% de dano; cada Provocar carrega +10 da ultimate"},
		]},
	],
	&"mateira": [
		{"id": "precisao", "name": "Precisão", "role": "o arco", "talents": [
			{"id": "corda_tensa", "name": "Corda Tensa", "row": 0, "max": 3, "per": 4, "desc": "+{v}% de dano das flechas"},
			{"id": "mao_firme", "name": "Mão Firme", "row": 0, "max": 3, "per": 3, "desc": "+{v}% de crítico"},
			{"id": "olho_gaviao", "name": "Olho de Gavião", "row": 1, "max": 2, "per": 1, "desc": "Olho de Caçadora vale {v} m mais perto e dá +5% de crítico por ponto"},
			{"id": "flecha_perfurante", "name": "Flecha Perfurante", "row": 1, "max": 1, "per": 60, "desc": "A flecha atravessa o primeiro inimigo; o segundo leva {v}%"},
			{"id": "tiro_certeiro", "name": "Tiro Certeiro", "row": 2, "max": 2, "per": 15, "desc": "O crítico causa +{v}% de dano"},
			{"id": "respiracao_calma", "name": "Respiração Calma", "row": 2, "max": 1, "per": 1.5, "desc": "Depois de {v} s parada, o próximo tiro é crítico garantido"},
			{"id": "chuva_flechas", "name": "Chuva de Flechas", "row": 3, "max": 1, "per": 5, "desc": "A cada {v} tiros, o seguinte sai como 3 flechas em leque"},
		]},
		{"id": "armadilheira", "name": "Armadilheira", "role": "prender e envenenar", "talents": [
			{"id": "cipo_grosso", "name": "Cipó Grosso", "row": 0, "max": 3, "per": 0.5, "desc": "A armadilha prende +{v} s"},
			{"id": "maos_ageis", "name": "Mãos Ágeis", "row": 0, "max": 2, "per": 1.5, "desc": "A armadilha recarrega {v} s mais rápido"},
			{"id": "espinhos", "name": "Espinhos", "row": 1, "max": 2, "per": 20, "desc": "O bicho preso leva {v}% do dano do arco a cada segundo"},
			{"id": "bolsa_cipo", "name": "Bolsa de Cipó", "row": 1, "max": 1, "per": 2, "desc": "Guarda {v} armadilhas (cargas)"},
			{"id": "presa_marcada", "name": "Presa Marcada", "row": 2, "max": 2, "per": 10, "desc": "O bicho preso leva +{v}% de dano"},
			{"id": "cipo_alastra", "name": "Cipó que Alastra", "row": 2, "max": 1, "per": 2, "desc": "Ao prender, prende também os inimigos a até {v} m"},
			{"id": "timbo", "name": "Armadilha de Timbó", "row": 3, "max": 1, "per": 3, "desc": "Quando solta o bicho, explode em veneno ({v} m): 30% do dano do arco por segundo, por 4 s"},
		]},
		{"id": "mata", "name": "Mata", "role": "movimento e harpia", "talents": [
			{"id": "pes_leves", "name": "Pés Leves", "row": 0, "max": 3, "per": 3, "desc": "+{v}% de velocidade"},
			{"id": "rastro_longo", "name": "Rastro Longo", "row": 0, "max": 2, "per": 1, "desc": "Rastro Leve dura +{v} s"},
			{"id": "atirar_correndo", "name": "Atirar Correndo", "row": 1, "max": 2, "per": 15, "desc": "Atirando andando, mantém +{v}% da velocidade (55% → 70% → 85%)"},
			{"id": "pena_gaviao", "name": "Pena de Gavião", "row": 1, "max": 1, "per": 3, "desc": "A Harpia dura +{v} s"},
			{"id": "garras_afiadas", "name": "Garras Afiadas", "row": 2, "max": 2, "per": 20, "desc": "Mergulhos da Harpia causam +{v}% de dano"},
			{"id": "vinculo", "name": "Vínculo", "row": 2, "max": 1, "per": 1, "desc": "Cada abate com a Harpia ativa a mantém +{v} s"},
			{"id": "revoada", "name": "Revoada", "row": 3, "max": 1, "per": 40, "desc": "A Harpia acompanha sempre ({v}% do dano); a ultimate vira Fúria da Harpia: dano em dobro por 8 s"},
		]},
	],
}


static func has_tree(hero_id: StringName) -> bool:
	return TREES.has(hero_id)


static func branches(hero_id: StringName) -> Array:
	return TREES.get(hero_id, [])


static func points_for_level(level: int) -> int:
	return maxi(level, 0) / LEVELS_PER_POINT


static func spent(talents: Dictionary) -> int:
	var total := 0
	for k in talents:
		total += int(talents[k])
	return total


static func rank(talents: Dictionary, id: String) -> int:
	return int(talents.get(id, 0))


## Valor do talento no nível atual (per × rank). Ex.: couro_anta com 2 pontos = 8 (%).
static func value(talents: Dictionary, id: String, hero_id: StringName) -> float:
	var t := find(hero_id, id)
	return float(t.get("per", 0)) * rank(talents, id) if not t.is_empty() else 0.0


static func find(hero_id: StringName, id: String) -> Dictionary:
	for b in branches(hero_id):
		for t in b.talents:
			if t.id == id:
				return t
	return {}


static func branch_of(hero_id: StringName, id: String) -> Dictionary:
	for b in branches(hero_id):
		for t in b.talents:
			if t.id == id:
				return b
	return {}


static func spent_in_branch(talents: Dictionary, branch: Dictionary) -> int:
	var total := 0
	for t in branch.talents:
		total += rank(talents, t.id)
	return total


static func row_open(talents: Dictionary, branch: Dictionary, row: int) -> bool:
	return spent_in_branch(talents, branch) >= ROW_REQUIREMENT[row]


## "" se dá para pôr mais um ponto; senão, o motivo.
static func can_add(talents: Dictionary, hero_id: StringName, id: String, level: int) -> String:
	var t := find(hero_id, id)
	if t.is_empty():
		return "Talento desconhecido."
	if rank(talents, id) >= int(t.max):
		return "Já está no máximo."
	if spent(talents) >= points_for_level(level):
		return "Sem pontos livres (1 ponto a cada 2 níveis)."
	var b := branch_of(hero_id, id)
	if not row_open(talents, b, int(t.row)):
		return "Gaste %d pontos em %s para abrir esta fileira." % [ROW_REQUIREMENT[int(t.row)], b.name]
	return ""


## Texto do efeito com o valor atual (ou o do 1º ponto, se ainda não tem).
static func describe(t: Dictionary, current_rank: int) -> String:
	var v := float(t.per) * maxi(current_rank, 1)
	var shown := str(int(v)) if is_equal_approx(v, round(v)) else String.num(v, 1).replace(".", ",")
	return String(t.desc).replace("{v}", shown)


## Tira pontos de talentos que não existem mais e os que passaram do máximo ou dos pontos do nível.
static func sanitize(talents: Dictionary, hero_id: StringName, level: int) -> Dictionary:
	var out := {}
	for k in talents:
		var t := find(hero_id, String(k))
		if t.is_empty():
			continue
		var r := clampi(int(talents[k]), 0, int(t.max))
		if r > 0:
			out[String(k)] = r
	if spent(out) > points_for_level(level):
		return {}  # nível baixou (não deveria): começa de novo
	return out


## Atributos simples dos talentos (o resto fica nos kits).
static func apply_stats(s: HeroStats, hero_id: StringName, talents: Dictionary) -> void:
	if talents.is_empty():
		return
	var v := func(id: String) -> float: return value(talents, id, hero_id)
	s.armor = int(round(s.armor * (1.0 + v.call("couro_anta") / 100.0)))
	s.damage_reduction = clampf(float(s.armor) / (float(s.armor) + 200.0), 0.0, 0.75)
	if s.block_chance > 0.0:
		s.block_chance = clampf(s.block_chance + v.call("escudo_firme") / 100.0, 0.0, HeroStats.MAX_BLOCK)
	var dmg: float = v.call("ponta_pedra") + v.call("corda_tensa")
	s.weapon.damage = maxi(int(round(s.weapon.damage * (1.0 + dmg / 100.0))), 1)
	s.crit_chance = clampf(s.crit_chance + v.call("mao_firme") / 100.0, 0.0, 1.0)
	s.move_speed *= 1.0 + v.call("pes_leves") / 100.0
