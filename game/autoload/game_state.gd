extends Node
## Autoload "GameState": o progresso do jogador enquanto o jogo roda.
## Carrega o save ao abrir e grava sozinho quando o app vai para segundo plano ou fecha.

signal coins_changed(new_value: int)

var coins: int = 0
var inventory := Inventory.new()
var professions := ProfessionProgress.new()
var unlocked_heroes: PackedStringArray = []


func _ready() -> void:
	var data := SaveSystem.load_game()
	if data.is_empty():
		_new_profile()
	else:
		from_dict(data)


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


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"inventory": inventory.to_dict(),
		"professions": professions.to_dict(),
		"unlocked_heroes": Array(unlocked_heroes),
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	inventory.from_dict(data.get("inventory", {}))
	professions.from_dict(data.get("professions", {}))
	unlocked_heroes = PackedStringArray(data.get("unlocked_heroes", []))
	coins_changed.emit(coins)


func _new_profile() -> void:
	coins = 0
	unlocked_heroes = PackedStringArray(["guardiao"])
