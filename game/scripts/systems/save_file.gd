class_name SaveFile
extends RefCounted
## Grava e lê o progresso com segurança.
##
## Como evita perder o save:
## 1. escreve tudo num arquivo temporário;
## 2. guarda o save anterior como backup (.bak);
## 3. só então troca o temporário pelo principal.
## Se o principal estiver corrompido ao carregar, usa o backup.

const CURRENT_VERSION := 3

## v3: heróis e reagentes com nomes da temática amazônica.
const HERO_RENAMES := {"guardiao": "icamiaba", "batedora": "mateira", "arcanista": "encantado"}
const ITEM_RENAMES := {"fragmento_osso": "madeira_lei", "couro_rasgado": "couro_jacare", "erva_vermelha": "oleo_andiroba"}
const PROFESSION_RENAMES := {"alquimista": "erveira"}


static func write(path: String, data: Dictionary) -> Error:
	var payload := data.duplicate(true)
	payload["save_version"] = CURRENT_VERSION
	payload["saved_at"] = Time.get_unix_time_from_system()

	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	# Confere se o temporário ficou legível antes de mexer no save bom.
	if _read_json(tmp_path).is_empty():
		return ERR_FILE_CORRUPT

	var bak_path := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var err := DirAccess.rename_absolute(path, bak_path)
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp_path, path)


## Devolve os dados, ou {} se não houver save. Tenta o backup se o principal falhar.
static func read(path: String) -> Dictionary:
	var data := _read_json(path)
	if data.is_empty():
		data = _read_json(path + ".bak")
		if not data.is_empty():
			push_warning("Save principal ilegível; carregado o backup.")
	return migrate(data)


## Converte saves de versões antigas para a atual. Cada versão nova ganha um passo aqui.
static func migrate(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return data
	var version := int(data.get("save_version", 1))
	if version < 2:
		# v2: heróis com nível/XP/equipamento; peças com raridade, nível e atributos.
		# Inventory e GameState completam os campos que faltam ao carregar.
		if not data.has("heroes"):
			data["heroes"] = {}
		version = 2
	if version < 3:
		_migrate_v3(data)
		version = 3
	data["save_version"] = version
	return data


static func _migrate_v3(data: Dictionary) -> void:
	var heroes: Dictionary = data.get("heroes", {})
	var new_heroes := {}
	for key in heroes:
		new_heroes[HERO_RENAMES.get(String(key), String(key))] = heroes[key]
	data["heroes"] = new_heroes
	var unlocked := []
	for h in data.get("unlocked_heroes", []):
		var renamed: String = HERO_RENAMES.get(String(h), String(h))
		if not unlocked.has(renamed):
			unlocked.append(renamed)
	data["unlocked_heroes"] = unlocked
	data["selected_hero"] = HERO_RENAMES.get(String(data.get("selected_hero", "icamiaba")), String(data.get("selected_hero", "icamiaba")))

	var inv: Dictionary = data.get("inventory", {})
	var stacks: Dictionary = inv.get("stacks", {})
	var new_stacks := {}
	for key in stacks:
		var id: String = ITEM_RENAMES.get(String(key), String(key))
		new_stacks[id] = int(new_stacks.get(id, 0)) + int(stacks[key])
	inv["stacks"] = new_stacks
	data["inventory"] = inv

	var profs: Dictionary = data.get("professions", {})
	var new_profs := {}
	for key in profs:
		new_profs[PROFESSION_RENAMES.get(String(key), String(key))] = profs[key]
	data["professions"] = new_profs


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}
