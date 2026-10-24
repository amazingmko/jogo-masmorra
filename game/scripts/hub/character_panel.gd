class_name CharacterPanel
extends HBoxContainer
## Tela do personagem (baú e equipamento), no jeito de MMORPG adaptado ao celular:
## - esquerda: o herói em 3D girando devagar no pedestal, com as peças vestidas em volta;
## - meio: os atributos, curtos (nome e número);
## - direita: a bolsa em grade de ícones (equipamentos ou reagentes) e, embaixo, o detalhe do item
##   tocado, com a comparação com o que está vestido e o botão de vestir/tirar.
## Pouco texto: o detalhe só aparece quando se toca num item.

const SLOT := 76
const LEFT_SLOTS := [GameEnums.Slot.HEAD, GameEnums.Slot.CHEST, GameEnums.Slot.HANDS]
const RIGHT_SLOTS := [GameEnums.Slot.LEGS, GameEnums.Slot.FEET, GameEnums.Slot.OFFHAND]
const SLOT_ICON := {GameEnums.Slot.HEAD: "cabeca", GameEnums.Slot.CHEST: "peito", GameEnums.Slot.HANDS: "maos",
	GameEnums.Slot.LEGS: "pernas", GameEnums.Slot.FEET: "pes", GameEnums.Slot.OFFHAND: "escudo"}
const MATERIAL_ICON := {"madeira_lei": "madeira", "fibra_tucum": "fibra", "couro_jacare": "couro",
	"minerio_ferro": "minerio", "pena_arara": "pena", "latex_seringueira": "latex", "oleo_andiroba": "oleo",
	"semente_guarana": "semente", "pelo_mapinguari": "pelo", "muiraquita": "muiraquita", "pocao_vida": "pocao"}
const WEAPON_ICON := {"lanca": "lanca", "arco": "arco", "cajado": "cajado", "cajado_raiz": "cajado"}

var player: Player
## "equip" ou "mat". (estáticos: a janela é remontada quando o herói muda, e a escolha continua)
static var tab := "equip"
## O que está selecionado: {"uid": ...} (peça), {"slot": n} (vestida) ou {"mat": id}.
static var selected := {}




static func icon_name(template: ItemData) -> String:
	if template == null:
		return ""
	match template.kind:
		ItemData.Kind.WEAPON:
			return WEAPON_ICON.get(String(template.weapon_type), "lanca")
		ItemData.Kind.ARMOR:
			return SLOT_ICON.get(int(template.slot), "peito")
	return MATERIAL_ICON.get(String(template.id), "minerio")


func build(p: Player) -> void:
	player = p
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_refresh()


func _refresh() -> void:
	for ch in get_children():
		ch.queue_free()
	add_child(_doll())
	add_child(_stats())
	add_child(_bag())


# ---------- herói e peças vestidas ----------

func _doll() -> Control:
	var hero := player.hero
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 0)
	# cabeçalho: nome (na mesma altura das abas da bolsa) e os selos de nível e poder
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.custom_minimum_size = Vector2(0, 46)
	box.add_child(head)
	head.add_child(UiStyle.header(hero.display_name))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	head.add_child(UiStyle.chip("%d" % GameState.level_of(hero.id), "nivel", Color("ffd25a")))
	head.add_child(UiStyle.chip("%d" % GameState.power_of(hero.id), "poder", UiStyle.c("accent")))
	var body := UiStyle.column_body()
	box.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	body.add_child(inner)
	# peças | herói | peças
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(mid)
	var equipped := GameState.equipped_items(hero.id)
	mid.add_child(_slot_column(LEFT_SLOTS, equipped, hero))
	mid.add_child(_hero_view(hero))
	mid.add_child(_slot_column(RIGHT_SLOTS, equipped, hero))
	# arma embaixo, no meio, entre os selos da classe
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	inner.add_child(bottom)
	bottom.add_child(UiStyle.chip(GameEnums.PRIMARY_NAMES[hero.primary_stat], UiStyle.primary_icon(hero.primary_stat)))
	bottom.add_child(_equip_slot(GameEnums.Slot.WEAPON, equipped, hero))
	bottom.add_child(UiStyle.chip(GameEnums.ARMOR_NAMES[hero.armor_type()], UiStyle.armor_icon(hero.armor_type())))
	return box


func _badge(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = Color(color, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	UiStyle.title_label(l, 17, color)
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _slot_column(slots: Array, equipped: Dictionary, hero: HeroData) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in slots:
		if s == GameEnums.Slot.OFFHAND and hero.hero_class != GameEnums.HeroClass.TANK:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(SLOT, SLOT)
			col.add_child(gap)
			continue
		col.add_child(_equip_slot(s, equipped, hero))
	return col


func _equip_slot(s: int, equipped: Dictionary, _hero: HeroData) -> Control:
	var inst: Dictionary = equipped.get(s, {})
	var template := ItemDB.get_item(StringName(inst.get("item_id", ""))) if not inst.is_empty() else null
	var b := _slot_button(-1 if inst.is_empty() else int(inst.rarity),
		icon_name(template) if template else SLOT_ICON.get(s, "lanca" if s == GameEnums.Slot.WEAPON else ""),
		inst.is_empty(), selected.get("slot", -1) == s)
	if s == GameEnums.Slot.WEAPON and inst.is_empty():
		b.get_child(0).texture = UiStyle.icon(icon_name(ItemDB.get_item(player.hero.starting_weapon_id)))
	b.tooltip_text = GameEnums.SLOT_NAMES[s]
	b.pressed.connect(func() -> void:
		selected = {"slot": s}
		_refresh())
	return b


## Casa de item com o ícone. ghost: ícone apagado (casa vazia mostra o que vai ali).
func _slot_button(rarity: int, icon: String, ghost: bool, is_selected: bool, count := -1, dim := false, badge := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.focus_mode = Control.FOCUS_NONE
	var box := UiStyle.slot_box(rarity)
	for k in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(k, box)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var tex := TextureRect.new()
	tex.texture = UiStyle.icon(icon)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 10
	tex.offset_top = 10
	tex.offset_right = -10
	tex.offset_bottom = -10
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.modulate = Color(1, 1, 1, 0.22) if ghost else (Color(0.55, 0.55, 0.55, 0.7) if dim else Color.WHITE)
	b.add_child(tex)
	if count >= 0:
		var n := UiStyle.label(_short(count), 15, UiStyle.TEXT, true)
		n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		n.grow_vertical = Control.GROW_DIRECTION_BEGIN
		n.offset_right = -7
		n.offset_bottom = -3
		b.add_child(n)
	if badge != "":
		var e := UiStyle.label(badge, 13, UiStyle.c("accent"), true)
		e.position = Vector2(8, 4)
		b.add_child(e)
	if is_selected:
		var ring := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = UiStyle.GOLD
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(9)
		sb.shadow_color = Color(UiStyle.GOLD, 0.5)
		sb.shadow_size = 6
		ring.add_theme_stylebox_override("panel", sb)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ring)
	return b


func _short(n: int) -> String:
	return str(n) if n < 1000 else ("%.1fk" % (n / 1000.0)).replace(".0k", "k").replace(".", ",")


## O herói em 3D, num pedestal com o anel de luz, num mundo só dele (não mexe no hub).
## Renderiza em resolução maior que a da tela (SUPERSAMPLE) e na escala real do aparelho: nítido
## também no celular. Arrastar gira o herói; dois toques voltam para a frente.
func _hero_view(hero: HeroData) -> Control:
	var v := HeroPreview.new().setup(hero)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return v


# ---------- atributos ----------

func _stats() -> Control:
	var hero := player.hero
	var st := player.stats
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(250, 0)
	outer.add_theme_constant_override("separation", 0)
	var hrow := HBoxContainer.new()
	hrow.custom_minimum_size = Vector2(0, 46)
	hrow.add_child(UiStyle.header("Atributos"))
	outer.add_child(hrow)
	var box := UiStyle.column_body()
	outer.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	box.add_child(col)
	var rows := [
		["Vida", str(st.max_health), Color("ff7a7a")],
		["Escudo", str(st.max_shield), Color("a9c4ff")],
		[GameEnums.PRIMARY_NAMES[hero.primary_stat], str(st.primary), UiStyle.TEXT],
		["Vigor", str(st.vigor), UiStyle.TEXT],
		["Armadura", "%d  (-%d%%)" % [st.armor, int(round(st.damage_reduction * 100))], UiStyle.TEXT],
		["Dano", str(st.weapon.damage), Color("ffcf6b")],
		["Crítico", "%d%%" % int(round(st.crit_chance * 100)), UiStyle.TEXT],
		["Aceleração", "%d%%" % int(st.haste), UiStyle.TEXT],
		["Sorte", "%d%%" % int(st.luck), UiStyle.TEXT],
	]
	if hero.hero_class == GameEnums.HeroClass.TANK:
		rows.append(["Bloqueio", "%d%%" % int(round(st.block_chance * 100)), UiStyle.TEXT])
	for i in rows.size():
		var r := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiStyle.c("row") if i % 2 == 0 else Color(0, 0, 0, 0)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		r.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		r.add_child(h)
		var k := UiStyle.label(rows[i][0], 17, UiStyle.TEXT_DIM)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(UiStyle.label(rows[i][1], 18, rows[i][2], true))
		col.add_child(r)
	return outer


# ---------- bolsa ----------

func _bag() -> Control:
	var hero := player.hero
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.custom_minimum_size = Vector2(0, 46)
	box.add_child(tabs)
	for t in [["equip", "Equipamentos"], ["mat", "Reagentes"]]:
		var b := Button.new()
		b.text = t[1]
		b.focus_mode = Control.FOCUS_NONE
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, UiStyle.tab_box(tab == t[0]))
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_override("font", UiStyle.button_font())
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", UiStyle.GOLD if tab == t[0] else UiStyle.TEXT_DIM)
		b.add_theme_color_override("font_hover_color", UiStyle.GOLD)
		var id: String = t[0]
		b.pressed.connect(func() -> void:
			tab = id
			selected = {}
			_refresh())
		tabs.add_child(b)
	var frame := UiStyle.column_body()
	box.add_child(frame)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	frame.add_child(inner)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, SLOT * 2 + 16)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var cells := 0
	if tab == "mat":
		for item_id in GameState.inventory.stacks:
			var item := ItemDB.get_item(StringName(item_id))
			if item == null:
				continue
			var b := _slot_button(int(item.rarity), icon_name(item), false, selected.get("mat", "") == String(item_id), int(GameState.inventory.stacks[item_id]))
			var mid := String(item_id)
			b.pressed.connect(func() -> void:
				selected = {"mat": mid}
				_refresh())
			grid.add_child(b)
			cells += 1
	else:
		var pieces: Array = GameState.inventory.equipment.duplicate()
		pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ua := ItemFactory.can_use(hero, ItemDB.get_item(StringName(a.item_id)))
			var ub := ItemFactory.can_use(hero, ItemDB.get_item(StringName(b.item_id)))
			if ua != ub:
				return ua
			return int(a.rarity) > int(b.rarity))
		for inst in pieces:
			var template := ItemDB.get_item(StringName(inst.item_id))
			if template == null:
				continue
			var wearer := GameState.wearer_of(inst.uid)
			var b := _slot_button(int(inst.rarity), icon_name(template), false, selected.get("uid", "") == String(inst.uid),
				-1, not ItemFactory.can_use(hero, template), "E" if wearer == hero.id else "")
			var uid := String(inst.uid)
			b.pressed.connect(func() -> void:
				selected = {"uid": uid}
				_refresh())
			grid.add_child(b)
			cells += 1
	# casas vazias completam a grade (a bolsa parece uma bolsa)
	while cells < 10 or cells % 5 != 0:
		var empty := _slot_button(-1, "", true, false)
		empty.disabled = true
		grid.add_child(empty)
		cells += 1
	inner.add_child(_detail())
	return box


func _detail() -> Control:
	var hero := player.hero
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.section(not selected.is_empty()))
	p.custom_minimum_size = Vector2(0, 190)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	p.add_child(col)
	var inst := {}
	if selected.has("uid"):
		for e in GameState.inventory.equipment:
			if String(e.uid) == selected.uid:
				inst = e
	elif selected.has("slot"):
		inst = GameState.equipped_items(hero.id).get(int(selected.slot), {})
	if selected.has("mat"):
		var item := ItemDB.get_item(StringName(selected.mat))
		var have := int(GameState.inventory.stacks.get(selected.mat, 0))
		var n := Label.new()
		n.text = item.display_name
		UiStyle.title_label(n, 22, GameEnums.rarity_color(int(item.rarity)))
		col.add_child(n)
		col.add_child(UiStyle.chips([["×%d" % have, "", UiStyle.GOLD], ["%d cada" % Economy.sell_price(item), "ouro", Color("ffd84a")]]))
		var uses := Economy.uses_of(StringName(selected.mat), ItemDB.catalog)
		var use_text := "Usado em: " + (", ".join(uses.slice(0, 4)) + (" e mais %d" % (uses.size() - 4) if uses.size() > 4 else "") if not uses.is_empty() else "nenhuma receita (pode vender)")
		var d := UiStyle.label(use_text, 15, UiStyle.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(380, 0)
		col.add_child(d)
		var fill := Control.new()
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(fill)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)
		for q in [1, 10]:
			var sb := Button.new()
			sb.text = "Vender %d" % q
			sb.focus_mode = Control.FOCUS_NONE
			UiStyle.style_button(sb, "normal", 18)
			sb.custom_minimum_size = Vector2(130, 48)
			sb.disabled = have < q
			var qq: int = q
			var mid: String = selected.mat
			sb.pressed.connect(func() -> void:
				GameState.sell_material(StringName(mid), qq)
				if GameState.inventory.count(StringName(mid)) <= 0:
					selected = {}
				_refresh())
			row.add_child(sb)
		return p
	if inst.is_empty():
		var hint := UiStyle.label("Toque num item para ver os detalhes." if not selected.has("slot") else "Nada vestido aqui. Fabrique peças na oficina.", 16, UiStyle.TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(380, 0)
		col.add_child(hint)
		return p
	var template := ItemDB.get_item(StringName(inst.item_id))
	var r := int(inst.rarity)
	var n2 := Label.new()
	n2.text = ItemFactory.display_name(inst, ItemDB.catalog)
	UiStyle.title_label(n2, 22, GameEnums.rarity_color(r))
	col.add_child(n2)
	var tags := [[GameEnums.rarity_name(r), "", GameEnums.rarity_color(r)], [GameEnums.SLOT_NAMES[int(template.slot)]]]
	if template.kind == ItemData.Kind.ARMOR:
		tags.append([GameEnums.ARMOR_NAMES[template.armor_type], UiStyle.armor_icon(template.armor_type)])
	tags.append(["%d" % GameEnums.RARITY_GEAR_POWER[clampi(r, 0, 3)], "poder"])
	col.add_child(UiStyle.chips(tags))
	# atributos com a diferença para o que está vestido
	var worn: Dictionary = GameState.equipped_items(hero.id).get(int(template.slot), {})
	var is_worn: bool = not worn.is_empty() and String(worn.uid) == String(inst.uid)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	col.add_child(grid)
	var keys: Array = inst.stats.keys()
	for k in worn.get("stats", {}):
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var v := int(inst.stats.get(k, 0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(UiStyle.label("%s %s" % ["+%d" % v if v >= 0 else str(v), GameEnums.STAT_NAMES.get(k, k)], 16))
		if not is_worn and not worn.is_empty():
			var diff := v - int(worn.stats.get(k, 0))
			if diff != 0:
				h.add_child(UiStyle.label(("▲%d" % diff) if diff > 0 else ("▼%d" % -diff), 15, UiStyle.OK if diff > 0 else UiStyle.BAD, true))
		grid.add_child(h)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)
	var wearer := GameState.wearer_of(inst.uid)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 50)
	if is_worn:
		b.text = "Tirar"
		UiStyle.style_button(b, "normal", 20)
		var slot_index := int(template.slot)
		b.pressed.connect(func() -> void:
			GameState.unequip(hero.id, slot_index)
			GameState.save()
			selected = {}
			_refresh())
	elif not ItemFactory.can_use(hero, template):
		b.text = "Não serve"
		UiStyle.style_button(b, "normal", 20)
		b.disabled = true
	else:
		b.text = "Vestir" if wearer == &"" else "Pegar de %s" % ItemDB.get_hero(wearer).display_name.split(" ")[0]
		UiStyle.style_button(b, "ouro", 20)
		var uid := String(inst.uid)
		b.pressed.connect(func() -> void:
			if GameState.equip(hero.id, uid) == "":
				GameState.save()
			_refresh())
	row.add_child(b)
	return p
