class_name SpecInfo
extends RefCounted
## Como mostrar cada especialização (ramo de talentos) e a origem de cada herói na interface:
## a função (Dano, Tank, Healer, Suporte, Controle, Mobilidade) com ícone e cor, e o ícone do ramo.

const ROLE := {
	"Dano": ["funcao_dano", Color("ff9a6a")],
	"Tank": ["funcao_tank", Color("ffb86a")],
	"Healer": ["funcao_healer", Color("7fe39a")],
	"Suporte": ["funcao_suporte", Color("ffd98a")],
	"Controle": ["funcao_controle", Color("c89bff")],
	"Mobilidade": ["funcao_mobilidade", Color("8fe8e8")],
}

## ramo -> [funções, ícone do ramo]
const SPECS := {
	"protecao": [["Tank"], "escudo"],
	"furia": [["Dano"], "espada"],
	"guardia": [["Tank", "Controle"], "controle"],
	"precisao": [["Dano"], "arco"],
	"armadilheira": [["Controle", "Dano"], "controle"],
	"mata": [["Mobilidade", "Dano"], "mobilidade"],
	"correnteza": [["Dano"], "inteligencia"],
	"espelho": [["Mobilidade", "Dano"], "mobilidade"],
	"pororoca": [["Controle", "Dano"], "controle"],
	"canto": [["Healer"], "vida"],
	"encanto": [["Controle", "Suporte"], "controle"],
	"rio": [["Suporte", "Dano"], "suporte"],
}

## herói -> [bioma, região de origem]
const ORIGIN := {
	"icamiaba": ["Amazônia", "Terra Firme"],
	"mateira": ["Amazônia", "Terra Firme"],
	"encantado": ["Amazônia", "Terra Firme"],
	"druida": ["Amazônia", "Terra Firme"],
}


static func roles(branch_id: String) -> Array:
	return SPECS.get(branch_id, [["Dano"], "espada"])[0]


static func icon(branch_id: String) -> String:
	if ResourceLoader.exists("res://game/ui/icones/s_spec_%s.png" % branch_id):
		return "spec_" + branch_id
	return SPECS.get(branch_id, [["Dano"], "espada"])[1]


## Selos das funções de um ramo.
static func role_chips(branch_id: String, size := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in roles(branch_id):
		var spec: Array = ROLE.get(r, ["espada", Color.WHITE])
		h.add_child(UiStyle.chip(r, spec[0], spec[1], size))
	return h


## Só os ícones das funções (sem o nome; o nome aparece ao segurar o dedo / passar o mouse).
static func role_icons(branch_id: String, size := 24) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	for r in roles(branch_id):
		var spec: Array = ROLE.get(r, ["espada", Color.WHITE])
		var t := TextureRect.new()
		t.texture = load("res://game/ui/icones/s_%s.png" % spec[0])
		t.custom_minimum_size = Vector2(size, size)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.tooltip_text = r
		h.add_child(t)
	return h


## As funções que o herói cobre (somando os 3 ramos, sem repetir), na ordem dos ramos.
static func hero_roles(hero_id: StringName) -> Array:
	var out := []
	for b in Talents.branches(hero_id):
		for r in roles(String(b.id)):
			if not out.has(r):
				out.append(r)
	return out


static func origin(hero_id: StringName) -> Array:
	return ORIGIN.get(String(hero_id), ["Amazônia", "Terra Firme"])
