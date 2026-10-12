class_name ItemData
extends Resource
## Molde de um item. Cada arquivo em game/data/items/ é um ItemData.
## Para criar um item novo: duplique um .tres existente no editor e mude os campos.

enum Kind { MATERIAL, WEAPON, ARMOR, ACCESSORY, CONSUMABLE }

## Identificador único, sem espaços nem acentos. Ex.: &"minerio_ferro".
@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.MATERIAL
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## Faixa de poder (1 = início do jogo). Usada para balancear drops e receitas.
@export_range(1, 20) var tier: int = 1
## Quantos cabem numa pilha. Equipamentos não empilham (1).
@export_range(1, 9999) var max_stack: int = 99
## Atributos que o item dá. Ex.: {"damage": 6, "attack_speed": 1.2}
@export var stats: Dictionary = {}
@export var icon: Texture2D


func is_equipment() -> bool:
	return kind in [Kind.WEAPON, Kind.ARMOR, Kind.ACCESSORY]


func is_stackable() -> bool:
	return not is_equipment() and max_stack > 1
