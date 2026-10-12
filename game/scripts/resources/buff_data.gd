class_name BuffData
extends Resource
## Buff escolhido entre fases da run.

enum Mode { ADD, MULTIPLY }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## Atributo afetado. Ex.: "max_armor", "fire_rate", "skill_cooldown".
@export var stat: StringName
@export var amount: float = 0.0
@export var mode: Mode = Mode.ADD
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
