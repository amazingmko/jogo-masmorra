class_name HubUI
extends CanvasLayer
## Interface do hub: barra do herói (nível, XP, atributos), joystick, botão de ação perto das
## estações e as janelas: portal (dificuldade e energia), baú/equipamento, quadro de heróis e
## oficina dos artesãos (crafting em cadeia de raridade).

signal enter_dungeon_requested

const PANEL_BG := Color(0.1, 0.08, 0.15, 0.95)
const TEXT := Color("f2ecff")
const MUTED := Color("a9a2bf")
const GOLD := Color("e8c26a")
const OK_COLOR := Color("6fdc7b")
const BAD_COLOR := Color("ff6b6b")
const PROFESSIONS := [&"ferreiro", &"curtidor", &"tecela", &"erveira"]
## Profissão que faz a armadura de cada tipo (tecido, couro, placa).
const PROFESSION_FOR_ARMOR := [&"tecela", &"curtidor", &"ferreiro"]

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
var _difficulty := -1
var _use_energy := true
var _craft_prof: StringName = &""
var _craft_item: StringName = &""
var _craft_msg := ""
var _craft_msg_color := TEXT


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
	if _difficulty < 0:
		_difficulty = GameState.selected_difficulty
	if GameState.difficulty_lock(_difficulty, hero.id) != "":
		_difficulty = 0
	var energy := GameState.energy_now()
	if energy <= 0:
		_use_energy = false

	_modal_body.add_child(_label("Terra Firme", 24, GOLD))
	_modal_body.add_child(_label("Mata fechada com 5 áreas geradas aleatoriamente; na última, o Mapinguari. A masmorra deixa só reagentes: todo equipamento é fabricado na oficina. XP e reagentes ficam com o herói, mesmo perdendo.", 17, TEXT, true))
	_modal_body.add_child(_label("Herói: %s, nível %d · nível de item médio %s" % [hero.display_name,
		GameState.level_of(hero.id), _num(GameState.average_ilvl(hero.id))], 17, MUTED))

	_modal_body.add_child(_label("Dificuldade", 20, GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_modal_body.add_child(row)
	for d in 4:
		var lock := GameState.difficulty_lock(d, hero.id)
		var text := Difficulty.name_of(d) + ("" if lock == "" else "  (trancado)")
		var b := _button(text, 18, Difficulty.color_of(d) if lock == "" else MUTED)
		b.disabled = lock != ""
		if d == _difficulty:
			b.add_theme_stylebox_override("normal", _selected_style(Difficulty.color_of(d)))
			b.add_theme_stylebox_override("hover", _selected_style(Difficulty.color_of(d)))
		var dd := d
		b.pressed.connect(func() -> void:
			_difficulty = dd
			_refresh_open_panel())
		row.add_child(b)
	var lines := PackedStringArray()
	lines.append("Inimigos: vida ×%s · dano ×%s · mais agressivos" % [_num(Difficulty.HEALTH_MULT[_difficulty]),
		_num(Difficulty.DAMAGE_MULT[_difficulty])])
	lines.append("Recompensa: XP ×%s · reagentes ×%s%s" % [_num(Difficulty.XP_MULT[_difficulty]),
		_num(Difficulty.REWARD_MULT[_difficulty]), " · chance de Muiraquitã no chefe" if _difficulty == 3 else ""])
	_modal_body.add_child(_label("\n".join(lines), 17, TEXT, true))
	for d in range(1, 4):
		var lock := GameState.difficulty_lock(d, hero.id)
		if lock != "":
			_modal_body.add_child(_label("%s: %s." % [Difficulty.name_of(d), lock], 15, MUTED, true))
			break

	_modal_body.add_child(_label("Energia", 20, GOLD))
	var wait := GameState.seconds_to_next_energy()
	var energy_text := "%d/%d" % [energy, GameState.MAX_ENERGY]
	energy_text += " · cheia" if wait == 0 else " · próxima em %d min" % ceili(wait / 60.0)
	_modal_body.add_child(_label(energy_text, 17, TEXT))
	var toggle := _button("", 17, OK_COLOR if _use_energy else MUTED, true)
	if energy <= 0:
		toggle.text = "Sem energia: a run rende só %d%% dos reagentes e nenhum troféu do chefe. Jogar continua liberado." % int(Difficulty.NO_ENERGY_REWARD * 100)
		toggle.disabled = true
	elif _use_energy:
		toggle.text = "[x] Usar 1 energia: recompensa completa (toque para guardar a energia)"
	else:
		toggle.text = "[  ] Guardar a energia: a run rende só %d%% dos reagentes e nenhum troféu" % int(Difficulty.NO_ENERGY_REWARD * 100)
	toggle.pressed.connect(func() -> void:
		_use_energy = not _use_energy
		_refresh_open_panel())
	_modal_body.add_child(toggle)

	var enter := _button("Entrar na masmorra (%s)" % Difficulty.name_of(_difficulty), 22, Difficulty.color_of(_difficulty))
	enter.pressed.connect(func() -> void:
		GameState.selected_difficulty = _difficulty
		GameState.run_difficulty = _difficulty
		GameState.run_full_rewards = _use_energy and GameState.spend_energy()
		enter_dungeon_requested.emit())
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
	_modal_title.text = "Oficina dos Artesãos"
	var hero := _player.hero
	if _craft_prof == &"":
		_craft_prof = PROFESSION_FOR_ARMOR[hero.armor_type()]

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_modal_body.add_child(tabs)
	for prof_id in PROFESSIONS:
		var prof := ItemDB.catalog.get_profession(prof_id)
		var t := _button("%s · nv %d" % [prof.display_name, GameState.professions.level_of(prof_id)], 17,
			GOLD if prof_id == _craft_prof else TEXT)
		var pid: StringName = prof_id
		t.pressed.connect(func() -> void:
			_craft_prof = pid
			_craft_item = &""
			_craft_msg = ""
			_refresh_open_panel())
		tabs.add_child(t)

	var prof := ItemDB.catalog.get_profession(_craft_prof)
	var lvl := GameState.professions.level_of(_craft_prof)
	_modal_body.add_child(_label("%s — %s Nível %d · %d/%d XP" % [prof.display_name, prof.description, lvl,
		GameState.professions.xp_of(_craft_prof), prof.xp_to_next(lvl)], 16, MUTED, true))
	if _craft_msg != "":
		_modal_body.add_child(_label(_craft_msg, 17, _craft_msg_color, true))

	# Receitas da profissão, agrupadas pela peça.
	var by_item := {}
	for recipe: RecipeData in ItemDB.catalog.recipes.values():
		if recipe.profession_id != _craft_prof:
			continue
		if not by_item.has(recipe.result_item_id):
			by_item[recipe.result_item_id] = []
		by_item[recipe.result_item_id].append(recipe)
	var item_ids: Array = by_item.keys()
	item_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ia := ItemDB.get_item(a)
		var ib := ItemDB.get_item(b)
		var ua := ItemFactory.can_use(hero, ia)
		var ub := ItemFactory.can_use(hero, ib)
		if ua != ub:
			return ua
		return int(ia.slot) < int(ib.slot))
	if _craft_item == &"" or not by_item.has(_craft_item):
		_craft_item = item_ids[0] if not item_ids.is_empty() else &""

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(columns)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(320, 340)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	left_scroll.add_child(left)
	for item_id in item_ids:
		var item := ItemDB.get_item(item_id)
		var best := _best_rarity_owned(item_id)
		var text := item.display_name
		if item.is_equipment() and ItemFactory.can_use(hero, item):
			text += "  · seu herói"
		var color := GameEnums.rarity_color(best) if best >= 0 else (TEXT if item_id == _craft_item else MUTED)
		var b := _button(text, 16, color)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if item_id == _craft_item:
			b.add_theme_stylebox_override("normal", _selected_style(GOLD))
		var iid: StringName = item_id
		b.pressed.connect(func() -> void:
			_craft_item = iid
			_craft_msg = ""
			_refresh_open_panel())
		left.add_child(b)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.custom_minimum_size = Vector2(0, 340)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right)
	if _craft_item == &"":
		right.add_child(_label("Nenhuma receita.", 16, MUTED))
		return
	var recipes: Array = by_item[_craft_item]
	recipes.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return int(a.result_rarity) < int(b.result_rarity))
	for recipe: RecipeData in recipes:
		right.add_child(_recipe_card(recipe))


## Cartão de uma receita: raridade, chance, requisitos (tem/precisa) e o botão de fabricar.
func _recipe_card(recipe: RecipeData) -> Control:
	var item := ItemDB.get_item(recipe.result_item_id)
	var r := int(recipe.result_rarity)
	var color := GameEnums.rarity_color(r) if item.is_equipment() else TEXT
	var box := _card_panel(color.darkened(0.3))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	box.add_child(col)
	var streak := GameState.craft_streak(recipe.id)
	var chance := Crafting.success_chance(recipe, GameState.professions, streak)
	var head := recipe.display_name
	if item.is_equipment():
		head = "[%s] %s · nível de item %d" % [GameEnums.rarity_name(r), item.display_name, Crafting.CRAFTED_ILVL[r]]
	col.add_child(_label(head, 18, color, true))
	var info := "Chance de sucesso %d%%" % int(round(chance * 100))
	if streak > 0:
		info += " (+%d%% por %d falha%s seguida%s)" % [streak * 10, streak, "s" if streak > 1 else "", "s" if streak > 1 else ""]
	col.add_child(_label(info, 16, TEXT))

	var lvl := GameState.professions.level_of(recipe.profession_id)
	if lvl < recipe.required_level:
		col.add_child(_label("Precisa de nível %d na profissão (o seu: %d)" % [recipe.required_level, lvl], 15, BAD_COLOR))
	if recipe.requires_base:
		var base := Crafting.find_base(recipe, GameState.inventory, GameState.worn_uids())
		var base_text := "Peça-base: %s %s" % [item.display_name, GameEnums.rarity_name(r - 1)]
		if base.is_empty():
			col.add_child(_label(base_text + " — não tem", 15, BAD_COLOR, true))
		else:
			var wearer := GameState.wearer_of(base.uid)
			var note := " — vestida por %s; a nova é vestida no lugar" % ItemDB.get_hero(wearer).display_name if wearer != &"" else " — tem"
			col.add_child(_label(base_text + note, 15, OK_COLOR, true))
	var parts := PackedStringArray()
	for ing_id in recipe.ingredients:
		var need := int(recipe.ingredients[ing_id])
		var have := GameState.inventory.count(StringName(ing_id))
		var ing := ItemDB.get_item(StringName(ing_id))
		parts.append("%s %d/%d" % [ing.display_name if ing else String(ing_id), have, need])
	var enough := GameState.inventory.has_all(recipe.ingredients)
	col.add_child(_label("Reagentes: " + " · ".join(parts), 15, OK_COLOR if enough else MUTED, true))
	col.add_child(_label("+%d XP · na falha: perde metade dos reagentes, a peça-base volta e ganha %d XP" % [
		recipe.xp_reward, int(round(recipe.xp_reward * Crafting.FAIL_XP_FRACTION))], 14, MUTED, true))

	var reason := Crafting.check(recipe, GameState.inventory, GameState.professions, GameState.worn_uids())
	var make := _button("Fabricar" if reason == "" else reason, 18, color if reason == "" else MUTED)
	make.disabled = reason != ""
	var rid: StringName = recipe.id
	make.pressed.connect(func() -> void: _do_craft(rid))
	col.add_child(make)
	return box


func _do_craft(recipe_id: StringName) -> void:
	var recipe := ItemDB.get_recipe(recipe_id)
	var level_before := GameState.professions.level_of(recipe.profession_id)
	var res := GameState.craft(recipe_id)
	var item := ItemDB.get_item(recipe.result_item_id)
	if not res.ok:
		_craft_msg = res.reason
		_craft_msg_color = BAD_COLOR
	elif res.success:
		var name := recipe.display_name
		var worn := false
		if item.is_equipment():
			name = "%s %s (nível de item %d)" % [item.display_name, GameEnums.rarity_name(int(recipe.result_rarity)),
				Crafting.CRAFTED_ILVL[int(recipe.result_rarity)]]
			worn = GameState.wearer_of(res.uid) != &""
		_craft_msg = "Sucesso! %s%s. +%d XP" % [name, " — já vestida" if worn else "", res.xp]
		_craft_msg_color = GameEnums.rarity_color(int(recipe.result_rarity)) if item.is_equipment() else OK_COLOR
	else:
		var lost := PackedStringArray()
		for ing_id in res.lost:
			var ing := ItemDB.get_item(StringName(ing_id))
			lost.append("%d× %s" % [res.lost[ing_id], ing.display_name if ing else String(ing_id)])
		_craft_msg = "Falhou (chance era %d%%). Perdeu %s.%s Próxima tentativa: +10%%. +%d XP" % [
			int(round(res.chance * 100)), ", ".join(lost), " A peça-base voltou." if recipe.requires_base else "", res.xp]
		_craft_msg_color = BAD_COLOR
	var level_after := GameState.professions.level_of(recipe.profession_id)
	if level_after > level_before:
		_craft_msg += "  ·  %s subiu para o nível %d!" % [ItemDB.catalog.get_profession(recipe.profession_id).display_name, level_after]
	_player.refresh_stats()
	_refresh_top_bar()
	_refresh_open_panel()


## Maior raridade que o jogador tem desta peça (-1 se nenhuma).
func _best_rarity_owned(item_id: StringName) -> int:
	var best := -1
	for eq in GameState.inventory.equipment:
		if eq.item_id == String(item_id):
			best = maxi(best, int(eq.rarity))
	return best


func _num(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


func _selected_style(color: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(color, 0.18)
	st.border_color = color
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(10)
	return st


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
		list.add_child(_label("Nenhum equipamento ainda. Traga reagentes da masmorra e fabrique na oficina.", 17, MUTED, true))
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
	_xp_label.text = "XP %d/%d · Energia %d/%d" % [p.xp, Progression.xp_to_next(p.level),
		GameState.energy_now(), GameState.MAX_ENERGY]


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
