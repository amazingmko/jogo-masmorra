class_name Hud
extends CanvasLayer
## Interface da partida: vida e armadura, onda atual, avisos de loot, controles de toque
## e a tela de derrota/vitória. Montada por código para ficar fácil de ajustar nesta fase.

signal restart_requested

var joystick: TouchJoystick
var attack_button: TouchButton

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


func _ready() -> void:
	add_to_group("loot_listeners")
	_build_status()
	_build_controls()
	_build_toasts()
	_build_panel()


# ---------- API usada pela arena ----------

func move_vector() -> Vector2:
	return joystick.value


func attack_held() -> bool:
	return attack_button.is_pressed


func bind_player(player: Player) -> void:
	player.health.changed.connect(_on_health_changed)
	player.hero_changed.connect(_on_hero_changed)
	_on_health_changed(player.health.health, player.health.max_health, player.health.armor, player.health.max_armor)
	if player.hero:
		_on_hero_changed(player.hero)


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


func show_panel(title: String, text: String) -> void:
	_panel_title.text = title
	_panel_text.text = text
	_panel.visible = true
	joystick.release()
	joystick.visible = false
	attack_button.visible = false


func hide_panel() -> void:
	_panel.visible = false
	joystick.visible = true
	attack_button.visible = true


## Chamado pelos itens do chão (grupo "loot_listeners").
func on_loot_collected(item: ItemData, qty: int) -> void:
	show_toast("+%d %s" % [qty, item.display_name], LootPickup.RARITY_COLORS.get(item.rarity, Color.WHITE))


# ---------- atualização ----------

func _on_health_changed(health: int, max_health: int, armor: int, max_armor: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	_armor_bar.max_value = maxi(max_armor, 1)
	_armor_bar.value = armor
	_health_label.text = "Vida %d/%d   Armadura %d/%d" % [health, max_health, armor, max_armor]


func _on_hero_changed(hero: HeroData) -> void:
	var class_names := {
		GameEnums.HeroClass.TANK: "Tank",
		GameEnums.HeroClass.RANGER: "Ranger",
		GameEnums.HeroClass.MAGE: "Mago",
	}
	_hero_label.text = "%s (%s)" % [hero.display_name, class_names.get(hero.hero_class, "?")]


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

	_wave_label = _make_label(26)
	_wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_label.position.y = 16
	add_child(_wave_label)

	_help_label = _make_label(14)
	_help_label.text = "PC: WASD anda · Espaço ataca\n1/2/3 troca herói · R recomeça\nC forja espada · G salva"
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
	_panel.custom_minimum_size = Vector2(420, 220)
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
	var button := Button.new()
	button.text = "Recomeçar"
	button.custom_minimum_size = Vector2(200, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: restart_requested.emit())
	box.add_child(button)
	_panel.visible = false


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
