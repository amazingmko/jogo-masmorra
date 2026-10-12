class_name Health
extends Node
## Vida e armadura de qualquer personagem (herói ou inimigo).
## A armadura absorve o dano primeiro e se regenera depois de um tempo sem apanhar.

signal changed(health: int, max_health: int, armor: int, max_armor: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 6
@export var max_armor: int = 0
## Segundos sem apanhar até a armadura começar a voltar.
@export var armor_regen_delay: float = 4.0
## Segundos para recuperar cada ponto de armadura.
@export var armor_regen_interval: float = 1.0
## Segundos de invencibilidade depois de apanhar (para o herói não morrer de uma vez).
@export var invulnerability_time: float = 0.0

var health: int
var armor: int
var is_dead: bool = false

var _since_hit: float = 0.0
var _regen_timer: float = 0.0
var _invulnerable: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	health = max_health
	armor = max_armor
	is_dead = false
	_since_hit = 0.0
	_invulnerable = 0.0
	_emit_changed()


## Aplica dano. Devolve quanto de dano foi realmente causado (0 se invencível ou morto).
func take_damage(amount: int) -> int:
	if is_dead or amount <= 0 or _invulnerable > 0.0:
		return 0
	var absorbed := mini(armor, amount)
	armor -= absorbed
	health -= amount - absorbed
	_since_hit = 0.0
	_regen_timer = 0.0
	_invulnerable = invulnerability_time
	damaged.emit(amount)
	if health <= 0:
		health = 0
		is_dead = true
		_emit_changed()
		died.emit()
	else:
		_emit_changed()
	return amount


## Muda os máximos (ex.: um buff de +2 de vida). Se o máximo aumenta, o atual sobe junto.
func set_maximums(new_max_health: int, new_max_armor: int) -> void:
	var gained_health := new_max_health - max_health
	var gained_armor := new_max_armor - max_armor
	max_health = new_max_health
	max_armor = new_max_armor
	if not is_dead:
		if gained_health > 0:
			health += gained_health
		if gained_armor > 0:
			armor += gained_armor
	health = mini(health, max_health)
	armor = mini(armor, max_armor)
	_emit_changed()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = mini(health + amount, max_health)
	_emit_changed()


func is_invulnerable() -> bool:
	return _invulnerable > 0.0


func _process(delta: float) -> void:
	tick(delta)


## Avança o tempo. Separado do _process para os testes conseguirem simular segundos.
func tick(delta: float) -> void:
	if is_dead:
		return
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_since_hit += delta
	if armor < max_armor and _since_hit >= armor_regen_delay:
		_regen_timer += delta
		while _regen_timer >= armor_regen_interval and armor < max_armor:
			_regen_timer -= armor_regen_interval
			armor += 1
			_emit_changed()


func _emit_changed() -> void:
	changed.emit(health, max_health, armor, max_armor)
