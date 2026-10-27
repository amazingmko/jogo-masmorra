extends Node
## Autoload "GameState": o progresso do jogador enquanto o jogo roda.
## Carrega o save ao abrir e grava sozinho quando o app vai para segundo plano ou fecha.
##
## Progresso de cada herói em `heroes`:
##   {"icamiaba": {"level": 3, "xp": 120, "equipped": {"0": "eq12", "2": "eq7"}}}
## (as chaves de "equipped" são o slot como texto; os valores, uids de peças do inventário)

signal coins_changed(new_value: int)
signal hero_progress_changed(hero_id: StringName)
signal leveled_up(hero_id: StringName, new_level: int)
signal energy_changed(value: int)

const STARTING_HEROES := ["icamiaba", "mateira", "encantado", "druida"]
## Energia de recompensa (opção B): jogar é ilimitado; gastar 1 energia faz a run render tudo.
const MAX_ENERGY := 5
const ENERGY_SECONDS := 3600

var coins: int = 0
var inventory := Inventory.new()
var professions := ProfessionProgress.new()
var unlocked_heroes: PackedStringArray = []
var selected_hero: StringName = &"icamiaba"
var heroes: Dictionary = {}

## Energia e o instante (unix) a partir do qual conta a próxima recarga.
var energy: int = MAX_ENERGY
var energy_at: int = 0
## Maior dificuldade já vencida (-1 = nenhuma) e a última escolhida no portal.
var highest_cleared: int = -1
var selected_difficulty: int = 0
## Falhas seguidas por receita: cada uma dá +10% na próxima tentativa.
var craft_streaks: Dictionary = {}
## Configuração da run que vai começar (não é salva): definida no portal.
var run_difficulty: int = 0
var run_full_rewards: bool = true
## Só para testes: soma segundos ao relógio.
var debug_time_offset: int = 0
## Só para testes (botão que só aparece na versão de desenvolvimento): pontos de talento extras.
var debug_talent_points: int = 0


func _ready() -> void:
	var data := SaveSystem.load_game()
	if data.is_empty():
		_new_profile()
	else:
		from_dict(data)
	_complete_old_equipment()


func _notification(what: int) -> void:
	# No celular, o sistema pode encerrar o app em segundo plano sem aviso.
	# Por isso grava ao pausar, e não só ao fechar.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


func save() -> bool:
	return SaveSystem.save_game(to_dict())


## Proteção contra azar do chefe: vitórias seguidas sem o reagente mais raro da tabela dele.
var boss_pity := {}


## Depois do sorteio do chefe: se o troféu mais raro (o de maior raridade que pode cair nesta
## dificuldade) não veio, a chance dele cresce na próxima vitória; se veio (ou a ajuda deu), zera.
## Devolve os drops extras que a ajuda deu.
func boss_pity_roll(table: DropTable, difficulty: int, drops: Array, rng: RandomNumberGenerator, full_rewards: bool) -> Array[Dictionary]:
	var extra: Array[Dictionary] = []
	if not full_rewards:
		return extra
	var rarest: ItemData = null
	var tables: Array = [table]
	for t in table.extra_tables:
		tables.append(ItemDB.get_drop_table(t))
	for t: DropTable in tables:
		if t == null:
			continue
		for e in t.entries:
			if e.min_difficulty > difficulty:
				continue
			var it := ItemDB.get_item(e.item_id)
			if it and not it.is_equipment() and (rarest == null or int(it.rarity) > int(rarest.rarity)):
				rarest = it
	if rarest == null or int(rarest.rarity) < GameEnums.Rarity.EPIC:
		return extra
	var key := "%s:%d" % [String(rarest.id), difficulty]
	var got := false
	for d in drops:
		got = got or d.item == rarest
	if got:
		boss_pity.erase(key)
		return extra
	var misses := int(boss_pity.get(key, 0))
	if misses > 0 and rng.randf() < misses * Economy.PITY_STEP:
		extra.append({"item": rarest, "qty": 1, "instance": {}})
		boss_pity.erase(key)
	else:
		boss_pity[key] = misses + 1
	return extra


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)


# ---------- heróis ----------

func progress(hero_id: StringName) -> Dictionary:
	var key := String(hero_id)
	if not heroes.has(key):
		heroes[key] = {"level": 1, "xp": 0, "equipped": {}, "talents": {}}
	return heroes[key]


func level_of(hero_id: StringName) -> int:
	return int(progress(hero_id).level)


## Dá XP ao herói. Devolve quantos níveis ele subiu.
func add_xp(hero_id: StringName, amount: int) -> int:
	var p := progress(hero_id)
	var gained := Progression.add_xp(p, amount, level_cap(hero_id))
	if gained > 0:
		leveled_up.emit(hero_id, p.level)
	hero_progress_changed.emit(hero_id)
	return gained


# ---------- Provações do Folclore ----------
## Nos níveis 10, 20 e 30 o herói para (a barra enche) até vencer a Provação dele. Entrar é grátis;
## o ouro só é cobrado ao vencer. Vencer libera o nível seguinte (e a fileira de talentos dele).
const TRIAL_LEVELS := [10, 20, 30]
const TRIAL_GOLD := [500, 2000, 6000]
## Provação em andamento (na cena da masmorra): {"hero": id, "tier": 10}.
var run_trial := {}
## Continuar run (só sozinho): o estado da run no começo do último andar, gravado no save. Vazio =
## nenhuma run aberta. resume_now: a próxima cena da masmorra deve retomar esta run.
var run_resume := {}
var resume_now := false


func trial_passed(hero_id: StringName, tier: int) -> bool:
	var p := progress(hero_id)
	return int(p.level) > tier or (p.get("trials", {}) as Dictionary).has(str(tier))


## Teto atual: o primeiro nível de Provação ainda não vencida.
func level_cap(hero_id: StringName) -> int:
	for t in TRIAL_LEVELS:
		if not trial_passed(hero_id, t):
			return t
	return Progression.MAX_LEVEL


## Nível da Provação disponível agora (o herói chegou ao teto), ou 0.
func trial_pending(hero_id: StringName) -> int:
	var cap := level_cap(hero_id)
	return cap if cap < Progression.MAX_LEVEL and level_of(hero_id) >= cap else 0


func trial_cost(tier: int) -> int:
	var i := TRIAL_LEVELS.find(tier)
	return TRIAL_GOLD[i] if i >= 0 else 0


## Estrelas da melhor vitória (0 = ainda não venceu).
func trial_stars(hero_id: StringName, tier: int) -> int:
	return int((progress(hero_id).get("trials", {}) as Dictionary).get(str(tier), 0))


## Venceu: paga o ouro, guarda as estrelas e deixa o herói subir (a XP que sobrou já conta).
func complete_trial(hero_id: StringName, tier: int, stars: int) -> void:
	var p := progress(hero_id)
	if not p.has("trials"):
		p["trials"] = {}
	var first := not (p.trials as Dictionary).has(str(tier))
	if first:
		add_coins(-trial_cost(tier))
	p.trials[str(tier)] = maxi(int(p.trials.get(str(tier), 0)), stars)
	add_xp(hero_id, 0)
	save()


## Só na versão de desenvolvimento: leva o herói ao próximo teto (barra cheia) e garante o ouro
## da Provação, para testar as provas sem precisar subir de nível jogando.
func debug_jump_to_trial(hero_id: StringName) -> int:
	var cap := level_cap(hero_id)
	if cap >= Progression.MAX_LEVEL:
		return 0
	var p := progress(hero_id)
	p.level = maxi(int(p.level), cap)
	p.xp = Progression.xp_to_next(cap)
	if coins < trial_cost(cap):
		add_coins(trial_cost(cap) - coins)
	hero_progress_changed.emit(hero_id)
	save()
	return cap


## Peças vestidas pelo herói: {slot(int): instance}.
func equipped_items(hero_id: StringName) -> Dictionary:
	var out := {}
	var eq: Dictionary = progress(hero_id).equipped
	for slot_key in eq:
		var inst := inventory.get_equipment(String(eq[slot_key]))
		if not inst.is_empty():
			out[int(slot_key)] = inst
	return out


## Veste uma peça do inventário. Devolve "" se deu certo, ou o motivo.
func equip(hero_id: StringName, uid: String) -> String:
	var inst := inventory.get_equipment(uid)
	if inst.is_empty():
		return "Item não encontrado."
	var template := ItemDB.get_item(StringName(inst.item_id))
	var hero := ItemDB.get_hero(hero_id)
	if not ItemFactory.can_use(hero, template):
		return "%s não pode usar este item." % hero.display_name
	# Uma peça só pode estar com um herói por vez.
	for other in heroes:
		var other_eq: Dictionary = heroes[other].equipped
		for slot_key in other_eq.keys():
			if other_eq[slot_key] == uid:
				other_eq.erase(slot_key)
	progress(hero_id).equipped[str(int(template.slot))] = uid
	hero_progress_changed.emit(hero_id)
	return ""


func unequip(hero_id: StringName, slot: int) -> void:
	progress(hero_id).equipped.erase(str(slot))
	hero_progress_changed.emit(hero_id)


## Herói que está vestindo a peça (ou &"" se ninguém).
func wearer_of(uid: String) -> StringName:
	for hero_id in heroes:
		for slot_key in heroes[hero_id].equipped:
			if heroes[hero_id].equipped[slot_key] == uid:
				return StringName(hero_id)
	return &""


func stats_for(hero_id: StringName, buffs: Array = []) -> HeroStats:
	return HeroStats.compute(ItemDB.get_hero(hero_id), level_of(hero_id), equipped_items(hero_id), ItemDB.catalog, buffs, talents_of(hero_id))


# ---------- talentos ----------

## Testes: todos os talentos valem juntos (para testar efeitos de ramos diferentes de uma vez).
var debug_all_specs := false


## Todos os pontos guardados do herói (das 3 especializações): {"couro_anta": 2, ...}.
func all_talents_of(hero_id: StringName) -> Dictionary:
	var p := progress(hero_id)
	if not p.has("talents"):
		p["talents"] = {}
	return p.talents


## Os talentos que VALEM: só os da especialização ativa.
func talents_of(hero_id: StringName) -> Dictionary:
	if debug_all_specs:
		return all_talents_of(hero_id)
	return Talents.only_branch(all_talents_of(hero_id), hero_id, active_spec(hero_id))


## Testes: começa sem talentos em nenhum herói (só na memória; não grava).
func debug_clear_talents() -> void:
	for k in heroes:
		heroes[k]["talents"] = {}
		heroes[k].erase("spec")


## Especialização ativa (ramo). Sem escolha ainda: a primeira.
func active_spec(hero_id: StringName) -> String:
	var p := progress(hero_id)
	var branches := Talents.branches(hero_id)
	var id := String(p.get("spec", ""))
	for b in branches:
		if String(b.id) == id:
			return id
	return String(branches[0].id) if not branches.is_empty() else ""


func set_active_spec(hero_id: StringName, branch_id: String) -> void:
	progress(hero_id)["spec"] = branch_id
	hero_progress_changed.emit(hero_id)
	save()


func talent_rank(hero_id: StringName, id: String) -> int:
	return Talents.rank(talents_of(hero_id), id)


func talent_value(hero_id: StringName, id: String) -> float:
	return Talents.value(talents_of(hero_id), id, hero_id)


## Nível usado nas regras (com os pontos de teste convertidos em níveis).
func talent_level(hero_id: StringName) -> int:
	return level_of(hero_id) + debug_talent_points * Talents.LEVELS_PER_POINT


## Pontos ainda livres numa especialização (vazio = a ativa).
func talent_points_free(hero_id: StringName, branch_id := "") -> int:
	var bid := branch_id if branch_id != "" else active_spec(hero_id)
	var spent := 0
	for b in Talents.branches(hero_id):
		if String(b.id) == bid:
			spent = Talents.spent_in_branch(all_talents_of(hero_id), b)
	return Talents.points_for_level(talent_level(hero_id)) - spent


## Põe um ponto (só na especialização ativa). Devolve "" se deu certo, ou o motivo.
func add_talent(hero_id: StringName, id: String) -> String:
	var t := all_talents_of(hero_id)
	var reason := Talents.can_add(t, hero_id, id, talent_level(hero_id), active_spec(hero_id))
	if reason != "":
		return reason
	t[id] = Talents.rank(t, id) + 1
	hero_progress_changed.emit(hero_id)
	save()
	return ""


## Redistribuir: devolve os pontos de uma especialização (vazio = todas). Grátis.
func reset_talents(hero_id: StringName, branch_id := "") -> void:
	if branch_id == "":
		progress(hero_id)["talents"] = {}
	else:
		var t := all_talents_of(hero_id)
		for b in Talents.branches(hero_id):
			if String(b.id) == branch_id:
				for tt in b.talents:
					t.erase(String(tt.id))
	hero_progress_changed.emit(hero_id)
	save()


# ---------- energia ----------

func now() -> int:
	return int(Time.get_unix_time_from_system()) + debug_time_offset


func energy_now() -> int:
	_regen_energy()
	return energy


## Segundos até a próxima energia (0 se está cheia).
func seconds_to_next_energy() -> int:
	_regen_energy()
	if energy >= MAX_ENERGY:
		return 0
	return maxi(ENERGY_SECONDS - (now() - energy_at), 0)


## Gasta 1 energia. Devolve false se não tinha.
func spend_energy() -> bool:
	_regen_energy()
	if energy <= 0:
		return false
	if energy >= MAX_ENERGY:
		energy_at = now()  # a recarga começa a contar agora
	energy -= 1
	energy_changed.emit(energy)
	return true


func _regen_energy() -> void:
	var t := now()
	if energy_at <= 0 or energy_at > t:
		energy_at = t  # primeira vez, ou relógio voltou
	if energy >= MAX_ENERGY:
		energy_at = t
		return
	var gained := (t - energy_at) / ENERGY_SECONDS
	if gained <= 0:
		return
	energy = mini(energy + gained, MAX_ENERGY)
	energy_at += gained * ENERGY_SECONDS
	if energy >= MAX_ENERGY:
		energy_at = t
	energy_changed.emit(energy)


# ---------- dificuldades ----------

## Poder do herói: soma dos pontos das peças vestidas (Comum 10, Rara 20, Épica 35, Lendária 55).
func power_of(hero_id: StringName) -> int:
	var total := 0
	for inst in equipped_items(hero_id).values():
		total += ItemFactory.gear_power(inst)
	return total


## "" se o herói pode entrar nessa dificuldade; senão, o que falta.
func difficulty_lock(d: int, hero_id: StringName) -> String:
	return Difficulty.lock_reason(d, highest_cleared, equipped_items(hero_id))


func world_lock(world: int, hero_id: StringName) -> String:
	return Difficulty.world_lock_reason(world, highest_cleared, equipped_items(hero_id))


func record_clear(d: int) -> void:
	highest_cleared = maxi(highest_cleared, d)


# ---------- crafting ----------

func worn_uids() -> Array:
	var out := []
	for hero_id in heroes:
		for slot_key in heroes[hero_id].equipped:
			out.append(heroes[hero_id].equipped[slot_key])
	return out


## Tenta fabricar. Se a peça-base estava vestida, a peça nova é vestida no lugar dela.
## Devolve o resultado do Crafting.craft (ok, success, chance, uid, lost, xp...).
func craft(recipe_id: StringName) -> Dictionary:
	var recipe := ItemDB.get_recipe(recipe_id)
	var worn := worn_uids()
	var streak := int(craft_streaks.get(String(recipe_id), 0))
	var base := Crafting.find_base(recipe, inventory, worn) if recipe else {}
	var wearer := wearer_of(base.uid) if not base.is_empty() else &""
	var cost := Economy.craft_cost(recipe, ItemDB.catalog) if recipe else 0
	if recipe and coins < cost and Crafting.check(recipe, inventory, professions, worn) == "":
		return {"ok": false, "success": false, "reason": "Falta ouro (precisa %d)." % cost}
	var result := Crafting.craft(recipe, inventory, professions, ItemDB.catalog, null, streak, worn)
	if not result.ok:
		return result
	add_coins(-cost)  # a taxa da oficina é paga em toda tentativa
	result["gold"] = cost
	if result.success:
		craft_streaks.erase(String(recipe_id))
		if wearer != &"" and result.uid != "":
			var template := ItemDB.get_item(recipe.result_item_id)
			progress(wearer).equipped[str(int(template.slot))] = result.uid
			hero_progress_changed.emit(wearer)
	else:
		craft_streaks[String(recipe_id)] = streak + 1
	save()
	return result


## Vende reagentes por ouro. Devolve o ouro ganho (0 se não tinha).
func sell_material(item_id: StringName, qty: int) -> int:
	var item := ItemDB.get_item(item_id)
	var have := inventory.count(item_id)
	var n := mini(qty, have)
	if item == null or n <= 0:
		return 0
	inventory.remove_all({String(item_id): n})
	var gold := n * Economy.sell_price(item)
	add_coins(gold)
	save()
	return gold


func craft_streak(recipe_id: StringName) -> int:
	return int(craft_streaks.get(String(recipe_id), 0))


# ---------- save ----------

func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"boss_pity": boss_pity.duplicate(),
		"inventory": inventory.to_dict(),
		"professions": professions.to_dict(),
		"unlocked_heroes": Array(unlocked_heroes),
		"selected_hero": String(selected_hero),
		"heroes": heroes.duplicate(true),
		"energy": energy,
		"energy_at": energy_at,
		"highest_cleared": highest_cleared,
		"selected_difficulty": selected_difficulty,
		"craft_streaks": craft_streaks.duplicate(),
		"debug_talent_points": debug_talent_points,
		"run_resume": run_resume.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	boss_pity = (data.get("boss_pity", {}) as Dictionary).duplicate()
	inventory.from_dict(data.get("inventory", {}))
	professions.from_dict(data.get("professions", {}))
	unlocked_heroes = PackedStringArray(data.get("unlocked_heroes", STARTING_HEROES))
	for h in STARTING_HEROES:
		if not unlocked_heroes.has(h):
			unlocked_heroes.append(h)
	selected_hero = StringName(data.get("selected_hero", "icamiaba"))
	heroes.clear()
	debug_talent_points = maxi(int(data.get("debug_talent_points", 0)), 0)
	var saved: Dictionary = data.get("heroes", {})
	for key in saved:
		var p: Dictionary = saved[key]
		var eq := {}
		var saved_eq: Dictionary = p.get("equipped", {})
		for slot_key in saved_eq:
			eq[str(int(slot_key))] = String(saved_eq[slot_key])
		var level := int(p.get("level", 1))
		var talents := Talents.sanitize(p.get("talents", {}), StringName(key), level + debug_talent_points * Talents.LEVELS_PER_POINT)
		heroes[String(key)] = {"level": level, "xp": int(p.get("xp", 0)), "equipped": eq, "talents": talents}
		if p.has("spec"):
			heroes[String(key)]["spec"] = String(p.spec)
		if p.has("trials"):
			heroes[String(key)]["trials"] = (p.trials as Dictionary).duplicate()
	energy = clampi(int(data.get("energy", MAX_ENERGY)), 0, MAX_ENERGY)
	energy_at = int(data.get("energy_at", 0))
	highest_cleared = int(data.get("highest_cleared", -1))
	selected_difficulty = clampi(int(data.get("selected_difficulty", 0)), 0, 3)
	craft_streaks.clear()
	var streaks: Dictionary = data.get("craft_streaks", {})
	for key in streaks:
		craft_streaks[String(key)] = int(streaks[key])
	if ItemDB.get_hero(selected_hero) == null:
		selected_hero = StringName(STARTING_HEROES[0])
	run_resume = (data.get("run_resume", {}) as Dictionary).duplicate(true)
	if not run_resume.is_empty() and ItemDB.get_hero(StringName(run_resume.get("hero", ""))) == null:
		run_resume = {}
	coins_changed.emit(coins)


func _new_profile() -> void:
	coins = 0
	unlocked_heroes = PackedStringArray(STARTING_HEROES)
	selected_hero = &"icamiaba"
	heroes.clear()
	energy = MAX_ENERGY
	energy_at = now()
	highest_cleared = -1
	selected_difficulty = 0
	craft_streaks.clear()


## Peças de saves antigos (antes dos atributos) ganham atributos de item comum.
func _complete_old_equipment() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in inventory.equipment.size():
		var eq: Dictionary = inventory.equipment[i]
		if not eq.get("stats", {}).is_empty():
			continue
		var template := ItemDB.get_item(StringName(eq.item_id))
		if template == null or not template.is_equipment():
			continue
		var rolled := ItemFactory.roll(template, int(eq.get("ilvl", 1)), int(eq.get("rarity", 0)), rng)
		eq["stats"] = rolled.stats
