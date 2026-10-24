extends SceneTree
## Provações do Folclore:
## - regras: o herói para no nível 10 (barra cheia) até vencer; vencer cobra o ouro uma vez,
##   guarda as estrelas, sobe com a XP guardada e vai até o próximo teto (20); save guarda tudo;
## - as 4 provas numa clareira de verdade (vitória e derrota de cada uma):
##   Muralha (totem atrai os bichos), Caçada (macaco foge e pula a cada acerto),
##   Cheia (fora da ilha machuca, ilhas mudam), Viveiro (cura do Druida cura as mudas).
## Rodar: godot --headless --fixed-fps 60 --path . --script res://tests/flow_provacoes.gd

var _ok := true
var gs
var db


func check(cond: bool, label: String) -> void:
	_ok = _ok and cond
	print(("ok: " if cond else "FALHOU: "), label)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	gs = root.get_node("GameState")
	db = root.get_node("ItemDB")
	var backup: Dictionary = gs.to_dict()
	gs.debug_clear_talents()
	_rules()
	for hero in ["icamiaba", "mateira", "encantado", "druida"]:
		await _trial(hero, true)
		await _trial(hero, false)
	gs.run_trial = {}
	gs.from_dict(backup)
	gs.save()
	print("fim: ", "TUDO OK" if _ok else "COM FALHAS")
	quit(0 if _ok else 1)


func _rules() -> void:
	var P = load("res://game/scripts/systems/progression.gd")
	var p: Dictionary = gs.progress(&"mateira")
	p.level = 9
	p.xp = 0
	p.erase("trials")
	gs.add_xp(&"mateira", 999999)
	check(int(p.level) == 10, "XP de sobra para no nível 10 (está no %d)" % p.level)
	check(int(p.xp) == P.xp_to_next(10), "no teto a barra fica cheia")
	check(gs.trial_pending(&"mateira") == 10, "Provação do nível 10 disponível")
	check(gs.level_cap(&"mateira") == 10, "teto atual 10")
	gs.coins = 600
	gs.complete_trial(&"mateira", 10, 2)
	check(gs.coins == 100, "vencer cobra 500 de ouro (sobrou %d)" % gs.coins)
	check(int(p.level) == 11, "a XP guardada conta: subiu para o 11")
	check(gs.trial_stars(&"mateira", 10) == 2, "guardou 2 estrelas")
	gs.complete_trial(&"mateira", 10, 3)
	check(gs.coins == 100 and gs.trial_stars(&"mateira", 10) == 3, "repetir não cobra de novo e melhora as estrelas")
	gs.add_xp(&"mateira", 99999999)
	check(int(p.level) == 20 and gs.trial_pending(&"mateira") == 20, "depois para no 20 (está no %d)" % p.level)
	var d: Dictionary = gs.to_dict()
	gs.from_dict(d)
	check(gs.trial_stars(&"mateira", 10) == 3 and gs.trial_pending(&"mateira") == 20, "save guarda as Provações")
	# save antigo: herói já acima do 10 conta como vencida
	var q: Dictionary = gs.progress(&"druida")
	q.level = 14
	q.erase("trials")
	check(gs.trial_passed(&"druida", 10) and gs.level_cap(&"druida") == 20, "save antigo no 14: Provação do 10 já conta")


## Abre a prova do herói (nível 10) e força vitória ou derrota pelo caminho de cada uma.
func _trial(hero: String, win: bool) -> void:
	var p: Dictionary = gs.progress(StringName(hero))
	p.level = 10
	p.xp = 0
	p.erase("trials")
	gs.coins = 5000
	gs.selected_hero = StringName(hero)
	gs.run_trial = {"hero": hero, "tier": 10}
	change_scene_to_file("res://game/scenes/main.tscn")
	await _frames(16)
	var m = current_scene
	var t = m.trial
	check(t != null and t.kind == hero, "%s: Provação aberta (%s)" % [hero, t.kind if t else "-"])
	if t == null:
		return
	var pl = m._player
	pl.health.max_health = 999999
	pl.health.health = 999999
	var tag := "%s %s" % [hero, "vitória" if win else "derrota"]
	var result := []
	t.finished.connect(func(v: bool, s: int, _r: String) -> void: result.append([v, s]))
	match hero:
		"icamiaba":
			var totem = t.wards[0]
			check(totem.is_in_group("heroes"), "totem é alvo dos bichos")
			t._wave_t = 0.0
			await _phys(150)
			var on_totem := 0
			var total := 0
			for e in get_nodes_in_group("enemies"):
				if not e.health.is_dead:
					total += 1
					if e._player == totem:
						on_totem += 1
			check(total > 0 and on_totem * 2 >= total, "bichos vão no totem (%d de %d)" % [on_totem, total])
			check(gs.level_of(&"icamiaba") == 10, "bichos da Provação não dão XP")
			if win:
				t.elapsed = 59.9
			else:
				totem.health.take_damage(99999999, false, true)
		"mateira":
			var mk = t.monkey
			check(mk != null, "macaco-prego na clareira")
			if win:
				var moved := 0
				for i in 10:
					var before: Vector3 = mk.global_position
					mk.health.take_damage(10, false, true)
					await _phys(25)
					if mk.global_position.distance_to(before) > 2.0:
						moved += 1
				check(t.hits == 10 or not result.is_empty(), "10 acertos contados (%d)" % t.hits)
				check(moved >= 8, "macaco pula para longe depois de cada acerto (%d)" % moved)
			else:
				t.elapsed = 59.9
		"encantado":
			check(t._water != null, "a clareira alagou")
			var hp0: int = pl.health.health
			await _phys(60)
			check(pl.health.health == hp0, "na ilha não machuca")
			var c: Vector3 = t.room.center()
			var off := Vector3.INF
			for i in 60:
				var cand: Vector3 = c + Vector3(randf_range(-6, 6), 0.1, randf_range(-6, 6))
				if not t.on_island(cand):
					off = cand
					break
			pl.global_position = off
			await _phys(70)
			check(pl.health.health < hp0, "fora da ilha a cheia machuca (%d -> %d)" % [hp0, pl.health.health])
			var before: Array = t.islands.duplicate()
			t._flood_t = 0.1
			await _phys(140)
			var changed := false
			for i in before.size():
				changed = changed or before[i].distance_to(t.islands[i]) > 0.5
			check(changed, "as ilhas mudaram de lugar")
			if win:
				t.elapsed = 59.9
			else:
				pl.health.take_damage(99999999, false, true)
		"druida":
			check(t.wards.size() == 5, "5 mudas")
			var muda = t.wards[0]
			muda.health.take_damage(int(muda.health.max_health * 0.5), false, true)
			var hp0: int = muda.health.health
			pl.global_position = muda.global_position + Vector3(1.5, 0.1, 0)
			await _phys(2)
			pl.health.heal(int(pl.health.max_health * 0.2))
			check(muda.health.health > hp0, "cura do Druida cura a muda por perto (%d -> %d)" % [hp0, muda.health.health])
			if win:
				t.wards[1].health.take_damage(99999999, false, true)
				t.elapsed = 59.9
			else:
				for i in 3:
					t.wards[i + 1].health.take_damage(99999999, false, true)
	await _phys(20)
	await _frames(4)
	check(result.size() == 1 and result[0][0] == win, "%s: terminou como esperado %s" % [tag, str(result)])
	if win and not result.is_empty():
		check(gs.trial_passed(StringName(hero), 10) and gs.trial_stars(StringName(hero), 10) == result[0][1], "%s: Provação marcada (%d estrelas)" % [tag, result[0][1]])
		check(gs.coins == 4500, "%s: cobrou 500 de ouro (%d)" % [tag, gs.coins])
		if hero == "druida":
			check(result[0][1] == 2, "Viveiro com 4 mudas = 2 estrelas")
	elif not win:
		check(not gs.trial_passed(StringName(hero), 10) and gs.coins == 5000, "%s: nada cobrado, nada marcado" % tag)
	check(m._hud._panel.visible, "%s: painel do resultado aberto" % tag)
	gs.run_trial = {}
