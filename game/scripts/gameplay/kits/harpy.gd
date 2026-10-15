class_name Harpy
extends Node3D
## Chamado da Harpia (ultimate da Mateira): o gavião-real circula acima dela e mergulha
## nos inimigos, começando pelo mais ferido. Visual provisório feito de formas simples
## (até ter o modelo 3D da harpia).

const RANGE := 12.0
const DIVE_EVERY := 0.75
const ORBIT_RADIUS := 2.2
const ORBIT_HEIGHT := 3.2

var owner_player: Player
var duration := 8.0
var damage := 50

var _t := 0.0
var _next_dive := 0.4
var _diving := false
var _body: Node3D
var _wings: Array[Node3D] = []


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var grey := _mat(Color("8d8f96"))
	var dark := _mat(Color("2b2a33"))
	var white := _mat(Color("f2f0ea"))
	_part(_capsule(0.16, 0.7), white, Vector3.ZERO, Vector3(90, 0, 0))          # corpo (barriga clara)
	_part(_sphere(0.17), grey, Vector3(0, 0.08, 0.38), Vector3.ZERO)            # cabeça cinza
	_part(_cone(0.07, 0.18), dark, Vector3(0, 0.05, 0.56), Vector3(90, 0, 0))   # bico
	_part(_box(Vector3(0.32, 0.03, 0.3)), dark, Vector3(0, 0.02, -0.45), Vector3.ZERO)  # cauda
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.12 * side, 0.05, 0.05)
		_body.add_child(pivot)
		var wing := MeshInstance3D.new()
		wing.mesh = _box(Vector3(0.95, 0.03, 0.42))
		wing.material_override = dark
		wing.position = Vector3(0.48 * side, 0, 0)
		pivot.add_child(wing)
		_wings.append(pivot)
	Vfx.particles(self, Vector3.ZERO, "faisca", 8, 0.6, Color("e8f5ff"), 0.25, Vector2(0.2, 0.6), 180.0, 0.0, true, false)


func _process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	_t += delta
	var flap := sin(_t * (22.0 if _diving else 9.0)) * 0.6
	_wings[0].rotation.z = flap
	_wings[1].rotation.z = -flap
	if _diving:
		return
	var center := owner_player.global_position
	var a := _t * 1.6
	var target := center + Vector3(cos(a) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(a) * ORBIT_RADIUS)
	global_position = global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	look_at(global_position + Vector3(-sin(a), 0, cos(a)), Vector3.UP, true)
	if _t >= duration:
		_leave()
		return
	_next_dive -= delta
	if _next_dive <= 0.0:
		var prey := _pick_prey()
		if prey:
			_dive(prey)
		else:
			_next_dive = 0.3


## O mais ferido (menor fração de vida) perto da Mateira.
func _pick_prey() -> Node3D:
	var best: Node3D = null
	var best_ratio := 2.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(owner_player.global_position) > RANGE:
			continue
		var h: Health = enemy.health
		var ratio := float(h.health) / maxf(h.max_health, 1.0)
		if ratio < best_ratio:
			best_ratio = ratio
			best = enemy
	return best


func _dive(prey: Node3D) -> void:
	_diving = true
	var hit_at := prey.global_position + Vector3(0, 0.8, 0)
	look_at(hit_at, Vector3.UP, true)
	var t := create_tween()
	t.tween_property(self, "global_position", hit_at, 0.22).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		if is_instance_valid(prey) and prey.has_method("take_hit"):
			prey.take_hit(damage, false, (prey.global_position - owner_player.global_position).normalized())
			Vfx.particles(get_parent(), hit_at, "faisca", 10, 0.35, Color("e8f5ff"), 0.4, Vector2(2.0, 4.0), 180.0, 0.0))
	t.tween_property(self, "global_position", hit_at + Vector3(0, ORBIT_HEIGHT, 0), 0.3).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_diving = false
		_next_dive = DIVE_EVERY)


func _leave() -> void:
	set_process(false)
	var t := create_tween()
	t.tween_property(self, "global_position", global_position + Vector3(0, 8, 0), 0.6)
	t.tween_callback(queue_free)


# ---------- formas ----------

func _part(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot_deg
	_body.add_child(m)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _cone(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
