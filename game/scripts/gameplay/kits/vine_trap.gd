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


const VINE_SHADER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform float grow = 0.0;      // 0 → 1: o cipó brota do chão
uniform float curl = 0.0;      // quanto a ponta enrola (fecha em volta do preso)
uniform float sway = 1.0;
uniform float seed = 0.0;
varying float v_s;
void vertex() {
	float s = UV.x;                       // 0 = raiz, 1 = ponta
	v_s = s;
	// balança devagar; a ponta mais que a raiz
	VERTEX.x += sin(TIME * 2.2 + seed + s * 3.0) * 0.06 * s * sway;
	// enrolar: a ponta dobra para dentro (eixo -Z do cipó) e para baixo
	float c = curl * s * s;
	VERTEX.z -= c * 0.9;
	VERTEX.y -= c * c * 0.35;
	// brotar: o que passou do "grow" encolhe para dentro da ponta
	VERTEX.y *= mix(0.25, 1.0, clamp(grow, 0.0, 1.0));
}
void fragment() {
	if (v_s > grow) discard;
	float stripe = smoothstep(0.35, 0.5, abs(fract(UV.x * 9.0 + UV.y * 1.5) - 0.5));
	vec3 base = mix(vec3(0.16, 0.26, 0.08), vec3(0.42, 0.62, 0.18), v_s);
	ALBEDO = mix(base, base * 0.6, stripe * 0.5);
	ROUGHNESS = 0.9;
	// a ponta acende de leve (magia da mata)
	EMISSION = vec3(0.3, 0.9, 0.35) * smoothstep(0.7, 1.0, v_s) * 1.2;
}
"""
static var _vine_shader: Shader
static var _vine_mesh: ArrayMesh
const VINES := 10
var _vines: Array[Node3D] = []
var _vine_mat: ShaderMaterial
var _coils: Array[MeshInstance3D] = []
var _leaves: Array[MeshInstance3D] = []
static var _coil_mat: StandardMaterial3D


static func _coil_material() -> StandardMaterial3D:
	if _coil_mat == null:
		_coil_mat = StandardMaterial3D.new()
		_coil_mat.albedo_color = Color(0.28, 0.45, 0.14)
		_coil_mat.emission_enabled = true
		_coil_mat.emission = Color(0.35, 0.9, 0.3)
		_coil_mat.emission_energy_multiplier = 0.35
		_coil_mat.roughness = 0.9
	return _coil_mat


func _ready() -> void:
	add_to_group("floor_effects")
	# o laço de cipó pintado no chão (imagem), por baixo dos cipós que brotam
	_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * RADIUS * 2.3
	quad.orientation = PlaneMesh.FACE_Y
	_ring.mesh = quad
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.material_override = Vfx.sprite_material("cipo_armadilha", Color(1.15, 1.25, 1.1, 1.0), false, false)
	add_child(_ring)
	# cipós de verdade: tubos que brotam do chão em volta do laço, inclinados para fora,
	# balançando, com a ponta acesa
	if _vine_shader == null:
		_vine_shader = Shader.new()
		_vine_shader.code = VINE_SHADER
		_vine_mesh = _make_vine()
	_vine_mat = ShaderMaterial.new()
	_vine_mat.shader = _vine_shader
	_vine_mat.set_shader_parameter("seed", randf() * 10.0)
	for i in VINES:
		var a := TAU * i / VINES + randf_range(-0.2, 0.2)
		var holder := Node3D.new()
		holder.position = Vector3(cos(a), 0.0, sin(a)) * RADIUS * 0.85
		holder.rotation.y = -a + PI * 0.5        # -Z do cipó aponta para o centro
		holder.rotation.x = deg_to_rad(-28.0)    # inclinado para fora
		holder.scale = Vector3.ONE * randf_range(0.8, 1.15)
		var vine := MeshInstance3D.new()
		vine.mesh = _vine_mesh
		vine.material_override = _vine_mat
		vine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(vine)
		# folhas no cipó, abertas para cima: de cima (câmera) é o que mais aparece
		for k in 2:
			var leaf := MeshInstance3D.new()
			var lq := QuadMesh.new()
			lq.size = Vector2(0.42, 0.42)
			leaf.mesh = lq
			leaf.material_override = _leaf_material()
			leaf.position = Vector3(0.0, 0.45 + k * 0.4, -0.06 - k * 0.08)
			leaf.rotation = Vector3(deg_to_rad(-70.0), randf() * TAU, 0.0)
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			leaf.scale = Vector3.ONE * 0.01
			vine.add_child(leaf)
			_leaves.append(leaf)
		add_child(holder)
		_vines.append(holder)
	var grow := create_tween()
	grow.tween_method(func(v: float) -> void: _vine_mat.set_shader_parameter("grow", v), 0.0, 1.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for leaf in _leaves:
		grow.parallel().tween_property(leaf, "scale", Vector3.ONE, 0.25).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_inside_tree():
		FxKit.ground_wave(get_parent(), global_position, RADIUS * 1.3, Color(0.45, 0.85, 0.3), 0.3)


static var _leaf_mat: StandardMaterial3D


static func _leaf_material() -> StandardMaterial3D:
	if _leaf_mat == null:
		_leaf_mat = StandardMaterial3D.new()
		_leaf_mat.albedo_texture = Vfx.tex("folha")
		_leaf_mat.albedo_color = Color(0.75, 1.0, 0.6)
		_leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_leaf_mat.alpha_scissor_threshold = 0.4
		_leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leaf_mat.roughness = 0.9
	return _leaf_mat


## Um cipó: tubo afinando, com uma curva suave, raiz em (0,0,0) e ponta para cima (~0,9 m).
static func _make_vine() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	var sides := 6
	for i in steps + 1:
		var s := float(i) / steps
		var center := Vector3(0, s * 1.35, -sin(s * 1.6) * 0.3)
		var r := lerpf(0.12, 0.018, s)
		for j in sides + 1:
			var a := TAU * j / sides
			var n := Vector3(cos(a), 0, sin(a))
			st.set_normal(n)
			st.set_uv(Vector2(s, float(j) / sides))
			st.add_vertex(center + n * r)
	for i in steps:
		for j in sides:
			var k := i * (sides + 1) + j
			st.add_index(k)
			st.add_index(k + sides + 1)
			st.add_index(k + 1)
			st.add_index(k + 1)
			st.add_index(k + sides + 1)
			st.add_index(k + sides + 2)
	return st.commit()


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


## Fecha em volta do bicho: os cipós se esticam para cima, inclinam para dentro e enrolam a
## ponta em volta dele; folhas voam e o laço do chão aperta.
func _snap(enemy: Node3D) -> void:
	set_physics_process(false)
	global_position = Vector3(enemy.global_position.x, global_position.y, enemy.global_position.z)
	Vfx.particles(get_parent(), global_position + Vector3(0, 0.3, 0), "folha", 12, 1.0, Color(1, 1, 1, 0.9), 0.35, Vector2(2.0, 4.0), 60.0, -6.0, false)
	FxKit.impact(get_parent(), global_position + Vector3(0, 0.8, 0), 1.8, Color(0.5, 1.0, 0.4), 0.2)
	var size := 1.0
	if "data" in enemy and enemy.data:
		size = clampf(enemy.data.body_scale, 0.7, 2.0)
	var t := create_tween()
	t.set_parallel(true)
	for v in _vines:
		var flat := Vector3(v.position.x, 0, v.position.z)
		t.tween_property(v, "position", flat.normalized() * 0.55 * size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(v, "rotation:x", deg_to_rad(12.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(v, "scale", Vector3(1.3, 1.5 * size, 1.3), 0.16)
	t.tween_method(func(c: float) -> void: _vine_mat.set_shader_parameter("curl", c), 0.0, 1.4, 0.2)
	t.tween_method(func(c: float) -> void: _vine_mat.set_shader_parameter("sway", c), 1.0, 0.25, 0.2)
	t.tween_property(_ring, "scale", Vector3(0.55, 0.8, 0.55), 0.15)
	# laços de cipó apertando o corpo do bicho (de cima lê como "amarrado")
	for k in 2:
		var coil := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42 * size
		tm.outer_radius = 0.58 * size
		tm.rings = 20
		tm.ring_segments = 8
		coil.mesh = tm
		coil.material_override = _coil_material()
		coil.position = Vector3(0, (0.35 + k * 0.45) * size, 0)
		coil.rotation = Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		coil.scale = Vector3.ONE * 1.8
		coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(coil)
		t.tween_property(coil, "scale", Vector3.ONE, 0.18).set_delay(0.05 * k).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_coils.append(coil)
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
	FxKit.ground_wave(get_parent(), global_position, timbo_radius, Color(0.55, 0.9, 0.3), 0.45, 0.0, 1.0)
	FxKit.impact(get_parent(), global_position + Vector3(0, 0.8, 0), 2.4, Color(0.55, 1.0, 0.35), 0.3)


## Os cipós voltam para a terra (encolhem até a raiz) e o laço some.
func _vanish() -> void:
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_method(func(v: float) -> void: _vine_mat.set_shader_parameter("grow", v), 1.0, 0.0, 0.3)
	t.tween_property(_ring, "scale", Vector3(0.01, 1.0, 0.01), 0.3)
	for c in _coils + _leaves:
		t.tween_property(c, "scale", Vector3.ONE * 0.01, 0.25)
	t.chain().tween_callback(queue_free)
