class_name UiStyle
extends RefCounted
## Identidade visual da interface, igual em todos os biomas: moldura de metal com cantoneiras e
## pedra, placa de título, botões, abas e casas de item (borda na cor da raridade). Um tema só,
## aplicado na janela inteira. Texturas: tools/gerar_ui.py (game/ui/<paleta>/ e game/ui/icones/).
##
## Paletas em teste: "obsidiana" (preto + ouro), "pedra_lunar" (ardósia + prata) e "abissal"
## (azul-marinho + linhas claras). Fontes: Lilita One (títulos/botões) + Nunito (texto).

static var palette := "obsidiana"
## "aventura" (Lilita One) ou "epico" (Cinzel) nos títulos.
static var variant := "aventura"

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
	return _font("cinzel.ttf", 800) if variant == "epico" else _font("lilita_one.ttf")


static func body_font() -> Font:
	return _font("nunito.ttf", 650)


static func bold_font() -> Font:
	return _font("nunito.ttf", 800)


static func button_font() -> Font:
	return _font("lilita_one.ttf")


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
