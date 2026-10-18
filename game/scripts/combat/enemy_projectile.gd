class_name EnemyProjectile
extends Area3D
## Disparo de inimigo: flecha, raio, bola de veneno ou raízes. Some ao bater no herói ou numa parede.

var direction := Vector3.FORWARD
var speed := 12.0
var damage := 10
var effect: int = EnemyAttack.Effect.NONE
var effect_duration := 0.0
var effect_power := 0
var color := Color("e05555")
var max_distance := 18.0
var attack_id: StringName = &""

var _traveled := 0.0
var _spent := false


static func create(attack: EnemyAttack, dir: Vector3, damage_mult: float) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.direction = Vector3(dir.x, 0, dir.z).normalized()
	p.speed = attack.speed
	p.damage = int(round(attack.damage * damage_mult))
	p.effect = attack.effect
	p.effect_duration = attack.effect_duration
	p.effect_power = attack.effect_power
	p.color = attack.color
	p.attack_id = attack.id
	return p


func _ready() -> void:
	add_to_group("enemy_projectiles")
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.PLAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	add_child(shape)

	if direction.length() > 0.01:
		rotation.y = atan2(direction.x, direction.z)
	body_entered.connect(_on_body_entered)
	if MobFx.projectile_visual(self):
		return
	var mesh := MeshInstance3D.new()
	var visual := SphereMesh.new()
	visual.radius = 0.22
	visual.height = 0.44
	mesh.mesh = visual
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material_override = mat
	mesh.scale = Vector3(0.8, 0.8, 1.6)
	add_child(mesh)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	# Pedra, tronco, sumaúma e borda da mata seguram o disparo (raio no caminho deste quadro).
	if not _spent and Layers.blocked(get_world_3d(), global_position, global_position + direction * step):
		_spent = true
		MobFx.projectile_end(get_parent(), global_position, attack_id)
		queue_free()
		return
	global_position += direction * step
	_traveled += step
	if _traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _spent:
		return
	_spent = true
	if body.is_in_group("player"):
		body.receive_attack(damage, effect, effect_duration, effect_power, global_position)
		MobFx.projectile_hit_player(body, attack_id, effect_duration)
	MobFx.projectile_end(get_parent(), global_position, attack_id)
	queue_free()
