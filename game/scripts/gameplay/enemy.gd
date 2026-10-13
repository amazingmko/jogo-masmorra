class_name Enemy
extends CharacterBody3D
## Inimigo com movimento próprio e vários ataques (definidos no EnemyData).
## Ciclo: MOVE (anda do seu jeito, decide atacar) → WINDUP (aviso no chão) → ataque → RECOVER → MOVE.
## Chefes usam os mesmos ataques, com fases (EnemyAttack.below_health) e fúria abaixo de 30% de vida.

signal died(enemy: Enemy)
signal summon_requested(enemy: Enemy, summon_id: StringName, count: int, at: Vector3)
signal announced(enemy: Enemy, text: String)

enum State { MOVE, WINDUP, CHARGING, RECOVER, DEAD }
## RUSH: vai direto · FLANK: arco pelo lado · DASH: arrancada curta · FEINT: recua e volta com tudo
## SIDESTEP: pulo lateral · CIRCLE: rodeia · RETREAT: abre distância (atiradores)
enum Maneuver { RUSH, FLANK, DASH, FEINT, SIDESTEP, CIRCLE, RETREAT }

const ENRAGE_AT := 0.3

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
var _own_telegraphs: Array[Telegraph] = []

var _player: Player
var _body: Node3D
var _material: StandardMaterial3D
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
	collision_layer = Layers.ENEMIES
	collision_mask = Layers.WORLD | Layers.ENEMIES
	_rng.randomize()
	_build_visuals()
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


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	for a in _cooldowns:
		_cooldowns[a] -= delta

	var player_alive := _player != null and is_instance_valid(_player) and not _player.health.is_dead
	var to_player := Vector3.ZERO
	if player_alive:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
	var dist := to_player.length()

	match state:
		State.MOVE:
			var v := _movement_velocity(delta, to_player, dist) if player_alive else Vector3.ZERO
			v += _separation()
			_set_horizontal(v)
			if v.length() > 0.2:
				_face(v, delta)
			elif player_alive:
				_face(to_player, delta)
			_decision -= delta
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
			if player_alive and not _charge_hit and dist <= 1.0 + 0.5 * data.body_scale + _attack.radius * 0.3:
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
				_decision = _rng.randf_range(0.2, 0.7) * (0.6 if enraged else 1.0)
				_maneuver_left = 0.0  # sai do ataque já com uma manobra nova

	if state != State.CHARGING:
		velocity += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()


func take_hit(amount: int, crit: bool, from_direction: Vector3) -> void:
	if state == State.DEAD:
		return
	if health.untouchable:
		Fx.damage_number(get_parent(), global_position + Vector3(0, 2.2 * data.body_scale, 0), 0, false, Color("8b5cf6"))
		return
	health.take_damage(amount)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 1.7 * data.body_scale, 0), amount, crit)
	Fx.flash(_material, data.color)
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
	var speed := data.move_speed * _speed_jitter * (1.25 if enraged else 1.0)
	var pref := data.preferred_distance
	# Fome: cresce enquanto não ataca; quanto maior, mais ele parte para cima.
	_hunger = minf(_hunger + delta * 0.35 * _aggression, 1.5)
	# Desvio suave e contínuo (passeio aleatório do ângulo), nunca o mesmo ritmo.
	_wander = clampf(_wander + _rng.randf_range(-1.0, 1.0) * delta * 4.0, -1.0, 1.0)

	_maneuver_left -= delta
	if is_on_wall() and _maneuver != Maneuver.RUSH:
		_maneuver_left = minf(_maneuver_left, 0.05)
		_side = -_side
	if _maneuver_left <= 0.0:
		_pick_maneuver(dist, pref)

	# Mira um pouco à frente de onde o herói está indo.
	var lead_dir := dir_to
	if _player and dist > 1.5:
		var lead := _player.velocity * clampf(dist / maxf(speed * 2.0, 0.1), 0.0, 0.6)
		lead.y = 0.0
		var aimed := to_player + lead
		if aimed.length() > 0.01:
			lead_dir = aimed.normalized()
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
	var total := 0
	for a in _attacks:
		if _cooldowns[a] <= 0.0 and dist >= a.range_min and dist <= a.range_max and hp_frac <= a.below_health:
			options.append(a)
			total += a.weight
	if options.is_empty():
		_decision = 0.15
		return
	var pick := _rng.randi_range(1, total)
	for a in options:
		pick -= a.weight
		if pick <= 0:
			_start(a)
			return


func _start(a: EnemyAttack) -> void:
	_attack = a
	_hunger = 0.0
	state = State.WINDUP
	var haste := 0.8 if enraged else 1.0
	_timer = a.windup * haste
	_cooldowns[a] = a.cooldown * (0.7 if enraged else 1.0)

	# Mira: onde o herói está, com uma leve antecipação para disparos.
	var target := _player.global_position
	if a.kind in [EnemyAttack.Kind.PROJECTILE, EnemyAttack.Kind.FAN, EnemyAttack.Kind.GROUND_AOE]:
		target += Vector3(_player.velocity.x, 0, _player.velocity.z) * _rng.randf_range(0.0, 0.35)
	_aim_dir = target - global_position
	_aim_dir.y = 0.0
	_aim_dir = _aim_dir.normalized() if _aim_dir.length() > 0.01 else Vector3.FORWARD

	_glow(true)
	match a.kind:
		EnemyAttack.Kind.MELEE:
			_spawn_telegraph(Telegraph.for_attack(a, global_position, _aim_dir, damage_multiplier), haste)
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
	announced.emit(self, "%s: %s! Corra para a luz verde!" % [data.display_name, a.display_name])


func _execute() -> void:
	var a := _attack
	_glow(false)
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
		EnemyAttack.Kind.MEGA:
			health.untouchable = false
	_enter_recover()


func _enter_recover() -> void:
	state = State.RECOVER
	_timer = _attack.recover * (0.7 if enraged else 1.0) if _attack else 0.5


func _fire(a: EnemyAttack, dir: Vector3) -> void:
	var p := EnemyProjectile.create(a, dir, damage_multiplier)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 0.9, 0) + dir.normalized() * (0.6 * data.body_scale)


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
		_material.albedo_color = data.color.lerp(Color("e05555"), 0.45)
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
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4 * s
	capsule.height = 1.4 * s
	mesh.mesh = capsule
	mesh.position.y = 0.7 * s
	_material = StandardMaterial3D.new()
	_material.albedo_color = data.color
	_material.roughness = 0.9
	mesh.material_override = _material
	_body.add_child(mesh)

	var eyes := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.12, 0.2) * s
	eyes.mesh = box
	eyes.position = Vector3(0, 1.05 * s, 0.35 * s)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color("ffe08a") if not is_boss else Color("ff4d4d")
	eyes.material_override = eye_mat
	_body.add_child(eyes)

	if is_boss:
		# Coroa simples para o chefe ser reconhecível.
		var crown := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.38 * s
		c.bottom_radius = 0.3 * s
		c.height = 0.25 * s
		crown.mesh = c
		crown.position = Vector3(0, 1.55 * s, 0)
		var crown_mat := StandardMaterial3D.new()
		crown_mat.albedo_color = Color("e8c26a")
		crown_mat.emission_enabled = true
		crown_mat.emission = Color("e8c26a")
		crown_mat.emission_energy_multiplier = 0.5
		crown.material_override = crown_mat
		_body.add_child(crown)
