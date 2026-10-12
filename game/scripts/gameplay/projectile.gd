class_name Projectile
extends Area3D
## Disparo de arco ou cajado. Anda em linha reta e some ao bater em inimigo, parede ou ao atingir o alcance.

const ELEMENT_COLORS := {
	GameEnums.Element.NEUTRAL: Color("f2ecff"),
	GameEnums.Element.FIRE: Color("ff8a3d"),
	GameEnums.Element.WATER: Color("4db8ff"),
	GameEnums.Element.NATURE: Color("8be06b"),
}

var direction := Vector3.FORWARD
var speed := 15.0
var max_distance := 10.0
var damage := 4
var element: GameEnums.Element = GameEnums.Element.NEUTRAL
var crit_chance := 0.0
var rng: RandomNumberGenerator

var _traveled := 0.0
var _spent := false


static func create(dir: Vector3, stats: WeaponStats, elem: GameEnums.Element, crit: float,
		random: RandomNumberGenerator) -> Projectile:
	var p := Projectile.new()
	p.direction = dir.normalized()
	p.speed = stats.projectile_speed
	p.max_distance = stats.attack_range
	p.damage = stats.damage
	p.element = elem
	p.crit_chance = crit
	p.rng = random
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.ENEMIES
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var visual := SphereMesh.new()
	visual.radius = 0.18
	visual.height = 0.36
	mesh.mesh = visual
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ELEMENT_COLORS.get(element, Color.WHITE)
	mesh.material_override = mat
	add_child(mesh)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	_traveled += step
	if _traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _spent:
		return
	if body.is_in_group("enemies"):
		_spent = true
		var hit := Damage.roll(damage, element, body.data.element, crit_chance, rng)
		body.take_hit(hit.amount, hit.crit, direction)
		queue_free()
	elif not body.is_in_group("player"):
		_spent = true
		queue_free()
