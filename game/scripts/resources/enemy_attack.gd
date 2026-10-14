class_name EnemyAttack
extends Resource
## Um ataque de inimigo. Cada inimigo tem uma lista deles (EnemyData.attacks) e escolhe
## qual usar conforme a distância, a recarga e a vida que ainda tem.
## Todo ataque mostra um aviso no chão antes de acontecer: é a janela para o jogador desviar.

enum Kind {
	MELEE,       ## golpe em círculo ou cone à frente
	CHARGE,      ## investida em linha reta
	PROJECTILE,  ## um disparo na direção do herói
	FAN,         ## leque de disparos
	GROUND_AOE,  ## áreas no chão onde o herói está (e em volta)
	NOVA,        ## anel de disparos para todos os lados
	SUMMON,      ## chama ajudantes
	MEGA,        ## mega magia: a sala inteira, menos as zonas seguras
}
## FEAR (medo): não anda nem ataca por um instante.
enum Effect { NONE, POISON, ROOT, SLOW, FEAR }

@export var id: StringName
@export var display_name: String = ""
@export var kind: Kind = Kind.MELEE
## Chance relativa de ser escolhido entre os ataques disponíveis.
@export_range(1, 100) var weight: int = 10

@export_group("Quando usar")
@export var range_min: float = 0.0
@export var range_max: float = 2.0
## Segundos até poder usar de novo.
@export var cooldown: float = 2.0
## Só usa quando a vida do inimigo está abaixo desta fração (1 = sempre). Cria as fases do chefe.
@export_range(0.0, 1.0) var below_health: float = 1.0
## Só aparece em salas com perigo a partir deste valor (0 = sempre). Ver Enemy.threat.
@export_range(0.0, 1.0) var min_threat: float = 0.0

@export_group("Tempo")
## Duração do aviso no chão antes do ataque acontecer.
@export var windup: float = 0.6
## Pausa depois do ataque.
@export var recover: float = 0.6

@export_group("Dano e forma")
@export var damage: int = 10
## Dano extra como fração da vida máxima do herói (para a mega magia).
@export_range(0.0, 1.0) var damage_percent_of_target: float = 0.0
## Raio do golpe/área, ou largura da investida.
@export var radius: float = 1.5
## Metade do ângulo do cone em graus (0 = círculo completo).
@export_range(0.0, 180.0) var cone_half_angle: float = 0.0
## Distância percorrida na investida.
@export var length: float = 6.0
## Quantidade de disparos, áreas ou ajudantes.
@export var count: int = 1
@export var spread_deg: float = 30.0
## Velocidade do disparo ou da investida.
@export var speed: float = 12.0
## Áreas que continuam no chão depois (ex.: poça de veneno), em segundos.
@export var linger: float = 0.0
@export var color: Color = Color("e05555")

@export_group("Efeito")
@export var effect: Effect = Effect.NONE
@export var effect_duration: float = 2.0
## Veneno: dano por segundo. Lentidão: % de redução.
@export var effect_power: int = 0
## Ajudante que aparece (SUMMON).
@export var summon_id: StringName

@export_group("Comportamento")
## Bando: ao usar este ataque, os iguais por perto (neste raio) atacam junto. 0 = sozinho.
@export var rally_radius: float = 0.0
## Se acertar, o atacante recupera esta fração da própria vida máxima.
@export_range(0.0, 1.0) var heal_percent_max_health: float = 0.0
## Depois deste ataque, o ponto fraco fica exposto por estes segundos (toma o dobro de dano).
@export var exposes_weak_spot: float = 0.0


## Magias e disparos: os inimigos usam enquanto recuam, e o chefe usa mais quanto menos vida tem.
func is_spell() -> bool:
	return kind != Kind.MELEE and kind != Kind.CHARGE
