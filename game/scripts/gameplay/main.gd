extends Node3D
## Cena de teste da fundação.
## Mostra que o 3D, a câmera, os dados, o inventário, o crafting e o save funcionam juntos.
##   WASD ou setas: andar
##   L: matar um esqueleto de mentira e sortear o loot
##   C: tentar forjar uma espada de ferro
##   G: gravar (salvar) agora

@onready var _info: Label = $HUD/Info

var _rng := RandomNumberGenerator.new()
var _last_message := "Aperte L para sortear loot de um esqueleto."


func _ready() -> void:
	_rng.randomize()
	GameState.inventory.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_L:
			_simulate_kill(&"esqueleto")
		KEY_C:
			_try_craft(&"forjar_espada_ferro")
		KEY_G:
			_last_message = "Jogo salvo." if GameState.save() else "Falha ao salvar."
			_refresh()


func _simulate_kill(table_id: StringName) -> void:
	var table := ItemDB.get_drop_table(table_id)
	var loot := table.roll(_rng)
	if loot.is_empty():
		_last_message = "O esqueleto não deixou nada."
	else:
		var parts := PackedStringArray()
		for drop in loot:
			var item := ItemDB.get_item(drop.item_id)
			GameState.inventory.add(item, drop.qty)
			parts.append("%d× %s" % [drop.qty, item.display_name])
		_last_message = "Loot: " + ", ".join(parts)
	_refresh()


func _try_craft(recipe_id: StringName) -> void:
	var recipe := ItemDB.get_recipe(recipe_id)
	var result := Crafting.craft(recipe, GameState.inventory, GameState.professions, ItemDB.catalog)
	if result.ok:
		_last_message = "Forjou: %s! (Ferreiro nível %d)" % [
			recipe.display_name, GameState.professions.level_of(recipe.profession_id)]
	else:
		_last_message = "Não deu para forjar: " + result.reason
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray()
	lines.append("FUNDAÇÃO — WASD/setas: andar · L: loot · C: forjar espada · G: salvar")
	lines.append(_last_message)
	lines.append("")
	lines.append("Inventário:")
	if GameState.inventory.stacks.is_empty() and GameState.inventory.equipment.is_empty():
		lines.append("  (vazio)")
	for item_id in GameState.inventory.stacks:
		var item := ItemDB.get_item(StringName(item_id))
		lines.append("  %d× %s" % [GameState.inventory.stacks[item_id], item.display_name if item else item_id])
	for eq in GameState.inventory.equipment:
		var item := ItemDB.get_item(StringName(eq.item_id))
		lines.append("  [equip.] %s" % (item.display_name if item else eq.item_id))
	_info.text = "\n".join(lines)
