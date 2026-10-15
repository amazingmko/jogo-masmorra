class_name Health
extends Node
## Vida e escudo de qualquer personagem (herói ou inimigo).
## O escudo (variáveis "armor", por compatibilidade) absorve o dano primeiro e se regenera
## depois de um tempo sem apanhar. A redução de dano vem da Armadura do equipamento.

signal changed(health: int, max_health: int, armor: int, max_armor: int)
signal damaged(amount: int)
signal died
## Um golpe foi bloqueado (amount: dano que ainda passou).
signal hit_blocked(amount: int)
## O escudo acabou de zerar.
signal shield_broken

@export var max_health: int = 6
@export var max_armor: int = 0
## Segundos sem apanhar até a armadura começar a voltar.
@export var armor_regen_delay: float = 4.0
## Segundos para recuperar cada parcela de escudo.
@export var armor_regen_interval: float = 1.0
## Quanto de escudo volta a cada parcela.
@export var armor_regen_amount: int = 1
## Fração do dano bloqueada pela Armadura (0 a 0.75).
var damage_reduction: float = 0.0
## Chance de bloquear um golpe direto (só tanques). Veneno e mega magia não são bloqueáveis.
var block_chance: float = 0.0
## Quanto do golpe o bloqueio segura.
const BLOCK_REDUCTION := 0.7
## Dano extra enquanto o escudo está zerado (heróis; 0 = sem efeito).
var exposed_bonus: float = 0.0
## Não toma dano nenhum (ex.: chefe canalizando a mega magia).
var untouchable: bool = false
## Segundos de invencibilidade depois de apanhar (para o herói não morrer de uma vez).
@export var invulnerability_time: float = 0.0

var health: int
var armor: int
var is_dead: bool = false

var _since_hit: float = 0.0
var _regen_timer: float = 0.0
var _invulnerable: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	health = max_health
	armor = max_armor
	is_dead = false
	_since_hit = 0.0
	_invulnerable = 0.0
	_emit_changed()


## Aplica dano. Devolve quanto de dano foi realmente causado (0 se invencível ou morto).
## grant_invuln: abre a janela de invencibilidade (falso para veneno).
## ignore_invuln: atravessa a invencibilidade (veneno, mega magia).
func take_damage(amount: int, grant_invuln: bool = true, ignore_invuln: bool = false) -> int:
	if is_dead or amount <= 0 or (_invulnerable > 0.0 and not ignore_invuln) or untouchable:
		return 0
	amount = maxi(int(round(amount * (1.0 - damage_reduction))), 1)
	var was_blocked := grant_invuln and not ignore_invuln and block_chance > 0.0 and _rng.randf() < block_chance
	if was_blocked:
		amount = maxi(int(round(amount * (1.0 - BLOCK_REDUCTION))), 1)
	if is_exposed():
		amount = int(round(amount * (1.0 + exposed_bonus)))
	var had_shield := armor > 0
	var absorbed := mini(armor, amount)
	armor -= absorbed
	health -= amount - absorbed
	_since_hit = 0.0
	_regen_timer = 0.0
	if grant_invuln:
		_invulnerable = invulnerability_time
	if was_blocked:
		hit_blocked.emit(amount)  # antes do "damaged", para a animação de bloqueio vencer a de dano
	damaged.emit(amount)
	if had_shield and armor == 0 and max_armor > 0:
		shield_broken.emit()
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


## Sem escudo e sujeito ao dano extra.
func is_exposed() -> bool:
	return exposed_bonus > 0.0 and max_armor > 0 and armor <= 0


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
			armor = mini(armor + armor_regen_amount, max_armor)
			_emit_changed()


func _emit_changed() -> void:
	changed.emit(health, max_health, armor, max_armor)
