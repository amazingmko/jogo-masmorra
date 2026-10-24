class_name SpecInfo
extends RefCounted
## Como mostrar cada especialização (ramo de talentos) e a origem de cada herói na interface:
## a função (Dano, Tank, Healer, Suporte, Controle, Mobilidade) com ícone e cor, e o ícone do ramo.

const ROLE := {
	"Dano": ["espada", Color("ff9a6a")],
	"Tank": ["escudo", Color("8fb0ff")],
	"Healer": ["vida", Color("7fe39a")],
	"Suporte": ["suporte", Color("ffd98a")],
	"Controle": ["controle", Color("c89bff")],
	"Mobilidade": ["mobilidade", Color("8fe8e8")],
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
