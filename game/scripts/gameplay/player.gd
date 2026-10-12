class_name Player
extends CharacterBody3D
## Herói controlado pelo jogador.
## Anda com joystick ou teclado; segurando "atacar", mira sozinho no inimigo mais próximo.

signal hero_changed(hero: HeroData)
signal died

const CLASS_COLORS := {
	GameEnums.HeroClass.TANK: Color("e8c26a"),
	GameEnums.HeroClass.RANGER: Color("7fc97a"),
	GameEnums.HeroClass.MAGE: Color("b483e8"),
}

@export var hero_id: StringName = &"guardiao"
@export var turn_speed: float = 14.0

var hero: HeroData
## Atributos finais (nível + equipamento + bênçãos). Ver HeroStats.
var stats := HeroStats.new()
var weapon_stats := WeaponStats.new()
## Bênçãos escolhidas nesta run (somem ao começar outra).
var buffs: Array[BuffData] = []
var move_speed := 5.0
var crit_chance := 0.05
## Preenchidos pela HUD a cada quadro (joystick e botão de toque).
var touch_move := Vector2.ZERO
var touch_attack := false
var controls_enabled := true
## No hub o herói só anda (sem atacar).
var combat_enabled := true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _attack_cooldown := 0.0
var _facing := Vector3(0, 0, 1)
var _target: Node3D
var _rng := RandomNumberGenerator.new()
var _base_color := Color("e8c26a")
var _material: StandardMaterial3D
var _marker: MeshInstance3D

@onready var health: Health = $Health
@onready var _body: Node3D = $Body
@onready var _mesh: MeshInstance3D = $Body/Mesh


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	_rng.randomize()
	_material = (_mesh.material_override as StandardMaterial3D).duplicate()
	_mesh.material_override = _material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.armor_regen_amount = 10
	_marker = _make_target_marker()
	GameState.hero_progress_changed.connect(_on_progress_changed)
	set_hero(ItemDB.get_hero(GameState.selected_hero))


func set_hero(new_hero: HeroData) -> void:
	if new_hero == null:
		return
	hero = new_hero
	hero_id = new_hero.id
	refresh_stats(true)
	_base_color = CLASS_COLORS.get(new_hero.hero_class, Color.WHITE)
	_material.albedo_color = _base_color
	hero_changed.emit(new_hero)


# ---------- atributos e bênçãos ----------

func apply_buff(buff: BuffData) -> void:
	buffs.append(buff)
	refresh_stats()


func clear_buffs() -> void:
	buffs.clear()
	refresh_stats()


## Recalcula tudo a partir do nível, equipamento e bênçãos. full_heal: começa com vida cheia.
func refresh_stats(full_heal: bool = false) -> void:
	if hero == null:
		return
	stats = GameState.stats_for(hero_id, buffs)
	weapon_stats = stats.weapon
	move_speed = stats.move_speed
	crit_chance = stats.crit_chance
	health.damage_reduction = stats.damage_reduction
	if full_heal:
		health.max_health = stats.max_health
		health.max_armor = stats.max_shield
		health.reset()
	else:
		health.set_maximums(stats.max_health, stats.max_shield)


func _on_progress_changed(changed_hero: StringName) -> void:
	if changed_hero == hero_id:
		refresh_stats()


func revive(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_body.rotation = Vector3.ZERO
	health.reset()
	controls_enabled = true


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = touch_move if touch_move.length() > 0.05 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input.x, 0.0, input.y)
	var speed := move_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	if direction.length() > 0.1:
		_facing = direction.normalized()

	_target = _find_target() if controls_enabled and combat_enabled else null
	_update_marker()

	_attack_cooldown -= delta
	var attacking := controls_enabled and combat_enabled and (touch_attack or Input.is_action_pressed("attack"))
	if attacking:
		if _target:
			var to_target := _target.global_position - global_position
			to_target.y = 0.0
			if to_target.length() > 0.01:
				_facing = to_target.normalized()
		if _attack_cooldown <= 0.0:
			_attack()
			_attack_cooldown = weapon_stats.cooldown()

	if controls_enabled:
		var target_angle := atan2(_facing.x, _facing.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, target_angle, turn_speed * delta)
	move_and_slide()


# ---------- ataque ----------

func _find_target() -> Node3D:
	var best: Node3D = null
	var best_dist := weapon_stats.aim_range()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _attack() -> void:
	if weapon_stats.is_ranged():
		var projectile := Projectile.create(_facing, weapon_stats, hero.element, crit_chance, _rng)
		get_parent().add_child(projectile)
		projectile.global_position = global_position + Vector3(0, 0.9, 0) + _facing * 0.6
	else:
		_melee_swing()


func _melee_swing() -> void:
	var reach := weapon_stats.attack_range
	Fx.slash(get_parent(), global_position, _facing, reach)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		# Acerta quem está no alcance e num cone de ~140° à frente (ou colado no herói).
		if dist <= reach + 0.4 and (dist < 0.6 or _facing.angle_to(to_enemy) <= deg_to_rad(70)):
			var hit := Damage.roll(weapon_stats.damage, hero.element, enemy.data.element, crit_chance, _rng)
			enemy.take_hit(hit.amount, hit.crit, to_enemy)


# ---------- dano ----------

func _on_damaged(amount: int) -> void:
	Fx.flash(_material, _base_color, Color("ff4d4d"))
	Fx.damage_number(get_parent(), global_position + Vector3(0, 2.0, 0), amount, false, Color("ff6b6b"))


func _on_died() -> void:
	controls_enabled = false
	_target = null
	_update_marker()
	var tween := create_tween()
	tween.tween_property(_body, "rotation:x", deg_to_rad(-90), 0.3)
	died.emit()


# ---------- marcador de alvo ----------

func _make_target_marker() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.7
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ff4d4d")
	ring.material_override = mat
	ring.visible = false
	ring.top_level = true
	add_child(ring)
	return ring


func _update_marker() -> void:
	if _marker == null:
		return
	_marker.visible = _target != null
	if _target:
		_marker.global_position = _target.global_position + Vector3(0, 0.05, 0)
