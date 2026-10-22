class_name VineBarrier
extends StaticBody3D
## Porta da clareira durante a luta: raízes grossas com espinhos brotam do chão dos dois lados,
## se cruzam no vão e fecham a passagem; no meio, um nó de raiz com uma runa acesa mostra que a
## sala está trancada. Ao vencer, a runa apaga e as raízes voltam para a terra.
##
## Cada raiz é um tubo curvo (com os espinhos na mesma malha) e cresce pelo shader (`grow`, por
## instância): nasce da ponta da terra até a outra ponta, uma depois da outra.

var width := 3.6
var _shape: CollisionShape3D
var _roots: Array[MeshInstance3D] = []
var _knot: Node3D
var _rune_mat: ShaderMaterial
var _tween: Tween
var _closed := false

const ROOT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
instance uniform float grow = 0.0;
uniform float t_glow = 0.0;
varying float v_s;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
	v_s = UV.x;
	// respira devagar quando fechada (a raiz está viva)
	VERTEX += NORMAL * sin(TIME * 2.0 + UV.x * 6.0) * 0.012;
}
void fragment() {
	if (v_s > grow) discard;
	// casca: listras ao longo da raiz, nós escuros, musgo por cima
	float bark = noise(vec2(UV.x * 26.0, UV.y * 5.0));
	float lines = smoothstep(0.4, 0.5, abs(fract(UV.y * 6.0 + bark * 0.6) - 0.5));
	vec3 c = mix(vec3(0.13, 0.08, 0.04), vec3(0.36, 0.22, 0.11), bark);
	c = mix(c, c * 0.55, lines * 0.6);
	float moss = smoothstep(0.62, 0.8, noise(vec2(UV.x * 9.0, UV.y * 3.0 + 4.0))) * step(0.3, NORMAL.y);
	c = mix(c, vec3(0.25, 0.42, 0.15), moss);
	// espinhos (UV.y > 1.5) vermelho-escuros; a ponta que acabou de crescer acende
	if (UV.y > 1.5) c = vec3(0.45, 0.1, 0.08);
	float tip = smoothstep(grow - 0.08, grow, v_s) * step(grow, 0.999);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	EMISSION = vec3(1.0, 0.45, 0.15) * (tip * 1.5 + step(1.5, UV.y) * 0.25);
}
"""

const RUNE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform float on = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// runa: anel duplo + losango + quatro traços, pulsando
	float ring = smoothstep(0.06, 0.0, abs(r - 0.82)) + smoothstep(0.04, 0.0, abs(r - 0.66));
	float diamond = smoothstep(0.05, 0.0, abs(abs(p.x) + abs(p.y) - 0.5));
	float ticks = smoothstep(0.05, 0.0, abs(fract(a / 1.5708) - 0.5) - 0.44) * step(0.5, r) * step(r, 0.66);
	float v = clamp(ring + diamond + ticks, 0.0, 1.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	ALBEDO = vec3(1.0, 0.55, 0.2) * v * on * pulse * 1.6;
}
"""
static var _root_shader: Shader
static var _rune_shader: Shader
static var _root_mat: ShaderMaterial


func setup(door_width: float, thickness: float) -> void:
	width = door_width
	collision_layer = Layers.WORLD
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(door_width, 2.0, thickness)
	_shape.shape = box
	_shape.position.y = 1.0
	_shape.disabled = true
	add_child(_shape)
	if _root_shader == null:
		_root_shader = Shader.new()
		_root_shader.code = ROOT_SHADER
		_root_mat = ShaderMaterial.new()
		_root_mat.shader = _root_shader
		_rune_shader = Shader.new()
		_rune_shader.code = RUNE_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var half := door_width * 0.5
	# raízes grossas dos dois lados, cruzando o vão em arco (uma por cima da outra)
	var count := 9
	for i in count:
		var from_left := i % 2 == 0
		var side := -1.0 if from_left else 1.0
		var x0 := side * (half + rng.randf_range(-0.1, 0.35))
		var x1 := -side * rng.randf_range(0.1, half * 0.9)
		var top := rng.randf_range(0.8, 1.9)
		var z := rng.randf_range(-0.2, 0.2)
		var r0 := rng.randf_range(0.18, 0.26)
		var mi := MeshInstance3D.new()
		mi.mesh = _make_root(Vector3(x0, -0.05, z), Vector3(x0 * 0.6, top * 0.9, z + rng.randf_range(-0.25, 0.25)),
				Vector3(x1 * 0.5, top, z), Vector3(x1, top * rng.randf_range(0.2, 0.6), z + rng.randf_range(-0.2, 0.2)), r0, rng)
		mi.material_override = _root_mat
		mi.set_instance_shader_parameter("grow", 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_roots.append(mi)
	# raízes baixas saindo do chão no meio (tapam o pé do vão)
	for i in 4:
		var x := rng.randf_range(-half * 0.8, half * 0.8)
		var mi := MeshInstance3D.new()
		mi.mesh = _make_root(Vector3(x, -0.05, rng.randf_range(-0.2, 0.2)), Vector3(x + 0.2, 0.6, 0.0),
				Vector3(x - 0.2, 0.9, 0.1), Vector3(x + rng.randf_range(-0.4, 0.4), rng.randf_range(0.7, 1.2), 0.0), 0.15, rng)
		mi.material_override = _root_mat
		mi.set_instance_shader_parameter("grow", 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_roots.append(mi)
	# nó de raiz com a runa no meio (a tranca)
	_knot = Node3D.new()
	_knot.position = Vector3(0, 1.15, 0)
	add_child(_knot)
	var knot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.5
	sm.radial_segments = 10
	sm.rings = 6
	knot.mesh = sm
	var km := StandardMaterial3D.new()
	km.albedo_color = Color(0.3, 0.19, 0.1)
	km.roughness = 1.0
	knot.material_override = km
	knot.scale = Vector3(1.0, 1.0, 0.6)
	_knot.add_child(knot)
	for face in [-1.0, 1.0]:  # a runa dos dois lados da porta
		var rune := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.75
		rune.mesh = q
		if _rune_mat == null:
			_rune_mat = ShaderMaterial.new()
			_rune_mat.shader = _rune_shader
		rune.material_override = _rune_mat
		rune.position = Vector3(0, 0, 0.21 * face)
		rune.rotation.y = 0.0 if face > 0 else PI
		_knot.add_child(rune)
	_knot.scale = Vector3.ONE * 0.01
	visible = false


## Raiz: tubo numa curva de Bézier (a → d), afinando, com espinhos ao longo dela.
## UV.x = posição ao longo da raiz (0 → 1, para o crescimento); UV.y > 1.5 marca os espinhos.
static func _make_root(a: Vector3, b: Vector3, c: Vector3, d: Vector3, r0: float, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	var sides := 7
	var pts: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / steps
		var ab := a.lerp(b, t); var bc := b.lerp(c, t); var cd := c.lerp(d, t)
		pts.append(ab.lerp(bc, t).lerp(bc.lerp(cd, t), t))
	var base := 0
	for i in steps + 1:
		var t := float(i) / steps
		var fwd := (pts[mini(i + 1, steps)] - pts[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.FORWARD if absf(fwd.z) < 0.9 else Vector3.UP).normalized()
		var up := side.cross(fwd).normalized()
		var r := r0 * lerpf(1.0, 0.18, t) * (1.0 + 0.15 * sin(t * 17.0))
		for j in sides + 1:
			var ang := TAU * j / sides
			var n := side * cos(ang) + up * sin(ang)
			st.set_normal(n)
			st.set_uv(Vector2(t, float(j) / sides))
			st.add_vertex(pts[i] + n * r)
	for i in steps:
		for j in sides:
			var k := i * (sides + 1) + j
			st.add_index(k); st.add_index(k + sides + 1); st.add_index(k + 1)
			st.add_index(k + 1); st.add_index(k + sides + 1); st.add_index(k + sides + 2)
	base = (steps + 1) * (sides + 1)
	# espinhos: cones curtos saindo da raiz
	for s in 5:
		var i := rng.randi_range(2, steps - 2)
		var t := float(i) / steps
		var fwd := (pts[i + 1] - pts[i - 1]).normalized()
		var side := fwd.cross(Vector3.FORWARD if absf(fwd.z) < 0.9 else Vector3.UP).normalized()
		var up := side.cross(fwd).normalized()
		var ang := rng.randf() * TAU
		var out := (side * cos(ang) + up * sin(ang)).normalized()
		var r := r0 * lerpf(1.0, 0.18, t)
		var root_c := pts[i] + out * r * 0.8
		var tip := pts[i] + out * (r + 0.16)
		var ring_n := 4
		for j in ring_n:
			var a2 := TAU * j / ring_n
			var p := root_c + (fwd * cos(a2) + out.cross(fwd) * sin(a2)) * 0.035
			st.set_normal(out)
			st.set_uv(Vector2(t, 2.0))
			st.add_vertex(p)
		st.set_normal(out)
		st.set_uv(Vector2(t, 2.0))
		st.add_vertex(tip)
		for j in ring_n:
			st.add_index(base + j)
			st.add_index(base + (j + 1) % ring_n)
			st.add_index(base + ring_n)
		base += ring_n + 1
	return st.commit()


func close() -> void:
	_shape.set_deferred("disabled", false)
	visible = true
	_closed = true
	_animate(true)
	if is_inside_tree():
		FxKit.ground_wave(get_parent(), global_position, width * 0.75, Color(0.6, 0.38, 0.2), 0.35, 1.0, 1.0)
		MobFx.chunks(get_parent(), global_position + Vector3(0, 0.2, 0), Color(0.32, 0.22, 0.14), 8, 0.08, Vector2(2.0, 4.0))


func open() -> void:
	_shape.set_deferred("disabled", true)
	_closed = false
	_animate(false)
	if is_inside_tree() and visible:
		Vfx.particles(get_parent(), global_position + Vector3(0, 0.3, 0), "poeira", 10, 0.8, Color(0.6, 0.5, 0.38, 0.6), 1.0, Vector2(1.0, 2.0), 80.0, -1.0, false, true, 1.0)


## Fechar: as raízes brotam uma atrás da outra, o nó aparece e a runa acende.
## Abrir: a runa apaga, o nó encolhe e as raízes voltam para a terra.
func _animate(closing: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	for k in _roots.size():
		var mi := _roots[k]
		var from: float = mi.get_instance_shader_parameter("grow")
		var delay := k * 0.035 if closing else (_roots.size() - k) * 0.02
		_tween.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("grow", v),
				from, 1.0 if closing else 0.0, 0.3 if closing else 0.25).set_delay(delay) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if closing else Tween.EASE_IN)
	if closing:
		_tween.tween_property(_knot, "scale", Vector3.ONE, 0.25).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_method(func(v: float) -> void: _rune_mat.set_shader_parameter("on", v), 0.0, 1.0, 0.3).set_delay(0.45)
	else:
		_tween.tween_method(func(v: float) -> void: _rune_mat.set_shader_parameter("on", v), 1.0, 0.0, 0.15)
		_tween.tween_property(_knot, "scale", Vector3.ONE * 0.01, 0.2).set_delay(0.1)
		_tween.chain().tween_callback(func() -> void:
			if not _closed:
				visible = false)
