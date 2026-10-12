class_name DropTable
extends Resource
## O que um inimigo, chefe ou baú pode deixar cair.

@export var id: StringName
## Quantas vezes sortear (um chefe pode sortear 3 vezes, um inimigo comum 1).
@export_range(1, 20) var rolls: int = 1
## Peso de "não cair nada". 0 = sempre cai algo.
@export_range(0, 10000) var nothing_weight: int = 0
@export var entries: Array[DropEntry] = []


## Sorteia o loot. Recebe o gerador da run, para a mesma semente dar o mesmo resultado.
## Devolve uma lista de {"item_id": StringName, "qty": int}, juntando itens repetidos.
func roll(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var totals := {}
	var total_weight := nothing_weight
	for entry in entries:
		total_weight += entry.weight
	if total_weight <= 0:
		return []

	for i in rolls:
		var pick := rng.randi_range(1, total_weight)
		if pick <= nothing_weight:
			continue
		var acc := nothing_weight
		for entry in entries:
			acc += entry.weight
			if pick <= acc:
				var qty := rng.randi_range(entry.min_qty, maxi(entry.min_qty, entry.max_qty))
				totals[entry.item_id] = totals.get(entry.item_id, 0) + qty
				break

	var result: Array[Dictionary] = []
	for item_id in totals:
		result.append({"item_id": item_id, "qty": totals[item_id]})
	return result
