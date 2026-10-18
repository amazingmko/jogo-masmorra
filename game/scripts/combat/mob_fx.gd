class_name MobFx
extends RefCounted
## Efeitos das habilidades dos bichos, escolhidos pelo id do ataque. O aviso no chão continua o
## mesmo (é ele que mostra a área); aqui entra o que conta o que está acontecendo: a pedra de
## verdade voando, os rasgos da garra, o tronco caindo, a nuvem do fedor...
## Ataque sem efeito próprio aqui fica só com o aviso padrão.
## Leve para o celular: poucas partículas, malhas simples, tudo some sozinho.

const BARK := Color(0.33, 0.22, 0.13)
const STONE := Color(0.52, 0.5, 0.46)
const NUT := Color(0.45, 0.28, 0.12)
const STINK := Color(0.55, 0.8, 0.35)

static var _mats := {}


# ---------- ganchos (chamados pelo aviso, pelo disparo e pelo inimigo) ----------

## Pouco antes do impacto (o tronco precisa começar a cair antes do dano).
static func before_impact(t: Telegraph) -> void:
	match t.attack_id:
		&"arvores":
			_falling_tree(t.get_parent(), t.global_position, t.time_left())


## Na hora do impacto do aviso.
static func on_resolve(t: Telegraph) -> void:
	var parent := t.get_parent()
	var at := t.global_position
	match t.attack_id:
		&"garras":
			_claws(parent, at, t.rotation.y, t.radius)
		&"bocarra":
			_belly_bite(parent, at, t.rotation.y)
		&"tapa":
			Vfx.ground_ring(parent, at, "anel_som", Color(1, 0.95, 0.85, 0.7), t.radius * 2.0, 0.25)
			Vfx.particles(parent, at + Vector3(0, 0.3, 0), "poeira", 8, 0.5, Color(0.75, 0.62, 0.45, 0.6), 0.6, Vector2(1.0, 2.0), 80.0, -1.0, false, true, t.radius * 0.6)
		&"ourico", &"chuva_ourico":
			chunks(parent, at + Vector3(0, 0.2, 0), NUT, 10, 0.09, Vector2(2.0, 4.0))
			Vfx.particles(parent, at + Vector3(0, 0.2, 0), "poeira", 10, 0.6, Color(0.72, 0.58, 0.4, 0.7), 0.8, Vector2(1.0, 2.5), 70.0, -1.0, false)
		&"arvores":
			chunks(parent, at + Vector3(0, 0.3, 0), BARK, 14, 0.12, Vector2(2.5, 5.0))
			Vfx.particles(parent, at + Vector3(0, 0.2, 0), "poeira", 16, 0.9, Color(0.7, 0.6, 0.45, 0.75), 1.3, Vector2(1.5, 3.5), 85.0, -0.8, false, true, 1.0)
			Vfx.ground_ring(parent, at, "onda_choque", Color(0.9, 0.7, 0.45, 0.5), t.radius * 2.2, 0.35)
		&"grito":
			_scream(parent, at, t.radius)
		&"fedor":
			_stink_cloud(t)
		&"bafo":
			_bafo_fog(t)


## Visual de um disparo. Devolve false para usar a bolinha padrão.
static func projectile_visual(p: EnemyProjectile) -> bool:
	match p.attack_id:
		&"pedrada":
			var rock := MeshInstance3D.new()
			var m := SphereMesh.new()
			m.radius = 0.17
			m.height = 0.3
			m.radial_segments = 6
			m.rings = 3
			rock.mesh = m
			rock.material_override = _solid(STONE)
			rock.scale = Vector3(1.0, 0.8, 1.15)
			rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(rock)
			_spin(rock, Vector3(13.0, 4.0, 0.0))
			return true
		&"cinco_olhos":
			var orb := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.2
			s.height = 0.4
			s.radial_segments = 8
			s.rings = 4
			orb.mesh = s
			orb.material_override = _glow(Color(1.0, 0.55, 0.15))
			orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(orb)
			# rastro: faíscas que ficam no caminho
			var trail := Vfx.particles(p, Vector3.ZERO, "faisca", 14, 0.35, Color(1.0, 0.6, 0.2, 0.9), 0.35, Vector2(0.0, 0.3), 180.0, 0.0, true, false)
			trail.local_coords = false
			return true
	return false


## Disparo acabou (acertou ou bateu em algo).
static func projectile_end(parent: Node, at: Vector3, id: StringName) -> void:
	match id:
		&"pedrada":
			chunks(parent, at, STONE, 7, 0.07, Vector2(1.5, 3.0))
			Vfx.particles(parent, at, "poeira", 6, 0.45, Color(0.7, 0.66, 0.6, 0.6), 0.5, Vector2(0.5, 1.5), 180.0, -1.0, false)
		&"cinco_olhos":
			Vfx.particles(parent, at, "faisca", 10, 0.35, Color(1.0, 0.6, 0.2), 0.3, Vector2(2.0, 4.0), 180.0, -3.0)


## Investida do Mapinguari: poeira e torrões saindo dos pés enquanto corre.
static func charge_step(enemy: Node3D, id: StringName) -> void:
	if id != &"investida_mapinguari":
		return
	var parent := enemy.get_parent()
	var at := enemy.global_position + Vector3(0, 0.15, 0)
	Vfx.particles(parent, at, "poeira", 3, 0.7, Color(0.68, 0.55, 0.4, 0.75), 1.1, Vector2(0.5, 1.5), 60.0, -0.5, false)
	if randf() < 0.5:
		chunks(parent, at, Color(0.38, 0.27, 0.18), 3, 0.1, Vector2(1.5, 3.0))


## Fim da investida (parou ou bateu na parede): o chão racha.
static func charge_end(enemy: Node3D, id: StringName) -> void:
	if id != &"investida_mapinguari":
		return
	var parent := enemy.get_parent()
	Vfx.ground_ring(parent, enemy.global_position, "onda_choque", Color(0.9, 0.65, 0.4, 0.55), 6.0, 0.4)
	chunks(parent, enemy.global_position + Vector3(0, 0.2, 0), Color(0.38, 0.27, 0.18), 10, 0.12, Vector2(2.0, 4.5))


## Ajudante chamado (Estouro de Queixadas): poeira onde ele aparece.
static func summon_dust(parent: Node, at: Vector3) -> void:
	Vfx.particles(parent, at + Vector3(0, 0.2, 0), "poeira", 14, 0.9, Color(0.72, 0.6, 0.45, 0.8), 1.2, Vector2(1.0, 3.0), 80.0, -0.8, false, true, 0.8)
	chunks(parent, at + Vector3(0, 0.2, 0), Color(0.38, 0.27, 0.18), 6, 0.1, Vector2(1.5, 3.0))


## Aquecimento (tela de carregamento): cada efeito aparece uma vez.
static func warm(parent: Node3D, at: Vector3) -> void:
	chunks(parent, at, NUT, 2, 0.1, Vector2.ONE)
	_claws(parent, at, 0.0, 2.0)
	_belly_bite(parent, at, 0.0)
	_scream(parent, at, 2.0)
	_falling_tree(parent, at, 0.1)
	Vfx.particles(parent, at, "fumaca", 2, 0.3, STINK, 0.5, Vector2.ONE, 30.0, 0.0, false)
	var orb := MeshInstance3D.new()
	orb.mesh = SphereMesh.new()
	orb.material_override = _glow(Color(1.0, 0.55, 0.15))
	parent.add_child(orb)
	orb.global_position = at
	var rock := MeshInstance3D.new()
	rock.mesh = SphereMesh.new()
	rock.material_override = _solid(STONE)
	parent.add_child(rock)
	rock.global_position = at


# ---------- peças ----------

## Lascas que voam e caem (castanha, pedra, madeira, terra): cubinhos com gravidade.
static func chunks(parent: Node, at: Vector3, color: Color, amount: int, size: float, speed: Vector2) -> void:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, size * 0.6, size * 1.3)
	box.material = _solid(color)
	p.mesh = box
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0, -14.0, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)


## Garras: três rasgos claros que somem rápido e as marcas escuras no chão, que ficam um pouco.
static func _claws(parent: Node, at: Vector3, yaw: float, reach: float) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var center := at + fwd * reach * 0.55
	var size := clampf(reach * 0.9, 1.2, 3.6)
	var slash := _decal(parent, center, yaw, size, "garra", Color(1.0, 0.92, 0.8, 0.95), true)
	var gouge := _decal(parent, center + Vector3(0, -0.01, 0), yaw, size, "garra", Color(0.16, 0.09, 0.05, 0.85), false)
	var t := slash.create_tween()
	t.tween_property(slash.material_override, "albedo_color:a", 0.0, 0.3)
	t.tween_callback(slash.queue_free)
	var g := gouge.create_tween()
	g.tween_interval(1.0)
	g.tween_property(gouge.material_override, "albedo_color:a", 0.0, 0.8)
	g.tween_callback(gouge.queue_free)
	chunks(parent, center + Vector3(0, 0.2, 0), Color(0.38, 0.27, 0.18), 6, 0.08, Vector2(1.5, 3.0))


## Bocarra do Ventre: a boca da barriga fecha cuspindo baba à frente.
static func _belly_bite(parent: Node, at: Vector3, yaw: float) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var front := at + fwd * 1.3 + Vector3(0, 1.3, 0)
	var spit := Vfx.particles(parent, front, "faisca", 14, 0.6, Color(0.85, 0.9, 0.35, 0.9), 0.22, Vector2(2.0, 4.5), 35.0, -9.0, false)
	spit.direction = (fwd + Vector3(0, 0.4, 0)).normalized()
	Vfx.ground_ring(parent, at + fwd * 1.6, "anel_som", Color(1.0, 0.6, 0.3, 0.8), 3.0, 0.3)


## Grito: anéis de som em sequência e folhas caindo das árvores em volta.
static func _scream(parent: Node, at: Vector3, radius: float) -> void:
	for i in 3:
		var tree := parent.get_tree() if parent.is_inside_tree() else null
		if i == 0 or tree == null:
			Vfx.ground_ring(parent, at, "anel_som", Color(1.0, 0.85, 0.4, 0.8), radius * 2.0, 0.45)
		else:
			tree.create_timer(0.12 * i, false).timeout.connect(func() -> void:
				if is_instance_valid(parent):
					Vfx.ground_ring(parent, at, "anel_som", Color(1.0, 0.85, 0.4, 0.7 - 0.15 * i), radius * 2.0, 0.45))
	var leaves := Vfx.particles(parent, at + Vector3(0, 4.5, 0), "folha", 18, 2.2, Color(1, 1, 1, 0.95), 0.35, Vector2(0.2, 0.8), 180.0, -2.0, false, true, radius * 0.8)
	leaves.explosiveness = 0.4


## Árvores derrubadas: um tronco tomba de pé até deitar em cima do aviso, bem na hora do dano.
static func _falling_tree(parent: Node, at: Vector3, fall_time: float) -> void:
	var length := 4.2
	var pivot := Node3D.new()
	parent.add_child(pivot)
	var yaw := randf() * TAU
	pivot.rotation.y = yaw
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	pivot.global_position = at - fwd * length * 0.5 + Vector3(0, 0.25, 0)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.32
	cyl.height = length
	cyl.radial_segments = 7
	cyl.rings = 1
	trunk.mesh = cyl
	trunk.material_override = _solid(BARK)
	trunk.position = Vector3(0, length * 0.5, 0)
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(trunk)
	var crown := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.9
	s.height = 1.4
	s.radial_segments = 7
	s.rings = 3
	crown.mesh = s
	crown.material_override = _solid(Color(0.2, 0.42, 0.16))
	crown.position = Vector3(0, length, 0)
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(crown)
	pivot.rotation.x = 0.15
	var t := pivot.create_tween()
	t.tween_property(pivot, "rotation:x", PI * 0.5, maxf(fall_time, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(pivot, "rotation:x", PI * 0.5 - 0.06, 0.08)
	t.tween_property(pivot, "rotation:x", PI * 0.5, 0.1)
	t.tween_interval(0.8)
	t.tween_property(pivot, "position:y", -0.8, 0.6)
	t.tween_callback(pivot.queue_free)


## Fedor: nuvem verde que fica borbulhando enquanto a poça dura, com moscas rodando.
static func _stink_cloud(t: Telegraph) -> void:
	var cloud := Vfx.particles(t, t.global_position + Vector3(0, 0.3, 0), "fumaca", 10, 1.6, Color(STINK, 0.45), 1.3, Vector2(0.2, 0.6), 25.0, 0.4, false, false, t.radius * 0.6)
	cloud.color_ramp.set_color(0, Color(STINK, 0.0))
	cloud.color_ramp.add_point(0.3, Color(STINK, 0.45))
	var flies := Vfx.particles(t, t.global_position + Vector3(0, 0.8, 0), "faisca", 6, 1.2, Color(0.05, 0.05, 0.03, 0.9), 0.08, Vector2(0.5, 1.0), 180.0, 0.0, false, false, t.radius * 0.5)
	flies.tangential_accel_min = 6.0
	flies.tangential_accel_max = 10.0
	Vfx.particles(t.get_parent(), t.global_position + Vector3(0, 0.2, 0), "fumaca", 10, 0.8, Color(STINK, 0.6), 1.0, Vector2(1.0, 2.5), 80.0, 0.0, false, true, t.radius * 0.5)


## Bafo: nuvem verde espalhada pela área perigosa, sem cobrir as zonas seguras.
static func _bafo_fog(t: Telegraph) -> void:
	var pts := PackedVector3Array()
	var tries := 0
	while pts.size() < 40 and tries < 400:
		tries += 1
		var a := randf() * TAU
		var r := sqrt(randf()) * t.radius
		var world := t.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		var safe := false
		for z in t.safe_zones:
			if Vector2(world.x - z.x, world.z - z.z).length() < t.safe_radius + 0.8:
				safe = true
		if not safe:
			pts.append(Vector3(cos(a) * r, 0.4, sin(a) * r))
	var p := Vfx.particles(t.get_parent(), t.global_position, "fumaca", 40, 2.0, Color(STINK, 0.6), 2.4, Vector2(0.3, 1.0), 40.0, 0.3, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.color_ramp.set_color(0, Color(STINK, 0.0))
	p.color_ramp.add_point(0.25, Color(STINK, 0.6))


# ---------- ajudantes ----------

static func _decal(parent: Node, at: Vector3, yaw: float, size: float, texture: String, color: Color, additive: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.orientation = PlaneMesh.FACE_Y
	mesh.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Vfx.tex(texture)
	m.albedo_color = color
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = Vector3(at.x, 0.07, at.z)
	mesh.rotation.y = yaw
	return mesh


static func _solid(color: Color) -> StandardMaterial3D:
	var key := "s" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		m.disable_receive_shadows = true
		_mats[key] = m
	return _mats[key]


static func _glow(color: Color) -> StandardMaterial3D:
	var key := "g" + color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color.lightened(0.3)
		_mats[key] = m
	return _mats[key]


static func _spin(node: Node3D, speed: Vector3) -> void:
	var t := node.create_tween().set_loops()
	t.tween_property(node, "rotation", speed, 1.0).as_relative()
