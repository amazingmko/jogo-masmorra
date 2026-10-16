class_name Hud
extends CanvasLayer
## Interface da partida: vida e armadura, andar atual, minimapa, avisos de loot, controles de toque,
## escolha de buff e resumo da run. Montada por código para ficar fácil de ajustar nesta fase.
## Roda mesmo com o jogo pausado (para a escolha de buff funcionar).

signal restart_requested
signal buff_chosen(buff: BuffData)

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
var _hero_label: Label
var _wave_label: Label
var _help_label: Label
var _toasts: VBoxContainer
var _panel: PanelContainer
var _panel_title: Label
var _panel_text: Label
var _panel_button: Button
var _buff_panel: PanelContainer
var _buff_cards: HBoxContainer
var _status_row: HBoxContainer
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss: Node
var _player: Player


func _ready() -> void:
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
			_boss_name.text = "%s — ENFURECIDO" % boss.data.display_name)
	_boss_box.visible = true


func hide_boss() -> void:
	_boss = null
	_boss_box.visible = false


func _process(_delta: float) -> void:
	_refresh_status()
	_update_kit_buttons()


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
		if kit.max_charges() > 1:
			skill_text += " ×%d" % kit.charges()
		form_button.set_state(1.0 - cd if cd > 0.0 else -1.0, cd > 0.0, skill_text)
	if ultimate_button.visible:
		var ready := kit.ultimate_ready()
		var label := kit.ultimate_name().to_upper() if ready else "%d%%" % int(kit.charge)
		ultimate_button.set_state(kit.charge / 100.0, not ready, label)


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


func show_toast(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1a1526"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 22)
	_toasts.add_child(label)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	var tween := label.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


func show_panel(title: String, text: String, button_text: String = "Recomeçar") -> void:
	_panel_title.text = title
	_panel_text.text = text
	_panel_button.text = button_text
	_panel.visible = true
	_hide_controls()


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
		card.add_theme_font_size_override("font_size", 20)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.17, 0.13, 0.25, 0.95)
		style.border_color = GameEnums.rarity_color(buff.rarity)
		style.set_border_width_all(3)
		style.set_corner_radius_all(14)
		style.set_content_margin_all(14)
		card.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.25, 0.2, 0.36, 0.98)
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
	_armor_bar.max_value = maxi(max_armor, 1)
	_armor_bar.value = armor
	_health_label.text = "Vida %d/%d   Escudo %d/%d" % [health, max_health, armor, max_armor]


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
	_hero_label.text = "%s (%s) · nv %d%s" % [hero.display_name, class_names.get(hero.hero_class, "?"),
		GameState.level_of(hero.id), form_text]
	_update_kit_buttons()


# ---------- montagem ----------

func _build_status() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(20, 16)
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	_hero_label = _make_label(24)
	box.add_child(_hero_label)
	_health_bar = _make_bar(Color("e05555"))
	box.add_child(_health_bar)
	_armor_bar = _make_bar(Color("9aa7c7"))
	box.add_child(_armor_bar)
	_health_label = _make_label(16)
	box.add_child(_health_label)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 12)
	box.add_child(_status_row)

	_wave_label = _make_label(26)
	_wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_label.position.y = 16
	add_child(_wave_label)

	_help_label = _make_label(14)
	_help_label.text = "PC: WASD anda · Espaço ataca · Q habilidade · F ultimate\nR nova run · G salva"
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
	attack_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	attack_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	attack_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	attack_button.offset_left = -210
	attack_button.offset_top = -210
	attack_button.offset_right = -60
	attack_button.offset_bottom = -60
	add_child(attack_button)

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
	form_button.font_size = 15
	form_button.pressed_changed.connect(func(pressed: bool) -> void:
		if pressed and _player:
			_player.touch_form = true)
	add_child(form_button)

	ultimate_button = TouchButton.new()
	ultimate_button.text = "ULTIMATE"
	ultimate_button.color = Color("e8c26a")
	ultimate_button.font_size = 17
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.92)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_panel_title = _make_label(34)
	_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_panel_title)
	_panel_text = _make_label(18)
	_panel_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_panel_text)
	_panel_button = Button.new()
	_panel_button.text = "Recomeçar"
	_panel_button.custom_minimum_size = Vector2(200, 56)
	_panel_button.add_theme_font_size_override("font_size", 22)
	_panel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel_button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(_panel_button)
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.9)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	_buff_panel.add_theme_stylebox_override("panel", style)
	add_child(_buff_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_buff_panel.add_child(box)
	var title := _make_label(28)
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
	label.add_theme_color_override("font_color", Color("f2ecff"))
	label.add_theme_color_override("font_outline_color", Color("1a1526"))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 16)
	bar.show_percentage = false
	bar.step = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar
