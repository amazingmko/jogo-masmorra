class_name Harpy
extends Node3D
## Chamado da Harpia (ultimate da Mateira): o gavião-real circula acima dela e mergulha
## nos inimigos, começando pelo mais ferido. Modelo 3D da harpia (game/art/herois/harpia.glb);
## o bater de asas é feito no shader (as pontas das asas sobem e descem), sem esqueleto.

const RANGE := 12.0
const DIVE_EVERY := 0.75
const ORBIT_RADIUS := 2.2
const ORBIT_HEIGHT := 3.2

var owner_player: Player
var duration := 8.0
var damage := 50
## Revoada: acompanha sempre, com parte do dano (companion_factor); a Fúria dá o dano cheio em dobro.
var companion := false
var companion_factor := 0.4
var _fury_left := 0.0
var _fury_fx: CPUParticles3D
var _fury_mats: Array[StandardMaterial3D] = []
const FURY_MULT := 2.0
const FURY_COLOR := Color("ffb02e")

var _t := 0.0
var _next_dive := 0.4
var _diving := false
var _body: Node3D
var _wings: Array[Node3D] = []
var _wing_mat: ShaderMaterial
var _trail: RibbonTrail

const MODEL := "res://game/art/herois/harpia.glb"
const WINGSPAN := 2.1
## Asas batendo: o modelo tem a envergadura no eixo Z; quanto mais longe do corpo, mais sobe/desce.
const WING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float flap = 0.0;
uniform vec3 glow : source_color = vec3(0.0);
void vertex() {
	float w = max(abs(VERTEX.z) - 0.06, 0.0);
	VERTEX.y += flap * w * (0.9 + w * 1.6);
}
void fragment() {
	ALBEDO = texture(tex, UV).rgb;
	ROUGHNESS = 1.0;
	EMISSION = glow;
}
"""
static var _wing_shader: Shader


func _ready() -> void:
	add_to_group("floor_effects")
	_body = Node3D.new()
	add_child(_body)
	# rastro de vento atrás dela (mais forte no mergulho)
	_trail = RibbonTrail.follow(self, 0.35, Color(0.85, 0.93, 1.0), 0.18)
	if ResourceLoader.exists(MODEL) and _build_model():
		Lighting.no_shadow_receive(_body)
		Vfx.particles(self, Vector3.ZERO, "faisca", 8, 0.6, Color("e8f5ff"), 0.25, Vector2(0.2, 0.6), 180.0, 0.0, true, false)
		return
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
	Lighting.no_shadow_receive(_body)
	Vfx.particles(self, Vector3.ZERO, "faisca", 8, 0.6, Color("e8f5ff"), 0.25, Vector2(0.2, 0.6), 180.0, 0.0, true, false)


func _process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	_t += delta
	if _fury_left > 0.0:
		_fury_left -= delta
		if _fury_left <= 0.0:
			_end_fury()
	var flap := sin(_t * (22.0 if _diving else 9.0)) * 0.6
	if _wing_mat:
		# mergulhando, as asas quase fecham; circulando, batem largo
		_wing_mat.set_shader_parameter("flap", flap * (0.5 if _diving else 1.0))
	else:
		_wings[0].rotation.z = flap
		_wings[1].rotation.z = -flap
	if _diving:
		return
	var center := owner_player.global_position
	var a := _t * 1.6
	var target := center + Vector3(cos(a) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(a) * ORBIT_RADIUS)
	global_position = global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	look_at(global_position + Vector3(-sin(a), 0, cos(a)), Vector3.UP, true)
	if not companion and _t >= duration:
		_leave()
		return
	_next_dive -= delta * (1.6 if _fury_left > 0.0 else 1.0)
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
	var prey_ref: WeakRef = weakref(prey)  # o bicho pode morrer no meio do mergulho
	t.tween_callback(func() -> void:
		var target: Node3D = prey_ref.get_ref()
		if is_instance_valid(target) and is_instance_valid(owner_player) and target.has_method("take_hit"):
			target.take_hit(_dive_damage(), false, (target.global_position - owner_player.global_position).normalized())
			var c := FURY_COLOR if _fury_left > 0.0 else Color("e8f5ff")
			FxKit.impact(get_parent(), hit_at, 1.9, c, 0.22, 5.0)
			FxKit.ground_wave(get_parent(), target.global_position, 1.3, Color(0.85, 0.8, 0.7), 0.25, 0.0, 1.0)
			Vfx.sprite(get_parent(), hit_at, "corte", 1.5, Color(1, 1, 1, 0.9), 0.2, 1.2, true)
			Vfx.particles(get_parent(), hit_at, "faisca", 10, 0.35, c, 0.4, Vector2(2.0, 4.0), 180.0, 0.0))
	t.tween_property(self, "global_position", hit_at + Vector3(0, ORBIT_HEIGHT, 0), 0.3).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_diving = false
		_next_dive = DIVE_EVERY)


func _dive_damage() -> int:
	if _fury_left > 0.0:
		return maxi(int(round(damage * FURY_MULT)), 1)
	if companion:
		return maxi(int(round(damage * companion_factor)), 1)
	return damage


## Fúria da Harpia (Revoada): dano cheio em dobro e mergulhos mais rápidos por um tempo.
## Visível: a harpia fica dourada, maior e solta faíscas enquanto durar.
func fury(seconds: float) -> void:
	var starting := _fury_left <= 0.0
	_fury_left = maxf(_fury_left, seconds)
	if not starting:
		return
	_body.scale = Vector3.ONE * 1.35
	if is_instance_valid(_trail):
		_trail.width = 0.9
		_trail._mat.set_shader_parameter("color", FURY_COLOR)
	if _wing_mat:
		_wing_mat.set_shader_parameter("glow", FURY_COLOR * 0.5)
	for m in _body.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat:
			mat.emission_enabled = true
			mat.emission = FURY_COLOR
			mat.emission_energy_multiplier = 0.6
			_fury_mats.append(mat)
	_fury_fx = Vfx.particles(self, Vector3.ZERO, "faisca", 24, 0.5, FURY_COLOR, 0.35, Vector2(0.5, 1.5), 180.0, 0.0, true, false)
	Vfx.particles(get_parent(), global_position, "faisca", 20, 0.6, FURY_COLOR, 0.45, Vector2(2.0, 4.0), 180.0, 0.0)


func _end_fury() -> void:
	_body.scale = Vector3.ONE
	if is_instance_valid(_trail):
		_trail.width = 0.35
		_trail._mat.set_shader_parameter("color", Color(0.85, 0.93, 1.0))
	if _wing_mat:
		_wing_mat.set_shader_parameter("glow", Color.BLACK)
	for mat in _fury_mats:
		mat.emission_enabled = false
	_fury_mats.clear()
	if is_instance_valid(_fury_fx):
		_fury_fx.queue_free()


func is_furious() -> bool:
	return _fury_left > 0.0


## Vínculo: cada abate a mantém mais tempo (sozinha) ou estende a Fúria (Revoada).
func extend(seconds: float) -> void:
	if companion:
		if _fury_left > 0.0:
			_fury_left += seconds
	else:
		duration += seconds


func _leave() -> void:
	set_process(false)
	var t := create_tween()
	t.tween_property(self, "global_position", global_position + Vector3(0, 8, 0), 0.6)
	t.tween_callback(queue_free)


## A harpia de verdade: cabeça do modelo (lado -X) para a frente (+Z do corpo), asas para os lados.
func _build_model() -> bool:
	var scene: Node = load(MODEL).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		scene.free()
		return false
	var src: MeshInstance3D = found[0]
	var mesh: Mesh = src.mesh
	var tex: Texture2D = null
	var m0 := src.get_active_material(0) as StandardMaterial3D
	if m0:
		tex = m0.albedo_texture
	scene.free()
	if _wing_shader == null:
		_wing_shader = Shader.new()
		_wing_shader.code = WING_SHADER
	_wing_mat = ShaderMaterial.new()
	_wing_mat.shader = _wing_shader
	_wing_mat.set_shader_parameter("tex", tex)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _wing_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var aabb := mesh.get_aabb()
	var k := WINGSPAN / maxf(aabb.size.z, 0.001)
	mi.rotation.y = PI * 0.5
	mi.scale = Vector3.ONE * k
	mi.position = -(Basis(Vector3.UP, PI * 0.5) * aabb.get_center()) * k
	_body.add_child(mi)
	return true


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
