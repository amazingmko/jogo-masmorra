class_name Enemy
extends CharacterBody3D
## Inimigo corpo a corpo: persegue o herói, avisa antes de golpear (círculo vermelho no chão)
## e deixa loot ao morrer. Os números vêm do EnemyData.

signal died(enemy: Enemy)

enum State { CHASE, WINDUP, RECOVER, DEAD }

var data: EnemyData
## Multiplicador de vida (andares mais fundos têm inimigos mais resistentes).
var health_multiplier := 1.0
var is_boss := false
var health: Health
var state: State = State.CHASE

var _timer := 0.0
var _player: Player
var _body: Node3D
var _material: StandardMaterial3D
var _telegraph: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
var _knockback := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _rng := RandomNumberGenerator.new()


static func create(enemy_data: EnemyData, hp_multiplier: float = 1.0) -> Enemy:
	var e := Enemy.new()
	e.data = enemy_data
	e.health_multiplier = hp_multiplier
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
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	var to_player := Vector3.ZERO
	var player_alive := _player != null and not _player.health.is_dead
	if player_alive:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
	var dist := to_player.length()

	match state:
		State.CHASE:
			if player_alive and dist <= data.attack_range:
				_start_windup()
				_set_horizontal(Vector3.ZERO)
			elif player_alive:
				_set_horizontal(to_player.normalized() * data.move_speed)
			else:
				_set_horizontal(Vector3.ZERO)
		State.WINDUP:
			_set_horizontal(Vector3.ZERO)
			_timer -= delta
			var progress := 1.0 - clampf(_timer / data.windup_time, 0.0, 1.0)
			_telegraph.scale = Vector3.ONE * lerpf(0.3, 1.0, progress)
			_telegraph_mat.albedo_color.a = lerpf(0.15, 0.55, progress)
			if _timer <= 0.0:
				_strike(dist, player_alive)
		State.RECOVER:
			_set_horizontal(Vector3.ZERO)
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE

	if player_alive and state != State.RECOVER and dist > 0.01:
		var angle := atan2(to_player.x, to_player.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, angle, 10.0 * delta)

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()


func take_hit(amount: int, crit: bool, from_direction: Vector3) -> void:
	if state == State.DEAD:
		return
	health.take_damage(amount)
	Fx.damage_number(get_parent(), global_position + Vector3(0, 1.7 * data.body_scale, 0), amount, crit)
	Fx.flash(_material, data.color)
	var push := from_direction
	push.y = 0.0
	if push.length() > 0.01:
		_knockback = push.normalized() * (3.0 / data.body_scale)


# ---------- estados ----------

func _start_windup() -> void:
	state = State.WINDUP
	_timer = data.windup_time
	_telegraph.visible = true


func _strike(dist: float, player_alive: bool) -> void:
	_telegraph.visible = false
	if player_alive and dist <= data.attack_range + 0.5:
		_player.health.take_damage(data.damage)
	state = State.RECOVER
	_timer = data.recover_time


func _set_horizontal(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


func _on_died() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	_telegraph.visible = false
	_drop_loot()
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 0.18)
	tween.tween_callback(queue_free)


func _drop_loot() -> void:
	var table := ItemDB.get_drop_table(data.drop_table_id)
	if table == null:
		return
	for drop in table.roll(_rng):
		var pickup := LootPickup.create(ItemDB.get_item(drop.item_id), drop.qty)
		get_parent().add_child(pickup)
		var offset := Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.8, 0.8))
		pickup.global_position = global_position + offset + Vector3(0, 0.4, 0)


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
	eye_mat.albedo_color = Color("ffe08a")
	eyes.material_override = eye_mat
	_body.add_child(eyes)

	_telegraph = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = data.attack_range + 0.3
	disc.bottom_radius = data.attack_range + 0.3
	disc.height = 0.02
	_telegraph.mesh = disc
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.albedo_color = Color(1, 0.2, 0.2, 0.15)
	_telegraph.material_override = _telegraph_mat
	_telegraph.position.y = 0.03
	_telegraph.visible = false
	add_child(_telegraph)
