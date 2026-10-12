class_name ItemData
extends Resource
## Molde de um item. Cada arquivo em game/data/items/ é um ItemData.
## Materiais e consumíveis empilham. Equipamentos são "moldes": cada um que cai ganha
## raridade, nível de item e atributos próprios (ver ItemFactory).

enum Kind { MATERIAL, WEAPON, ARMOR, ACCESSORY, CONSUMABLE }

## Identificador único, sem espaços nem acentos. Ex.: &"minerio_ferro".
@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.MATERIAL
## Raridade de materiais e consumíveis. Para equipamentos, a raridade é sorteada ao cair.
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## Faixa de poder (1 = início do jogo). Usada para balancear drops e receitas.
@export_range(1, 20) var tier: int = 1
## Quantos cabem numa pilha. Equipamentos não empilham (1).
@export_range(1, 9999) var max_stack: int = 99
## Atributos fixos. Em armas: damage, attack_speed, attack_range, projectile_speed.
@export var stats: Dictionary = {}
@export var icon: Texture2D

@export_group("Equipamento")
@export var slot: GameEnums.Slot = GameEnums.Slot.WEAPON
## Só para armaduras: tecido, couro ou placa.
@export var armor_type: GameEnums.ArmorType = GameEnums.ArmorType.CLOTH
## Só para armas: tipo que a classe usa (ex.: "espada", "arco", "cajado").
@export var weapon_type: StringName
## Só para armas: atributo que a arma dá.
@export var primary_stat: GameEnums.PrimaryStat = GameEnums.PrimaryStat.STRENGTH


func is_equipment() -> bool:
	return kind in [Kind.WEAPON, Kind.ARMOR, Kind.ACCESSORY]


func is_stackable() -> bool:
	return not is_equipment() and max_stack > 1
