class_name UiStyle
extends RefCounted
## Identidade visual da interface, igual em todos os biomas: moldura de metal com cantoneiras e
## pedra, placa de título, botões, abas e casas de item (borda na cor da raridade). Um tema só,
## aplicado na janela inteira. Texturas: tools/gerar_ui.py (game/ui/<paleta>/ e game/ui/icones/).
##
## Paletas em teste: "obsidiana" (preto + ouro), "pedra_lunar" (ardósia + prata) e "abissal"
## (azul-marinho + linhas claras). Fontes: Lilita One (títulos/botões) + Nunito (texto).

static var palette := "abissal"
## Fonte dos títulos e botões: Marcellus SC (escolhida). "aventura" volta para a Lilita One.
static var variant := "classico"
## Fundo sutil das janelas (marca d'água): "folhas" (escolhido), "emblema", "constelacao" ou "".
static var watermark := "folhas"

const OUTLINE := Color("07080b")
const OK := Color("6fdc7b")
const BAD := Color("ff6b6b")

const PALETTES := {
	"obsidiana": {"text": Color("efe6d2"), "dim": Color("a39c8c"), "title": Color("f3cf72"), "accent": Color("40c4d6"), "line": Color("6b5428"), "row": Color(1, 1, 1, 0.04), "gold_text": Color("2b1a04")},
	"pedra_lunar": {"text": Color("e9eef6"), "dim": Color("9aa6ba"), "title": Color("dfe8f5"), "accent": Color("60ded6"), "line": Color("4f5d75"), "row": Color(1, 1, 1, 0.045), "gold_text": Color("0b2b2c")},
	"abissal": {"text": Color("e6f4ff"), "dim": Color("8eaecb"), "title": Color("ffd98a"), "accent": Color("8fdcff"), "line": Color("2c5a86"), "row": Color(0.5, 0.8, 1.0, 0.05), "gold_text": Color("2b1a04")},
}

static var _fonts := {}
static var _theme: Theme
static var _theme_key := ""


static func c(key: String) -> Color:
	return PALETTES[palette][key]


static var TEXT: Color:
	get: return c("text")
static var TEXT_DIM: Color:
	get: return c("dim")
static var GOLD: Color:
	get: return c("title")


static func dir() -> String:
	return "res://game/ui/%s/" % palette


static func _font(file: String, weight := 0) -> Font:
	var key := "%s:%d" % [file, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load("res://game/ui/fontes/" + file)
	var f: Font = base
	if weight > 0:
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f = v
	_fonts[key] = f
	return f


static func title_font() -> Font:
	return _font("marcellus_sc.ttf") if variant == "classico" else _font("lilita_one.ttf")


## Números de dano e textos que sobem na luta: Lilita One (lê melhor no meio da ação).
static func number_font() -> Font:
	return _font("lilita_one.ttf")


static func body_font() -> Font:
	return _font("nunito.ttf", 650)


static func bold_font() -> Font:
	return _font("nunito.ttf", 800)


static func button_font() -> Font:
	return title_font()


## Marca d'água das janelas: imagem bem fraca, tingida com a cor de destaque, atrás do conteúdo.
## Põe como PRIMEIRO filho de um PanelContainer (ele empilha os filhos no mesmo retângulo).
static func watermark_rect(strength := 0.16) -> Control:
	var t := TextureRect.new()
	t.name = "MarcaDagua"
	if watermark == "":
		return t
	t.texture = load("res://game/ui/fundo_%s.png" % watermark)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.modulate = Color(c("accent"), strength)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.clip_contents = true
	return t


static func icon(name: String) -> Texture2D:
	var path := "res://game/ui/icones/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func _tex_box(file: String, margin: Vector4, content: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(dir() + file)
	sb.texture_margin_left = margin.x
	sb.texture_margin_top = margin.y
	sb.texture_margin_right = margin.z
	sb.texture_margin_bottom = margin.w
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


## Moldura grande (janelas, diálogos).
static func panel() -> StyleBoxTexture:
	return _tex_box("moldura.png", Vector4(84, 84, 84, 84), Vector4(34, 30, 34, 28))


## Placa do título da janela e faixa dos avisos.
static func plate() -> StyleBoxTexture:
	return _tex_box("placa.png", Vector4(44, 20, 44, 20), Vector4(52, 6, 52, 9))


## Casa de item (rarity -1 = vazia).
static func slot_box(rarity := -1) -> StyleBoxTexture:
	return _tex_box("casa.png" if rarity < 0 else "casa_%d.png" % rarity, Vector4(18, 18, 18, 18), Vector4(8, 8, 8, 8))


static func tab_box(active: bool) -> StyleBoxTexture:
	return _tex_box("aba_ativa.png" if active else "aba.png", Vector4(14, 14, 14, 6), Vector4(18, 8, 18, 8))


## Caixa por dentro de uma janela (seções): fundo mais escuro e um filete.
static func section(highlight := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.28) if not highlight else Color(c("accent"), 0.10)
	sb.border_color = c("line") if not highlight else c("title")
	sb.set_border_width_all(1 if not highlight else 2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	return sb


static func button_boxes(kind := "normal") -> Dictionary:
	var m := Vector4(14, 14, 14, 14)
	var cm := Vector4(18, 8, 18, 11)
	var gold := kind == "ouro"
	return {"normal": _tex_box("botao_ouro.png" if gold else "botao.png", m, cm),
		"hover": _tex_box("botao_ouro_hover.png" if gold else "botao_hover.png", m, cm),
		"pressed": _tex_box("botao_press.png", m, cm), "disabled": _tex_box("botao_off.png", m, cm),
		"focus": StyleBoxEmpty.new()}


static func style_button(b: Button, kind := "normal", font_size := 20) -> void:
	var boxes := button_boxes(kind)
	for k in boxes:
		b.add_theme_stylebox_override(k, boxes[k])
	b.add_theme_font_override("font", button_font())
	b.add_theme_font_size_override("font_size", font_size)
	var gold := kind == "ouro"
	b.add_theme_color_override("font_color", c("gold_text") if gold else TEXT)
	b.add_theme_color_override("font_hover_color", c("gold_text") if gold else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color("8a8a8a"))
	b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3) if gold else OUTLINE)
	b.add_theme_constant_override("outline_size", 2 if gold else 5)


static func ribbon() -> StyleBoxTexture:
	return plate()


static func theme() -> Theme:
	var key := palette + variant
	if _theme and _theme_key == key:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("panel", "PanelContainer", section())
	t.set_stylebox("panel", "Panel", panel())
	var boxes := button_boxes()
	for k in boxes:
		t.set_stylebox(k, "Button", boxes[k])
	t.set_font("font", "Button", button_font())
	t.set_font_size("font_size", "Button", 19)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_outline_color", "Button", OUTLINE)
	t.set_constant("outline_size", "Button", 5)
	var grab := StyleBoxFlat.new()
	grab.bg_color = c("line").lightened(0.25)
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 5
	grab.content_margin_right = 5
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.3)
	track.set_corner_radius_all(4)
	track.content_margin_left = 5
	track.content_margin_right = 5
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(s, "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(0, 0, 0, 0.45)
	edit.border_color = c("line").lightened(0.2)
	edit.set_border_width_all(2)
	edit.set_corner_radius_all(5)
	edit.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit)
	t.set_color("font_color", "LineEdit", TEXT)
	_theme = t
	_theme_key = key
	return t


static func apply(window: Window) -> void:
	window.theme = theme()
	ThemeDB.fallback_font = body_font()


static func title_label(l: Label, size: int, color: Color = Color(0, 0, 0, 0)) -> void:
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD if color.a == 0.0 else color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 2)


static func label(text: String, size := 17, color: Color = Color(0, 0, 0, 0), bold := false) -> Label:
	var l := Label.new()
	l.text = text
	if bold:
		l.add_theme_font_override("font", bold_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT if color.a == 0.0 else color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ---------- componentes ----------

## Selo (a "pílula" do jogo): um losango de metal com o ícone encaixado, sobreposto a uma placa
## escura de ponta chanfrada com o texto. Sem ícone, um losango pequeno na cor do selo.
## icon: nome em icones/s_<nome>.png.
static func chip(text: String, icon := "", color: Color = Color(0, 0, 0, 0), size := 15) -> Control:
	var col := c("accent") if color.a == 0.0 else color
	var d := float(size + 17)          # lado do losango
	var overlap := d * 0.42
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", -int(overlap))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# losango (por cima da placa)
	var gem := Control.new()
	gem.custom_minimum_size = Vector2(d, d)
	gem.z_index = 1
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(gem)
	if icon != "":
		for layer in [["selo_losango.png", Color.WHITE, 0.0], ["selo_brilho.png", Color(col, 0.45), 0.0]]:
			var t := TextureRect.new()
			t.texture = load(dir() + layer[0])
			t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.modulate = layer[1]
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gem.add_child(t)
		var ic := TextureRect.new()
		ic.texture = load("res://game/ui/icones/s_%s.png" % icon)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pad := d * 0.24
		ic.offset_left = pad
		ic.offset_top = pad
		ic.offset_right = -pad
		ic.offset_bottom = -pad
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.add_child(ic)
	else:
		gem.custom_minimum_size = Vector2(d * 0.62, d * 0.62)
		var dot := TextureRect.new()
		dot.texture = load(dir() + "selo_ponto.png")
		dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.modulate = col
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.add_child(dot)
		overlap = d * 0.62 * 0.45
		root.add_theme_constant_override("separation", -int(overlap))
	# placa com o texto
	var plate := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = load(dir() + "selo_placa.png")
	sb.texture_margin_left = 3
	sb.texture_margin_right = 12
	sb.texture_margin_top = 8
	sb.texture_margin_bottom = 8
	sb.content_margin_left = overlap + 5
	sb.content_margin_right = 15
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", sb)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT if color.a == 0.0 else col.lerp(Color.WHITE, 0.3))
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(l)
	if text == "":
		plate.visible = false
		root.add_theme_constant_override("separation", 0)
	return root


## Fileira de selos.
## Retrato do herói (arte do Gemini): o rosto recortado em círculo com um aro dourado em volta.
## full = true usa o retrato inteiro, com a moldura original (tamanhos grandes).
static func portrait(hero_id: String, size: float, full := false) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(size, size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	face.name = "Rosto"
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(face)
	if not full:
		var pad := size * 0.06
		face.offset_left = pad
		face.offset_top = pad
		face.offset_right = -pad
		face.offset_bottom = -pad
		var ring := TextureRect.new()
		ring.name = "Aro"
		ring.texture = load("res://game/ui/abissal/anel.png")
		ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ring.stretch_mode = TextureRect.STRETCH_SCALE
		ring.modulate = Color("e8c27a")
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(ring)
	root.set_meta("full", full)
	set_portrait(root, hero_id)
	return root


static func set_portrait(p: Control, hero_id: String) -> void:
	var full: bool = p.get_meta("full", false)
	var path := "res://game/ui/retratos/%s%s.png" % [hero_id, "" if full else "_rosto"]
	(p.get_node("Rosto") as TextureRect).texture = load(path) if ResourceLoader.exists(path) else null
	p.visible = ResourceLoader.exists(path)


static func chips(items: Array, sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it in items:
		h.add_child(chip(it[0], it[1] if it.size() > 1 else "", it[2] if it.size() > 2 else Color(0, 0, 0, 0)))
	return h


## Cabeçalho de coluna (mesma altura das abas: as colunas começam alinhadas).
static func header(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", tab_box(true))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.custom_minimum_size = Vector2(0, 46)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", button_font())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Corpo de coluna logo abaixo do cabeçalho/abas (canto de cima-esquerdo reto, colado nelas).
static func column_body() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := section()
	sb.corner_radius_top_left = 0
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p


## Barra com o número escrito dentro (vida, XP).
static func bar(fill: Color, width := 260.0, height := 20.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, height)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.04, 0.08, 0.85)
	bg.border_color = Color(c("line"), 1.0).lightened(0.15)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.border_color = fill.lightened(0.4)
	fg.border_width_top = 3
	fg.set_corner_radius_all(5)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.name = "Texto"
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", maxi(int(height * 0.72), 13))
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return b


static func set_bar(b: ProgressBar, value: float, max_value: float, text := "") -> void:
	b.max_value = maxf(max_value, 1.0)
	b.value = value
	(b.get_node("Texto") as Label).text = text


## Contas (energia, pontos de talento): n de total acesas, em losango.
static func pips(n: int, total: int, color: Color, size := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 1)
	for i in total:
		var t := TextureRect.new()
		t.texture = load(dir() + ("conta.png" if i < n else "conta_vazia.png"))
		t.custom_minimum_size = Vector2(size + 4, size + 4)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.modulate = color if i < n else Color.WHITE
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(t)
	return h


## Ícone do atributo principal e do tipo de armadura (para os selos).
static func primary_icon(stat: int) -> String:
	return ["forca", "agilidade", "inteligencia"][clampi(stat, 0, 2)]


static func armor_icon(armor: int) -> String:
	return ["tecido", "couro", "placa"][clampi(armor, 0, 2)]
