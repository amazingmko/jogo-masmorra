class_name ProfessionProgress
extends RefCounted
## Nível e XP do jogador em cada profissão.

signal leveled_up(profession_id: StringName, new_level: int)

var data: Dictionary = {}  # String id -> {"level": int, "xp": int}


func level_of(profession_id: StringName) -> int:
	return int(data.get(String(profession_id), {}).get("level", 1))


func xp_of(profession_id: StringName) -> int:
	return int(data.get(String(profession_id), {}).get("xp", 0))


func add_xp(profession: ProfessionData, amount: int) -> void:
	if profession == null or amount <= 0:
		return
	var key := String(profession.id)
	var entry: Dictionary = data.get(key, {"level": 1, "xp": 0})
	entry.xp += amount
	while entry.level < profession.max_level and entry.xp >= profession.xp_to_next(entry.level):
		entry.xp -= profession.xp_to_next(entry.level)
		entry.level += 1
		leveled_up.emit(profession.id, entry.level)
	if entry.level >= profession.max_level:
		entry.xp = 0
	data[key] = entry


func to_dict() -> Dictionary:
	return data.duplicate(true)


func from_dict(saved: Dictionary) -> void:
	data.clear()
	for key in saved:
		data[String(key)] = {"level": int(saved[key].get("level", 1)), "xp": int(saved[key].get("xp", 0))}
