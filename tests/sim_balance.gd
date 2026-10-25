extends SceneTree
## Simulador de balanceamento: robôs jogam uma run inteira (10 andares) sozinhos ou em grupo de
## até 4 heróis no mesmo aparelho (aliados controlados por robô; os bichos recebem o mesmo reforço
## do multijogador). No fim imprime uma linha "RESULTADO_JSON {...}" com o que aconteceu.
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/sim_balance.gd -- \
##       party=icamiaba,mateira gear=comum diff=0 level=5 seed=7
##
## party: heróis do grupo (o primeiro é o "jogador"); gear: sem | comum; diff: 0 Normal, 1 Difícil...
## O robô: desvia dos avisos no chão, vai para cima do inimigo mais perto (de longe se atira),
## usa a habilidade com bicho por perto e a ultimate com 2+ bichos ou chefe, recolhe loot, abre baús,
## levanta parceiro caído (3 s perto) e desce pelo portal. Não escolhe talento nem se cura de propósito.

const MAX_SECONDS := 2400
const WEAPONS := {"icamiaba": ["lanca_ipe", "escudo_casco"], "mateira": ["arco_simples"],
	"encantado": ["cajado_aprendiz"], "druida": ["cajado_raiz"]}
const ARMOR := {
	2: ["elmo_placa", "peitoral_placa", "manoplas_placa", "grevas_placa", "botas_placa"],
	1: ["capuz_couro", "armadura_couro", "luvas_couro", "calca_couro", "botas_couro"],
	0: ["capuz_tecido", "tunica_tecido", "luvas_tecido", "calca_tecido", "sandalias_tecido"],
}

var _party: Array = ["icamiaba"]
var _gear := "sem"
var _diff := 0
var _level := 5
var _seed := 1
var _main: Node
var _heroes: Array = []  # Player nodes (0 = principal)
var _frames := 0
var _started := false
var _deaths := {}
var _revive_t := {}
var _floor_seen := 0
var _floor_times := []
var _floor_started := 0
var _lowest_hp := {}
var _skills := {}
var _ults := {}
var _dodges := 0
var _stuck := {}
var _last := {}
var _detour := {}
## Robô "humano": vê o aviso com atraso (REACT_FRAMES) e só desvia de uma parte deles (_dodge_rate);
## nos outros fica batendo. dodge=1 volta ao robô perfeito.
const REACT_FRAMES := 18
var _dodge_rate := 0.7
var _seen := {}  # "id_robô:id_aviso" -> [frame em que viu, vai desviar?]
var _drng := RandomNumberGenerator.new()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"party": _party = Array(kv[1].split(","))
			"gear": _gear = kv[1]
			"diff": _diff = int(kv[1])
			"level": _level = int(kv[1])
			"seed": _seed = int(kv[1])
			"dodge": _dodge_rate = float(kv[1])
	_drng.seed = _seed * 7919


func _profile(hero_id: String) -> Dictionary:
	var db = root.get_node("ItemDB")
	var T = load("res://game/scripts/systems/talents.gd")
	var hero = db.get_hero(StringName(hero_id))
	var eq := {}
	if _gear != "sem":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(hero_id) + _seed
		var names: Array = WEAPONS[hero_id].duplicate()
		names.append_array(ARMOR[int(hero.armor_type())])
		if _gear.begins_with("comum") and _gear.length() > 5:  # comum2 = só as 2 primeiras peças
			names = names.slice(0, int(_gear.substr(5)))
		var rarity: int = {"rara": 1, "epica": 2}.get(_gear, 0)
		for n in names:
			var tpl = db.get_item(StringName(n))
			if tpl == null:
				continue
			var inst: Dictionary = load("res://game/scripts/systems/item_factory.gd").roll(tpl, 10, rarity, rng)
			eq[str(int(tpl.slot))] = inst
	# talentos: os pontos do nível no 1º ramo (especialização padrão), fileira por fileira
	var talents := {}
	var branch = T.branches(StringName(hero_id))[0] if T.has_tree(StringName(hero_id)) else null
	if branch:
		var guard := 0
		while guard < 60:
			guard += 1
			var added := false
			for t in branch.talents:
				if int(talents.get(t.id, 0)) < int(t.max) and T.can_add(talents, StringName(hero_id), t.id, _level, String(branch.id)) == "":
					talents[t.id] = int(talents.get(t.id, 0)) + 1
					added = true
					break
			if not added:
				break
	return {"hero_id": hero_id, "level": _level, "equipped": eq, "talents": talents}


func _process(_delta: float) -> bool:
	if _main == null:
		var gs = root.get_node("GameState")
		gs.selected_hero = StringName(_party[0])
		gs.run_trial = {}
		gs.run_difficulty = _diff
		gs.run_full_rewards = true
		_main = load("res://game/scenes/main.tscn").instantiate()
		root.add_child(_main)
		current_scene = _main
		return false
	_frames += 1
	if _frames == 3:
		_setup()
		return false
	if not _started:
		return false
	var hud = _main.get_node("HUD")
	if hud._buff_panel.visible:
		var cards: Array = hud._buff_cards.get_children()
		if not cards.is_empty():
			cards[0].pressed.emit()
		return false
	if hud.is_asking():
		hud._on_panel_button(false)  # acampamento: continuar descendo
	if _main.floor_number != _floor_seen:
		if _floor_seen > 0:
			_floor_times.append((_frames - _floor_started) / 60)
		_floor_seen = _main.floor_number
		_floor_started = _frames
	_tick_revive(1.0 / 60.0)
	for i in _heroes.size():
		var p = _heroes[i]
		if not is_instance_valid(p):
			continue
		var hid: String = String(p.hero_id)
		if not p.health.is_dead:
			_lowest_hp[hid] = minf(float(_lowest_hp.get(hid, 1.0)), float(p.health.health) / float(p.health.max_health))
		var mv: Vector2 = Vector2.ZERO if p.health.is_dead else _steer(p, i)
		if i == 0:
			hud.joystick.value = mv
		else:
			p.touch_move = mv
		_use_powers(p)
	if _main._run_over or _frames > MAX_SECONDS * 60:
		_heal_report()
		_report()
	return false


func _setup() -> void:
	var db = root.get_node("ItemDB")
	var main_p = _main.get_node("Player")
	main_p.profile = _profile(_party[0])
	main_p.set_hero(db.get_hero(StringName(_party[0])))
	_heroes = [main_p]
	for i in range(1, _party.size()):
		var a = load("res://game/scenes/player.tscn").instantiate()
		a.profile = _profile(_party[i])
		a.name = "Aliado%d" % i
		_main.add_child(a)
		a.set_hero(db.get_hero(StringName(_party[i])))
		_heroes.append(a)
		a.health.died.connect(_on_ally_died.bind(a))
	_main.sim_allies = _heroes.slice(1)
	for h in _heroes:
		h.health.healed.connect(_on_healed.bind(h))
		h.health.damaged.connect(func(a: int) -> void: _taken[String(h.hero_id)] = int(_taken.get(String(h.hero_id), 0)) + a)
	main_p.health.died.connect(func() -> void: _deaths[String(main_p.hero_id)] = int(_deaths.get(String(main_p.hero_id), 0)) + 1)
	_main.new_run(_seed)
	Input.action_press("attack")
	_started = true


func _on_ally_died(a) -> void:
	_deaths[String(a.hero_id)] = int(_deaths.get(String(a.hero_id), 0)) + 1
	_main._check_party_down()


func _use_powers(p) -> void:
	if p.health.is_dead or p.kit == null:
		return
	var near := 0
	var boss := false
	for e in get_nodes_in_group("enemies"):
		if e.health.is_dead:
			continue
		var d: float = e.global_position.distance_to(p.global_position)
		if d < 8.0:
			near += 1
		if e.is_boss and d < 14.0:
			boss = true
	var hid := String(p.hero_id)
	if near >= 1 and p.kit.skill_ready():
		p.touch_form = true
		_skills[hid] = int(_skills.get(hid, 0)) + 1
	if p.kit.has_ultimate() and p.kit.ultimate_ready() and (near >= 2 or boss):
		p.touch_ultimate = true
		_ults[hid] = int(_ults.get(hid, 0)) + 1


## Levantar parceiro: um herói de pé perto de um caído por 3 s.
func _tick_revive(delta: float) -> void:
	if _heroes.size() < 2:
		return
	for d in _heroes:
		if not d.health.is_dead:
			_revive_t.erase(d)
			continue
		var helping := false
		for a in _heroes:
			if a != d and not a.health.is_dead and a.global_position.distance_to(d.global_position) < 1.8:
				helping = true
		if not helping:
			_revive_t.erase(d)
			continue
		_revive_t[d] = float(_revive_t.get(d, 0.0)) + delta
		# mesma regra do jogo: 5 s e 25% da vida; com a Druida levantando, 2 s e 60%
		var healer = null
		for a in _heroes:
			if a != d and not a.health.is_dead and a.global_position.distance_to(d.global_position) < 1.8 \
					and a.hero.hero_class == GameEnums.HeroClass.DRUID:
				healer = a
		var need: float = _main.REVIVE_TIME_HEALER if healer else _main.REVIVE_TIME
		var frac: float = _main.REVIVE_HP_HEALER if healer else _main.REVIVE_HP
		if _revive_t[d] >= need:
			_revive_t.erase(d)
			d.revive(d.global_position)
			d.health.set_current(maxi(int(d.health.max_health * frac), 1), d.health.max_health)


func _steer(p, i: int) -> Vector2:
	var pos: Vector3 = p.global_position
	var target := _choose(p, i)
	var wants := target != Vector3.INF and Vector2(target.x - pos.x, target.z - pos.z).length() > 0.3
	if wants and int(_detour.get(i, 0)) == 0 and pos.distance_to(_last.get(i, Vector3.ZERO)) < 0.02:
		_stuck[i] = int(_stuck.get(i, 0)) + 1
	else:
		_stuck[i] = 0
	_last[i] = pos
	if int(_stuck[i]) > 20:
		_detour[i] = 45
		_stuck[i] = 0
	if int(_detour.get(i, 0)) > 0 and _main._current_room:
		_detour[i] = int(_detour[i]) - 1
		target = _main._current_room.center()
	if target == Vector3.INF:
		return Vector2.ZERO
	var flat := Vector2(target.x - pos.x, target.z - pos.z)
	return flat.normalized() if flat.length() > 0.3 else Vector2.ZERO


func _choose(p, i: int) -> Vector3:
	var pos: Vector3 = p.global_position
	var danger: Node = null
	for t in get_nodes_in_group("telegraphs"):
		if t.is_pending() and t.contains(pos):
			var key := "%d:%d" % [p.get_instance_id(), t.get_instance_id()]
			if not _seen.has(key):
				_seen[key] = [_frames, _drng.randf() < _dodge_rate]
			if not _seen[key][1] or _frames - int(_seen[key][0]) < REACT_FRAMES:
				continue
			if danger == null or t.shape == 3 or t.time_left() < danger.time_left():
				danger = t
	if danger:
		_dodges += 1 if _frames % 30 == 0 else 0
		return danger.escape_point(pos)
	var enemy := _nearest(pos, get_nodes_in_group("enemies").filter(func(e): return not e.health.is_dead))
	# parceiro caído e nenhum bicho perto: vai levantar
	if enemy == null or pos.distance_to(enemy.global_position) > 6.0:
		for d in _heroes:
			if d != p and d.health.is_dead:
				return d.global_position
	if enemy:
		var reach: float = p.weapon_stats.attack_range * (0.8 if p.weapon_stats.is_ranged() else 0.7)
		if pos.distance_to(enemy.global_position) > reach:
			return enemy.global_position
		return Vector3.INF
	if i > 0:
		# aliado sem bicho por perto: segue o principal
		var lead = _heroes[0]
		if lead.health.is_dead:
			return Vector3.INF
		return lead.global_position if pos.distance_to(lead.global_position) > 2.5 else Vector3.INF
	var pickups := get_nodes_in_group("pickups").filter(func(n): return not n.has_meta("robot_skip"))
	var pickup := _nearest(pos, pickups)
	if pickup and pos.distance_to(pickup.global_position) < 12.0:
		var tries: int = pickup.get_meta("robot_frames", 0) + 1
		pickup.set_meta("robot_frames", tries)
		if tries > 240:
			pickup.set_meta("robot_skip", true)
		return pickup.global_position
	var layout = _main.layout
	var builder = _main.builder
	var cur = _main._current_room
	if layout == null or cur == null:
		return Vector3.INF
	var goal_index: int = layout.goal_index
	for idx in builder.props:
		var prop = builder.props[idx]
		if prop.kind == 0 and not prop.used:
			goal_index = idx
			break
	if cur.index == goal_index:
		for portal in _main.find_children("Portal", "Area3D", true, false):
			if not portal.used and cur.contains(portal.global_position):
				return portal.global_position
		return cur.center()
	var path: Array = layout.path(cur.index, goal_index)
	if path.size() < 2:
		return Vector3.INF
	var next = builder.rooms[path[1]]
	var dir: Vector3 = (next.center() - cur.center()).normalized()
	var rel: Vector3 = pos - cur.center()
	var along := rel.dot(dir)
	var lateral := (rel - dir * along).length()
	if lateral > 0.8:
		return cur.center() + dir * maxf(along, 0.0)
	return next.center()


func _nearest(pos: Vector3, nodes: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n in nodes:
		var d := pos.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


var _taken := {}  # herói -> dano recebido (escudo + vida)
var _healed := {}  # herói -> vida curada de verdade (sem contar o que passou do máximo)


func _on_healed(amount: int, h) -> void:
	var id := String(h.hero_id)
	_healed[id] = int(_healed.get(id, 0)) + mini(amount, h.health.max_health - h.health.health)


func _heal_report() -> void:
	pass


func _report() -> void:
	Input.action_release("attack")
	var hud = _main.get_node("HUD")
	var won: bool = _main._run_over and String(hud._panel_title.text).begins_with("Vit")
	var loot := {}
	for k in _main._stats.loot:
		var parts := String(k).split("#")
		var item = root.get_node("ItemDB").get_item(StringName(parts[0]))
		var nm: String = item.display_name if item else parts[0]
		if parts.size() > 1:
			nm += " (%s)" % ["Comum", "Rara", "Épica", "Lendária"][int(parts[1])]
		loot[nm] = int(loot.get(nm, 0)) + int(_main._stats.loot[k])
	var out := {
		"party": _party, "gear": _gear, "diff": _diff, "level": _level, "seed": _seed,
		"result": "venceu" if won else ("caiu" if _main._run_over else "tempo"),
		"floor": _main.floor_number, "seconds": _frames / 60, "kills": _main._stats.kills,
		"elites": int(_main._stats.get("elites", 0)), "gold": int(_main._stats.get("gold", 0)),
		"xp": int(_main._stats.get("xp", 0)), "deaths": _deaths, "lowest_hp": _lowest_hp,
		"skills": _skills, "ults": _ults, "floor_times": _floor_times, "loot": loot,
		"healed": _healed, "taken": _taken, "synergy": Synergy.active(_main.party_heroes()).map(func(x): return "%s x%d" % [x.name, int(x.heroes)]), "dodge": _dodge_rate,
	}
	print("RESULTADO_JSON ", JSON.stringify(out))
	quit(0)
