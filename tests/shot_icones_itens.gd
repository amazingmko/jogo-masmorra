extends SceneTree
## Folha com o ícone de todos os itens (fundo da bolsa), para conferir o recorte da arte.
##   godot --path . --script res://tests/shot_icones_itens.gd -- out=/pasta

var _out := "/tmp"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _run() -> void:
	var db = root.get_node("ItemDB")
	var bg := ColorRect.new()
	bg.color = Color("1b1712")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(20, 14)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	bg.add_child(grid)
	var ids: Array = []
	for f in DirAccess.get_files_at("res://game/data/items"):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	for id in ids:
		var item = db.get_item(StringName(id))
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(148, 0)
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2a241c")
		sb.border_color = Color("6b5634")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		var t := TextureRect.new()
		var path := "res://game/ui/icones/item_%s.png" % id
		if ResourceLoader.exists(path):
			t.texture = load(path)
		t.custom_minimum_size = Vector2(110, 110)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(t)
		box.add_child(panel)
		var l := Label.new()
		l.text = item.display_name if item else id
		l.add_theme_font_size_override("font_size", 13)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		box.add_child(l)
		grid.add_child(box)
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/icones_itens.png" % _out)
	quit(0)
