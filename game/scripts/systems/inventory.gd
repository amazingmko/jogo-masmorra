class_name Inventory
extends RefCounted
## Inventário do jogador.
## Materiais e consumíveis empilham: {id: quantidade}.
## Equipamentos são peças únicas, cada uma com "uid", raridade, nível de item e atributos
## (ver ItemFactory). Peças salvas sem atributos são completadas pelo GameState ao carregar.

signal changed

var stacks: Dictionary = {}            # String id -> int quantidade
var equipment: Array[Dictionary] = []  # [{"uid", "item_id", "ilvl", "rarity", "stats"}]
var _next_uid: int = 1


func add(item: ItemData, qty: int = 1) -> void:
	if item == null or qty <= 0:
		return
	if item.is_equipment():
		for i in qty:
			add_equipment({"item_id": String(item.id), "ilvl": 1, "rarity": 0, "stats": {}}, false)
	else:
		var key := String(item.id)
		stacks[key] = stacks.get(key, 0) + qty
	changed.emit()


## Guarda uma peça gerada pelo ItemFactory e devolve o uid dela.
func add_equipment(instance: Dictionary, notify: bool = true) -> String:
	var piece := instance.duplicate(true)
	piece["uid"] = "eq%d" % _next_uid
	_next_uid += 1
	equipment.append(piece)
	if notify:
		changed.emit()
	return piece.uid


func get_equipment(uid: String) -> Dictionary:
	for eq in equipment:
		if eq.uid == uid:
			return eq
	return {}


func remove_equipment(uid: String) -> bool:
	for i in equipment.size():
		if equipment[i].uid == uid:
			equipment.remove_at(i)
			changed.emit()
			return true
	return false


func count(item_id: StringName) -> int:
	var key := String(item_id)
	if stacks.has(key):
		return stacks[key]
	var n := 0
	for eq in equipment:
		if eq.item_id == key:
			n += 1
	return n


## True se tiver todos os itens pedidos. requirements = {id: quantidade}
func has_all(requirements: Dictionary) -> bool:
	for item_id in requirements:
		if count(StringName(item_id)) < int(requirements[item_id]):
			return false
	return true


## Remove os itens pedidos. Só remove se tiver tudo (não deixa pela metade).
func remove_all(requirements: Dictionary) -> bool:
	if not has_all(requirements):
		return false
	for item_id in requirements:
		var key := String(item_id)
		var qty := int(requirements[item_id])
		if stacks.has(key):
			stacks[key] -= qty
			if stacks[key] <= 0:
				stacks.erase(key)
		else:
			for i in qty:
				for j in equipment.size():
					if equipment[j].item_id == key:
						equipment.remove_at(j)
						break
	changed.emit()
	return true


func to_dict() -> Dictionary:
	return {"stacks": stacks.duplicate(), "equipment": equipment.duplicate(true), "next_uid": _next_uid}


func from_dict(data: Dictionary) -> void:
	stacks.clear()
	equipment.clear()
	var saved_stacks: Dictionary = data.get("stacks", {})
	for key in saved_stacks:
		stacks[String(key)] = int(saved_stacks[key])
	for eq in data.get("equipment", []):
		var stats := {}
		var saved_eq_stats: Dictionary = eq.get("stats", {})
		for k in saved_eq_stats:
			stats[String(k)] = int(saved_eq_stats[k])
		equipment.append({
			"uid": String(eq.get("uid", "")),
			"item_id": String(eq.get("item_id", "")),
			"ilvl": int(eq.get("ilvl", eq.get("level", 1))),
			"rarity": int(eq.get("rarity", 0)),
			"stats": stats,
		})
	_next_uid = int(data.get("next_uid", equipment.size() + 1))
	changed.emit()
