extends Node
## Autoload "SaveSystem": onde fica o save e quando gravar.
## As regras de gravação segura estão em SaveFile.

const SAVE_PATH := "user://save.json"


func save_game(data: Dictionary) -> bool:
	var err := SaveFile.write(SAVE_PATH, data)
	if err != OK:
		push_error("Falha ao salvar o jogo (erro %d)." % err)
		return false
	return true


func load_game() -> Dictionary:
	return SaveFile.read(SAVE_PATH)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak")
