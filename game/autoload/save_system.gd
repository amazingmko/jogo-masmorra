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
	_migrate_old_name()
	return SaveFile.read(SAVE_PATH)


## O jogo se chamava "Jogo de Masmorra": no PC o save ficava na pasta com esse nome. Na primeira
## vez com o nome novo (Encante), copia o save antigo para a pasta nova (o antigo fica intacto).
## No Android a pasta é a do pacote, que não mudou.
func _migrate_old_name() -> void:
	if has_save():
		return
	var old_dir := OS.get_user_data_dir().get_base_dir().path_join("Jogo de Masmorra")
	for file in ["save.json", "save.json.bak"]:
		var from := old_dir.path_join(file)
		if FileAccess.file_exists(from):
			DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
			DirAccess.copy_absolute(from, OS.get_user_data_dir().path_join(file))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak")
