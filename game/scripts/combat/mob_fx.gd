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
const VENOM := Color(0.55, 0.95, 0.3)
const BLOOD := Color(0.55, 0.05, 0.08)
const WEB := Color(0.95, 0.95, 0.92)
## Rastro enquanto corre (investidas, botes): cor da poeira/faísca e se solta torrões.
const CHARGE_TRAIL := {
	&"investida_mapinguari": {"cor": Color(0.68, 0.55, 0.4, 0.75), "torrao": true},
	&"investida_bando": {"cor": Color(0.7, 0.58, 0.42, 0.7), "torrao": true},
	&"estouro": {"cor": Color(0.7, 0.58, 0.42, 0.8), "torrao": true},
	&"bote_onca": {"cor": Color(1.0, 0.8, 0.3, 0.8), "faisca": true},
	&"formigueiro": {"cor": Color(1.0, 0.4, 0.15, 0.9), "faisca": true, "brasa": true},
	&"bote_cobra": {"cor": Color(0.55, 0.95, 0.3, 0.8), "faisca": true},
}

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
		# ---- queixada
		&"dentada":
			_bite(parent, at, t.rotation.y, t.radius, Color(1.0, 0.95, 0.85, 0.8), Color(0.38, 0.27, 0.18))
		# ---- onça
		&"patada":
			_claws(parent, at, t.rotation.y, t.radius)
		&"mordida_cranio":
			_bite(parent, at, t.rotation.y, t.radius, Color(1.0, 0.5, 0.3, 0.9), BLOOD)
		&"esturro":
			_scream(parent, at, t.radius)
		# ---- aranha
		&"picada":
			_venom(parent, at, t.rotation.y, t.radius, VENOM)
		&"armadilha_teia":
			_web_decal(parent, at, t.radius * 2.2, t.linger + 0.5)
		# ---- formiga
		&"ferroada":
			_venom(parent, at, t.rotation.y, t.radius, Color(1.0, 0.55, 0.15))
		# ---- jararaca
		&"picada_cobra":
			_venom(parent, at, t.rotation.y, t.radius, VENOM)
		&"veneno_forte":
			_venom(parent, at, t.rotation.y, t.radius, Color(0.75, 0.08, 0.1))
		&"bafo":
			_bafo_fog(t)
		_:
			# qualquer outro golpe: a área estala no chão na cor do ataque
			if t.shape == Telegraph.Shape.CIRCLE:
				FxKit.ground_wave(parent, at, t.radius, Color(t.color.r, t.color.g, t.color.b), 0.25)
			elif t.shape == Telegraph.Shape.LINE:
				FxKit.impact(parent, t.to_global(Vector3(0, 0.8, t.length)), 1.6, t.color, 0.2)


## Visual de um disparo. Devolve false para usar a bolinha padrão.
static func projectile_visual(p: EnemyProjectile) -> bool:
	match p.attack_id:
		&"pedrada":
			var real := prop("pedra_macaco", 0.36)
			if real:
				p.add_child(real)
				_spin(real, Vector3(13.0, 4.0, 0.0))
				return true
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
			# o olho de fogo voando (imagem virada para a câmera), pulsando
			var orb := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1.1, 0.55)
			orb.mesh = q
			orb.material_override = Vfx.sprite_material("olhar", Color(1.3, 1.2, 1.1, 1.0), true)
			orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(orb)
			var pulse := orb.create_tween().set_loops()
			pulse.tween_property(orb, "scale", Vector3.ONE * 1.15, 0.12)
			pulse.tween_property(orb, "scale", Vector3.ONE, 0.12)
			# rastro: faíscas que ficam no caminho
			var trail := Vfx.particles(p, Vector3.ZERO, "faisca", 14, 0.35, Color(1.0, 0.6, 0.2, 0.9), 0.35, Vector2(0.0, 0.3), 180.0, 0.0, true, false)
			trail.local_coords = false
			return true
		&"teia":
			# bolo de teia girando
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.36
			sm.radial_segments = 8
			sm.rings = 4
			ball.mesh = sm
			ball.material_override = _soft(WEB, 0.85)
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(ball)
			_spin(ball, Vector3(0.0, 0.0, 9.0))
			var fibers := Vfx.particles(p, Vector3.ZERO, "faisca", 8, 0.3, Color(1, 1, 1, 0.7), 0.18, Vector2(0.0, 0.2), 180.0, 0.0, true, false)
			fibers.local_coords = false
			return true
		&"pelos":
			# tufo de pelos urticantes girando
			var tuft := MeshInstance3D.new()
			var tq := QuadMesh.new()
			tq.size = Vector2.ONE * 0.75
			tuft.mesh = tq
			tuft.material_override = Vfx.sprite_material("pelos", Color(0.95, 0.8, 0.6, 1.0), true, false)
			tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(tuft)
			var glint := Vfx.particles(p, Vector3.ZERO, "faisca", 6, 0.25, Color(1.0, 0.85, 0.6, 0.8), 0.12, Vector2(0.0, 0.2), 180.0, 0.0, true, false)
			glint.local_coords = false
			return true
	return false


## Disparo acertou o herói.
static func projectile_hit_player(player: Node3D, id: StringName, duration: float) -> void:
	if id != &"teia" or not is_instance_valid(player):
		return
	# casulo de teia em volta do herói enquanto ele está preso
	var cocoon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.5
	cyl.height = 1.5
	cyl.radial_segments = 10
	cyl.rings = 2
	cocoon.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = Vfx.tex("teia")
	m.uv1_scale = Vector3(3, 2, 1)
	m.albedo_color = Color(WEB, 0.0)
	cocoon.material_override = m
	cocoon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cocoon.position = Vector3(0, 0.8, 0)
	player.add_child(cocoon)
	var t := cocoon.create_tween()
	t.tween_property(m, "albedo_color:a", 0.8, 0.12)
	t.tween_interval(maxf(duration - 0.4, 0.3))
	t.tween_property(m, "albedo_color:a", 0.0, 0.3)
	t.tween_callback(cocoon.queue_free)


## Disparo acabou (acertou ou bateu em algo).
static func projectile_end(parent: Node, at: Vector3, id: StringName) -> void:
	match id:
		&"pedrada":
			chunks(parent, at, STONE, 7, 0.07, Vector2(1.5, 3.0))
			Vfx.particles(parent, at, "poeira", 6, 0.45, Color(0.7, 0.66, 0.6, 0.6), 0.5, Vector2(0.5, 1.5), 180.0, -1.0, false)
		&"cinco_olhos":
			Vfx.particles(parent, at, "faisca", 10, 0.35, Color(1.0, 0.6, 0.2), 0.3, Vector2(2.0, 4.0), 180.0, -3.0)
			Vfx.sprite(parent, at, "olhar", 1.2, Color(1.2, 1.0, 0.9, 0.9), 0.3, 1.8)
		&"teia":
			_web_decal(parent, at, 1.6, 2.5)
			Vfx.particles(parent, at, "faisca", 10, 0.4, Color(1, 1, 1, 0.8), 0.2, Vector2(1.0, 2.5), 180.0, -3.0)
		&"pelos":
			Vfx.particles(parent, at, "poeira", 6, 0.6, Color(0.55, 0.4, 0.25, 0.6), 0.4, Vector2(0.5, 1.5), 180.0, -0.5, false)
			Vfx.sprite(parent, at, "pelos", 1.0, Color(0.95, 0.8, 0.6, 0.9), 0.35, 1.7, true, 0.0, false)


## Investida do Mapinguari: poeira e torrões saindo dos pés enquanto corre.
static func charge_step(enemy: Node3D, id: StringName) -> void:
	if not CHARGE_TRAIL.has(id):
		return
	var cfg: Dictionary = CHARGE_TRAIL[id]
	var parent := enemy.get_parent()
	var at := enemy.global_position + Vector3(0, 0.15, 0)
	var big := 1.1 if id == &"investida_mapinguari" else 0.7
	if cfg.get("faisca", false):
		# rastro rápido e brilhante (bote): faíscas que ficam no ar atrás do bicho
		Vfx.particles(parent, at + Vector3(0, 0.3, 0), "faisca", 4, 0.35, cfg.cor, 0.25, Vector2(0.0, 0.4), 180.0, 0.0)
	else:
		Vfx.particles(parent, at, "poeira", 3, 0.7, cfg.cor, big, Vector2(0.5, 1.5), 60.0, -0.5, false)
	if cfg.get("torrao", false) and randf() < 0.5:
		chunks(parent, at, Color(0.38, 0.27, 0.18), 3, 0.08 * big / 0.7, Vector2(1.5, 3.0))
	if cfg.get("brasa", false):
		Vfx.particles(parent, at, "faisca", 3, 0.6, Color(1.0, 0.3, 0.1, 0.9), 0.12, Vector2(0.3, 1.0), 70.0, -1.0)


## Fim da investida (parou ou bateu na parede): o chão racha.
static func charge_end(enemy: Node3D, id: StringName) -> void:
	if not CHARGE_TRAIL.has(id):
		return
	if id != &"investida_mapinguari":
		var cfg: Dictionary = CHARGE_TRAIL[id]
		var par := enemy.get_parent()
		Vfx.particles(par, enemy.global_position + Vector3(0, 0.2, 0), "poeira", 8, 0.6, Color(0.7, 0.58, 0.42, 0.7), 0.7, Vector2(1.0, 2.5), 80.0, -0.8, false)
		Vfx.ground_ring(par, enemy.global_position, "anel_som", cfg.cor, 2.5, 0.3)
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
	_bite(parent, at, 0.0, 1.0, Color.WHITE, NUT)
	_venom(parent, at, 0.0, 1.0, VENOM)
	_web_decal(parent, at, 1.0, 0.3)
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
	for n in ["pedra_macaco", "ourico_castanha"]:
		var pr := prop(n, 0.4)
		if pr:
			parent.add_child(pr)
			pr.global_position = at


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
	Vfx.sprite(parent, at + fwd * 1.4 + Vector3(0, 1.2, 0), "mordida", 2.6, Color(1.0, 0.75, 0.45, 1.0), 0.32, 1.1)


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


## Árvores derrubadas: uma árvore da mata (o mesmo modelo da borda do mapa) é arrancada com raiz e
## tudo e tomba até deitar em cima do aviso, bem na hora do dano.
static func _falling_tree(parent: Node, at: Vector3, fall_time: float) -> void:
	var length := 4.6
	var pivot := Node3D.new()
	parent.add_child(pivot)
	var yaw := randf() * TAU
	pivot.rotation.y = yaw
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var base_at := at - fwd * length * 0.55
	pivot.global_position = base_at
	var piece: Dictionary = RoomDecor._piece("arvore_borda")
	var tree := MeshInstance3D.new()
	tree.mesh = piece.mesh
	# o modelo vem com 6 m; aqui a árvore tem o comprimento do aviso
	tree.transform = Transform3D(Basis().scaled(Vector3.ONE * length / 6.0), Vector3.ZERO) * piece.base
	tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(tree)
	# raízes arrancadas: terra e lascas voando da base
	chunks(parent, base_at + Vector3(0, 0.2, 0), Color(0.36, 0.25, 0.16), 10, 0.1, Vector2(1.5, 3.5))
	Vfx.particles(parent, base_at + Vector3(0, 0.2, 0), "poeira", 10, 0.9, Color(0.55, 0.42, 0.3, 0.8), 1.0, Vector2(0.8, 2.0), 70.0, -1.0, false, true, 0.6)
	pivot.rotation.x = 0.08
	var t := pivot.create_tween()
	t.tween_property(pivot, "rotation:x", PI * 0.5, maxf(fall_time, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(pivot, "rotation:x", PI * 0.5 - 0.07, 0.08)
	t.tween_property(pivot, "rotation:x", PI * 0.5, 0.1)
	# no tombo, as folhas da copa se soltam
	t.tween_callback(func() -> void:
		if is_instance_valid(parent) and parent.is_inside_tree():
			Vfx.particles(parent, at + fwd * 1.2 + Vector3(0, 0.8, 0), "folha", 14, 1.6, Color(1, 1, 1, 0.95), 0.4, Vector2(1.0, 3.0), 80.0, -2.5, false, true, 1.2))
	t.tween_interval(0.8)
	t.tween_property(pivot, "position:y", -1.2, 0.6)
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


## Mordida: dentes fechando (dois arcos que se juntam) + lascas/gotas.
static func _bite(parent: Node, at: Vector3, yaw: float, reach: float, flash: Color, chip: Color) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var spot := at + fwd * reach * 0.6
	Vfx.ground_ring(parent, spot, "anel_som", flash, maxf(reach, 1.2), 0.22)
	# os dentes fechando no ar, na frente do bicho
	Vfx.sprite(parent, spot + Vector3(0, 0.8, 0), "mordida", clampf(reach * 1.1, 1.0, 2.4), Color(flash, 1.0), 0.28, 1.1)
	Vfx.particles(parent, spot + Vector3(0, 0.6, 0), "faisca", 8, 0.3, flash, 0.25, Vector2(1.5, 3.0), 60.0, -4.0)
	chunks(parent, spot + Vector3(0, 0.3, 0), chip, 5, 0.06, Vector2(1.0, 2.5))


## Picada venenosa: gotas da cor do veneno caindo e uma pocinha que some.
static func _venom(parent: Node, at: Vector3, yaw: float, reach: float, color: Color) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var spot := at + fwd * reach * 0.6
	var drops := Vfx.particles(parent, spot + Vector3(0, 0.6, 0), "gota_veneno", 12, 0.6, color, 0.22, Vector2(1.0, 3.0), 50.0, -9.0, false)
	Vfx.sprite(parent, spot + Vector3(0, 0.7, 0), "gota_veneno", 0.7, Color(color, 1.0), 0.3, 1.4)
	drops.direction = (fwd + Vector3(0, 0.6, 0)).normalized()
	var puddle := _decal(parent, spot, yaw, maxf(reach * 0.9, 0.8), "fumaca", Color(color, 0.55), false)
	var t := puddle.create_tween()
	t.tween_interval(0.8)
	t.tween_property(puddle.material_override, "albedo_color:a", 0.0, 0.8)
	t.tween_callback(puddle.queue_free)


## Teia no chão (armadilha, bolo de teia que acertou): fica um tempo e some.
static func _web_decal(parent: Node, at: Vector3, size: float, life: float) -> void:
	var web := _decal(parent, at, randf() * TAU, size, "teia", Color(WEB, 0.0), false)
	var t := web.create_tween()
	t.tween_property(web.material_override, "albedo_color:a", 0.85, 0.15)
	t.tween_interval(maxf(life - 0.8, 0.2))
	t.tween_property(web.material_override, "albedo_color:a", 0.0, 0.6)
	t.tween_callback(web.queue_free)


# ---------- ajudantes ----------

static var _props := {}


## Objeto 3D pequeno do jogo (pedra, ouriço) em game/art/ambiente/<nome>.glb, com o maior lado
## medindo "size" e o centro na origem. Devolve null se o modelo não existir.
static func prop(name: String, size: float) -> MeshInstance3D:
	if not _props.has(name):
		var path := "res://game/art/ambiente/%s.glb" % name
		var mesh: Mesh = null
		if ResourceLoader.exists(path):
			var scene: Node = load(path).instantiate()
			var found := scene.find_children("*", "MeshInstance3D", true, false)
			if not found.is_empty():
				mesh = (found[0] as MeshInstance3D).mesh
			scene.free()
		_props[name] = mesh
	var m: Mesh = _props[name]
	if m == null:
		return null
	var holder := MeshInstance3D.new()
	var aabb := m.get_aabb()
	var k := size / maxf(aabb.get_longest_axis_size(), 0.001)
	var inner := MeshInstance3D.new()
	inner.mesh = m
	inner.scale = Vector3.ONE * k
	inner.position = -aabb.get_center() * k
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(inner)
	return holder

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


static func _soft(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "a" + color.to_html() + str(alpha)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(color, alpha)
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
