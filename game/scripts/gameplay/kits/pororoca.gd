class_name Pororoca
extends Node3D
## Pororoca (ultimate do Encantado): uma onda larga que atravessa a sala na direção em que ele
## mira. Quem a onda pega leva dano e é arremessado para a frente; se bater na parede, leva
## mais dano (o dobro se estiver encharcado). Ver Enemy.hurl.

const SPEED := 11.0
const LENGTH := 16.0
const WIDTH := 7.0
const THROW := 8.0

var direction := Vector3.FORWARD
var damage := 60
var slam_damage := 80
var width := WIDTH
var throw := THROW
## Ressaca: fração do dano da onda que volta depois (0 = não volta).
var backwash := 0.0
var on_slam := Callable()
var returning := false
var _traveled := 0.0
var _hit := {}
var _wave: MeshInstance3D


func _ready() -> void:
	add_to_group("floor_effects")
	direction.y = 0.0
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	look_at(global_position + direction, Vector3.UP)
	_wave = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 1.6 if not returning else 1.1, 0.9)
	_wave.mesh = box
	_wave.position.y = 0.6
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.6, 0.95, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.55, 1.0)
	mat.emission_energy_multiplier = 0.25
	mat.roughness = 0.15
	_wave.material_override = mat
	add_child(_wave)
	var foam := Vfx.particles(self, Vector3(0, 1.3, 0), "faisca", 30, 0.5, Color(0.85, 0.95, 1.0), 0.35, Vector2(1.0, 2.5), 60.0, -6.0, true, false)
	foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	foam.emission_box_extents = Vector3(width * 0.5, 0.2, 0.3)


func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	global_position += direction * step
	_traveled += step
	var right := direction.cross(Vector3.UP)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(enemy.get_instance_id()):
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if absf(to.dot(direction)) <= 0.9 and absf(to.dot(right)) <= width * 0.5:
			_hit[enemy.get_instance_id()] = true
			enemy.take_hit(damage, false, direction)
			if enemy.has_method("hurl"):
				enemy.hurl(direction, throw, slam_damage, on_slam)
	if _traveled >= LENGTH:
		set_physics_process(false)
		if backwash > 0.0 and not returning:
			# Ressaca: a água volta, menor, e acerta de novo.
			var back := Pororoca.new()
			back.direction = -direction
			back.damage = maxi(int(round(damage * backwash)), 1)
			back.slam_damage = maxi(int(round(slam_damage * backwash)), 1)
			back.width = width * 0.8
			back.throw = throw * 0.5
			back.returning = true
			back.on_slam = on_slam
			get_parent().add_child(back)
			back.global_position = global_position
		var t := create_tween()
		t.tween_property(_wave, "scale", Vector3(1.0, 0.05, 1.0), 0.3)
		t.tween_callback(queue_free)
