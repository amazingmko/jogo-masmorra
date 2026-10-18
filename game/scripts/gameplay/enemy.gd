class_name Enemy
extends CharacterBody3D
## Inimigo com movimento próprio e vários ataques (definidos no EnemyData).
## Ciclo: MOVE (anda do seu jeito, decide atacar) → WINDUP (aviso no chão) → ataque → RECOVER → MOVE.
## Por cima disso, uma tática: PRESS (parte para cima e emenda uma sequência de ataques) e
## BACK_OFF (recua, rodeia e solta magias de longe). Também esquiva de disparos e golpes do herói.
## O "perigo" da sala (threat, 0 a 1) aumenta sequências, esquivas, recuos e libera magias extras.
## Chefes usam os mesmos ataques, com fases (EnemyAttack.below_health); quanto menos vida,
## mais rápidos ficam e mais magias soltam. Abaixo de 30% de vida entram em fúria.

signal died(enemy: Enemy)
signal summon_requested(enemy: Enemy, summon_id: StringName, count: int, at: Vector3)
signal announced(enemy: Enemy, text: String)

enum State { MOVE, WINDUP, CHARGING, RECOVER, DEAD }
## RUSH: vai direto · FLANK: arco pelo lado · DASH: arrancada curta · FEINT: recua e volta com tudo
## SIDESTEP: pulo lateral · CIRCLE: rodeia · RETREAT: abre distância (atiradores)
enum Tactic { PRESS, BACK_OFF }
enum Maneuver { RUSH, FLANK, DASH, FEINT, SIDESTEP, CIRCLE, RETREAT }

const ENRAGE_AT := 0.3
## Dano extra no ponto fraco exposto (barriga do Mapinguari).
const WEAK_SPOT_MULT := 2.0

var data: EnemyData
var health: Health
var state: State = State.MOVE
## Multiplicadores do andar (mais fundo = mais forte).
var health_multiplier := 1.0
var damage_multiplier := 1.0
var is_boss := false
## Contexto do loot (nível de item, perfil de raridade, herói). Preenchido pela run.
var loot_context: Dictionary = {}
## Sala onde nasceu (a sala só reabre quando todos os dela morrem).
var home_room: Node3D
## Inimigos invocados não deixam loot nem XP.
var is_summon := false
var enraged := false
## Furioso (elite): definido pela run antes de entrar na cena (vida e dano já multiplicados lá).
var elite := false
## Perigo da sala (0 a 1), definido pela run antes de entrar na cena.
var threat := 0.0
var tactic: Tactic = Tactic.PRESS

var _attacks: Array[EnemyAttack] = []
var _cooldowns := {}
var _attack: EnemyAttack
var _timer := 0.0
var _decision := 0.5
var _aim_dir := Vector3.FORWARD
var _charge_left := 0.0
var _charge_hit := false
# Movimento: manobras sorteadas (ver _pick_maneuver), sempre puxando para o herói.
var _side := 1.0
var _maneuver := Maneuver.RUSH
var _maneuver_left := 0.0
var _maneuver_angle := 0.0
var _maneuver_speed := 1.0
var _next_maneuver := -1
var _wander := 0.0
var _hunger := 0.0
## Personalidade sorteada ao nascer: dois inimigos iguais não se movem igual.
var _aggression := 1.0
var _speed_jitter := 1.0
var _caution := 0.5
# Tática, sequência de ataques e esquiva.
var _tactic_left := 0.0
var _combo_left := 1
var _dodge_cd := 0.0
var _dodge_left := 0.0
var _dodge_dir := Vector3.ZERO
var _seen_shots := {}
var _recent_damage := 0
# Tocaia (cobra parada até o herói chegar perto) e camuflagem (onça quase invisível de longe).
var _awake := true
var _alpha := 1.0
## Cor base do corpo (o furioso é avermelhado).
var _tint := Color.WHITE
## Couro do Mapinguari: depois da Bocarra, a barriga fica exposta por alguns segundos.
var _exposed_left := 0.0
## Apertado pela Sucuri: não anda nem decide atacar. Depois, fica imune por um tempo.
var _constrict_left := 0.0
## Provocado pelo tanque: só avança (não recua) e bate mais fraco.
var _provoked_left := 0.0
const PROVOKE_DAMAGE := 0.75
var _provoke_factor := PROVOKE_DAMAGE
var _constrict_immune := 0.0
## Efeitos dos talentos do herói: atordoado (não anda nem decide), lento, envenenado e marcas
## que aumentam o dano recebido ({nome: [bônus, segundos]}).
var _stun_left := 0.0
var _slow_left := 0.0
var _slow_factor := 1.0
var _poison_left := 0.0
var _poison_dps := 0.0
var _poison_acc := 0.0
var _poison_tick := 0.0
var _marks := {}
## Dano a mais que recebe enquanto está provocado (Grito das Amazonas).
var provoked_vulnerability := 0.0
## Boneco de treino (só para testes): não desvia nem machuca, e quase não morre.
var training_dummy := false
## Encharcado (Encantado): fica pingando; poderes do Encantado batem mais nele.
var _soaked_left := 0.0
var _drip: CPUParticles3D
## Escorrega quando encharcado (Chão Escorregadio, do Encantado): chance de errar o ataque.
var slip_chance := 0.0
var _foam_left := 0.0       # Espuma: erra ataques por um tempo
var _foam_chance := 0.0
var _fear_left := 0.0       # Rugido: foge do herói
var _lure: WeakRef          # Cópia Teimosa: vai atrás da cópia em vez do herói
var _lure_left := 0.0
var _charm_left := 0.0      # Encanto: ataca os outros inimigos
var _charm_tick := 0.0
var _frozen_left := 0.0
var _on_slam := Callable()
## Arremessado pela Pororoca: se bater na parede enquanto voa, leva este dano.
var _slam_damage := 0
var _slam_left := 0.0
var _mouth_material: StandardMaterial3D
var _recent_timer := 0.0
var _own_telegraphs: Array[Telegraph] = []

var _player: Player
var _body: Node3D
var _material: StandardMaterial3D
var _eye_material: StandardMaterial3D
var _knockback := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _rng := RandomNumberGenerator.new()


static func create(enemy_data: EnemyData, hp_multiplier: float = 1.0, dmg_multiplier: float = 1.0) -> Enemy:
	var e := Enemy.new()
	e.data = enemy_data
	e.health_multiplier = hp_multiplier
	e.damage_multiplier = dmg_multiplier
	e.is_boss = enemy_data.is_boss
	e.name = String(enemy_data.id).capitalize()
	return e


func _ready() -> void:
	add_to_group("enemies")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	collision_layer = Layers.ENEMIES
	collision_mask = Layers.WORLD | Layers.ENEMIES
	_rng.randomize()
	_tint = data.color.lerp(Color("e0303a"), 0.35) if elite else data.color
	_build_visuals()
	if elite:
		_add_elite_marks()
	Lighting.no_shadow_receive(self)
	health = Health.new()
	health.max_health = maxi(int(round(data.max_health * health_multiplier)), 1)
	add_child(health)
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	_player = get_tree().get_first_node_in_group("player")

	_attacks = data.attacks.duplicate()
	if _attacks.is_empty():
		_attacks.append(_fallback_attack())
	for a in _attacks:
		# Começam com recargas diferentes, para não atacarem todos ao mesmo tempo.
		_cooldowns[a] = _rng.randf_range(0.2, a.cooldown * 0.6)
	_decision = _rng.randf_range(0.3, 0.9)
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_aggression = _rng.randf_range(0.8, 1.25)
	_speed_jitter = _rng.randf_range(0.92, 1.1)
	_wander = _rng.randf_range(-1.0, 1.0)
	_maneuver_left = _rng.randf_range(0.0, 0.4)
	_caution = _rng.randf_range(0.2, 0.8)
	_dodge_cd = _rng.randf_range(0.5, 2.0)
	_combo_left = _new_combo()
	_awake = data.ambush_range <= 0.0


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	var haste := _haste()
	for a in _cooldowns:
		_cooldowns[a] -= delta * haste
	_dodge_cd -= delta
	_constrict_left -= delta
	_constrict_immune -= delta
	_stun_left -= delta
	_slow_left -= delta
	_foam_left -= delta
	_fear_left -= delta
	_lure_left -= delta
	_charm_left -= delta
	if _frozen_left > 0.0:
		_frozen_left -= delta
		if _frozen_left <= 0.0:
			_material.albedo_color = _tint
	if _soaked_left > 0.0:
		_soaked_left -= delta
		if _soaked_left <= 0.0 and is_instance_valid(_drip):
			_drip.queue_free()
	_tick_poison(delta)
	for m in _marks.keys():
		_marks[m][1] -= delta
		if _marks[m][1] <= 0.0:
			_marks.erase(m)
	if _provoked_left > 0.0:
		_provoked_left -= delta
		if _provoked_left <= 0.0:
			damage_multiplier /= _provoke_factor
			provoked_vulnerability = 0.0
	if _exposed_left > 0.0:
		_exposed_left -= delta
		if _exposed_left <= 0.0 and _mouth_material:
			_mouth_material.emission_enabled = false
	_recent_timer -= delta
	if _recent_timer <= 0.0:
		_recent_damage = 0

	var player_alive := _player != null and is_instance_valid(_player) and not _player.health.is_dead
	var to_player := Vector3.ZERO
	if player_alive:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
	var dist := to_player.length()

	match state:
		State.MOVE:
			if _constrict_left > 0.0 or _stun_left > 0.0 or (_slam_left > 0.0 and _knockback.length() > 2.0):
				_set_horizontal(Vector3.ZERO)
			elif not _awake:
				# De tocaia: parado, esperando o herói chegar perto.
				_set_horizontal(Vector3.ZERO)
				if player_alive and dist <= data.ambush_range:
					_wake()
			elif _fear_left > 0.0 and player_alive:
				# Assustado (Rugido): corre para longe do herói, sem atacar.
				var away := -to_player.normalized() if dist > 0.01 else Vector3.FORWARD
				_set_horizontal(away * _move_speed() * 1.1 + _separation())
				_face(away, delta)
			elif _charm_left > 0.0:
				_charmed_step(delta)
			elif _lure_left > 0.0 and _lure and is_instance_valid(_lure.get_ref()):
				# Atraído pela cópia de água: vai até ela (e ela explode quando ele encosta).
				var to_lure: Vector3 = (_lure.get_ref() as Node3D).global_position - global_position
				to_lure.y = 0.0
				var lv := to_lure.normalized() * _move_speed() if to_lure.length() > 0.3 else Vector3.ZERO
				_set_horizontal(lv + _separation())
				if lv.length() > 0.1:
					_face(lv, delta)
			elif _dodge_left > 0.0:
				# Esquiva: deslize rápido para o lado, sem decidir nada no meio.
				_dodge_left -= delta
				_set_horizontal(_dodge_dir * _move_speed() * 3.0)
				_face(to_player, delta)
			else:
				if player_alive:
					_update_tactic(delta)
					_watch_shots()
				var v := _movement_velocity(delta, to_player, dist) if player_alive else Vector3.ZERO
				v += _separation()
				_set_horizontal(v)
				if v.length() > 0.2:
					_face(v, delta)
				elif player_alive:
					_face(to_player, delta)
				_decision -= delta * haste
				if player_alive and _decision <= 0.0:
					_try_attack(dist)
		State.WINDUP:
			_set_horizontal(Vector3.ZERO)
			_face(_aim_dir, delta * 2.0)
			_timer -= delta
			if _timer <= 0.0:
				_execute()
		State.CHARGING:
			_set_horizontal(_aim_dir * _attack.speed)
			_charge_left -= _attack.speed * delta
			if player_alive and not _charge_hit and dist <= 1.0 + 0.5 * data.body_scale + _attack.radius * 0.3 \
					and Layers.clear_path(get_world_3d(), global_position, _player.global_position):
				_charge_hit = true
				_player.receive_attack(int(round(_attack.damage * damage_multiplier)), _attack.effect,
					_attack.effect_duration, _attack.effect_power, global_position)
			if _charge_left <= 0.0 or (is_on_wall() and _charge_left < _attack.length - 0.5):
				_enter_recover()
		State.RECOVER:
			_set_horizontal(Vector3.ZERO)
			_timer -= delta
			if _timer <= 0.0:
				state = State.MOVE
				_maneuver_left = 0.0  # sai do ataque já com uma manobra nova
				_after_attack()

	_update_camouflage(delta, dist if player_alive else 99.0)
	if state != State.CHARGING:
		velocity += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()
	if _slam_left > 0.0:
		_slam_left -= delta
		if _knockback.length() > 1.5 and _hit_obstacle():
			_slam()


func take_hit(amount: int, crit: bool, from_direction: Vector3) -> void:
	if state == State.DEAD:
		return
	if health.untouchable:
		Fx.damage_number(get_parent(), global_position + Vector3(0, 2.2 * data.body_scale, 0), 0, false, Color("8b5cf6"))
		return
	if not _awake:
		_wake()
	if _try_evade(from_direction):
		return
	# Couro grosso (Mapinguari): toma menos dano, e o dobro com a barriga exposta.
	var number_color := Color.WHITE
	if _exposed_left > 0.0:
		amount = int(round(amount * WEAK_SPOT_MULT))
		number_color = Color("ff8a3d")
	elif data.hide_damage_mult < 1.0:
		amount = maxi(int(round(amount * data.hide_damage_mult)), 1)
		number_color = Color("b9b2a3")
	amount = maxi(int(round(amount * (1.0 + damage_taken_bonus()))), 1)
	health.take_damage(amount)
	_recent_damage += amount
	_recent_timer = 1.2
	_react_to_pain()
	Fx.damage_number(get_parent(), global_position + Vector3(0, 1.7 * data.body_scale, 0), amount, crit, number_color)
	Fx.flash(_material, _tint)
	var push := from_direction
	push.y = 0.0
	if push.length() > 0.01 and state != State.CHARGING and not is_boss:
		_knockback = push.normalized() * (3.0 / data.body_scale)


## Morre sem loot nem XP (ex.: ajudantes quando o chefe cai).
func dismiss() -> void:
	if state == State.DEAD:
		return
	is_summon = true
	health.untouchable = false
	health.take_damage(health.health + 999999, false, true)


# ---------- movimento ----------

func _movement_velocity(delta: float, to_player: Vector3, dist: float) -> Vector3:
	var dir_to := to_player.normalized() if dist > 0.01 else Vector3.FORWARD
	var speed := _move_speed()
	var pref := data.preferred_distance
	# Fome: cresce enquanto não ataca; quanto maior, mais ele parte para cima. Recuando, não cresce.
	if tactic == Tactic.PRESS:
		_hunger = minf(_hunger + delta * 0.35 * _aggression, 1.5)
	# Desvio suave e contínuo (passeio aleatório do ângulo), nunca o mesmo ritmo.
	_wander = clampf(_wander + _rng.randf_range(-1.0, 1.0) * delta * 4.0, -1.0, 1.0)

	_maneuver_left -= delta
	if is_on_wall() and _maneuver != Maneuver.RUSH:
		_maneuver_left = minf(_maneuver_left, 0.05)
		_side = -_side
	if _maneuver_left <= 0.0:
		_pick_maneuver(dist, pref)

	# Vai para onde o herói está (sem antecipar o passo dele: antecipando, o bando inteiro
	# desviava para o mesmo lado junto com o herói e parecia imitar o movimento).
	var lead_dir := dir_to
	var tangent := Vector3(-dir_to.z, 0, dir_to.x) * _side
	var noise := deg_to_rad(18.0) * _wander
	var v := Vector3.ZERO

	match _maneuver:
		Maneuver.RUSH:
			v = lead_dir.rotated(Vector3.UP, noise) * speed * _maneuver_speed
		Maneuver.FLANK:
			# Arco: começa bem aberto e vai fechando no herói.
			v = lead_dir.rotated(Vector3.UP, _maneuver_angle * _side + noise * 0.5) * speed * _maneuver_speed
		Maneuver.DASH:
			v = lead_dir.rotated(Vector3.UP, noise * 0.3) * speed * _maneuver_speed
		Maneuver.FEINT:
			v = (-dir_to * 0.6 + tangent * 0.8).normalized() * speed * 0.9
		Maneuver.SIDESTEP:
			v = (tangent + dir_to * 0.35).normalized() * speed * _maneuver_speed
		Maneuver.CIRCLE:
			# Rodeia, mas vai apertando o círculo.
			var pull := clampf((dist - pref * 0.8) * 0.4, -0.6, 0.6) + 0.15 * _hunger
			v = (tangent + dir_to * pull).normalized().rotated(Vector3.UP, noise * 0.5) * speed * _maneuver_speed
		Maneuver.RETREAT:
			v = (-dir_to + tangent * 0.7).normalized().rotated(Vector3.UP, noise) * speed * 1.05
	return v


## Sorteia a próxima manobra. Os pesos dependem do tipo de movimento, da distância
## e da "fome" (tempo sem atacar): todas as manobras terminam empurrando para o herói.
func _pick_maneuver(dist: float, pref: float) -> void:
	if _rng.randf() < 0.4:
		_side = -_side
	if _next_maneuver >= 0:
		# Finta sempre emenda numa arrancada ou investida.
		_set_maneuver(_next_maneuver)
		_next_maneuver = -1
		return
	var far := dist > pref + 1.0
	var h := _hunger * _aggression
	var w := {}
	match data.movement:
		EnemyData.Movement.CHASE:
			if far:
				w = {Maneuver.RUSH: 3.0 + h * 2.0, Maneuver.FLANK: 3.0, Maneuver.DASH: 1.5 + h,
					Maneuver.FEINT: 0.8, Maneuver.SIDESTEP: 1.0}
			else:
				w = {Maneuver.CIRCLE: 2.0, Maneuver.SIDESTEP: 1.5, Maneuver.DASH: 1.0 + h * 2.0,
					Maneuver.RUSH: 1.0 + h, Maneuver.FEINT: 0.7}
		EnemyData.Movement.SKITTER:
			if far:
				w = {Maneuver.DASH: 2.5 + h * 2.0, Maneuver.SIDESTEP: 2.5, Maneuver.FLANK: 2.5,
					Maneuver.FEINT: 1.5, Maneuver.RUSH: 1.5 + h}
			else:
				w = {Maneuver.SIDESTEP: 2.5, Maneuver.CIRCLE: 1.5, Maneuver.DASH: 1.5 + h * 2.0,
					Maneuver.FEINT: 1.0}
		EnemyData.Movement.STRAFE:
			if dist > pref + 1.5:
				w = {Maneuver.FLANK: 3.0, Maneuver.RUSH: 2.0 + h * 2.0, Maneuver.DASH: 1.0 + h}
			else:
				w = {Maneuver.CIRCLE: 3.0, Maneuver.SIDESTEP: 1.5, Maneuver.DASH: 1.0 + h * 1.5,
					Maneuver.FLANK: 1.0}
		EnemyData.Movement.KITE:
			if dist < pref - 2.5:
				w = {Maneuver.RETREAT: 4.0, Maneuver.SIDESTEP: 2.0}
			elif dist > pref + 2.0:
				# Longe demais: avança para pressionar, sem andar em linha reta.
				w = {Maneuver.FLANK: 3.0, Maneuver.RUSH: 1.5 + h, Maneuver.SIDESTEP: 1.0}
			else:
				w = {Maneuver.CIRCLE: 2.5, Maneuver.SIDESTEP: 2.0, Maneuver.FLANK: 1.0 + h}
	if tactic == Tactic.BACK_OFF:
		# Recuando: abre distância e fica rodeando, mas sem sumir de perto.
		if dist < pref + 3.5:
			w = {Maneuver.RETREAT: 3.0, Maneuver.SIDESTEP: 2.0, Maneuver.CIRCLE: 1.0}
		else:
			w = {Maneuver.CIRCLE: 2.5, Maneuver.SIDESTEP: 2.0, Maneuver.FLANK: 0.8}
	var total := 0.0
	for k in w:
		total += float(w[k])
	var roll := _rng.randf() * total
	for k in w:
		roll -= float(w[k])
		if roll <= 0.0:
			_set_maneuver(int(k))
			return
	_set_maneuver(Maneuver.RUSH)


func _set_maneuver(m: int) -> void:
	_maneuver = m as Maneuver
	var quick := data.movement == EnemyData.Movement.SKITTER
	var t_scale := 0.6 if quick else 1.0
	_maneuver_speed = 1.0
	match _maneuver:
		Maneuver.RUSH:
			_maneuver_left = _rng.randf_range(0.4, 1.1) * t_scale
			_maneuver_speed = _rng.randf_range(1.0, 1.15)
		Maneuver.FLANK:
			_maneuver_left = _rng.randf_range(0.5, 1.2) * t_scale
			_maneuver_angle = deg_to_rad(_rng.randf_range(25.0, 70.0))
			_maneuver_speed = _rng.randf_range(1.0, 1.1)
		Maneuver.DASH:
			_maneuver_left = _rng.randf_range(0.18, 0.35)
			_maneuver_speed = _rng.randf_range(1.6, 2.1)
		Maneuver.FEINT:
			_maneuver_left = _rng.randf_range(0.15, 0.3)
			_next_maneuver = Maneuver.DASH if _rng.randf() < 0.6 else Maneuver.RUSH
		Maneuver.SIDESTEP:
			_maneuver_left = _rng.randf_range(0.15, 0.35)
			_maneuver_speed = _rng.randf_range(1.2, 1.5)
		Maneuver.CIRCLE:
			_maneuver_left = _rng.randf_range(0.5, 1.3)
			_maneuver_speed = _rng.randf_range(0.6, 0.9)
		Maneuver.RETREAT:
			_maneuver_left = _rng.randf_range(0.35, 0.7)


# ---------- tática: pressionar, recuar, esquivar ----------

## 0 para inimigos comuns; para o chefe, cresce de 0 a 1 conforme perde vida.
func _rage() -> float:
	if not is_boss:
		return 0.0
	return clampf(1.0 - float(health.health) / float(maxi(health.max_health, 1)), 0.0, 1.0)


## Ritmo de decisões e recargas: salas mais perigosas e chefe ferido agem mais rápido.
func _haste() -> float:
	return 1.0 + 0.25 * threat + 0.9 * _rage()


func _move_speed() -> float:
	return data.move_speed * _speed_jitter * (_slow_factor if _slow_left > 0.0 else 1.0) * (1.25 if enraged else 1.0) * (1.15 if elite else 1.0) \
		* (1.0 + 0.08 * threat + 0.45 * _rage())


## Quantos ataques emenda antes de pensar em recuar.
func _new_combo() -> int:
	var extra := _rng.randi_range(0, int(round(threat * 2.0)))
	if is_boss:
		extra += int(round(_rage() * 2.0))
	return 1 + extra


## Chance de esquivar quando vê um disparo vindo ou leva um golpe.
func _dodge_chance() -> float:
	var c := 0.06 + 0.3 * threat
	match data.movement:
		EnemyData.Movement.SKITTER:
			c *= 1.3
		EnemyData.Movement.KITE:
			c *= 1.1
		EnemyData.Movement.CHASE:
			c *= 0.75
	if is_boss:
		c = 0.08 + 0.25 * _rage()
	return c


func _update_tactic(delta: float) -> void:
	if tactic != Tactic.BACK_OFF:
		return
	_tactic_left -= delta
	if _tactic_left <= 0.0:
		_set_tactic(Tactic.PRESS)


func _set_tactic(t: Tactic) -> void:
	if t == Tactic.BACK_OFF and _provoked_left > 0.0:
		t = Tactic.PRESS  # provocado não recua
	tactic = t
	_maneuver_left = 0.0
	if t == Tactic.BACK_OFF:
		var rage := _rage()
		_tactic_left = _rng.randf_range(0.8, 1.7) * (1.0 - 0.5 * rage)
		_hunger = 0.0
		_decision = _rng.randf_range(0.3, 0.7)
	else:
		_combo_left = _new_combo()
		_hunger = 0.4 * _aggression  # volta com vontade
		_decision = _rng.randf_range(0.1, 0.35)


## Depois de cada ataque: continua a sequência, ou recua um pouco, ou segue pressionando.
func _after_attack() -> void:
	var quick := 0.6 if enraged else 1.0
	if tactic == Tactic.BACK_OFF:
		_decision = _rng.randf_range(0.5, 1.0) * quick / _haste()
		return
	_combo_left -= 1
	if _combo_left > 0:
		_decision = _rng.randf_range(0.05, 0.2)
		return
	var back_chance := 0.0
	match data.movement:
		EnemyData.Movement.KITE:
			back_chance = 0.6 + 0.3 * threat
		EnemyData.Movement.SKITTER:
			back_chance = 0.3 + 0.4 * threat
		EnemyData.Movement.CHASE:
			back_chance = 0.15 + 0.35 * threat
		EnemyData.Movement.STRAFE:
			back_chance = 0.35
	back_chance *= 0.6 + 0.8 * _caution
	if _rng.randf() < back_chance:
		_set_tactic(Tactic.BACK_OFF)
	else:
		_combo_left = _new_combo()
		_decision = _rng.randf_range(0.2, 0.7) * quick / _haste()


## Levou muito dano em pouco tempo: chance de sair da briga por um instante.
func _react_to_pain() -> void:
	if is_boss or tactic == Tactic.BACK_OFF or state != State.MOVE:
		return
	if _recent_damage < int(health.max_health * 0.3):
		return
	if _rng.randf() < 0.25 + 0.45 * threat * (0.5 + _caution):
		_recent_damage = 0
		_start_dodge(-_dir_to_player())
		_set_tactic(Tactic.BACK_OFF)


## Golpe do herói chegando: chance de sair de lado e não tomar o dano.
func _try_evade(from_direction: Vector3) -> bool:
	if training_dummy:
		return false
	if state != State.MOVE or _dodge_cd > 0.0 or _dodge_left > 0.0:
		return false
	if _rng.randf() >= _dodge_chance() * 0.5:
		return false
	var away := from_direction
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -_dir_to_player()
	var side := Vector3(-away.z, 0, away.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_start_dodge((side + away * 0.6).normalized())
	return true


## Olha os disparos do herói; se um vem na sua direção, talvez saia da frente.
func _watch_shots() -> void:
	if _dodge_cd > 0.0:
		return
	for shot in get_tree().get_nodes_in_group("player_projectiles"):
		var id := shot.get_instance_id()
		if _seen_shots.has(id):
			continue
		var rel: Vector3 = global_position - shot.global_position
		rel.y = 0.0
		var dir: Vector3 = shot.direction
		var along := rel.dot(dir)
		if along <= 0.0 or along > 6.0:
			continue
		var lateral_v := rel - dir * along
		if lateral_v.length() > 1.0:
			continue
		_seen_shots[id] = true
		if _seen_shots.size() > 64:
			_seen_shots.clear()
		if _rng.randf() < _dodge_chance():
			var out := lateral_v.normalized() if lateral_v.length() > 0.05 else Vector3(-dir.z, 0, dir.x)
			_start_dodge(out, false)
			return


func _start_dodge(dir: Vector3, show_text: bool = true) -> void:
	_dodge_dir = dir.normalized()
	_dodge_left = 0.22
	_dodge_cd = _rng.randf_range(1.4, 2.6) * (1.0 - 0.4 * _rage())
	if show_text:
		Fx.float_text(get_parent(), global_position + Vector3(0, 1.8 * data.body_scale, 0), "esquiva", Color("9fd8ff"))


func _dir_to_player() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return Vector3.FORWARD
	var d := _player.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


## Empurra para longe de outros inimigos muito próximos (não se amontoam).
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var d := away.length()
		var min_d := 1.3 * maxf(data.body_scale, 0.8)
		if d > 0.01 and d < min_d:
			push += away.normalized() * (min_d - d) * 3.0
	return push


# ---------- ataques ----------

func _try_attack(dist: float) -> void:
	var hp_frac := float(health.health) / float(maxi(health.max_health, 1))
	var options: Array[EnemyAttack] = []
	var weights: Array[float] = []
	var total := 0.0
	var rage := _rage()
	for a in _attacks:
		if _cooldowns[a] > 0.0 or dist < a.range_min or dist > a.range_max:
			continue
		if hp_frac > a.below_health or threat < a.min_threat:
			continue
		if tactic == Tactic.BACK_OFF and not a.is_spell():
			continue
		var w := float(a.weight)
		if a.is_spell():
			# Recuando, prefere magia; chefe ferido também.
			w *= (1.5 if tactic == Tactic.BACK_OFF else 1.0) * (1.0 + 2.0 * rage)
		options.append(a)
		weights.append(w)
		total += w
	if options.is_empty():
		_decision = 0.15
		return
	var pick := _rng.randf() * total
	for i in options.size():
		pick -= weights[i]
		if pick <= 0.0:
			_start(options[i])
			return
	_start(options[-1])


## from_rally: entrou no ataque chamado por outro do bando (não chama mais ninguém).
func _start(a: EnemyAttack, from_rally: bool = false) -> void:
	# Encharcado no chão escorregadio / coberto de espuma: às vezes escorrega e perde o ataque.
	var miss := miss_chance()
	if miss > 0.0 and a.kind != EnemyAttack.Kind.MEGA and _rng.randf() < miss:
		_cooldowns[a] = a.cooldown * 0.5
		Fx.float_text(get_parent(), global_position + Vector3(0, 2.0 * data.body_scale, 0), "escorregou!", Color("8fd3ff"))
		state = State.RECOVER
		_timer = 0.6
		return
	if a.rally_radius > 0.0 and not from_rally:
		for other in get_tree().get_nodes_in_group("enemies"):
			if other == self or not (other is Enemy) or other.data.id != data.id:
				continue
			if other.state == State.MOVE and other._awake and other.global_position.distance_to(global_position) <= a.rally_radius:
				other._join_rally(a)
	_attack = a
	_hunger = 0.0
	state = State.WINDUP
	var haste := (0.8 if enraged else 1.0) * (1.0 - 0.15 * _rage())
	_timer = a.windup * haste
	_cooldowns[a] = a.cooldown * (0.7 if enraged else 1.0)
	_dodge_left = 0.0

	# Mira: onde o herói está, com uma leve antecipação para disparos.
	var target := _player.global_position
	if a.kind in [EnemyAttack.Kind.PROJECTILE, EnemyAttack.Kind.FAN, EnemyAttack.Kind.GROUND_AOE]:
		target += Vector3(_player.velocity.x, 0, _player.velocity.z) * _rng.randf_range(0.0, 0.35)
	_aim_dir = target - global_position
	_aim_dir.y = 0.0
	_aim_dir = _aim_dir.normalized() if _aim_dir.length() > 0.01 else Vector3.FORWARD

	_glow(true)
	if is_boss and a.effect == EnemyAttack.Effect.FEAR:
		announced.emit(self, "%s: %s! Saia de perto!" % [data.display_name, a.display_name])
	match a.kind:
		EnemyAttack.Kind.MELEE:
			var melee := Telegraph.for_attack(a, global_position, _aim_dir, damage_multiplier)
			melee.blockable = true  # garra/mordida/grito saem dele: obstáculo no meio protege
			if a.heal_percent_max_health > 0.0:
				melee.resolved.connect(_on_feeding_hit.bind(a))
			_spawn_telegraph(melee, haste)
		EnemyAttack.Kind.CHARGE:
			var t := Telegraph.for_attack(a, global_position, _aim_dir, damage_multiplier)
			t.visual_only = true
			_spawn_telegraph(t, haste)
		EnemyAttack.Kind.PROJECTILE, EnemyAttack.Kind.FAN:
			var aim := Telegraph.new()
			aim.shape = Telegraph.Shape.LINE
			aim.length = 5.0
			aim.width = 0.35 if a.kind == EnemyAttack.Kind.PROJECTILE else 0.35 + a.count * 0.25
			aim.color = a.color
			aim.visual_only = true
			aim.position = Vector3(global_position.x, 0.04, global_position.z)
			aim.rotation.y = atan2(_aim_dir.x, _aim_dir.z)
			_spawn_telegraph(aim, haste, a.windup)
		EnemyAttack.Kind.NOVA, EnemyAttack.Kind.SUMMON:
			var ring := Telegraph.new()
			ring.shape = Telegraph.Shape.CIRCLE
			ring.radius = 2.2 * data.body_scale
			ring.color = a.color
			ring.visual_only = true
			ring.position = Vector3(global_position.x, 0.04, global_position.z)
			_spawn_telegraph(ring, haste, a.windup)
		EnemyAttack.Kind.GROUND_AOE:
			for i in a.count:
				var spot := target if i == 0 else target + Vector3(_rng.randf_range(-3.5, 3.5), 0, _rng.randf_range(-3.5, 3.5))
				_spawn_telegraph(Telegraph.for_attack(a, spot, Vector3.FORWARD, damage_multiplier), haste)
		EnemyAttack.Kind.MEGA:
			_start_mega(a)


## Provocar (tanque): vem para cima do herói sem recuar, aparece se estava escondido e bate mais fraco.
## Chefe: metade do tempo.
## damage_factor: quanto do dano ele mantém enquanto provocado (Voz da Tribo baixa isso).
func provoke(seconds: float, damage_factor := PROVOKE_DAMAGE) -> void:
	if state == State.DEAD:
		return
	if is_boss:
		seconds *= 0.5
	if _provoked_left > 0.0:
		damage_multiplier /= _provoke_factor
	_provoke_factor = damage_factor
	damage_multiplier *= _provoke_factor
	_provoked_left = seconds
	_recent_timer = maxf(_recent_timer, seconds)  # a onça sai da camuflagem
	if not _awake:
		_wake()
	if tactic == Tactic.BACK_OFF:
		_set_tactic(Tactic.PRESS)
	Vfx.provoked_mark(self, seconds, 2.3 * data.body_scale)


func is_provoked() -> bool:
	return _provoked_left > 0.0


## Golpe da Sucuri: segura o inimigo no lugar por alguns segundos (chefe: bem menos).
## Não interrompe um ataque já avisado no chão.
func constrict(seconds: float, label := "apertado") -> void:
	if state == State.DEAD or _constrict_immune > 0.0:
		return
	if is_boss:
		seconds *= 0.3
	_constrict_left = seconds
	_constrict_immune = seconds + 2.0
	Fx.float_text(get_parent(), global_position + Vector3(0, 2.0 * data.body_scale, 0), label, Color("9fd86b"))


## Atordoado (Terceiro Golpe): não anda nem decide atacar. Chefe: bem menos.
## Não interrompe um ataque já avisado no chão.
func stun(seconds: float) -> void:
	if state == State.DEAD:
		return
	if is_boss:
		seconds *= 0.3
	if _stun_left <= 0.0:
		Fx.float_text(get_parent(), global_position + Vector3(0, 2.0 * data.body_scale, 0), "atordoado", Color("ffd34d"))
	_stun_left = maxf(_stun_left, seconds)


## Congelado (Gelo de Rio): como atordoado, mas fica azul-gelo. Chefe: bem menos.
func freeze(seconds: float) -> void:
	if state == State.DEAD:
		return
	if is_boss:
		seconds *= 0.3
	_stun_left = maxf(_stun_left, seconds)
	_frozen_left = maxf(_frozen_left, seconds)
	_material.albedo_color = _tint.lerp(Color("bfe9ff"), 0.7)
	Fx.float_text(get_parent(), global_position + Vector3(0, 2.0 * data.body_scale, 0), "congelado", Color("bfe9ff"))


## Espuma (Encantado): erra `chance` dos ataques por `seconds`.
func foam(chance: float, seconds: float) -> void:
	if state == State.DEAD:
		return
	_foam_chance = maxf(_foam_chance if _foam_left > 0.0 else 0.0, chance)
	_foam_left = maxf(_foam_left, seconds)


## Chance de perder o próximo ataque (espuma, ou escorregar encharcado). Chefe: metade.
func miss_chance() -> float:
	var c := 0.0
	if _foam_left > 0.0:
		c = _foam_chance
	if is_soaked():
		c = maxf(c, slip_chance)
	return c * (0.5 if is_boss else 1.0)


## Assustado (Rugido da Onça): foge do herói. Chefe não foge.
func scare(seconds: float) -> void:
	if state == State.DEAD or is_boss:
		return
	if state == State.WINDUP:
		return  # ataque já avisado no chão não é cancelado
	_fear_left = maxf(_fear_left, seconds)
	Fx.float_text(get_parent(), global_position + Vector3(0, 2.0 * data.body_scale, 0), "assustado", Color("ffd34d"))


func is_scared() -> bool:
	return _fear_left > 0.0


## Atraído (Cópia Teimosa): vai até `target` em vez do herói. Chefe ignora.
func lure(target: Node3D, seconds: float) -> void:
	if state == State.DEAD or is_boss or target == null:
		return
	_lure = weakref(target)
	_lure_left = maxf(_lure_left, seconds)


func is_lured() -> bool:
	return _lure_left > 0.0 and _lure != null and is_instance_valid(_lure.get_ref())


## Enfeitiçado (Encanto do Boto): ataca os outros inimigos por `seconds`. Chefe ignora.
func charm(seconds: float) -> void:
	if state == State.DEAD or is_boss:
		return
	if _charm_left <= 0.0:
		Fx.float_text(get_parent(), global_position + Vector3(0, 2.0 * data.body_scale, 0), "enfeitiçado", Color("f2a7c3"))
	_charm_left = maxf(_charm_left, seconds)
	_charm_tick = 0.3


func is_charmed() -> bool:
	return _charm_left > 0.0


## Enfeitiçado: corre até o inimigo mais perto e morde (dano do ataque mais forte dele).
func _charmed_step(delta: float) -> void:
	var best: Node3D = null
	var best_d := 12.0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Enemy) or other.state == State.DEAD:
			continue
		var d: float = other.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = other
	if best == null:
		_set_horizontal(Vector3.ZERO)
		return
	var to: Vector3 = best.global_position - global_position
	to.y = 0.0
	_face(to, delta)
	if to.length() > 1.4 + 0.4 * data.body_scale:
		_set_horizontal(to.normalized() * _move_speed())
		return
	_set_horizontal(Vector3.ZERO)
	_charm_tick -= delta
	if _charm_tick <= 0.0:
		_charm_tick = 0.9
		var dmg := 10
		for a in _attacks:
			dmg = maxi(dmg, a.damage)
		best.take_hit(maxi(int(round(dmg * maxf(damage_multiplier, 1.0))), 1), false, to)
		Vfx.particles(get_parent(), best.global_position + Vector3(0, 1.0, 0), "faisca", 8, 0.4, Color("f2a7c3"), 0.25, Vector2(1.0, 2.5), 120.0, -3.0)


## Lento (Chão Tremido): factor = fração da velocidade que sobra.
func slow(factor: float, seconds: float) -> void:
	if state == State.DEAD:
		return
	_slow_factor = minf(factor, _slow_factor) if _slow_left > 0.0 else factor
	_slow_left = maxf(_slow_left, seconds)


## Veneno (Espinhos, Timbó): dano por segundo; reaplicar fica com o mais forte e renova.
func poison(dps: float, seconds: float) -> void:
	if state == State.DEAD or dps <= 0.0:
		return
	_poison_dps = maxf(_poison_dps, dps) if _poison_left > 0.0 else dps
	_poison_left = maxf(_poison_left, seconds)


func _tick_poison(delta: float) -> void:
	if _poison_left <= 0.0:
		return
	_poison_left -= delta
	_poison_acc += _poison_dps * delta
	_poison_tick -= delta
	if _poison_tick > 0.0 and _poison_left > 0.0:
		return
	_poison_tick = 0.5  # o número aparece a cada meio segundo
	var amount := int(_poison_acc)
	if amount <= 0:
		return
	_poison_acc -= amount
	amount = maxi(int(round(amount * (1.0 + damage_taken_bonus()))), 1)
	health.take_damage(amount, false, true)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 1.7 * data.body_scale, 0), amount, false, Color("8be06b"))


## Marca que aumenta o dano recebido por um tempo (Presa Marcada). Mesmo nome: renova.
func mark(mark_name: String, bonus: float, seconds: float) -> void:
	if state == State.DEAD:
		return
	_marks[mark_name] = [bonus, seconds]


func damage_taken_bonus() -> float:
	var total := provoked_vulnerability if _provoked_left > 0.0 else 0.0
	for m in _marks:
		total += float(_marks[m][0])
	return total


## Empurrão (ou puxão, com a direção para o herói): anda `distance` metros e para.
func push(dir: Vector3, distance: float) -> void:
	if state == State.DEAD or is_boss:
		return
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_knockback = dir.normalized() * sqrt(60.0 * maxf(distance, 0.0))


## Encharcado pelo Encantado (Encharcar): pinga água por alguns segundos.
func soak(seconds: float) -> void:
	if state == State.DEAD:
		return
	_soaked_left = maxf(_soaked_left, seconds)
	if not is_instance_valid(_drip):
		_drip = Vfx.particles(self, Vector3(0, 1.2 * data.body_scale, 0), "faisca", 8, 0.6, Color(0.45, 0.75, 1.0, 0.9),
			0.18, Vector2(0.2, 0.6), 30.0, -6.0, false, false)


func is_soaked() -> bool:
	return _soaked_left > 0.0


## Pororoca: empurra com força; se bater na parede no caminho, leva `damage` (dobro se encharcado).
func hurl(dir: Vector3, distance: float, damage: int, on_slam := Callable()) -> void:
	if state == State.DEAD:
		return
	_slam_damage = damage
	_on_slam = on_slam
	_slam_left = 1.0
	if is_boss:
		return
	dir.y = 0.0
	if dir.length() > 0.01:
		_knockback = dir.normalized() * sqrt(60.0 * maxf(distance, 0.0))


## Bateu em parede, pilar ou pedra neste quadro (colisão de lado, não o chão)?
func _hit_obstacle() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if absf(c.get_normal().y) < 0.5 and c.get_collider() is StaticBody3D:
			return true
	return false


func _slam() -> void:
	_slam_left = 0.0
	if _on_slam.is_valid():
		_on_slam.call(self)
		_on_slam = Callable()
	var amount := _slam_damage * (2 if is_soaked() else 1)
	_knockback = Vector3.ZERO
	take_hit(amount, is_soaked(), Vector3.ZERO)
	Fx.float_text(get_parent(), global_position + Vector3(0, 2.2 * data.body_scale, 0), "PAREDE!", Color("4db8ff"))
	Vfx.particles(get_parent(), global_position + Vector3(0, 0.8, 0), "faisca", 14, 0.5, Color(0.6, 0.85, 1.0), 0.4, Vector2(2.0, 4.0), 180.0, -4.0)


func is_constricted() -> bool:
	return _constrict_left > 0.0


## Chamado por outro do bando: ataca junto, com um tiquinho de atraso para não sair igual.
func _join_rally(a: EnemyAttack) -> void:
	var mine: EnemyAttack = null
	for own in _attacks:
		if own.id == a.id:
			mine = own
	if mine == null:
		return
	var delay := _rng.randf_range(0.05, 0.35)
	state = State.RECOVER
	_attack = mine
	_timer = delay + 1.0  # o temporizador abaixo é quem dispara
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if state == State.RECOVER and _attack == mine and is_instance_valid(_player):
			_start(mine, true))


## Mordida que alimenta: recupera vida quando acerta (boca na barriga do Mapinguari).
func _on_feeding_hit(hit: bool, a: EnemyAttack) -> void:
	if not hit or state == State.DEAD:
		return
	var amount := int(round(health.max_health * a.heal_percent_max_health))
	health.heal(amount)
	Fx.float_text(get_parent(), global_position + Vector3(0, 2.4 * data.body_scale, 0), "+%d" % amount, Color("6fdc7b"))


func _wake() -> void:
	_awake = true
	_decision = _rng.randf_range(0.05, 0.25)


## Onça: quase invisível de longe; aparece perto, ao atacar ou ao apanhar.
## Cobra de tocaia: meio apagada até acordar.
func _update_camouflage(delta: float, dist: float) -> void:
	if not data.stalker and data.ambush_range <= 0.0:
		return
	var target := 1.0
	if data.stalker and state == State.MOVE and dist > 4.5 and _recent_timer <= 0.0:
		target = 0.15
	elif not _awake:
		target = 0.5
	_alpha = move_toward(_alpha, target, delta * 2.5)
	for mat: StandardMaterial3D in [_material, _eye_material]:
		var c := mat.albedo_color
		c.a = _alpha if mat == _material else maxf(_alpha, 0.6)
		mat.albedo_color = c


func _start_mega(a: EnemyAttack) -> void:
	# O chefe salta para o centro da sala e fica imune enquanto canaliza.
	var center := global_position
	if home_room and is_instance_valid(home_room):
		center = home_room.global_position
	global_position = Vector3(center.x, global_position.y, center.z)
	health.untouchable = true
	var t := Telegraph.for_attack(a, center, Vector3.FORWARD, damage_multiplier)
	var zones: Array[Vector3] = []
	for i in maxi(a.count, 1):
		var p := center
		for attempt in 20:
			var angle := _rng.randf_range(0.0, TAU)
			var dist := _rng.randf_range(3.5, a.radius - 2.0)
			p = center + Vector3(cos(angle), 0, sin(angle)) * dist
			var far_enough := true
			for z in zones:
				if z.distance_to(p) < 4.0:
					far_enough = false
			# Zona segura nunca em cima de pilar nem fora da sala.
			if home_room and is_instance_valid(home_room):
				if not home_room.contains(p):
					far_enough = false
				for pillar in home_room.pillars:
					if Vector2(p.x - (center.x + pillar.x), p.z - (center.z + pillar.z)).length() < 2.6:
						far_enough = false
			if far_enough:
				break
		zones.append(p)
	t.safe_zones = zones
	_spawn_telegraph(t, 1.0)
	announced.emit(self, "%s: %s! Corra para a zona segura verde!" % [data.display_name, a.display_name])


func _execute() -> void:
	var a := _attack
	_glow(false)
	if a.exposes_weak_spot > 0.0:
		_exposed_left = a.exposes_weak_spot
		if _mouth_material:
			_mouth_material.emission_enabled = true
		Fx.float_text(get_parent(), global_position + Vector3(0, 2.6 * data.body_scale, 0), "BARRIGA EXPOSTA!", Color("ff8a3d"))
	match a.kind:
		EnemyAttack.Kind.CHARGE:
			state = State.CHARGING
			_charge_left = a.length
			_charge_hit = false
			return
		EnemyAttack.Kind.PROJECTILE:
			_fire(a, _aim_dir)
		EnemyAttack.Kind.FAN:
			var n := maxi(a.count, 1)
			for i in n:
				var offset := 0.0 if n == 1 else lerpf(-a.spread_deg, a.spread_deg, float(i) / (n - 1))
				_fire(a, _aim_dir.rotated(Vector3.UP, deg_to_rad(offset)))
		EnemyAttack.Kind.NOVA:
			var start := _rng.randf_range(0.0, TAU)
			for i in a.count:
				var angle := start + TAU * i / a.count
				_fire(a, Vector3(sin(angle), 0, cos(angle)))
		EnemyAttack.Kind.SUMMON:
			summon_requested.emit(self, a.summon_id, a.count, global_position)
			announced.emit(self, "%s: %s!" % [data.display_name, a.display_name])
		EnemyAttack.Kind.MEGA:
			health.untouchable = false
	_enter_recover()


func _enter_recover() -> void:
	state = State.RECOVER
	_timer = _attack.recover * (0.7 if enraged else 1.0) if _attack else 0.5
	# No meio de uma sequência, a pausa é menor: o próximo golpe vem logo.
	if tactic == Tactic.PRESS and _combo_left > 1:
		_timer *= 0.55


func _fire(a: EnemyAttack, dir: Vector3) -> void:
	var at := global_position + Vector3(0, 0.9, 0) + dir.normalized() * (0.6 * data.body_scale)
	if Layers.shot_blocked(get_world_3d(), global_position, at):
		Vfx.particles(get_parent(), at, "faisca", 6, 0.25, Color(1, 1, 1, 0.6), 0.2, Vector2(0.5, 1.5), 180.0, -4.0)
		return
	var p := EnemyProjectile.create(a, dir, damage_multiplier)
	get_parent().add_child(p)
	p.global_position = at


func _spawn_telegraph(t: Telegraph, haste: float, visual_duration: float = -1.0) -> void:
	if visual_duration > 0.0:
		t.duration = visual_duration
	t.duration *= haste
	get_parent().add_child(t)
	_own_telegraphs.append(t)


func _fallback_attack() -> EnemyAttack:
	var a := EnemyAttack.new()
	a.id = &"golpe"
	a.kind = EnemyAttack.Kind.MELEE
	a.range_max = data.attack_range + 0.3
	a.radius = data.attack_range + 0.3
	a.windup = data.windup_time
	a.recover = data.recover_time
	a.cooldown = data.windup_time + data.recover_time
	a.damage = data.damage
	return a


# ---------- vida e morte ----------

func _on_health_changed(hp: int, max_hp: int, _a: int, _b: int) -> void:
	if is_boss and not enraged and hp > 0 and float(hp) / max_hp <= ENRAGE_AT:
		enraged = true
		_tint = data.color.lerp(Color("e05555"), 0.45)
		_material.albedo_color = _tint
		announced.emit(self, "%s está enfurecido!" % data.display_name)


func _on_died() -> void:
	state = State.DEAD
	health.untouchable = false
	remove_from_group("enemies")
	collision_layer = 0
	for t in _own_telegraphs:
		# Avisos que ainda não aconteceram somem com quem os lançou (poças já feitas ficam).
		if is_instance_valid(t) and (t.is_pending() or t.visual_only):
			t.queue_free()
	if not is_summon:
		_drop_loot()
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 0.18)
	tween.tween_callback(queue_free)


func _drop_loot() -> void:
	var table := ItemDB.get_drop_table(data.drop_table_id)
	if table == null:
		return
	# Furioso deixa o dobro (sorteia a tabela duas vezes).
	for i in (2 if elite else 1):
		for drop in LootRoller.roll(table, ItemDB.catalog, _rng, loot_context):
			var pickup := LootPickup.create(drop.item, drop.qty, drop.instance)
			get_parent().add_child(pickup)
			var offset := Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.8, 0.8))
			pickup.global_position = global_position + offset + Vector3(0, 0.4, 0)


# ---------- auxiliares ----------

func _set_horizontal(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)


func _glow(on: bool) -> void:
	_material.emission_enabled = on
	if on and _attack:
		_material.emission = _attack.color
		_material.emission_energy_multiplier = 0.8


# ---------- visual provisório (vira modelo 3D na etapa de arte) ----------

func _build_visuals() -> void:
	var s := data.body_scale
	var col := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4 * s
	capsule_shape.height = 1.4 * s
	col.shape = capsule_shape
	col.position.y = 0.7 * s
	add_child(col)

	_body = Node3D.new()
	add_child(_body)
	_material = StandardMaterial3D.new()
	_material.albedo_color = _tint
	_material.roughness = 0.9
	if data.stalker or data.ambush_range > 0.0:
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	mesh.material_override = _material
	_body.add_child(mesh)

	# Onde ficam os olhos: na frente da cabeça (em pé) ou na ponta do corpo (deitado).
	var eye_y := 1.05 * s
	var eye_z := 0.36 * s
	if data.quadruped:
		capsule.radius = 0.32 * s
		capsule.height = 1.5 * s
		mesh.rotation_degrees.x = 90.0
		mesh.position = Vector3(0, 0.35 * s, 0)
		eye_y = 0.48 * s
		eye_z = 0.72 * s
	else:
		capsule.radius = 0.4 * s
		capsule.height = 1.4 * s
		mesh.position.y = 0.7 * s
	mesh.mesh = capsule

	_eye_material = StandardMaterial3D.new()
	_eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_material.albedo_color = Color("ffe08a") if not is_boss else Color("ff4d4d")
	if data.stalker or data.ambush_range > 0.0:
		_eye_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var n := data.eye_count
	for i in n:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07 * s if n > 2 else 0.09 * s
		sphere.height = sphere.radius * 2.0
		eye.mesh = sphere
		# Em arco na testa: o do meio mais alto.
		var t := 0.0 if n == 1 else lerpf(-1.0, 1.0, float(i) / (n - 1))
		var body_r := (0.32 if data.quadruped else 0.4) * s
		var spread := minf(0.11 * s * (n - 1), body_r * 0.75) * 0.5
		eye.position = Vector3(t * spread, eye_y + (1.0 - absf(t)) * 0.06 * s, eye_z - absf(t) * 0.05 * s)
		eye.material_override = _eye_material
		_body.add_child(eye)

	if data.spotted:
		# Rosetas da onça.
		var spot_mat := StandardMaterial3D.new()
		spot_mat.albedo_color = Color("2a1d12")
		var spot_rng := RandomNumberGenerator.new()
		spot_rng.seed = 77
		for i in 14:
			var sp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.07 * s
			sm.height = 0.05 * s
			sp.mesh = sm
			var z := spot_rng.randf_range(-0.6, 0.5) * s
			var ang := spot_rng.randf_range(-1.2, 1.2)
			sp.position = Vector3(sin(ang) * 0.31 * s, 0.35 * s + cos(ang) * 0.31 * s, z)
			sp.material_override = spot_mat
			_body.add_child(sp)

	if data.belly_mouth:
		# Boca na barriga, com dentes.
		var mouth := MeshInstance3D.new()
		var mb := BoxMesh.new()
		mb.size = Vector3(0.42, 0.22, 0.08) * s
		mouth.mesh = mb
		mouth.position = Vector3(0, 0.62 * s, 0.38 * s)
		_mouth_material = StandardMaterial3D.new()
		_mouth_material.albedo_color = Color("5a0f12")
		_mouth_material.emission = Color("ff6a2a")
		_mouth_material.emission_energy_multiplier = 1.6
		mouth.material_override = _mouth_material
		_body.add_child(mouth)
		var tooth_mat := StandardMaterial3D.new()
		tooth_mat.albedo_color = Color("f2ecdc")
		for i in 5:
			for row in [1.0, -1.0]:
				var tooth := MeshInstance3D.new()
				var tb := BoxMesh.new()
				tb.size = Vector3(0.05, 0.06, 0.05) * s
				tooth.mesh = tb
				tooth.position = Vector3(lerpf(-0.16, 0.16, i / 4.0) * s, (0.62 + row * 0.08) * s, 0.42 * s)
				tooth.material_override = tooth_mat
				_body.add_child(tooth)


## Marcas do furioso: corpo maior, anel vermelho no chão e o nome em cima.
func _add_elite_marks() -> void:
	var s := data.body_scale
	_body.scale = Vector3.ONE * 1.2
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55 * s
	torus.outer_radius = 0.7 * s
	ring.mesh = torus
	ring.position.y = 0.05
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color("ff3b3b")
	ring.material_override = ring_mat
	add_child(ring)
	var label := Label3D.new()
	label.text = "Furioso"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 60
	label.outline_size = 14
	label.modulate = Color("ff6b6b")
	label.pixel_size = 0.006
	label.position.y = 2.0 * s + 0.3
	add_child(label)
