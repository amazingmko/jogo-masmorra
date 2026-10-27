class_name HeroesPanel
extends HBoxContainer
## Escolha de herói (como a seleção de personagem de um MMORPG), sem rolagem:
## - esquerda: os heróis em cartões (nome, funções, nível);
## - meio: o herói olhado, em 3D, girável;
## - direita: quem é, de onde vem (bioma e região), atributo e armadura, XP, as 3 especializações
##   com a função de cada uma, e os botões de talentos e de escolher.

signal open_talents(hero_id: StringName)
signal hero_chosen(hero: HeroData)
## Enfrentar a Provação do Folclore deste herói (nível 10, 20 ou 30).
signal trial_requested(hero_id: StringName, tier: int)

## Herói que está sendo olhado (não precisa ser o escolhido).
static var viewing: StringName = &""

var player: Player


func build(p: Player) -> void:
	player = p
	if viewing == &"" or ItemDB.get_hero(viewing) == null:
		viewing = p.hero_id
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_refresh()


func _refresh() -> void:
	for ch in get_children():
		ch.queue_free()
	var hero := ItemDB.get_hero(viewing)
	if hero == null:
		hero = player.hero
		viewing = hero.id
	add_child(_list())
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 0)
	add_child(center)
	var body := UiStyle.column_body()
	center.add_child(body)
	var v := HeroPreview.new().setup(hero, Vector2(260, 380))
	body.add_child(v)
	add_child(_info(hero))


func _list() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(392, 0)
	col.add_theme_constant_override("separation", 0)
	var body := UiStyle.column_body()
	col.add_child(body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	for hero_id in GameState.unlocked_heroes:
		var hero := ItemDB.get_hero(StringName(hero_id))
		if hero == null:
			continue
		list.add_child(_hero_card(hero))
	return col


func _hero_card(hero: HeroData) -> Control:
	var looking := hero.id == viewing
	var chosen := hero.id == player.hero_id
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := UiStyle.section(looking)
	sb.bg_color = Color(UiStyle.c("accent"), 0.14) if looking else Color(0, 0, 0, 0.35)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, sb)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(hrow)
	var face := UiStyle.portrait(String(hero.id), 66)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not looking:
		face.modulate = Color(0.8, 0.8, 0.85)
	hrow.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var n := Label.new()
	n.text = hero.display_name
	UiStyle.title_label(n, 20, UiStyle.GOLD if looking else UiStyle.TEXT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(n)
	# uma linha só embaixo do nome: o nível (e se é o herói em uso)
	var sub := UiStyle.label("Nível %d" % GameState.level_of(hero.id), 15, UiStyle.TEXT_DIM)
	if chosen:
		sub.text = "Nível %d, em uso" % GameState.level_of(hero.id)
		sub.add_theme_color_override("font_color", UiStyle.GOLD)
	v.add_child(sub)
	var hid := hero.id
	b.pressed.connect(func() -> void:
		viewing = hid
		_refresh())
	return b


func _info(hero: HeroData) -> Control:
	var p := GameState.progress(hero.id)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 0)
	var body := UiStyle.column_body()
	col.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	body.add_child(v)
	var n := Label.new()
	n.text = hero.display_name
	UiStyle.title_label(n, 30)
	v.add_child(n)
	var xp := UiStyle.bar(Color("4fbf7a"), 100, 22)
	xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pending := GameState.trial_pending(hero.id)
	# o nível vai dentro da barra de XP
	UiStyle.set_bar(xp, p.xp, Progression.xp_to_next(p.level), "Nível %d: falta a Provação" % p.level if pending > 0
		else "Nível %d" % p.level)
	v.add_child(xp)
	var done := []
	for t in GameState.TRIAL_LEVELS:
		var st := GameState.trial_stars(hero.id, t)
		if st > 0:
			done.append(t)
	if not done.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for t in done:
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			cell.add_child(UiStyle.chip("Nv %d" % t, "coroa", Color("ffd84a"), 12))
			cell.add_child(UiStyle.pips(GameState.trial_stars(hero.id, t), 3, Color("ffd84a"), 12))
			row.add_child(cell)
		v.add_child(row)
	var d := UiStyle.label(hero.description, 15, UiStyle.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(340, 0)
	if pending == 0:  # com a Provação na tela, a caixa dela ocupa o lugar (sem rolagem)
		v.add_child(d)
	# as 3 especializações e a função de cada uma
	var specs := VBoxContainer.new()
	specs.add_theme_constant_override("separation", 5)
	v.add_child(specs)
	for b in Talents.branches(hero.id):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ic := TextureRect.new()
		ic.texture = load("res://game/ui/icones/s_%s.png" % SpecInfo.icon(String(b.id)))
		ic.custom_minimum_size = Vector2(26, 26)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
		var active: bool = String(b.id) == GameState.active_spec(hero.id)
		var bl := Label.new()
		bl.text = b.name
		UiStyle.title_label(bl, 17, UiStyle.GOLD if active else UiStyle.TEXT)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bl)
		# ativa = nome em dourado; as funções só com o ícone
		row.add_child(SpecInfo.role_icons(String(b.id), 24))
		specs.add_child(row)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	if pending > 0:
		v.add_child(_trial_box(hero, pending))
	elif OS.is_debug_build() and GameState.level_cap(hero.id) < Progression.MAX_LEVEL:
		# atalho de teste (não aparece no jogo final)
		var dev := Button.new()
		dev.text = "Teste: ir para a Provação do %d" % GameState.level_cap(hero.id)
		dev.focus_mode = Control.FOCUS_NONE
		dev.custom_minimum_size = Vector2(0, 42)
		UiStyle.style_button(dev, "normal", 15)
		var did := hero.id
		dev.pressed.connect(func() -> void:
			GameState.debug_jump_to_trial(did)
			_refresh())
		v.add_child(dev)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	v.add_child(buttons)
	if Talents.has_tree(hero.id):
		var free := GameState.talent_points_free(hero.id)
		var tb := Button.new()
		tb.text = "Talentos" + ("  +%d" % free if free > 0 else "")
		UiStyle.style_button(tb, "normal", 19)
		if free > 0:
			tb.add_theme_color_override("font_color", UiStyle.OK)
		tb.custom_minimum_size = Vector2(0, 56)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hid := hero.id
		tb.pressed.connect(func() -> void: open_talents.emit(hid))
		buttons.add_child(tb)
	var pick := Button.new()
	pick.custom_minimum_size = Vector2(0, 56)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hero.id == player.hero_id:
		pick.text = "Em uso"
		UiStyle.style_button(pick, "normal", 19)
		pick.disabled = true
		pick.add_theme_color_override("font_disabled_color", UiStyle.GOLD)
	else:
		pick.text = "Escolher"
		UiStyle.style_button(pick, "ouro", 20)
		pick.pressed.connect(func() -> void:
			hero_chosen.emit(hero)
			_refresh())
	buttons.add_child(pick)
	return col


## Provação pendente: o nome da prova, o objetivo e o botão (com o preço, cobrado só ao vencer).
func _trial_box(hero: HeroData, tier: int) -> Control:
	var info := Trial.info(hero.id)
	var cost := GameState.trial_cost(tier)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.section(true))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var t := Label.new()
	t.text = info.name
	UiStyle.title_label(t, 19, UiStyle.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	v.add_child(UiStyle.label(info.goal, 15, UiStyle.TEXT_DIM))
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 50)
	b.focus_mode = Control.FOCUS_NONE
	var can := GameState.coins >= cost and not Net.active
	b.text = "Enfrentar  %d ouro" % cost
	UiStyle.style_button(b, "ouro" if can else "normal", 18)
	b.disabled = not can
	v.add_child(b)
	if not can:
		v.add_child(UiStyle.chips([["Só sozinho" if Net.active else "Faltam %d de ouro" % (cost - GameState.coins), "cadeado", UiStyle.TEXT_DIM]]))
	else:
		b.tooltip_text = "O ouro só sai se vencer."
	var hid := hero.id
	b.pressed.connect(func() -> void: trial_requested.emit(hid, tier))
	return box
