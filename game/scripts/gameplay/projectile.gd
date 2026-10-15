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
## Crítico extra contra alvos longe de onde a flecha saiu (Olho de Caçadora).
var far_crit_bonus := 0.0
var far_distance := 6.0
var origin := Vector3.ZERO
## Desenho de flecha (arco) em vez de bola (magia).
var arrow := false

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
	add_to_group("player_projectiles")  # inimigos enxergam e tentam desviar
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.ENEMIES
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	add_child(shape)

	if arrow:
		_build_arrow()
	else:
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


## Flecha: haste de madeira, ponta de pedra verde e penas de arara, apontada para onde voa.
func _build_arrow() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var parts := [
		[_cyl(0.022, 0.022, 0.8), Color("8a5a2b"), Vector3.ZERO],
		[_cyl(0.0, 0.06, 0.16), Color("6fdc7b"), Vector3(0, 0.48, 0)],
		[_cyl(0.07, 0.0, 0.18), Color("e05555"), Vector3(0, -0.36, 0)],
	]
	for p in parts:
		var m := MeshInstance3D.new()
		m.mesh = p[0]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = p[1]
		m.material_override = mat
		m.position = p[2]
		holder.add_child(m)
	holder.rotation_degrees.x = -90  # o comprimento (Y) passa a apontar para -Z
	if direction.length() > 0.01:
		look_at_from_position(position, position + direction, Vector3.UP)
	# leve rastro
	Vfx.particles(self, Vector3.ZERO, "faisca", 6, 0.25, Color(1, 1, 1, 0.5), 0.15, Vector2(0.0, 0.2), 180.0, 0.0, true, false)


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 6
	return c


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
		var crit := crit_chance
		if far_crit_bonus > 0.0 and origin.distance_to(body.global_position) >= far_distance:
			crit += far_crit_bonus
		var hit := Damage.roll(damage, element, body.data.element, crit, rng)
		body.take_hit(hit.amount, hit.crit, direction)
		queue_free()
	elif not body.is_in_group("player"):
		_spent = true
		queue_free()
