class_name EnemyData
extends Resource
## Molde de um inimigo. Cada arquivo em game/data/enemies/ é um EnemyData.

enum Movement { CHASE, STRAFE, SKITTER, KITE }

@export var id: StringName
@export var display_name: String = ""
@export var element: GameEnums.Element = GameEnums.Element.NEUTRAL
@export var color: Color = Color("c95b5b")
## Tamanho do corpo (1 = tamanho do herói).
@export_range(0.4, 3.0) var body_scale: float = 1.0

@export_group("Atributos")
@export var max_health: int = 20
@export var damage: int = 1
@export var move_speed: float = 2.8

@export_group("Movimento")
## CHASE: avança com ginga · STRAFE: circula em volta · SKITTER: zigue-zague rápido · KITE: mantém distância
@export var movement: Movement = Movement.CHASE
## Distância que o inimigo tenta manter do herói.
@export var preferred_distance: float = 1.2
@export var is_boss: bool = false

@export_group("Ataques")
## Lista de ataques (ver EnemyAttack). Vazia = um golpe simples com os valores abaixo.
@export var attacks: Array[EnemyAttack] = []
## Valores do golpe simples (usados só se a lista acima estiver vazia).
@export var attack_range: float = 1.4
@export var windup_time: float = 0.6
@export var recover_time: float = 0.8

@export_group("Recompensa")
@export var drop_table_id: StringName
@export var xp_reward: int = 3
