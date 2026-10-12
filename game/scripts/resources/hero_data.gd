class_name HeroData
extends Resource
## Molde de um herói jogável.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var hero_class: GameEnums.HeroClass = GameEnums.HeroClass.TANK
@export var element: GameEnums.Element = GameEnums.Element.NEUTRAL

@export_group("Atributos base")
@export var max_health: int = 6
@export var max_armor: int = 3
@export var max_energy: int = 150
@export var move_speed: float = 5.0
@export_range(0.0, 1.0) var crit_chance: float = 0.05

@export_group("Equipamento inicial")
@export var starting_weapon_id: StringName
