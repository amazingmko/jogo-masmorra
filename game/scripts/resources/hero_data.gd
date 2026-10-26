class_name HeroData
extends Resource
## Molde de um herói jogável.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var hero_class: GameEnums.HeroClass = GameEnums.HeroClass.TANK
@export var element: GameEnums.Element = GameEnums.Element.NEUTRAL
## Atributo principal; define o tipo de armadura (força = placa, agilidade = couro, inteligência = tecido).
@export var primary_stat: GameEnums.PrimaryStat = GameEnums.PrimaryStat.STRENGTH
## Tipo de arma que a classe usa (igual ao weapon_type das armas).
@export var weapon_type: StringName

@export_group("Atributos base (nível 1, sem equipamento)")
@export var max_health: int = 100
## Escudo que absorve dano e se regenera fora de combate.
## Escudo que se regenera: saiu do jogo (só vida + proteção temporária das habilidades). Fica 0.
@export var max_shield: int = 0
@export var base_primary: int = 10
@export var max_energy: int = 150
@export var move_speed: float = 5.0
@export_range(0.0, 1.0) var crit_chance: float = 0.05
## Armadura própria da classe, somada à do equipamento (tanques nascem mais protegidos).
@export var base_armor: int = 0
## Chance de bloquear um golpe inimigo (só tanques; o escudo equipado soma mais).
@export_range(0.0, 0.5) var block_chance: float = 0.0

@export_group("Visual")
## Modelo 3D do herói (.glb). Vazio = cápsula provisória. Deve olhar para +Z, pés em y = 0, ~1,7 m.
@export var model: PackedScene

@export_group("Equipamento inicial")
@export var starting_weapon_id: StringName


## Estilo elemental que conta na sinergia (um por herói; o Neutro não conta).
func elemental_styles() -> Array[int]:
	var out: Array[int] = []
	if element != GameEnums.Element.NEUTRAL:
		out.append(int(element))
	return out


func armor_type() -> GameEnums.ArmorType:
	return GameEnums.ARMOR_FOR_PRIMARY[primary_stat]
