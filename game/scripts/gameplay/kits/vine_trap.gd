class_name VineTrap
extends Node3D
## Armadilha de Cipó (Mateira): fica no chão; o primeiro bicho que pisar fica preso.
## Some depois de pegar alguém ou quando o tempo acaba.

const RADIUS := 1.3
const LIFETIME := 20.0

var hold_time := 3.0
## Talentos: Espinhos (dano por segundo no preso), Presa Marcada (dano a mais no preso),
## Cipó que Alastra (prende quem está perto) e Timbó (explode em veneno ao soltar).
var thorn_dps := 0.0
var mark_bonus := 0.0
var spread_radius := 0.0
var timbo_radius := 0.0
var timbo_dps := 0.0
const TIMBO_TIME := 4.0
var _left := LIFETIME
var _ring: MeshInstance3D
var _spikes: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("floor_effects")
	# Círculo de cipó trançado no chão e pontas de cipó em volta.
	_ring = MeshInstance3D.new()
	if Vfx.tex("cipo_armadilha"):
		# o laço de cipó pintado (imagem), deitado no chão
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * RADIUS * 2.3
		quad.orientation = PlaneMesh.FACE_Y
		_ring.mesh = quad
		_ring.position.y = 0.05
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		var torus := TorusMesh.new()
		torus.inner_radius = RADIUS * 0.82
		torus.outer_radius = RADIUS
		torus.rings = 24
		_ring.mesh = torus
		_ring.scale = Vector3(1, 0.25, 1)
		_ring.position.y = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4a5a24")
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color("6fdc7b")
	mat.emission_energy_multiplier = 0.08
	_ring.material_override = Vfx.sprite_material("cipo_armadilha", Color(1.1, 1.1, 1.1, 1.0), false, false) if Vfx.tex("cipo_armadilha") else mat
	add_child(_ring)
	for i in 6:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07
		cone.height = 0.35
		spike.mesh = cone
		spike.material_override = mat
		var a := TAU * i / 6.0
		spike.position = Vector3(cos(a), 0.1, sin(a)) * RADIUS * 0.9
		spike.rotation = Vector3(0, -a, deg_to_rad(-25))
		add_child(spike)
		_spikes.append(spike)
	if not Vfx.tex("cipo_armadilha"):
		var leaf := Vfx.icon(self, "folha", 0.12, 0.6, Color(1, 1, 1, 0.9))
		leaf.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		leaf.rotation_degrees.x = -90


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_vanish()
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() <= RADIUS and enemy.has_method("constrict"):
			_catch(enemy)
			if spread_radius > 0.0:
				for other in get_tree().get_nodes_in_group("enemies"):
					if other != enemy and other.global_position.distance_to(enemy.global_position) <= spread_radius:
						_catch(other)
			_snap(enemy)
			return


func _catch(enemy: Node3D) -> void:
	enemy.constrict(hold_time, "preso no cipó")
	if thorn_dps > 0.0 and enemy.has_method("poison"):
		enemy.poison(thorn_dps, hold_time)
	if mark_bonus > 0.0 and enemy.has_method("mark"):
		enemy.mark("presa", mark_bonus, hold_time)


## Fecha em volta do bicho: os cipós sobem e se enrolam, depois somem.
func _snap(enemy: Node3D) -> void:
	set_physics_process(false)
	global_position = Vector3(enemy.global_position.x, global_position.y, enemy.global_position.z)
	Vfx.particles(get_parent(), global_position + Vector3(0, 0.3, 0), "folha", 12, 1.0, Color(1, 1, 1, 0.9), 0.35, Vector2(2.0, 4.0), 60.0, -6.0, false)
	var t := create_tween()
	t.set_parallel(true)
	for spike in _spikes:
		t.tween_property(spike, "scale", Vector3(1.4, 4.0, 1.4), 0.15)
		t.tween_property(spike, "position", Vector3(spike.position.x * 0.45, 0.6, spike.position.z * 0.45), 0.15)
	t.tween_property(_ring, "scale", Vector3(0.55, 0.8, 0.55), 0.15)
	t.chain().tween_interval(hold_time)
	if timbo_radius > 0.0:
		t.chain().tween_callback(_explode_timbo)
	t.chain().tween_callback(_vanish)


## Armadilha de Timbó: o cipó solta o bicho e estoura numa nuvem de veneno.
func _explode_timbo() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() <= timbo_radius and enemy.has_method("poison"):
			enemy.poison(timbo_dps, TIMBO_TIME)
	Vfx.particles(get_parent(), global_position + Vector3(0, 0.4, 0), "poeira", 24, 1.2, Color("8be06b"), 0.9, Vector2(1.5, 3.5), 180.0, -0.5, false)
	Vfx.ground_ring(get_parent(), global_position, "onda_choque", Color("8be06b"), timbo_radius * 2.0, 0.5)


func _vanish() -> void:
	set_physics_process(false)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	t.tween_callback(queue_free)
