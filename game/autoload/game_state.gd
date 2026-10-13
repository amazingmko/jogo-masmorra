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

const STARTING_HEROES := ["icamiaba", "mateira", "encantado"]
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


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)


# ---------- heróis ----------

func progress(hero_id: StringName) -> Dictionary:
	var key := String(hero_id)
	if not heroes.has(key):
		heroes[key] = {"level": 1, "xp": 0, "equipped": {}}
	return heroes[key]


func level_of(hero_id: StringName) -> int:
	return int(progress(hero_id).level)


## Dá XP ao herói. Devolve quantos níveis ele subiu.
func add_xp(hero_id: StringName, amount: int) -> int:
	var p := progress(hero_id)
	var gained := Progression.add_xp(p, amount)
	if gained > 0:
		leveled_up.emit(hero_id, p.level)
	hero_progress_changed.emit(hero_id)
	return gained


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
	return HeroStats.compute(ItemDB.get_hero(hero_id), level_of(hero_id), equipped_items(hero_id), ItemDB.catalog, buffs)


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

## Média do nível de item das 6 peças vestidas (slot vazio conta 0).
func average_ilvl(hero_id: StringName) -> float:
	var total := 0
	for inst in equipped_items(hero_id).values():
		total += int(inst.ilvl)
	return total / float(GameEnums.SLOT_NAMES.size())


## "" se o herói pode entrar nessa dificuldade; senão, o que falta.
func difficulty_lock(d: int, hero_id: StringName) -> String:
	return Difficulty.lock_reason(d, highest_cleared, average_ilvl(hero_id))


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
	var result := Crafting.craft(recipe, inventory, professions, ItemDB.catalog, null, streak, worn)
	if not result.ok:
		return result
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


func craft_streak(recipe_id: StringName) -> int:
	return int(craft_streaks.get(String(recipe_id), 0))


# ---------- save ----------

func to_dict() -> Dictionary:
	return {
		"coins": coins,
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
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	inventory.from_dict(data.get("inventory", {}))
	professions.from_dict(data.get("professions", {}))
	unlocked_heroes = PackedStringArray(data.get("unlocked_heroes", STARTING_HEROES))
	for h in STARTING_HEROES:
		if not unlocked_heroes.has(h):
			unlocked_heroes.append(h)
	selected_hero = StringName(data.get("selected_hero", "icamiaba"))
	heroes.clear()
	var saved: Dictionary = data.get("heroes", {})
	for key in saved:
		var p: Dictionary = saved[key]
		var eq := {}
		var saved_eq: Dictionary = p.get("equipped", {})
		for slot_key in saved_eq:
			eq[str(int(slot_key))] = String(saved_eq[slot_key])
		heroes[String(key)] = {"level": int(p.get("level", 1)), "xp": int(p.get("xp", 0)), "equipped": eq}
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
