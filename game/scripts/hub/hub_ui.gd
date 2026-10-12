class_name HubUI
extends CanvasLayer
## Interface do hub: barra do herói (nível, XP, atributos), joystick, botão de ação perto das
## estações e as janelas: portal, baú/equipamento, quadro de heróis e artesão.

signal enter_dungeon_requested

const PANEL_BG := Color(0.1, 0.08, 0.15, 0.95)
const TEXT := Color("f2ecff")
const MUTED := Color("a9a2bf")
const GOLD := Color("e8c26a")

var joystick: TouchJoystick
var action_button: TouchButton

var _player: Player
var _station: HubStation
var _hero_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _modal: PanelContainer
var _modal_title: Label
var _modal_body: VBoxContainer
var _open_station: StringName = &""
var _bag_tab := "equip"


func _ready() -> void:
	_build_top_bar()
	_build_controls()
	_build_modal()


func setup(player: Player) -> void:
	_player = player
	GameState.hero_progress_changed.connect(func(_id: StringName) -> void:
		_refresh_top_bar()
		_refresh_open_panel())
	_refresh_top_bar()


func move_vector() -> Vector2:
	return joystick.value if not _modal.visible else Vector2.ZERO


func on_station_presence(station: HubStation, inside: bool) -> void:
	if inside:
		_station = station
		action_button.text = station.action_text
		action_button.visible = not _modal.visible
		action_button.queue_redraw()
	elif _station == station:
		_station = null
		action_button.visible = false


func activate_current_station() -> void:
	if _station == null or _modal.visible:
		return
	_open(_station.station_id)


# ---------- janelas ----------

func _open(station_id: StringName) -> void:
	_open_station = station_id
	_modal.visible = true
	action_button.visible = false
	joystick.release()
	joystick.visible = false
	_refresh_open_panel()


func _close() -> void:
	_modal.visible = false
	_open_station = &""
	joystick.visible = true
	action_button.visible = _station != null


func _refresh_open_panel() -> void:
	if not _modal.visible:
		return
	for c in _modal_body.get_children():
		c.queue_free()
	match _open_station:
		&"portal":
			_fill_portal()
		&"bau":
			_fill_bag()
		&"herois":
			_fill_heroes()
		&"artesao":
			_fill_artisan()


func _fill_portal() -> void:
	_modal_title.text = "Portal da Masmorra"
	var hero := _player.hero
	_modal_body.add_child(_label("Masmorra das Criptas — Normal", 24, GOLD))
	_modal_body.add_child(_label("5 andares gerados aleatoriamente. No último, o Rei Ossudo.\nEquipamentos de nível 1 a 10. Todo loot e XP ficam com o herói, mesmo perdendo.", 18, TEXT, true))
	_modal_body.add_child(_label("Herói: %s, nível %d" % [hero.display_name, GameState.level_of(hero.id)], 18, MUTED))
	_modal_body.add_child(_label("Difícil, Heroico e Mítico chegam na próxima etapa (4b).", 16, MUTED))
	var enter := _button("Entrar na masmorra", 22)
	enter.pressed.connect(func() -> void: enter_dungeon_requested.emit())
	_modal_body.add_child(enter)


func _fill_heroes() -> void:
	_modal_title.text = "Quadro de Heróis"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_body.add_child(row)
	for hero_id in GameState.unlocked_heroes:
		var hero := ItemDB.get_hero(StringName(hero_id))
		if hero == null:
			continue
		var p := GameState.progress(hero.id)
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(260, 0)
		card.add_theme_constant_override("separation", 6)
		var box := _card_panel(GOLD if hero.id == _player.hero_id else Color(1, 1, 1, 0.3))
		box.add_child(card)
		row.add_child(box)
		card.add_child(_label(hero.display_name, 24, GOLD if hero.id == _player.hero_id else TEXT))
		card.add_child(_label("Nível %d · %d/%d XP" % [p.level, p.xp, Progression.xp_to_next(p.level)], 16, MUTED))
		card.add_child(_label("%s · %s" % [GameEnums.PRIMARY_NAMES[hero.primary_stat], GameEnums.ARMOR_NAMES[hero.armor_type()]], 18))
		card.add_child(_label(hero.description, 15, MUTED, true))
		if hero.id == _player.hero_id:
			card.add_child(_label("Selecionado", 18, GOLD))
		else:
			var pick := _button("Escolher", 18)
			pick.pressed.connect(func() -> void:
				GameState.selected_hero = hero.id
				_player.set_hero(hero)
				GameState.save()
				_refresh_top_bar()
				_refresh_open_panel())
			card.add_child(pick)


func _fill_artisan() -> void:
	_modal_title.text = "Artesão"
	_modal_body.add_child(_label("\"Traga materiais das masmorras e eu transformo em equipamento.\"", 18, TEXT, true))
	_modal_body.add_child(_label("Profissões, receitas e a chance de falha chegam na próxima etapa (4b).", 16, MUTED))
	_modal_body.add_child(_label("Seus materiais:", 20, GOLD))
	var any := false
	for item_id in GameState.inventory.stacks:
		var item := ItemDB.get_item(StringName(item_id))
		_modal_body.add_child(_label("  %d× %s" % [GameState.inventory.stacks[item_id], item.display_name if item else item_id], 17))
		any = true
	if not any:
		_modal_body.add_child(_label("  nenhum ainda — explore a masmorra!", 17, MUTED))


# ---------- baú e equipamento ----------

func _fill_bag() -> void:
	var hero := _player.hero
	_modal_title.text = "Baú e Equipamento — %s" % hero.display_name
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(columns)

	# Esquerda: o que está vestido e os atributos.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)
	left.add_child(_label("Vestido (toque para tirar)", 18, GOLD))
	var equipped := GameState.equipped_items(hero.id)
	for slot in GameEnums.SLOT_NAMES.size():
		var inst: Dictionary = equipped.get(slot, {})
		var text := "%s: —" % GameEnums.SLOT_NAMES[slot]
		var color := MUTED
		if not inst.is_empty():
			text = "%s: %s" % [GameEnums.SLOT_NAMES[slot], ItemFactory.display_name(inst, ItemDB.catalog)]
			color = GameEnums.rarity_color(int(inst.rarity))
		var b := _button(text, 16, color)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = inst.is_empty()
		var slot_index := slot
		b.pressed.connect(func() -> void: GameState.unequip(hero.id, slot_index))
		left.add_child(b)

	var st := _player.stats
	left.add_child(_label("Atributos", 18, GOLD))
	var lines := PackedStringArray([
		"Vida %d · Escudo %d" % [st.max_health, st.max_shield],
		"%s %d · Vigor %d" % [GameEnums.PRIMARY_NAMES[hero.primary_stat], st.primary, st.vigor],
		"Armadura %d (bloqueia %d%% do dano)" % [st.armor, int(round(st.damage_reduction * 100))],
		"Dano da arma %d · Crítico %d%%" % [st.weapon.damage, int(round(st.crit_chance * 100))],
		"Aceleração %d%% · Sorte %d%%" % [int(st.haste), int(st.luck)],
	])
	left.add_child(_label("\n".join(lines), 16))

	# Direita: abas de equipamento e materiais.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	right.add_child(tabs)
	for tab in [["equip", "Equipamentos"], ["mat", "Materiais"]]:
		var t := _button(tab[1], 17, GOLD if _bag_tab == tab[0] else TEXT)
		var tab_id: String = tab[0]
		t.pressed.connect(func() -> void:
			_bag_tab = tab_id
			_refresh_open_panel())
		tabs.add_child(t)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	if _bag_tab == "mat":
		_fill_materials(list)
	else:
		_fill_equipment_list(list, hero, equipped)


func _fill_materials(list: VBoxContainer) -> void:
	if GameState.inventory.stacks.is_empty():
		list.add_child(_label("Nenhum material ainda.", 17, MUTED))
	for item_id in GameState.inventory.stacks:
		var item := ItemDB.get_item(StringName(item_id))
		if item == null:
			continue
		list.add_child(_label("%d× %s — %s" % [GameState.inventory.stacks[item_id], item.display_name, item.description], 16, TEXT, true))


func _fill_equipment_list(list: VBoxContainer, hero: HeroData, equipped: Dictionary) -> void:
	var pieces: Array = GameState.inventory.equipment.duplicate()
	if pieces.is_empty():
		list.add_child(_label("Nenhum equipamento ainda. Os inimigos e baús deixam cair peças.", 17, MUTED, true))
		return
	# Primeiro o que o herói pode usar; depois por raridade e nível.
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ua := ItemFactory.can_use(hero, ItemDB.get_item(StringName(a.item_id)))
		var ub := ItemFactory.can_use(hero, ItemDB.get_item(StringName(b.item_id)))
		if ua != ub:
			return ua
		if int(a.rarity) != int(b.rarity):
			return int(a.rarity) > int(b.rarity)
		return int(a.ilvl) > int(b.ilvl))

	for inst in pieces:
		var template := ItemDB.get_item(StringName(inst.item_id))
		if template == null:
			continue
		var usable := ItemFactory.can_use(hero, template)
		var wearer := GameState.wearer_of(inst.uid)
		var header := "[%s] %s" % [GameEnums.rarity_name(int(inst.rarity)), ItemFactory.display_name(inst, ItemDB.catalog)]
		var detail := ItemFactory.describe_stats(inst.stats)
		var note := ""
		if wearer == hero.id:
			note = "vestido"
		elif wearer != &"":
			note = "com %s" % ItemDB.get_hero(wearer).display_name
		elif not usable:
			note = _usage_note(template)
		else:
			note = _compare(inst, equipped.get(int(template.slot), {}), hero)
		var b := _button("%s\n%s%s" % [header, detail, ("   ·   " + note) if note != "" else ""], 15,
			GameEnums.rarity_color(int(inst.rarity)) if usable else MUTED, true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not usable or wearer == hero.id
		var uid: String = inst.uid
		b.pressed.connect(func() -> void:
			var err := GameState.equip(hero.id, uid)
			if err != "":
				push_warning(err)
			GameState.save())
		list.add_child(b)


func _usage_note(template: ItemData) -> String:
	if template.kind == ItemData.Kind.ARMOR:
		var primary: int = GameEnums.PRIMARY_FOR_ARMOR[template.armor_type]
		return "%s — heróis de %s" % [GameEnums.ARMOR_NAMES[template.armor_type], GameEnums.PRIMARY_NAMES[primary].to_lower()]
	return "arma de outra classe (%s)" % template.weapon_type


## "▲ +5 Força ▼ -2 Vigor" em relação à peça vestida no mesmo slot.
func _compare(inst: Dictionary, current: Dictionary, hero: HeroData) -> String:
	var keys := [GameEnums.PRIMARY_KEYS[hero.primary_stat], "vigor", "armor", "damage"]
	var parts := PackedStringArray()
	for key in keys:
		var a := int(inst.stats.get(key, 0))
		var b := int(current.get("stats", {}).get(key, 0))
		if a == b or (a == 0 and b == 0):
			continue
		parts.append("%s%+d %s" % ["▲" if a > b else "▼", a - b, GameEnums.STAT_NAMES.get(key, key)])
	if current.is_empty():
		return "slot vazio — toque para vestir"
	return " ".join(parts) if not parts.is_empty() else "igual ao vestido"


# ---------- montagem ----------

func _refresh_top_bar() -> void:
	if _player == null or _player.hero == null:
		return
	var hero := _player.hero
	var p := GameState.progress(hero.id)
	_hero_label.text = "%s · nível %d · %s/%s" % [hero.display_name, p.level,
		GameEnums.PRIMARY_NAMES[hero.primary_stat], GameEnums.ARMOR_NAMES[hero.armor_type()]]
	_xp_bar.max_value = Progression.xp_to_next(p.level)
	_xp_bar.value = p.xp
	_xp_label.text = "XP %d/%d" % [p.xp, Progression.xp_to_next(p.level)]


func _build_top_bar() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_hero_label = _label("", 24)
	box.add_child(_hero_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(300, 14)
	_xp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("8b5cf6")
	fill.set_corner_radius_all(6)
	_xp_bar.add_theme_stylebox_override("background", bg)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_xp_bar)
	_xp_label = _label("", 15, MUTED)
	box.add_child(_xp_label)

	var help := _label("Base · ande até um ponto e toque no botão (PC: E)", 15, MUTED)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help.offset_right = -20
	help.offset_top = 18
	add_child(help)


func _build_controls() -> void:
	joystick = TouchJoystick.new()
	joystick.anchor_left = 0.0
	joystick.anchor_top = 0.3
	joystick.anchor_right = 0.5
	joystick.anchor_bottom = 1.0
	add_child(joystick)

	action_button = TouchButton.new()
	action_button.color = Color("4db8ff")
	action_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	action_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	action_button.offset_left = -210
	action_button.offset_top = -210
	action_button.offset_right = -60
	action_button.offset_bottom = -60
	action_button.visible = false
	action_button.pressed_changed.connect(func(pressed: bool) -> void:
		if pressed:
			activate_current_station())
	add_child(action_button)


func _build_modal() -> void:
	_modal = PanelContainer.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.offset_left = 60
	_modal.offset_right = -60
	_modal.offset_top = 40
	_modal.offset_bottom = -40
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(22)
	_modal.add_theme_stylebox_override("panel", style)
	add_child(_modal)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_modal.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	_modal_title = _label("", 28, GOLD)
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_modal_title)
	var close := _button("Fechar", 18)
	close.custom_minimum_size = Vector2(120, 0)
	close.pressed.connect(_close)
	header.add_child(close)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 10)
	outer.add_child(_modal_body)
	_modal.visible = false


## wrap: quebra linhas (só use quando o rótulo estiver dentro de um container com largura).
func _label(text: String, font_size: int, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("1a1526"))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, font_size: int, color: Color = TEXT, wrap: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_disabled_color", color.darkened(0.15))
	if wrap:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.14)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(1, 1, 1, 0.03)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	return b


func _card_panel(border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", style)
	return p
