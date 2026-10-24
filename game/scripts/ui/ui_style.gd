class_name UiStyle
extends RefCounted
## Identidade visual da interface: fontes, moldura dos painéis (madeira + faixa de inspiração
## marajoara), botões de madeira e a faixa dos avisos. Um tema só, aplicado na janela inteira:
## tudo que é Label/Button/Panel herda daqui. As texturas saem de tools/gerar_ui.py.
##
## Duas propostas de fonte (para escolher olhando): "aventura" (Lilita One + Nunito) e "epico"
## (Cinzel + Nunito). A escolhida fica; a outra sai.

const DIR := "res://game/ui/"
static var variant := "aventura"

const TEXT := Color("f1e4c6")        # creme
const TEXT_DIM := Color("bba98a")
const GOLD := Color("f0c060")
const OUTLINE := Color("1a0f08")

static var _fonts := {}
static var _theme: Theme


static func _font(file: String, weight := 0) -> Font:
	var key := "%s:%d" % [file, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: FontFile = load(DIR + "fontes/" + file)
	var f: Font = base
	if weight > 0:
		var v := FontVariation.new()
		v.base_font = base
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		f = v
	_fonts[key] = f
	return f


## Títulos de janela, números de dano, avisos.
static func title_font() -> Font:
	return _font("cinzel.ttf", 800) if variant == "epico" else _font("lilita_one.ttf")


## Texto corrido (descrições, listas).
static func body_font() -> Font:
	return _font("nunito.ttf", 650)


## Texto dos botões.
static func button_font() -> Font:
	return _font("cinzel.ttf", 700) if variant == "epico" else _font("lilita_one.ttf")


static func _tex_box(file: String, margin: int, content: Vector4, tile := false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(DIR + file)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


## Moldura grande (janelas do hub, diálogos).
static func panel() -> StyleBoxTexture:
	return _tex_box("moldura_painel.png", 34, Vector4(40, 36, 40, 36), true)


## Caixa simples por dentro de uma janela (cartões, listas): madeira escura com filete.
static func card(accent: Color = Color("6b4a2c"), selected := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.115, 0.08, 0.92) if not selected else Color(0.27, 0.18, 0.09, 0.95)
	sb.border_color = accent if not selected else GOLD
	sb.set_border_width_all(2 if not selected else 3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Estilos de botão: "madeira" (comum) ou "ouro" (ação principal).
static func button_boxes(kind := "madeira") -> Dictionary:
	var c := Vector4(16, 8, 16, 11)
	if kind == "ouro":
		return {"normal": _tex_box("botao_ouro.png", 14, c), "hover": _tex_box("botao_ouro_hover.png", 14, c),
			"pressed": _tex_box("botao_press.png", 14, c), "disabled": _tex_box("botao_off.png", 14, c),
			"focus": StyleBoxEmpty.new()}
	return {"normal": _tex_box("botao.png", 14, c), "hover": _tex_box("botao_hover.png", 14, c),
		"pressed": _tex_box("botao_press.png", 14, c), "disabled": _tex_box("botao_off.png", 14, c),
		"focus": StyleBoxEmpty.new()}


static func style_button(b: Button, kind := "madeira", font_size := 20) -> void:
	var boxes := button_boxes(kind)
	for k in boxes:
		b.add_theme_stylebox_override(k, boxes[k])
	b.add_theme_font_override("font", button_font())
	b.add_theme_font_size_override("font_size", font_size)
	var dark := kind == "ouro"
	b.add_theme_color_override("font_color", Color("2a1606") if dark else TEXT)
	b.add_theme_color_override("font_hover_color", Color("1a0d03") if dark else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color("9a9a9a"))
	b.add_theme_color_override("font_outline_color", Color(1, 0.9, 0.7, 0.35) if dark else OUTLINE)
	b.add_theme_constant_override("outline_size", 2 if dark else 5)


## Faixa dos avisos no meio da tela.
static func ribbon() -> StyleBoxTexture:
	var sb := _tex_box("faixa_aviso.png", 0, Vector4(70, 12, 70, 16))
	sb.texture_margin_left = 40
	sb.texture_margin_right = 40
	sb.texture_margin_top = 20
	sb.texture_margin_bottom = 20
	return sb


## O tema da janela inteira.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("panel", "PanelContainer", card())
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
	# barra de rolagem fina, cor de madeira
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("8a5e36")
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.25)
	track.set_corner_radius_all(4)
	track.content_margin_left = 6
	track.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", track)
	# campo de texto (IP)
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(0.08, 0.05, 0.03, 0.9)
	edit.border_color = Color("8a5e36")
	edit.set_border_width_all(2)
	edit.set_corner_radius_all(5)
	edit.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit)
	t.set_color("font_color", "LineEdit", TEXT)
	_theme = t
	return t


## Liga a identidade na janela (chamar uma vez, no começo de cada cena com interface).
static func apply(window: Window) -> void:
	window.theme = theme()
	ThemeDB.fallback_font = body_font()  # Label3D (números de dano) e o que não tiver tema


## Rótulo de título (janela, seção).
static func title_label(l: Label, size: int, color: Color = GOLD) -> void:
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 2)
