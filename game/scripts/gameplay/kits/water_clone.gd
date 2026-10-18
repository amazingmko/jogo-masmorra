class_name WaterClone
extends Node3D
## Espelho do Rio (Encantado): cópia de água deixada para trás. Quando um inimigo encosta,
## explode em água: dano em volta e encharca quem pegou. Some sozinha depois de um tempo.

const LIFETIME := 6.0
const TRIGGER := 1.4
const RADIUS := 3.0

var owner_player: Player
var damage := 50
var soak_time := 4.0
var lifetime := LIFETIME
var radius := RADIUS
var foam_chance := 0.0    # Espuma: quem pega a explosão erra ataques
var slip_chance := 0.0
var _left := LIFETIME
var _body: MeshInstance3D


func _ready() -> void:
	add_to_group("floor_effects")
	_left = lifetime
	_body = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	_body.mesh = capsule
	_body.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.7, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.3
	mat.roughness = 0.2
	_body.material_override = mat
	add_child(_body)
	Vfx.particles(self, Vector3(0, 0.9, 0), "faisca", 6, 0.8, Color(0.5, 0.8, 1.0, 0.8), 0.2, Vector2(0.1, 0.4), 180.0, -1.0, true, false)


func _physics_process(delta: float) -> void:
	_left -= delta
	_body.position.y = 0.85 + sin(_left * 4.0) * 0.05
	if _left <= 0.0:
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() <= TRIGGER:
			_explode()
			return


## Explode agora (Iara: o Encantado voltou para cá).
func burst() -> void:
	if is_physics_processing():
		_explode()


func _explode() -> void:
	set_physics_process(false)
	var kit: MageKit = owner_player.kit as MageKit if is_instance_valid(owner_player) else null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() <= radius and Layers.clear_path(get_world_3d(), global_position, enemy.global_position):
			if kit:
				kit.soak_enemy(enemy)
			elif enemy.has_method("soak"):
				enemy.soak(soak_time)
			enemy.take_hit(damage, false, to)
			if foam_chance > 0.0 and enemy.has_method("foam"):
				enemy.foam(foam_chance, 3.0)
	Vfx.particles(get_parent(), global_position + Vector3(0, 0.6, 0), "faisca", 26, 0.6, Color(0.5, 0.8, 1.0), 0.45, Vector2(3.0, 6.0), 180.0, -9.0)
	Vfx.ground_ring(get_parent(), global_position, "onda_choque", Color(0.4, 0.75, 1.0), radius * 2.0, 0.4)
	queue_free()


## Cópia Atiradora: dispara uma bolinha d'água no inimigo mais perto.
func shoot(dmg: int, on_hit: Callable) -> void:
	if not is_physics_processing():
		return
	var best: Node3D = null
	var best_d := 9.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: float = enemy.global_position.distance_to(global_position)
		if d < best_d and not enemy.health.is_dead:
			best_d = d
			best = enemy
	if best == null or not is_instance_valid(owner_player):
		return
	var to := best.global_position - global_position
	to.y = 0.0
	var stats := WeaponStats.new()
	stats.damage = dmg
	stats.projectile_speed = owner_player.weapon_stats.projectile_speed
	stats.attack_range = 10.0
	var p := Projectile.create(to.normalized(), stats, GameEnums.Element.WATER, 0.0, RandomNumberGenerator.new())
	p.on_hit = on_hit
	get_parent().add_child(p)
	var at := global_position + Vector3(0, 1.0, 0) + to.normalized() * 0.4
	p.global_position = at
	p.origin = at
