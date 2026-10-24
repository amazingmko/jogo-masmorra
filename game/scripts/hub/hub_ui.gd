class_name HubUI
extends CanvasLayer
## Interface do hub: barra do herói (nível, XP, atributos), joystick, botão de ação perto das
## estações e as janelas: portal (dificuldade e energia), baú/equipamento, quadro de heróis e
## oficina dos artesãos (crafting em cadeia de raridade).

signal enter_dungeon_requested

var TEXT := UiStyle.TEXT
var MUTED := UiStyle.TEXT_DIM
var GOLD := UiStyle.GOLD
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
var _top_chips: HBoxContainer
var _energy_box: HBoxContainer
var _modal: PanelContainer
var _top_bar: Control
var _help: Control
var _modal_title: Label
var _modal_body: VBoxContainer
var _open_station: StringName = &""
var _bag_tab := "equip"
var _difficulty := -1
var _use_energy := true
var _craft_prof: StringName = &""
var _craft_item: StringName = &""
var _craft_msg := ""
var _craft_msg_color := UiStyle.TEXT
## Árvore de talentos aberta (pelo Quadro de Heróis) e o último aviso dela.
var _talent_hero: StringName = &""
var _talent_msg := ""


func _ready() -> void:
	UiStyle.apply(get_tree().root)
	_build_top_bar()
	_build_controls()
	_build_modal()


func setup(player: Player) -> void:
	_player = player
	# (métodos, não funções soltas: quando o hub some, o Godot desliga sozinho)
	Net.lobby_changed.connect(_on_net_lobby)
	Net.found_changed.connect(_on_net_lobby)
	Net.connection_failed.connect(_on_net_failed)
	Net.disconnected.connect(_on_net_disconnected)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.hero_progress_changed.connect(func(_id: StringName) -> void:
		_refresh_top_bar()
		if Net.active:
			Net.refresh_profile()  # a sala vê a peça/herói novo (requisito da dificuldade)
		_refresh_open_panel())
	_refresh_top_bar()


func _on_coins_changed(_v: int) -> void:
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
	_top_bar.visible = false
	_help.visible = false
	action_button.visible = false
	joystick.release()
	joystick.visible = false
	_refresh_open_panel()


func _close() -> void:
	_modal.visible = false
	_top_bar.visible = true
	_help.visible = true
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
		&"talentos":
			_fill_talents()


## Regiões do portal, agrupadas por bioma. world: índice em Difficulty.WORLDS (-1 = em breve).
const REGIONS := [
	{"biome": "Amazônia", "id": "terra_firme", "name": "Terra Firme", "world": 0, "boss": "Mapinguari",
		"desc": "Mata fechada de terra firme. Bichos deixam ouro; os reagentes vêm dos chefes, dos baús e, às vezes, dos furiosos."},
	{"biome": "Amazônia", "id": "igapo", "name": "Várzea e Igapó", "world": 1, "boss": "Iara", "soon": true,
		"desc": "Floresta alagada: a água sobe e desce no meio da luta."},
	{"biome": "Amazônia", "id": "urnas", "name": "Cidade das Urnas", "world": -1, "boss": "Anhangá",
		"desc": "Ruínas de pedra e cerâmica, tochas e espíritos antigos."},
	{"biome": "Cerrado", "id": "cerrado", "name": "Em breve", "world": -1, "boss": "?", "desc": ""},
]
var _region := "terra_firme"
var _portal_tab := "solo"


func _region_lock(r: Dictionary) -> String:
	if int(r.world) < 0 or r.get("soon", false):
		return "Em breve"
	if int(r.world) >= Difficulty.WORLDS.size():
		return "Em breve"
	var lock := GameState.world_lock(int(r.world), _player.hero.id)
	if lock == "":
		return ""
	# "Precisa vencer X no Normal e Poder 90 (o seu: 0)" -> curto para o selo
	return "6 peças" if lock.contains("peças") and not lock.contains("vencer") else "Vença a anterior"


func _fill_portal() -> void:
	_modal_title.text = "Portal"
	if Net.active:
		_portal_tab = "grupo"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(row)
	row.add_child(_portal_regions())
	row.add_child(_portal_right())


## Coluna das regiões: cartões por bioma; fechadas aparecem com cadeado e o que falta.
func _portal_regions() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(330, 0)
	col.add_theme_constant_override("separation", 0)
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 46)
	h.add_child(UiStyle.header("Regiões"))
	col.add_child(h)
	var body := UiStyle.column_body()
	col.add_child(body)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	var biome := ""
	for r in REGIONS:
		if r.biome != biome:
			biome = r.biome
			var bl := Label.new()
			bl.text = biome.to_upper()
			UiStyle.title_label(bl, 16, UiStyle.TEXT_DIM)
			list.add_child(bl)
		list.add_child(_region_card(r))
	return col


func _region_card(r: Dictionary) -> Control:
	var lock := _region_lock(r)
	var sel: bool = r.id == _region
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	var sb := UiStyle.section(sel)
	sb.bg_color = Color(UiStyle.c("accent"), 0.16) if sel else Color(0, 0, 0, 0.35)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, sb)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := TextureRect.new()
	ic.texture = load("res://game/ui/icones/s_%s.png" % ("mapa" if lock == "" else "cadeado"))
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if lock == "" else Color(1, 1, 1, 0.7)
	h.add_child(ic)
	var name_l := Label.new()
	name_l.text = r.name
	UiStyle.title_label(name_l, 20, UiStyle.GOLD if sel else (UiStyle.TEXT if lock == "" else UiStyle.TEXT_DIM))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(name_l)
	if lock != "":
		h.add_child(UiStyle.chip(lock, "", UiStyle.TEXT_DIM, 13))
	if r.world >= 0 or r.id == _region:
		var rid: String = r.id
		b.pressed.connect(func() -> void:
			_region = rid
			_refresh_open_panel())
	else:
		b.disabled = true
		b.add_theme_stylebox_override("disabled", sb)
	return b


## Coluna da direita: abas Sozinho / Em grupo.
func _portal_right() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	var tabs := HBoxContainer.new()
	tabs.custom_minimum_size = Vector2(0, 46)
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
	for t in [["solo", "Expedição"], ["grupo", "Em grupo (Wi-Fi)"]]:
		tabs.add_child(_tab_button(t[1], _portal_tab == t[0], func() -> void:
			_portal_tab = t[0]
			_refresh_open_panel()))
	var body := UiStyle.column_body()
	col.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	body.add_child(inner)
	var outer := _modal_body
	_modal_body = inner
	if _portal_tab == "grupo":
		_fill_multiplayer()
	else:
		_fill_expedition()
	_modal_body = outer
	return col


## "Para o Heroico:" + as 6 casinhas do equipamento (✓ se já tem a raridade pedida) + vencer a anterior.
func _set_requirement_row(d: int, hero: HeroData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiStyle.chip("Para o %s" % Difficulty.name_of(d), "cadeado", Difficulty.color_of(d)))
	var need: int = Difficulty.SET_RARITY[d]
	var equipped := GameState.equipped_items(hero.id)
	for st in Difficulty.set_status(need, equipped):
		var inst: Dictionary = equipped.get(st.slot, {})
		var template := ItemDB.get_item(StringName(inst.get("item_id", ""))) if not inst.is_empty() else null
		var icon: String = CharacterPanel.icon_name(template) if template else CharacterPanel.SLOT_ICON.get(st.slot, "lanca")
		var slot := _mini_slot(icon, int(st.rarity), 44)
		if template == null:
			slot.get_child(0).modulate = Color(1, 1, 1, 0.25)
		var mark := UiStyle.label("✓" if st.ok else "✗", 17, UiStyle.OK if st.ok else UiStyle.BAD, true)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mark.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		slot.add_child(mark)
		slot.tooltip_text = GameEnums.SLOT_NAMES[st.slot]
		row.add_child(slot)
	var need_name: String = ["Comum", "Rara", "Épica", "Lendária"][need]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	row2.add_child(UiStyle.chip("cada peça %s ou melhor" % need_name, "", GameEnums.rarity_color(need)))
	if GameState.highest_cleared < d - 1:
		row2.add_child(UiStyle.chip("vencer o %s" % Difficulty.name_of(d - 1), "chefe", UiStyle.TEXT_DIM))
	box.add_child(row2)
	return box


func _tab_button(text: String, active: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, UiStyle.tab_box(active))
	b.add_theme_font_override("font", UiStyle.button_font())
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", UiStyle.GOLD if active else UiStyle.TEXT_DIM)
	b.add_theme_color_override("font_hover_color", UiStyle.GOLD)
	b.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
	b.add_theme_constant_override("outline_size", 4)
	b.pressed.connect(on_press)
	return b


func _region_data() -> Dictionary:
	for r in REGIONS:
		if r.id == _region:
			return r
	return REGIONS[0]


func _fill_expedition() -> void:
	var hero := _player.hero
	var r := _region_data()
	var lock := _region_lock(r)
	if _difficulty < 0:
		_difficulty = GameState.selected_difficulty
	if GameState.difficulty_lock(_difficulty, hero.id) != "":
		_difficulty = 0
	var energy := GameState.energy_now()
	if energy <= 0:
		_use_energy = false
	# região: nome, frase curta e selos
	var name_l := Label.new()
	name_l.text = r.name
	UiStyle.title_label(name_l, 30)
	_modal_body.add_child(name_l)
	_modal_body.add_child(UiStyle.chips([["%d andares" % 10, "mapa"], ["Chefe: %s" % r.boss, "chefe", Color("ff8a6a")], ["Reagentes", "chance", Color("8fe38f")]]))
	if r.desc != "":
		var d := UiStyle.label(r.desc, 16, UiStyle.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(400, 0)
		_modal_body.add_child(d)
	if lock != "":
		var why := "Esta região ainda está sendo construída." if lock == "Em breve" else GameState.world_lock(int(r.world), hero.id)
		_modal_body.add_child(UiStyle.chips([[why, "cadeado", UiStyle.TEXT_DIM]]))
		return
	# dificuldade
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 6)
	_modal_body.add_child(drow)
	var locked_note := ""
	for d in 4:
		var dl := GameState.difficulty_lock(d, hero.id)
		var b := _button(Difficulty.name_of(d), 18, Difficulty.color_of(d) if dl == "" else UiStyle.TEXT_DIM)
		b.custom_minimum_size = Vector2(0, 50)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if dl != "":
			b.disabled = true
			b.icon = load("res://game/ui/icones/s_cadeado.png")
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 22)
			if locked_note == "":
				locked_note = "%s: %s" % [Difficulty.name_of(d), dl.trim_prefix("Precisa ")]
		if d == _difficulty:
			b.add_theme_stylebox_override("normal", _selected_style(Difficulty.color_of(d)))
			b.add_theme_stylebox_override("hover", _selected_style(Difficulty.color_of(d)))
		var dd := d
		b.pressed.connect(func() -> void:
			_difficulty = dd
			_refresh_open_panel())
		drow.add_child(b)
	_modal_body.add_child(UiStyle.chips([
		["Vida ×%s" % _num(Difficulty.HEALTH_MULT[_difficulty]), "vida", Color("ff8a8a")],
		["Dano ×%s" % _num(Difficulty.DAMAGE_MULT[_difficulty]), "espada", Color("ffcf6b")],
		["XP ×%s" % _num(Difficulty.XP_MULT[_difficulty]), "xp", Color("8fe38f")],
		["Reagentes ×%s" % _num(Difficulty.REWARD_MULT[_difficulty]), "chance", Color("8fe38f")]]))
	# próxima dificuldade trancada: o que falta (as 6 peças com ✓/✗ e vencer a anterior)
	for d in range(1, 4):
		if GameState.difficulty_lock(d, hero.id) != "":
			_modal_body.add_child(_set_requirement_row(d, hero))
			break
	# energia: pontos e o interruptor
	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 10)
	_modal_body.add_child(erow)
	erow.add_child(UiStyle.chip("Energia", "energia", Color("ffd84a")))
	var pips := UiStyle.pips(energy, GameState.MAX_ENERGY, Color("ffd84a"), 18)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	erow.add_child(pips)
	var wait := GameState.seconds_to_next_energy()
	if wait > 0:
		erow.add_child(UiStyle.label("+1 em %d min" % ceili(wait / 60.0), 15, UiStyle.TEXT_DIM))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(fill)
	var toggle := _button("Recompensa completa" if _use_energy else "Guardar energia", 17, Color("ffd84a") if _use_energy else UiStyle.TEXT_DIM)
	toggle.icon = load("res://game/ui/icones/s_energia.png") if _use_energy else null
	toggle.add_theme_constant_override("icon_max_width", 22)
	toggle.disabled = energy <= 0
	if _use_energy:
		toggle.add_theme_stylebox_override("normal", _selected_style(Color("ffd84a")))
		toggle.add_theme_stylebox_override("hover", _selected_style(Color("ffd84a")))
	toggle.pressed.connect(func() -> void:
		_use_energy = not _use_energy
		_refresh_open_panel())
	erow.add_child(toggle)
	if not _use_energy:
		_modal_body.add_child(UiStyle.label("Sem energia a run rende %d%% dos reagentes e nenhum troféu do chefe." % int(Difficulty.NO_ENERGY_REWARD * 100), 14, UiStyle.TEXT_DIM))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(spacer)
	var enter := _button("Entrar  (%s)" % Difficulty.name_of(_difficulty), 26, TEXT, false, "ouro")
	enter.custom_minimum_size = Vector2(0, 64)
	enter.pressed.connect(func() -> void:
		GameState.selected_difficulty = _difficulty
		GameState.run_difficulty = _difficulty
		GameState.run_full_rewards = _use_energy and GameState.spend_energy()
		enter_dungeon_requested.emit())
	_modal_body.add_child(enter)


func _on_net_lobby() -> void:
	if _open_station == &"portal":
		_refresh_open_panel()


func _on_net_failed() -> void:
	_net_msg = "Não deu para entrar na partida."
	_refresh_open_panel()


func _on_net_disconnected(reason: String) -> void:
	_net_msg = reason
	_refresh_open_panel()


## Jogar com amigos na mesma rede Wi-Fi (até 4).
var _join_ip := ""
var _net_msg := ""


func _fill_multiplayer() -> void:
	if _net_msg != "":
		_modal_body.add_child(UiStyle.chips([[_net_msg, "cadeado", UiStyle.BAD]]))
	if not Net.active:
		_modal_body.add_child(UiStyle.chips([["Mesmo Wi-Fi", "mapa"], ["Até 4 jogadores", "coroa", UiStyle.GOLD], ["Mais difícil", "chefe", Color("ff8a6a")]]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_modal_body.add_child(row)
		var create := _button("Criar partida", 20, TEXT, false, "ouro")
		create.custom_minimum_size = Vector2(0, 54)
		create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		create.pressed.connect(func() -> void:
			_net_msg = Net.host()
			_refresh_open_panel())
		row.add_child(create)
		var search := _button("Procurar partidas", 20)
		search.custom_minimum_size = Vector2(0, 54)
		search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search.pressed.connect(func() -> void:
			Net.start_search()
			_refresh_open_panel())
		row.add_child(search)
		for ip in Net.found:
			var info: Dictionary = Net.found[ip]
			var b := _button("Entrar: %s  (%d/%d)" % [info.name, info.count, Net.MAX_PLAYERS], 18, UiStyle.OK)
			var ip_s := String(ip)
			b.pressed.connect(func() -> void:
				Net.stop_search()
				_net_msg = Net.join(ip_s)
				_refresh_open_panel())
			_modal_body.add_child(b)
		var ip_row := HBoxContainer.new()
		ip_row.add_theme_constant_override("separation", 8)
		_modal_body.add_child(ip_row)
		var edit := LineEdit.new()
		edit.placeholder_text = "IP do anfitrião (ex.: 192.168.0.10)"
		edit.text = _join_ip
		edit.custom_minimum_size = Vector2(320, 48)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.add_theme_font_size_override("font_size", 17)
		edit.text_changed.connect(func(t: String) -> void: _join_ip = t.strip_edges())
		ip_row.add_child(edit)
		var go := _button("Entrar pelo IP", 18)
		go.custom_minimum_size = Vector2(0, 48)
		go.pressed.connect(func() -> void:
			if _join_ip != "":
				Net.stop_search()
				_net_msg = Net.join(_join_ip)
				_refresh_open_panel())
		ip_row.add_child(go)
		return
	# na partida: a dificuldade (o anfitrião escolhe), um cartão por jogador com ✓/✗ do requisito
	# dele e o botão de começar (só quando todos podem entrar)
	var diff := Net.lobby_difficulty()
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 6)
	_modal_body.add_child(drow)
	for d in 4:
		var b := _button(Difficulty.name_of(d), 17, Difficulty.color_of(d))
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not Net.is_host()
		if d == diff:
			b.add_theme_stylebox_override("normal", _selected_style(Difficulty.color_of(d)))
			b.add_theme_stylebox_override("disabled", _selected_style(Difficulty.color_of(d)))
			b.add_theme_color_override("font_disabled_color", Difficulty.color_of(d))
		var dd := d
		b.pressed.connect(func() -> void:
			_difficulty = dd
			Net.refresh_profile(dd)
			_refresh_open_panel())
		drow.add_child(b)
	var ids := Net.players.keys()
	ids.sort()
	if ids.is_empty():
		_modal_body.add_child(UiStyle.label("Conectando...", 17, UiStyle.TEXT_DIM))
	for id in ids:
		var prof: Dictionary = Net.players[id]
		var h := ItemDB.get_hero(StringName(prof.get("hero_id", "")))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiStyle.section(int(id) == Net.my_id()))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var n := Label.new()
		n.text = h.display_name if h else "?"
		UiStyle.title_label(n, 20, UiStyle.TEXT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(UiStyle.chip("%d" % int(prof.get("level", 1)), "nivel", Color("ffd25a")))
		if int(id) == 1:
			row.add_child(UiStyle.chip("Anfitrião", "coroa", UiStyle.GOLD))
		if int(id) == Net.my_id():
			row.add_child(UiStyle.chip("Você", "", UiStyle.c("accent")))
		var lock := Net.lock_for(int(id), diff)
		if lock == "":
			row.add_child(UiStyle.chip("Pode entrar", "", UiStyle.OK))
		else:
			row.add_child(UiStyle.chip(lock.trim_prefix("Precisa "), "cadeado", UiStyle.BAD))
		_modal_body.add_child(card)
	if Net.is_host():
		var ips := Net.local_ips()
		_modal_body.add_child(UiStyle.chips([["Seu IP: %s" % (ips[0] if not ips.is_empty() else "?"), "mapa"]]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_child(spacer)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	_modal_body.add_child(row2)
	var leave := _button("Sair", 20, UiStyle.BAD)
	leave.custom_minimum_size = Vector2(140, 60)
	leave.pressed.connect(func() -> void:
		Net.leave()
		_refresh_open_panel())
	row2.add_child(leave)
	if Net.is_host():
		var can := Net.all_can_enter(diff)
		var start := _button("Começar  (%d jogadores)" % Net.players.size() if can else "Alguém não pode entrar", 24, TEXT, false, "ouro" if can else "normal")
		start.custom_minimum_size = Vector2(0, 60)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		start.disabled = not can
		start.pressed.connect(func() -> void:
			GameState.selected_difficulty = diff
			Net.start_run(diff))
		row2.add_child(start)
	else:
		var wait := UiStyle.label("Esperando o anfitrião começar...", 17, UiStyle.TEXT_DIM)
		wait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(wait)


func _fill_heroes() -> void:
	_modal_title.text = "Heróis"
	var panel := HeroesPanel.new()
	_modal_body.add_child(panel)
	panel.build(_player)
	panel.open_talents.connect(func(hid: StringName) -> void:
		_talent_hero = hid
		_open_station = &"talentos"
		_refresh_open_panel())
	panel.hero_chosen.connect(func(hero: HeroData) -> void:
		GameState.selected_hero = hero.id
		if Net.active:
			Net.refresh_profile()
		_player.set_hero(hero)
		GameState.save()
		_refresh_top_bar()
		_refresh_open_panel())


## Talentos (como no WoW): especializações, mini árvore e o detalhe do talento.
func _fill_talents() -> void:
	var hero := ItemDB.get_hero(_talent_hero)
	if hero == null:
		return
	_modal_title.text = "Talentos"
	var panel := TalentsPanel.new()
	_modal_body.add_child(panel)
	panel.build(hero, _player)
	panel.back_requested.connect(func() -> void:
		_open_station = &"herois"
		_refresh_open_panel())


func _fill_artisan() -> void:
	_modal_title.text = "Oficina"
	var hero := _player.hero
	if _craft_prof == &"":
		_craft_prof = PROFESSION_FOR_ARMOR[hero.armor_type()]
	var prof := ItemDB.catalog.get_profession(_craft_prof)
	var lvl := GameState.professions.level_of(_craft_prof)

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

	# abas das profissões em cima de tudo
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tabs.custom_minimum_size = Vector2(0, 46)
	_modal_body.add_child(tabs)
	for prof_id in PROFESSIONS:
		var pr := ItemDB.catalog.get_profession(prof_id)
		var pid: StringName = prof_id
		tabs.add_child(_tab_button(pr.display_name, prof_id == _craft_prof, func() -> void:
			_craft_prof = pid
			_craft_item = &""
			_craft_msg = ""
			_refresh_open_panel()))
	var body := UiStyle.column_body()
	_modal_body.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	body.add_child(inner)
	# nível da profissão
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	inner.add_child(top)
	top.add_child(UiStyle.chip("Nível %d" % lvl, "nivel", Color("ffd25a")))
	var xp := UiStyle.bar(Color("4fbf7a"), 260, 20)
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.set_bar(xp, GameState.professions.xp_of(_craft_prof), prof.xp_to_next(lvl), "XP %d / %d" % [GameState.professions.xp_of(_craft_prof), prof.xp_to_next(lvl)])
	top.add_child(xp)
	var pd := UiStyle.label(prof.description, 15, UiStyle.TEXT_DIM)
	pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pd.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(pd)
	if _craft_msg != "":
		var msg := UiStyle.label(_craft_msg, 16, _craft_msg_color)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size = Vector2(600, 0)
		inner.add_child(msg)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(columns)
	# esquerda: as peças, com ícone (borda na maior raridade que você já tem)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(300, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left)
	for item_id in item_ids:
		var item := ItemDB.get_item(item_id)
		var best := _best_rarity_owned(item_id)
		var sel: bool = item_id == _craft_item
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		var sb := UiStyle.section(sel)
		sb.set_content_margin_all(4)
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, sb)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 6
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		h.add_child(_mini_slot(CharacterPanel.icon_name(item), best, 46))
		var nl := Label.new()
		nl.text = item.display_name
		UiStyle.title_label(nl, 17, UiStyle.GOLD if sel else (TEXT if ItemFactory.can_use(hero, item) or not item.is_equipment() else MUTED))
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(nl)
		var iid: StringName = item_id
		b.pressed.connect(func() -> void:
			_craft_item = iid
			_craft_msg = ""
			_refresh_open_panel())
		left.add_child(b)
	# direita: as receitas da peça (uma por raridade)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right)
	if _craft_item == &"":
		right.add_child(UiStyle.label("Nenhuma receita.", 16, MUTED))
		return
	var recipes: Array = by_item[_craft_item]
	recipes.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return int(a.result_rarity) < int(b.result_rarity))
	for recipe: RecipeData in recipes:
		right.add_child(_recipe_card(recipe))


## Casinha pequena com ícone (lista da oficina, reagentes da receita). Com count_text, o número
## vai embaixo da casa (tem/precisa), sem cobrir o ícone.
func _mini_slot(icon: String, rarity: int, size: int, count_text := "", count_color := Color.WHITE) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(size, size)
	var sb := UiStyle.slot_box(rarity)
	sb.set_content_margin_all(5)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t := TextureRect.new()
	t.texture = UiStyle.icon(icon)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)
	if count_text == "":
		return p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.add_child(p)
	var n := UiStyle.label(count_text, 14, count_color, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return v


func _count(n: int) -> String:
	return str(n) if n < 1000 else ("%.1fk" % (n / 1000.0)).replace(".0k", "k").replace(".", ",")


## Cartão de uma receita: raridade, chance, peça-base, reagentes (ícones com tem/precisa) e o botão.
func _recipe_card(recipe: RecipeData) -> Control:
	var item := ItemDB.get_item(recipe.result_item_id)
	var r := int(recipe.result_rarity)
	var color := GameEnums.rarity_color(r) if item.is_equipment() else TEXT
	var box := PanelContainer.new()
	var sb := UiStyle.section()
	sb.border_color = Color(color, 0.7)
	sb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	var streak := GameState.craft_streak(recipe.id)
	var chance := Crafting.success_chance(recipe, GameState.professions, streak)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var nl := Label.new()
	nl.text = item.display_name if item.is_equipment() else recipe.display_name
	UiStyle.title_label(nl, 19, color)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nl)
	if item.is_equipment():
		head.add_child(UiStyle.chip(GameEnums.rarity_name(r), "", color))
		head.add_child(UiStyle.chip("%d" % GameEnums.RARITY_GEAR_POWER[r], "poder"))
	head.add_child(UiStyle.chip("%d%%" % int(round(chance * 100)), "chance", UiStyle.OK if chance >= 0.5 else Color("ffcf6b")))
	var cost := Economy.craft_cost(recipe, ItemDB.catalog)
	head.add_child(UiStyle.chip("%d" % cost, "ouro", Color("ffd84a") if GameState.coins >= cost else UiStyle.BAD))
	var notes := HBoxContainer.new()
	notes.add_theme_constant_override("separation", 6)
	var lvl := GameState.professions.level_of(recipe.profession_id)
	if lvl < recipe.required_level:
		notes.add_child(UiStyle.chip("Nível %d na profissão" % recipe.required_level, "cadeado", UiStyle.BAD))
	if recipe.requires_base:
		var base := Crafting.find_base(recipe, GameState.inventory, GameState.worn_uids())
		notes.add_child(UiStyle.chip("Base: %s" % GameEnums.rarity_name(r - 1), "", UiStyle.OK if not base.is_empty() else UiStyle.BAD))
	if streak > 0:
		notes.add_child(UiStyle.chip("+%d%% (falhas)" % (streak * 10), "", Color("ffcf6b")))
	if notes.get_child_count() > 0:
		col.add_child(notes)
	# reagentes: ícone com tem/precisa
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	col.add_child(bottom)
	for ing_id in recipe.ingredients:
		var need := int(recipe.ingredients[ing_id])
		var have := GameState.inventory.count(StringName(ing_id))
		var ing := ItemDB.get_item(StringName(ing_id))
		var slot := _mini_slot(CharacterPanel.icon_name(ing), -1, 50, "%s/%d" % [_count(have), need], UiStyle.OK if have >= need else UiStyle.BAD)
		slot.tooltip_text = ing.display_name if ing else String(ing_id)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		bottom.add_child(slot)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(fill)
	var reason := Crafting.check(recipe, GameState.inventory, GameState.professions, GameState.worn_uids())
	if reason == "" and GameState.coins < cost:
		reason = "Falta ouro."
	var make := _button("Fabricar", 20, TEXT, false, "ouro" if reason == "" else "normal")
	make.custom_minimum_size = Vector2(150, 54)
	make.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	make.disabled = reason != ""
	make.tooltip_text = reason
	var rid: StringName = recipe.id
	make.pressed.connect(func() -> void: _do_craft(rid))
	bottom.add_child(make)
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
			name = "%s %s (Poder %d)" % [item.display_name, GameEnums.rarity_name(int(recipe.result_rarity)),
				GameEnums.RARITY_GEAR_POWER[int(recipe.result_rarity)]]
			worn = GameState.wearer_of(res.uid) != &""
		_craft_msg = "Sucesso! %s%s. +%d XP" % [name, " (já vestida)" if worn else "", res.xp]
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
		_craft_msg += "\n%s subiu para o nível %d!" % [ItemDB.catalog.get_profession(recipe.profession_id).display_name, level_after]
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


## Botão escolhido (dificuldade, aba, talento): madeira mais clara com a borda na cor dele.
func _selected_style(color: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.11, 0.14).lerp(color, 0.22)
	st.border_color = color
	st.set_border_width_all(3)
	st.set_corner_radius_all(7)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 8
	st.content_margin_bottom = 11
	st.shadow_color = Color(color, 0.35)
	st.shadow_size = 6
	return st


# ---------- baú e equipamento ----------

func _fill_bag() -> void:
	_modal_title.text = "Personagem"
	var panel := CharacterPanel.new()
	_modal_body.add_child(panel)
	panel.build(_player)


# ---------- montagem ----------

func _refresh_top_bar() -> void:
	if _player == null or _player.hero == null:
		return
	var hero := _player.hero
	var p := GameState.progress(hero.id)
	_hero_label.text = hero.display_name
	for ch in _top_chips.get_children():
		ch.queue_free()
	_top_chips.add_child(UiStyle.chip("%d" % p.level, "nivel", Color("ffd25a")))
	_top_chips.add_child(UiStyle.chip("%d" % GameState.power_of(hero.id), "poder"))
	_top_chips.add_child(UiStyle.chip(GameEnums.PRIMARY_NAMES[hero.primary_stat], UiStyle.primary_icon(hero.primary_stat)))
	_top_chips.add_child(UiStyle.chip(GameEnums.ARMOR_NAMES[hero.armor_type()], UiStyle.armor_icon(hero.armor_type())))
	UiStyle.set_bar(_xp_bar, p.xp, Progression.xp_to_next(p.level), "XP %d / %d" % [p.xp, Progression.xp_to_next(p.level)])
	for ch in _energy_box.get_children():
		ch.queue_free()
	_energy_box.add_child(UiStyle.chip("%d" % GameState.coins, "ouro", Color("ffd84a")))
	_energy_box.add_child(UiStyle.chip("", "energia", Color("ffd84a")))
	var pips := UiStyle.pips(GameState.energy_now(), GameState.MAX_ENERGY, Color("ffd84a"), 14)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_box.add_child(pips)


func _build_top_bar() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(20, 14)
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_top_bar = box
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_hero_label = Label.new()
	UiStyle.title_label(_hero_label, 26, TEXT)
	row.add_child(_hero_label)
	_top_chips = HBoxContainer.new()
	_top_chips.add_theme_constant_override("separation", 5)
	row.add_child(_top_chips)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	box.add_child(row2)
	_xp_bar = UiStyle.bar(Color("4fbf7a"), 300, 20)
	row2.add_child(_xp_bar)
	_energy_box = HBoxContainer.new()
	_energy_box.add_theme_constant_override("separation", 4)
	row2.add_child(_energy_box)

	var help := UiStyle.label("Ande até um ponto e toque no botão  (PC: E)", 15, MUTED)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help.offset_right = -20
	help.offset_top = 18
	add_child(help)
	_help = help


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
	_modal.offset_left = 50
	_modal.offset_right = -50
	_modal.offset_top = 12   # a janela usa a tela toda (a barra do herói some enquanto ela está aberta)
	_modal.offset_bottom = -12
	_modal.add_theme_stylebox_override("panel", UiStyle.panel())
	add_child(_modal)
	_modal.add_child(UiStyle.watermark_rect())

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_modal.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiStyle.plate())
	plate.custom_minimum_size = Vector2(340, 0)
	header.add_child(plate)
	_modal_title = _label("", 30, GOLD)
	UiStyle.title_label(_modal_title, 30)
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_modal_title)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(fill)
	var close := _button("X", 22)
	close.custom_minimum_size = Vector2(56, 52)
	close.pressed.connect(_close)
	header.add_child(close)
	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 10)
	outer.add_child(_modal_body)
	_modal.visible = false


## wrap: quebra linhas (só use quando o rótulo estiver dentro de um container com largura).
func _label(text: String, font_size: int, color: Color = Color(0, 0, 0, 0), wrap: bool = false) -> Label:
	if color.a == 0.0:
		color = TEXT
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	if font_size >= 20:
		UiStyle.title_label(l, font_size + 2, color)  # títulos e nomes: fonte de título
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## kind: "normal" (comum) ou "ouro" (ação principal da janela).
func _button(text: String, font_size: int, color: Color = Color(0, 0, 0, 0), wrap: bool = false, kind := "normal") -> Button:
	if color.a == 0.0:
		color = TEXT
	var b := Button.new()
	b.text = text
	UiStyle.style_button(b, kind, font_size)
	if kind != "ouro" and color != TEXT:
		b.add_theme_color_override("font_color", color)
		b.add_theme_color_override("font_hover_color", color.lightened(0.25))
	b.add_theme_color_override("font_disabled_color", color.darkened(0.15) if kind != "ouro" else Color("9a9a9a"))
	if wrap:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _card_panel(border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.section(border == GOLD))
	return p
