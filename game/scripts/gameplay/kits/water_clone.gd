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
var _left := LIFETIME
var _body: MeshInstance3D


func _ready() -> void:
	add_to_group("floor_effects")
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


func _explode() -> void:
	set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() <= RADIUS and Layers.clear_path(get_world_3d(), global_position, enemy.global_position):
			enemy.take_hit(damage, false, to)
			if enemy.has_method("soak"):
				enemy.soak(soak_time)
	Vfx.particles(get_parent(), global_position + Vector3(0, 0.6, 0), "faisca", 26, 0.6, Color(0.5, 0.8, 1.0), 0.45, Vector2(3.0, 6.0), 180.0, -9.0)
	Vfx.ground_ring(get_parent(), global_position, "onda_choque", Color(0.4, 0.75, 1.0), RADIUS * 2.0, 0.4)
	queue_free()
