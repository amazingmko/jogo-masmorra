extends Node
## Autoload "GameState": o progresso do jogador enquanto o jogo roda.
## Carrega o save ao abrir e grava sozinho quando o app vai para segundo plano ou fecha.
##
## Progresso de cada herói em `heroes`:
##   {"guardiao": {"level": 3, "xp": 120, "equipped": {"0": "eq12", "2": "eq7"}}}
## (as chaves de "equipped" são o slot como texto; os valores, uids de peças do inventário)

signal coins_changed(new_value: int)
signal hero_progress_changed(hero_id: StringName)
signal leveled_up(hero_id: StringName, new_level: int)

const STARTING_HEROES := ["guardiao", "batedora", "arcanista"]

var coins: int = 0
var inventory := Inventory.new()
var professions := ProfessionProgress.new()
var unlocked_heroes: PackedStringArray = []
var selected_hero: StringName = &"guardiao"
var heroes: Dictionary = {}


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


# ---------- save ----------

func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"inventory": inventory.to_dict(),
		"professions": professions.to_dict(),
		"unlocked_heroes": Array(unlocked_heroes),
		"selected_hero": String(selected_hero),
		"heroes": heroes.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	inventory.from_dict(data.get("inventory", {}))
	professions.from_dict(data.get("professions", {}))
	unlocked_heroes = PackedStringArray(data.get("unlocked_heroes", STARTING_HEROES))
	for h in STARTING_HEROES:
		if not unlocked_heroes.has(h):
			unlocked_heroes.append(h)
	selected_hero = StringName(data.get("selected_hero", "guardiao"))
	heroes.clear()
	var saved: Dictionary = data.get("heroes", {})
	for key in saved:
		var p: Dictionary = saved[key]
		var eq := {}
		var saved_eq: Dictionary = p.get("equipped", {})
		for slot_key in saved_eq:
			eq[str(int(slot_key))] = String(saved_eq[slot_key])
		heroes[String(key)] = {"level": int(p.get("level", 1)), "xp": int(p.get("xp", 0)), "equipped": eq}
	coins_changed.emit(coins)


func _new_profile() -> void:
	coins = 0
	unlocked_heroes = PackedStringArray(STARTING_HEROES)
	selected_hero = &"guardiao"
	heroes.clear()


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
