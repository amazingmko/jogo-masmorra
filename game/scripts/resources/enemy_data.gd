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
## Usa o modelo/esqueleto de outro bicho (ex.: a Onça Alfa usa o da onça), maior por model_scale.
@export var model_id: StringName
@export var model_scale: float = 1.0

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
## Couro grosso: multiplica o dano recebido (0,5 = toma metade). Ver EnemyAttack.exposes_weak_spot.
@export_range(0.1, 1.0) var hide_damage_mult: float = 1.0
## Aparece em grupo: quantos iguais nascem juntos (ex.: bando de queixadas).
@export_range(1, 8) var group_min: int = 1
@export_range(1, 8) var group_max: int = 1
## Camuflado: quase invisível de longe; aparece ao chegar perto ou ao atacar (ex.: onça).
@export var stalker: bool = false
## Tocaia: fica parado até o herói chegar a esta distância ou atacar (0 = sempre ativo).
@export var ambush_range: float = 0.0

@export_group("Visual provisório")
## Corpo deitado (bicho de quatro patas, cobra, formiga) em vez de em pé.
@export var quadruped: bool = false
@export_range(1, 7) var eye_count: int = 1
## Pintas no corpo (onça).
@export var spotted: bool = false
## Boca na barriga (Mapinguari).
@export var belly_mouth: bool = false

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
