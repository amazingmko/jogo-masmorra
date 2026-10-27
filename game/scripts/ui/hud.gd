class_name Hud
extends CanvasLayer
## Interface da partida: vida e armadura, andar atual, minimapa, avisos de loot, controles de toque,
## escolha de buff e resumo da run. Montada por código para ficar fácil de ajustar nesta fase.
## Roda mesmo com o jogo pausado (para a escolha de buff funcionar).

signal restart_requested
signal buff_chosen(buff: BuffData)
## Tocou no próprio retrato: pedido de cura para o grupo.
signal help_requested

var joystick: TouchJoystick
var attack_button: TouchButton
## Habilidade da classe (Druida: forma; tanque: Provocar). Escondido se a classe não tem.
var form_button: TouchButton
## Ultimate da classe (carrega no combate).
var ultimate_button: TouchButton
var minimap: Minimap

var _health_bar: ProgressBar
var _armor_bar: ProgressBar
var _health_label: Label
var _hero_chips: HBoxContainer
var _wave_chips: HBoxContainer
var _panel_chips: HFlowContainer
var _panel_chip_items: Array = []
var _panel_loot: GridContainer
var _panel_loot_box: PanelContainer
var _panel_loot_items: Array = []
var _hero_label: Label
var _portrait: Control
var _synergy_row: HBoxContainer
var _armor_row: Control  # agora: a proteção temporária (some quando não tem)
var _wave_label: Label
var _help_label: Label
## Provação: o objetivo, numa linha centralizada embaixo do medidor.
var _goal_row: HBoxContainer
var _toasts: VBoxContainer
var _panel: PanelContainer
var _panel_title: Label
var _panel_text: Label
var _panel_button: Button
var _panel_button2: Button
var _ask_callback := Callable()
var _buff_panel: PanelContainer
var _buff_cards: HBoxContainer
var _status_row: HBoxContainer
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss: Node
var _player: Player


func _ready() -> void:
	UiStyle.apply(get_tree().root)
	add_to_group("loot_listeners")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_status()
	_build_boss_bar()
	_build_minimap()
	_build_controls()
	_build_toasts()
	_build_panel()
	_build_buff_panel()


# ---------- API usada pela arena ----------

func move_vector() -> Vector2:
	return joystick.value


func attack_held() -> bool:
	return attack_button.is_pressed


func bind_player(player: Player) -> void:
	_player = player
	player.health.changed.connect(_on_health_changed)
	player.hero_changed.connect(_on_hero_changed)
	player.form_changed.connect(func(_name: String) -> void: _on_hero_changed(player.hero))
	_on_health_changed(player.health.health, player.health.max_health, player.health.armor, player.health.max_armor)
	if player.hero:
		_on_hero_changed(player.hero)


## Barra de vida do chefe no topo da tela.
func show_boss(boss: Node) -> void:
	_boss = boss
	_boss_name.text = boss.data.display_name
	_boss_bar.max_value = boss.health.max_health
	_boss_bar.value = boss.health.health
	boss.health.changed.connect(func(hp: int, max_hp: int, _a: int, _b: int) -> void:
		_boss_bar.max_value = max_hp
		_boss_bar.value = hp
		if boss.enraged:
			_boss_name.text = "%s enfurecido!" % boss.data.display_name)
	_boss_box.visible = true


func hide_boss() -> void:
	_boss = null
	_boss_box.visible = false


func _process(_delta: float) -> void:
	_refresh_status()
	_update_kit_buttons()
	_update_party(_delta)


# ---------- pedido de cura ----------
const HELP_COOLDOWN := 4.0
const HELP_TIME := 4.0
var _help_cd := 0.0


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed) or _portrait == null or not _portrait.is_visible_in_tree():
		return
	if _party_rows.is_empty() or _help_cd > 0.0:
		return
	if _portrait.get_global_rect().grow(6).has_point(event.position):
		_help_cd = HELP_COOLDOWN
		help_requested.emit()
		_flash_portrait(_portrait)
		get_viewport().set_input_as_handled()


## Alguém pediu cura: o rosto dele na barra do grupo pisca e ganha um "+" por HELP_TIME s.
func mark_help(member: Node) -> void:
	for r in _party_rows:
		if r.hero == member:
			r["help"] = HELP_TIME


func _flash_portrait(p: Control) -> void:
	var t := p.create_tween()
	t.tween_property(p, "scale", Vector2(1.12, 1.12), 0.08)
	t.tween_property(p, "scale", Vector2.ONE, 0.15)


# ---------- barra do grupo ----------
## Os parceiros, discretos, no lado esquerdo abaixo da vida: rosto pequeno + barra fina verde.
## Abaixo de 35% a barra fica vermelha e pisca (quem precisa de cura agora); caído fica cinza.
const PARTY_CRITICAL := 0.35
var _party_box: VBoxContainer
var _party_rows: Array = []  # [{hero: Player, face, bar, fill}]
var _party_t := 0.0


func set_party(members: Array) -> void:
	if _party_box == null:
		_party_box = VBoxContainer.new()
		_party_box.add_theme_constant_override("separation", 5)
		_party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_party_box.position = Vector2(18, 178)
		add_child(_party_box)
	for ch in _party_box.get_children():
		ch.queue_free()
	_party_rows.clear()
	for m in members:
		if not is_instance_valid(m) or m.hero == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := UiStyle.portrait(String(m.hero_id), 34)
		row.add_child(face)
		var bar := UiStyle.bar(Color("5fd67a"), 118, 11)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var cross := Label.new()  # pediu cura
		cross.text = "+ CURA"
		UiStyle.title_label(cross, 15, Color("6fdc7b"))
		cross.visible = false
		cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cross)
		_party_box.add_child(row)
		_party_rows.append({"hero": m, "face": face, "bar": bar, "fill": bar.get_theme_stylebox("fill"), "cross": cross})
	_party_box.visible = not _party_rows.is_empty()
	_update_party(1.0)


func _update_party(delta: float) -> void:
	if _party_rows.is_empty():
		return
	_party_t += delta
	_help_cd = maxf(_help_cd - delta, 0.0)
	for r in _party_rows:
		var m = r.hero
		if not is_instance_valid(m):
			continue
		var h: Health = m.health
		var frac := float(h.health) / float(maxi(h.max_health, 1))
		UiStyle.set_bar(r.bar, h.health, h.max_health, "")
		var fill: StyleBoxFlat = r.fill
		var help: float = float(r.get("help", 0.0))
		if help > 0.0:
			r["help"] = help - delta
			r.cross.visible = true
			r.cross.modulate.a = 0.5 + 0.5 * absf(sin(_party_t * 8.0))
		else:
			r.cross.visible = false
		if h.is_dead:
			r.face.modulate = Color(0.45, 0.45, 0.45, 0.8)
		elif frac < PARTY_CRITICAL:
			var pulse := 0.6 + 0.4 * absf(sin(_party_t * 6.0))
			fill.bg_color = Color("ff4d4d") * Color(1, 1, 1, 1).lerp(Color(1.3, 1.3, 1.3), pulse - 0.6)
			r.face.modulate = Color(1.0, 0.55 + 0.45 * pulse, 0.55 + 0.45 * pulse)
		else:
			fill.bg_color = Color("5fd67a") if frac >= 0.6 else Color("f2c14e")
			r.face.modulate = Color.WHITE


## Botões de habilidade e ultimate: nome do poder, anel de recarga/carga, apagado quando não dá.
func _update_kit_buttons() -> void:
	if form_button == null or ultimate_button == null:
		return
	var kit: HeroKit = _player.kit if _player else null
	form_button.visible = kit != null and kit.has_skill()
	ultimate_button.visible = kit != null and kit.has_ultimate()
	if form_button.visible:
		var cd := kit.skill_cooldown_ratio()
		form_button.color = kit.skill_color()
		var skill_text := kit.skill_name().to_upper()
		var charges := "×%d" % kit.charges() if kit.max_charges() > 1 else ""
		var sk_icon := _kit_icon(kit.skill_icon())
		if sk_icon == null and charges != "":
			skill_text += " " + charges
		form_button.set_state(1.0 - cd if cd > 0.0 else -1.0, cd > 0.0, skill_text, charges, sk_icon)
	if ultimate_button.visible:
		var ready := kit.ultimate_ready()
		var label := kit.ultimate_name().to_upper() if ready else "%d%%" % int(kit.charge)
		ultimate_button.set_state(kit.charge / 100.0, not ready, label, "" if ready else "%d%%" % int(kit.charge), _kit_icon(kit.ultimate_icon()))


var _icon_cache := {}


func _kit_icon(name: String) -> Texture2D:
	if name == "":
		return null
	if not _icon_cache.has(name):
		var path := "res://game/ui/icones/%s.png" % name
		_icon_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _icon_cache[name]


func _refresh_status() -> void:
	if _player == null or _status_row == null:
		return
	var effects: Array = _player.status.active()
	while _status_row.get_child_count() > effects.size():
		_status_row.get_child(_status_row.get_child_count() - 1).free()
	while _status_row.get_child_count() < effects.size():
		_status_row.add_child(_make_label(16))
	for i in effects.size():
		var chip: Label = _status_row.get_child(i)
		chip.text = "%s %.1fs" % [effects[i].name, effects[i].time]
		chip.add_theme_color_override("font_color", effects[i].color)


func refresh_hero(hero: HeroData) -> void:
	_on_hero_changed(hero)


func set_wave(text: String) -> void:
	_wave_label.text = text
	_wave_chips.visible = false


## Topo da tela: "Andar 3/10" na placa e, ao lado, a dificuldade (e o aviso de sem energia).
func set_floor(floor_number: int, total: int, difficulty: int, full_rewards: bool, group_bonus := 0) -> void:
	_wave_label.text = "Andar %d/%d" % [floor_number, total]
	for ch in _wave_chips.get_children():
		ch.queue_free()
	_wave_chips.add_child(UiStyle.chip(Difficulty.name_of(difficulty), "chefe", Difficulty.color_of(difficulty)))
	if not full_rewards:
		_wave_chips.add_child(UiStyle.chip("Sem energia", "energia", UiStyle.TEXT_DIM))
	if group_bonus > 0:
		# Força da Aldeia: em grupo, mais reagentes para cada um
		_wave_chips.add_child(UiStyle.chip("Aldeia +%d%%" % group_bonus, "suporte", Color("ffd98a")))
	_wave_chips.visible = true


## Sinergias elementais ligadas do grupo (Synergy.active): um selo por elemento, abaixo da vida.
func set_synergies(list: Array) -> void:
	for ch in _synergy_row.get_children():
		ch.queue_free()
	for sy in list:
		_synergy_row.add_child(UiStyle.chip("%s ×%d" % [sy.name, int(sy.heroes)], sy.icon, Color(sy.color), 13))
	_synergy_row.visible = not list.is_empty()


## Provação: o nome na placa do topo e, ao lado, o relógio e o objetivo (selos).
## chips[0] (o relógio) fica ao lado da placa; o resto (o objetivo) vai na linha de baixo.
func set_trial(title: String, chips: Array) -> void:
	_wave_label.text = title
	_help_label.visible = false
	for ch in _wave_chips.get_children():
		ch.queue_free()
	for ch in _goal_row.get_children():
		ch.queue_free()
	for i in chips.size():
		var it: Array = chips[i]
		(_wave_chips if i == 0 else _goal_row).add_child(UiStyle.chip(it[0], it[1], it[2] if it.size() > 2 else Color(0, 0, 0, 0)))
	_wave_chips.visible = true
	_goal_row.visible = true
	_goal_row.offset_top = 128 if _boss_box.visible else 62


## Barra grande do topo (a do chefe) usada como medidor da Provação (vida do totem, acertos...).
func show_meter(title: String, value: int, max_value: int, color: Color) -> void:
	_boss = null
	_boss_name.text = title
	_boss_name.add_theme_color_override("font_color", color)
	_boss_bar.max_value = max_value
	_boss_bar.value = value
	_boss_box.visible = true


func set_meter(value: int, max_value: int) -> void:
	_boss_bar.max_value = max_value
	_boss_bar.value = value


func hide_meter() -> void:
	_boss_box.visible = false


## Aviso no meio-baixo da tela: faixa terracota que entra saltando e some sozinha. Em fila
## (no máximo 3), um embaixo do outro: nunca um por cima do outro.
func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", UiStyle.ribbon())
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# cor clareada: lê bem em cima da terracota
	UiStyle.title_label(label, 24, color.lerp(Color("fff4dc"), 0.45) if color != Color.WHITE else UiStyle.TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_child(label)
	_toasts.add_child(ribbon)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).free()
	ribbon.modulate.a = 0.0
	ribbon.scale = Vector2(0.6, 0.6)
	ribbon.resized.connect(func() -> void: ribbon.pivot_offset = ribbon.size * 0.5)
	var tween := ribbon.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ribbon, "modulate:a", 1.0, 0.12)
	tween.tween_property(ribbon, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(1.5)
	tween.chain().tween_property(ribbon, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(ribbon.queue_free)


## Selos em cima do texto do próximo painel (resumo da run). Vale só para o próximo show_panel.
func set_panel_chips(items: Array) -> void:
	_panel_chip_items = items


## Lista de loot do próximo painel: [{icon, name, qty, rarity}]. Vale só para o próximo show_panel.
func set_panel_loot(entries: Array) -> void:
	_panel_loot_items = entries


func show_panel(title: String, text: String, button_text: String = "Recomeçar") -> void:
	_ask_callback = Callable()
	for ch in _panel_loot.get_children():
		ch.queue_free()
	for e in _panel_loot_items.slice(0, 12):
		_panel_loot.add_child(_loot_row(e))
	_panel_loot_box.visible = not _panel_loot_items.is_empty()
	_panel_loot_items = []
	for ch in _panel_chips.get_children():
		ch.queue_free()
	for it in _panel_chip_items:
		_panel_chips.add_child(UiStyle.chip(it[0], it[1], it[2] if it.size() > 2 else Color(0, 0, 0, 0)))
	_panel_chips.visible = not _panel_chip_items.is_empty()
	_panel_chip_items = []
	_panel_title.text = title
	_panel_text.text = text
	_panel_text.visible = text != ""
	_panel_button.text = button_text
	_panel_button2.visible = false
	_panel.visible = true
	_hide_controls()


## Pergunta com duas respostas (ex.: voltar do acampamento?). callback(true) para a 1ª, (false) para a 2ª.
func ask(title: String, text: String, yes_text: String, no_text: String, callback: Callable) -> void:
	show_panel(title, text, yes_text)
	_panel_button2.text = no_text
	_panel_button2.visible = true
	_ask_callback = callback


func is_asking() -> bool:
	return _panel.visible and _ask_callback.is_valid()


func _on_panel_button(first: bool) -> void:
	if _ask_callback.is_valid():
		var cb := _ask_callback
		_ask_callback = Callable()
		hide_panel()
		cb.call(first)
		return
	if first:
		restart_requested.emit()


## Mostra até 3 buffs para escolher. A run fica pausada até a escolha.
func show_buff_choice(options: Array[BuffData], title: String) -> void:
	for c in _buff_cards.get_children():
		c.queue_free()
	(_buff_panel.get_child(0).get_child(0) as Label).text = title
	for buff in options:
		var card := Button.new()
		card.custom_minimum_size = Vector2(220, 170)
		card.text = "%s\n\n%s" % [buff.display_name, buff.description]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_theme_font_size_override("font_size", 19)
		card.add_theme_font_override("font", UiStyle.body_font())
		var style := UiStyle.section()
		style.border_color = GameEnums.rarity_color(buff.rarity)
		style.set_border_width_all(3)
		style.bg_color = Color(0.06, 0.07, 0.1, 0.95)
		card.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.12, 0.13, 0.18, 0.98)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		card.pressed.connect(func() -> void:
			_buff_panel.visible = false
			_show_controls()
			buff_chosen.emit(buff))
		_buff_cards.add_child(card)
	_buff_panel.visible = true
	_hide_controls()


func _hide_controls() -> void:
	joystick.release()
	joystick.visible = false
	attack_button.visible = false


func _show_controls() -> void:
	joystick.visible = true
	attack_button.visible = true


func hide_panel() -> void:
	_panel.visible = false
	_buff_panel.visible = false
	joystick.visible = true
	attack_button.visible = true


## Chamado pelos itens do chão (grupo "loot_listeners").
func on_loot_collected(item: ItemData, qty: int, instance: Dictionary = {}) -> void:
	if instance.is_empty():
		show_toast("+%d %s" % [qty, item.display_name], GameEnums.rarity_color(item.rarity))
	else:
		var r := int(instance.rarity)
		show_toast("+ %s %s" % [ItemFactory.display_name(instance, ItemDB.catalog), GameEnums.rarity_name(r)],
			GameEnums.rarity_color(r))


# ---------- atualização ----------

func _on_health_changed(health: int, max_health: int, armor: int, max_armor: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	# proteção temporária (Bolha e afins): barra branca embaixo da vida, só enquanto dura
	var shield: int = _player.health.bubble if _player else 0
	UiStyle.set_bar(_health_bar, health, max_health, "%d / %d" % [health, max_health] + ("  +%d" % shield if shield > 0 else ""))
	UiStyle.set_bar(_armor_bar, shield, max_health, "")
	_armor_row.visible = shield > 0


func _on_hero_changed(hero: HeroData) -> void:
	var class_names := {
		GameEnums.HeroClass.TANK: "Tank",
		GameEnums.HeroClass.RANGER: "Ranger",
		GameEnums.HeroClass.MAGE: "Mago",
		GameEnums.HeroClass.DRUID: "Druida",
	}
	var form_text := ""
	if _player and _player.form_name() != "":
		form_text = " · forma: %s" % _player.form_name()
	_hero_label.text = hero.display_name
	UiStyle.set_portrait(_portrait, String(hero.id))
	for ch in _hero_chips.get_children():
		ch.queue_free()
	_hero_chips.add_child(UiStyle.chip("%d" % GameState.level_of(hero.id), "nivel", Color("ffd25a")))
	_hero_chips.add_child(UiStyle.chip(class_names.get(hero.hero_class, "?"), UiStyle.primary_icon(hero.primary_stat)))
	if form_text != "":
		_hero_chips.add_child(UiStyle.chip(_player.form_name(), "", UiStyle.OK))
	_update_kit_buttons()


# ---------- montagem ----------

func _build_status() -> void:
	var outer := HBoxContainer.new()
	outer.position = Vector2(14, 10)
	outer.add_theme_constant_override("separation", 8)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	_portrait = UiStyle.portrait("icamiaba", 92)
	outer.add_child(_portrait)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	_hero_label = _make_label(24)
	UiStyle.title_label(_hero_label, 24, UiStyle.TEXT)
	head.add_child(_hero_label)
	_hero_chips = HBoxContainer.new()
	_hero_chips.add_theme_constant_override("separation", 4)
	head.add_child(_hero_chips)
	# vida e escudo: barras com o número dentro e o ícone ao lado
	for spec in [["vida", Color("e05555"), 22], ["escudo", Color("eef3ff"), 10]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		box.add_child(row)
		var ic := TextureRect.new()
		ic.texture = load("res://game/ui/icones/s_%s.png" % spec[0])
		ic.custom_minimum_size = Vector2(spec[2] + 6, spec[2] + 6)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
		var bar := UiStyle.bar(spec[1], 260, spec[2])
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		if spec[0] == "vida":
			_health_bar = bar
		else:
			_armor_bar = bar
			_armor_row = row
			row.visible = false
	_health_label = _make_label(16)
	_health_label.visible = false
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 12)
	box.add_child(_status_row)
	_synergy_row = HBoxContainer.new()
	_synergy_row.add_theme_constant_override("separation", 6)
	_synergy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_row.visible = false
	box.add_child(_synergy_row)

	# topo: placa com o andar e os selos ao lado
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiStyle.plate())
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(plate)
	_wave_label = _make_label(24)
	UiStyle.title_label(_wave_label, 24, UiStyle.GOLD)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_wave_label)
	_wave_chips = HBoxContainer.new()
	_wave_chips.add_theme_constant_override("separation", 4)
	top.add_child(_wave_chips)

	_goal_row = HBoxContainer.new()
	_goal_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_goal_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_goal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_row.visible = false
	add_child(_goal_row)

	_help_label = _make_label(14)
	_help_label.text = "PC   WASD anda   Espaço ataca   Q habilidade   F ultimate\nR nova run   G salva"
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help_label.modulate.a = 0.7
	_help_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_help_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help_label.offset_right = -20
	_help_label.offset_top = 16
	add_child(_help_label)


func _build_controls() -> void:
	joystick = TouchJoystick.new()
	joystick.anchor_left = 0.0
	joystick.anchor_top = 0.3
	joystick.anchor_right = 0.5
	joystick.anchor_bottom = 1.0
	add_child(joystick)

	attack_button = TouchButton.new()
	attack_button.text = "ATACAR"
	attack_button.font = UiStyle.button_font()
	attack_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	attack_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	attack_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	attack_button.offset_left = -210
	attack_button.offset_top = -210
	attack_button.offset_right = -60
	attack_button.offset_bottom = -60
	add_child(attack_button)
	attack_button.frame = UiStyle.texture_or_null("botao_ataque")

	form_button = TouchButton.new()
	form_button.text = "FORMA"
	form_button.color = Color("6fdc7b")
	form_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	form_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	form_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	form_button.offset_left = -330
	form_button.offset_top = -150
	form_button.offset_right = -230
	form_button.offset_bottom = -50
	form_button.visible = false
	form_button.font_size = 16
	form_button.font = UiStyle.button_font()
	form_button.frame = UiStyle.texture_or_null("botao_habilidade")
	form_button.pressed_changed.connect(func(pressed: bool) -> void:
		if pressed and _player:
			_player.touch_form = true)
	add_child(form_button)

	ultimate_button = TouchButton.new()
	ultimate_button.text = "ULTIMATE"
	ultimate_button.color = Color("e8c26a")
	ultimate_button.font_size = 18
	ultimate_button.font = UiStyle.button_font()
	ultimate_button.frame = UiStyle.texture_or_null("botao_habilidade")
	ultimate_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ultimate_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ultimate_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ultimate_button.offset_left = -200
	ultimate_button.offset_top = -330
	ultimate_button.offset_right = -90
	ultimate_button.offset_bottom = -220
	ultimate_button.visible = false
	ultimate_button.pressed_changed.connect(func(pressed: bool) -> void:
		if pressed and _player:
			_player.touch_ultimate = true)
	add_child(ultimate_button)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_top = -200
	_toasts.offset_bottom = -40
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(640, 220)
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	add_child(_panel)
	_panel.add_child(UiStyle.watermark_rect(0.18))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_panel_title = _make_label(34)
	UiStyle.title_label(_panel_title, 38)
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_panel_title)
	_panel_chips = HFlowContainer.new()
	_panel_chips.alignment = FlowContainer.ALIGNMENT_CENTER
	_panel_chips.add_theme_constant_override("h_separation", 6)
	_panel_chips.add_theme_constant_override("v_separation", 6)
	_panel_chips.custom_minimum_size = Vector2(600, 0)
	_panel_chips.visible = false
	box.add_child(_panel_chips)
	# loot: lista em duas colunas (ícone, nome, quantidade)
	_panel_loot_box = PanelContainer.new()
	_panel_loot_box.add_theme_stylebox_override("panel", UiStyle.section())
	_panel_loot_box.visible = false
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	_panel_loot_box.add_child(lv)
	var lt := Label.new()
	lt.text = "Loot"
	UiStyle.title_label(lt, 20)
	lv.add_child(lt)
	_panel_loot = GridContainer.new()
	_panel_loot.columns = 2
	_panel_loot.add_theme_constant_override("h_separation", 16)
	_panel_loot.add_theme_constant_override("v_separation", 4)
	lv.add_child(_panel_loot)
	box.add_child(_panel_loot_box)
	_panel_text = _make_label(18)
	_panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_panel_text)
	_panel_button = Button.new()
	_panel_button.text = "Recomeçar"
	_panel_button.custom_minimum_size = Vector2(220, 60)
	UiStyle.style_button(_panel_button, "ouro", 24)
	_panel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel_button.pressed.connect(_on_panel_button.bind(true))
	_panel_button2 = Button.new()
	_panel_button2.custom_minimum_size = Vector2(220, 60)
	UiStyle.style_button(_panel_button2, "normal", 24)
	_panel_button2.pressed.connect(_on_panel_button.bind(false))
	_panel_button2.visible = false
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	buttons.add_child(_panel_button)
	buttons.add_child(_panel_button2)
	box.add_child(buttons)
	_panel.visible = false


func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_box.offset_top = 56
	_boss_box.custom_minimum_size = Vector2(520, 0)
	_boss_box.offset_left = -260
	_boss_box.offset_right = 260
	add_child(_boss_box)
	_boss_name = _make_label(22)
	UiStyle.title_label(_boss_name, 26, Color("ffa53d"))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_color_override("font_color", Color("ffa53d"))
	_boss_box.add_child(_boss_name)
	_boss_bar = _make_bar(Color("c0392b"))
	_boss_bar.custom_minimum_size = Vector2(520, 18)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false


func _build_minimap() -> void:
	minimap = Minimap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.offset_left = -200
	minimap.offset_right = -20
	minimap.offset_top = 90
	minimap.offset_bottom = 220
	add_child(minimap)


func _build_buff_panel() -> void:
	_buff_panel = PanelContainer.new()
	_buff_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_buff_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_buff_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_buff_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	add_child(_buff_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_buff_panel.add_child(box)
	var title := _make_label(28)
	UiStyle.title_label(title, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_buff_cards = HBoxContainer.new()
	_buff_cards.add_theme_constant_override("separation", 16)
	_buff_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_buff_cards)
	_buff_panel.visible = false


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiStyle.TEXT)
	label.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 16)
	bar.show_percentage = false
	bar.step = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.05, 0.03, 0.75)
	bg.border_color = Color("1a0f08")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.border_color = fill_color.lightened(0.35)
	fill.border_width_top = 2  # brilho em cima: barra com volume
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Uma linha do loot: casinha com o ícone (borda na raridade), o nome e "×N".
func _loot_row(e: Dictionary) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 4
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	row.add_theme_stylebox_override("panel", sb)
	row.custom_minimum_size = Vector2(300, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(42, 42)
	var ss := UiStyle.slot_box(int(e.rarity))
	ss.set_content_margin_all(4)
	slot.add_theme_stylebox_override("panel", ss)
	var ic := TextureRect.new()
	ic.texture = UiStyle.icon(String(e.icon))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(ic)
	h.add_child(slot)
	var n := UiStyle.label(String(e.name), 16, GameEnums.rarity_color(int(e.rarity)) if int(e.rarity) > 0 else UiStyle.TEXT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	var q := Label.new()
	q.text = "×%d" % int(e.qty)
	UiStyle.title_label(q, 20, UiStyle.GOLD)
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(q)
	return row
