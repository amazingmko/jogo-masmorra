class_name TalentsPanel
extends VBoxContainer
## Talentos no jeito do WoW, sem rolagem:
## - esquerda: as 3 especializações do herói, cada uma com a sua função (Dano, Tank, Healer...);
## - meio: a mini árvore da especialização escolhida (4 fileiras ligadas por linhas; a de baixo é
##   o talento máximo). Fileira fechada mostra o cadeado e quantos pontos faltam;
## - direita: o talento tocado (o que faz agora e no próximo ponto) e o botão de aprender.
## As regras dos pontos continuam as de Talents (1 ponto a cada 2 níveis).

signal back_requested
signal changed

static var spec := ""
static var picked := ""

var hero: HeroData
var player: Player
## Nível usado nas regras (com os pontos de teste).
var level := 1
static var message := ""

const NODE := 70


func build(h: HeroData, p: Player) -> void:
	hero = h
	player = p
	level = GameState.talent_level(h.id)
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var branches := Talents.branches(hero.id)
	var ok := false
	for b in branches:
		ok = ok or b.id == spec
	if not ok and not branches.is_empty():
		# abre na especialização ativa
		spec = GameState.active_spec(hero.id)
		picked = ""
	_refresh()


func _refresh() -> void:
	for ch in get_children():
		ch.queue_free()
	var talents := GameState.all_talents_of(hero.id)
	var free := GameState.talent_points_free(hero.id, spec)
	# topo: herói, pontos e botões
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.custom_minimum_size = Vector2(0, 46)
	add_child(top)
	top.add_child(UiStyle.header(hero.display_name))
	top.add_child(UiStyle.chip("Nível %d" % GameState.level_of(hero.id), "nivel", Color("ffd25a")))
	top.add_child(UiStyle.chip("%d pontos livres" % maxi(free, 0), "poder", UiStyle.OK if free > 0 else UiStyle.TEXT_DIM))
	top.add_child(UiStyle.chip("1 ponto a cada 3 níveis", "", UiStyle.TEXT_DIM, 13))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	if OS.is_debug_build():
		var dbg := Button.new()
		dbg.text = "+5 (teste)"
		UiStyle.style_button(dbg, "normal", 15)
		dbg.pressed.connect(func() -> void:
			GameState.debug_talent_points += 5
			GameState.save()
			_refresh())
		top.add_child(dbg)
	var reset := Button.new()
	reset.text = "Redistribuir"
	UiStyle.style_button(reset, "normal", 17)
	reset.disabled = Talents.spent_in_branch(talents, _branch()) == 0
	reset.pressed.connect(func() -> void:
		GameState.reset_talents(hero.id, spec)
		player.refresh_stats()
		message = "Pontos devolvidos"
		changed.emit()
		_refresh())
	top.add_child(reset)
	var back := Button.new()
	back.text = "Voltar"
	UiStyle.style_button(back, "normal", 17)
	back.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	row.add_child(_specs(talents))
	row.add_child(_tree(talents, free))
	row.add_child(_detail(talents, free))


# ---------- especializações ----------

func _specs(talents: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(290, 0)
	col.add_theme_constant_override("separation", 8)
	for b in Talents.branches(hero.id):
		col.add_child(_spec_card(b, talents))
	return col


func _spec_card(b: Dictionary, talents: Dictionary) -> Control:
	var sel: bool = b.id == spec
	var pts := Talents.spent_in_branch(talents, b)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := UiStyle.section(sel)
	sb.bg_color = Color(UiStyle.c("accent"), 0.15) if sel else Color(0, 0, 0, 0.35)
	for k in ["normal", "hover", "pressed"]:
		btn.add_theme_stylebox_override(k, sb)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var ic := TextureRect.new()
	ic.texture = load("res://game/ui/icones/s_%s.png" % SpecInfo.icon(String(b.id)))
	ic.custom_minimum_size = Vector2(52, 52)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if sel or pts > 0 else Color(1, 1, 1, 0.6)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var n := Label.new()
	n.text = b.name
	UiStyle.title_label(n, 21, UiStyle.GOLD if sel else UiStyle.TEXT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(n)
	if b.id == GameState.active_spec(hero.id):
		top.add_child(UiStyle.chip("Ativa", "", UiStyle.OK, 13))
	top.add_child(UiStyle.chip("%d" % pts, "", UiStyle.GOLD if pts > 0 else UiStyle.TEXT_DIM, 14))
	v.add_child(SpecInfo.role_chips(String(b.id), 13))
	var rt := String(b.role)
	var role := UiStyle.label(rt.left(1).to_upper() + rt.substr(1), 14, UiStyle.TEXT_DIM)
	v.add_child(role)
	var bid: String = b.id
	btn.pressed.connect(func() -> void:
		spec = bid
		picked = ""
		_refresh())
	return btn


# ---------- árvore ----------

func _branch() -> Dictionary:
	for b in Talents.branches(hero.id):
		if b.id == spec:
			return b
	return Talents.branches(hero.id)[0]


func _tree(talents: Dictionary, free: int) -> Control:
	var b := _branch()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.section())
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tree := _TreeView.new()
	tree.panel = self
	tree.branch = b
	tree.talents = talents
	tree.free = free
	box.add_child(tree)
	return box


func _node(t: Dictionary, talents: Dictionary, open: bool) -> Button:
	var r := Talents.rank(talents, t.id)
	var maxed := r >= int(t.max)
	var cap := int(t.row) == 3
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var size := NODE + (12 if cap else 0)
	b.custom_minimum_size = Vector2(size, size)
	b.size = b.custom_minimum_size
	var box := UiStyle.slot_box(3 if cap and r > 0 else (1 if maxed else (2 if r > 0 else -1)))
	if r > 0 and not maxed and not cap:
		box = UiStyle.slot_box(0)
	for k in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(k, box)
	var ic := TextureRect.new()
	ic.texture = load("res://game/ui/icones/s_%s.png" % SpecInfo.icon(spec))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top"]:
		ic.set("offset_" + side, 14)
	for side in ["right", "bottom"]:
		ic.set("offset_" + side, -14)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if r > 0 else (Color(0.8, 0.8, 0.85, 0.75) if open else Color(0.4, 0.4, 0.45, 0.5))
	b.add_child(ic)
	var rank := UiStyle.chip("%d/%d" % [r, int(t.max)], "", UiStyle.GOLD if maxed else (UiStyle.OK if r > 0 else UiStyle.TEXT_DIM), 12)
	rank.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	rank.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rank.grow_vertical = Control.GROW_DIRECTION_BOTH
	rank.offset_top = -2
	rank.offset_bottom = 10
	b.add_child(rank)
	if picked == t.id:
		var ring := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = UiStyle.GOLD
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		sb.shadow_color = Color(UiStyle.GOLD, 0.55)
		sb.shadow_size = 8
		ring.add_theme_stylebox_override("panel", sb)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ring)
	var id: String = t.id
	b.pressed.connect(func() -> void:
		picked = id
		message = ""
		_refresh())
	return b


## A árvore desenhada: nós em fileiras e as linhas que ligam uma fileira à de baixo.
class _TreeView extends Control:
	var panel: TalentsPanel
	var branch: Dictionary
	var talents: Dictionary
	var free := 0
	var _nodes := {}   # id -> Button
	var _rows: Array = []

	func _ready() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(360, 0)
		_rows = []
		for row in Talents.ROW_LEVEL.size():
			var list := []
			for t in branch.talents:
				if int(t.row) == row:
					list.append(t)
			_rows.append(list)
		for row in _rows.size():
			var open := Talents.row_open(panel.level, row)
			for t in _rows[row]:
				var b := panel._node(t, talents, open)
				add_child(b)
				_nodes[t.id] = b
			if not open:
				var lock := UiStyle.chip("Nv %d" % Talents.ROW_LEVEL[row], "cadeado", UiStyle.TEXT_DIM, 13)
				lock.name = "Trava%d" % row
				add_child(lock)
		resized.connect(_layout)
		_layout.call_deferred()

	func _layout() -> void:
		var n := _rows.size()
		var top := 20.0
		var step := (size.y - 40.0) / maxf(n, 1)
		for row in n:
			var list: Array = _rows[row]
			var y := top + step * (row + 0.5)
			for i in list.size():
				var b: Button = _nodes[list[i].id]
				var x := size.x * (0.5 if list.size() == 1 else (0.3 + 0.4 * i / maxf(list.size() - 1, 1)))
				b.position = Vector2(x, y) - b.size * 0.5
			var lock := get_node_or_null("Trava%d" % row)
			if lock:
				lock.position = Vector2(8, y - lock.size.y * 0.5)
		queue_redraw()

	func _draw() -> void:
		for row in range(_rows.size() - 1):
			var here: Array = _rows[row]
			var below: Array = _rows[row + 1]
			for ia in here.size():
				for ib in below.size():
					# ligação reta: cada nó com o de baixo na mesma coluna; fileira de 1 liga com todos
					if here.size() == below.size() and ia != ib:
						continue
					var a: Dictionary = here[ia]
					var b: Dictionary = below[ib]
					var na: Button = _nodes[a.id]
					var nb: Button = _nodes[b.id]
					var lit := Talents.rank(talents, a.id) > 0 and Talents.row_open(panel.level, row + 1)
					var col := Color(UiStyle.GOLD, 0.85) if lit else Color(UiStyle.c("line"), 0.9)
					draw_line(na.position + na.size * 0.5, nb.position + nb.size * 0.5, Color(0, 0, 0, 0.6), 7.0, true)
					draw_line(na.position + na.size * 0.5, nb.position + nb.size * 0.5, col, 3.0, true)


# ---------- detalhe ----------

func _detail(talents: Dictionary, free: int) -> Control:
	var b := _branch()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.section(picked != ""))
	box.custom_minimum_size = Vector2(320, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	box.add_child(v)
	var t := Talents.find(hero.id, picked) if picked != "" else {}
	if t.is_empty():
		var n0 := Label.new()
		n0.text = b.name
		UiStyle.title_label(n0, 24)
		v.add_child(n0)
		v.add_child(SpecInfo.role_chips(String(b.id), 14))
		var hint := UiStyle.label("Toque num talento da árvore para ver o que ele faz.", 15, UiStyle.TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(280, 0)
		v.add_child(hint)
		if message != "":
			v.add_child(UiStyle.chip(message, "", UiStyle.GOLD))
		if String(b.id) != GameState.active_spec(hero.id):
			var fill0 := Control.new()
			fill0.size_flags_vertical = Control.SIZE_EXPAND_FILL
			v.add_child(fill0)
			v.add_child(_activate_button(b))
		return box
	var r := Talents.rank(talents, t.id)
	var n := Label.new()
	n.text = t.name
	UiStyle.title_label(n, 24, UiStyle.GOLD if int(t.row) == 3 else UiStyle.TEXT)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(280, 0)
	v.add_child(n)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	tags.add_child(UiStyle.chip("Talento máximo" if int(t.row) == 3 else "Fileira %d" % (int(t.row) + 1), "", UiStyle.GOLD if int(t.row) == 3 else UiStyle.TEXT_DIM, 13))
	var pips := UiStyle.pips(r, int(t.max), UiStyle.OK, 13)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tags.add_child(pips)
	v.add_child(tags)
	var now := UiStyle.label(Talents.describe(t, r) if r > 0 else "Ainda não aprendido.", 16, UiStyle.TEXT if r > 0 else UiStyle.TEXT_DIM)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	now.custom_minimum_size = Vector2(280, 0)
	v.add_child(now)
	if r < int(t.max):
		var nx := UiStyle.label("Próximo ponto: " + Talents.describe(t, r + 1), 15, UiStyle.OK)
		nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nx.custom_minimum_size = Vector2(280, 0)
		v.add_child(nx)
	var why := Talents.can_add(talents, hero.id, t.id, level, GameState.active_spec(hero.id))
	if why != "" and r < int(t.max):
		var w := UiStyle.label(why, 14, Color("ffb46b"))
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size = Vector2(280, 0)
		v.add_child(w)
	if message != "":
		v.add_child(UiStyle.chip(message, "", UiStyle.GOLD))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	if String(b.id) != GameState.active_spec(hero.id):
		v.add_child(_activate_button(b))
		return box
	var learn := Button.new()
	learn.text = "Aprender" if r == 0 else ("No máximo" if r >= int(t.max) else "Melhorar")
	UiStyle.style_button(learn, "ouro" if why == "" else "normal", 21)
	learn.custom_minimum_size = Vector2(0, 58)
	learn.disabled = why != ""
	var id: String = t.id
	learn.pressed.connect(func() -> void:
		var res := GameState.add_talent(hero.id, id)
		message = res if res != "" else "%s %d/%d" % [t.name, r + 1, int(t.max)]
		player.refresh_stats()
		changed.emit()
		_refresh())
	v.add_child(learn)
	return box


## Troca a especialização ativa (a função do herói). Grátis, no hub; cada uma guarda os pontos.
func _activate_button(b: Dictionary) -> Button:
	var act := Button.new()
	act.text = "Ativar %s" % b.name
	UiStyle.style_button(act, "ouro", 20)
	act.custom_minimum_size = Vector2(0, 58)
	var bid: String = b.id
	act.pressed.connect(func() -> void:
		GameState.set_active_spec(hero.id, bid)
		player.refresh_stats()
		message = "%s ativa" % b.name
		changed.emit()
		_refresh())
	return act
