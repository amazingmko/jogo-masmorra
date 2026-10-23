class_name Telegraph
extends Node3D
## Aviso de ataque desenhado no chão. O contorno mostra a área; o preenchimento cresce até
## o momento do impacto. Quando o tempo acaba, quem estiver dentro leva o dano/efeito.
## Formas: círculo, linha (investida), cone (golpe à frente) e mega (sala inteira, menos zonas seguras).

signal resolved(hit: bool)

enum Shape { CIRCLE, LINE, CONE, MEGA }

var shape: Shape = Shape.CIRCLE
var radius := 1.5
var length := 6.0
var width := 1.2
var half_angle_deg := 60.0
var duration := 0.6
var damage := 0
var damage_percent := 0.0
var effect: int = EnemyAttack.Effect.NONE
var effect_duration := 0.0
var effect_power := 0
var color := Color("e05555")
## Segundos que a área continua no chão aplicando o efeito (poças).
var linger := 0.0
## Mega magia: centros das zonas seguras (posição global) e raio delas.
var safe_zones: Array[Vector3] = []
var safe_radius := 1.7
## Só visual (ex.: mira de disparo): não causa dano.
var visual_only := false
## O golpe sai de quem atacou (garra, cone, grito): parede, pilar, pedra ou tronco no meio protegem.
## Falso para o que cai do alto (ouriços, árvores) e para a mega magia (que tem as zonas seguras).
var blockable := false
## Ataque que criou o aviso (os efeitos próprios dele ficam em MobFx).
var attack_id: StringName = &""
var _pre_fx_done := false
## Multijogador: cópia do aviso de um bicho do anfitrião (desenha e toca os efeitos, sem dano).
var net_copy := false

var _t := 0.0
var _resolved := false
var _linger_tick := 0.0
## Área que prende (teia no chão): prende uma vez; só prende de novo se o herói sair e pisar outra vez.
var _holding := false
var _holding_by := {}
var _fill: MeshInstance3D
var _fill_mat: ShaderMaterial

## Aviso "vivo" num shader só: contorno com tracejado correndo, preenchimento que cresce do
## centro (ou da origem, na linha) com a frente acesa, listras andando e pisca no fim.
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 color : source_color = vec4(0.88, 0.33, 0.33, 1.0);
uniform float progress = 0.0;
uniform float flash = 0.0;
uniform float alpha_mul = 1.0;
uniform float half_angle = 3.1416;   // cone (radianos); círculo = PI
uniform float is_line = 0.0;
uniform float length_m = 6.0;
uniform float size_m = 3.0;          // diâmetro (círculo) ou largura (linha), para a borda ter espessura certa
void fragment() {
	float inside;
	float edge;
	float fill;
	float front;
	float stripes;
	if (is_line > 0.5) {
		float x = abs(UV.x - 0.5) * 2.0;      // 0 no meio, 1 na borda
		float y = UV.y;                       // 0 = quem ataca, 1 = ponta (UV.y cresce para +Z)
		float bw = 0.12 / size_m * 2.0;
		inside = 1.0;
		edge = step(1.0 - bw * 2.0, x) + step(1.0 - 0.06 / length_m * 2.0, y);
		fill = step(y, progress);
		front = smoothstep(0.05, 0.0, abs(y - progress)) * step(0.01, progress);
		// setas (chevrons) correndo para a frente
		float v = fract(y * length_m / 1.1 - x * 0.35 - TIME * 1.8);
		stripes = smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.28, 0.36, v));
	} else {
		vec2 p = UV * 2.0 - 1.0;              // p.y = frente (+Z do aviso)
		float r = length(p);
		float a = atan(p.x, p.y);
		float bw = 0.14 / size_m * 2.0;
		inside = step(r, 1.0) * step(abs(a), half_angle);
		float ang_edge = (half_angle < 3.1) ? step(half_angle - bw / max(r, 0.15), abs(a)) : 0.0;
		edge = step(1.0 - bw, r) + ang_edge;
		// tracejado correndo em volta da borda
		float dash = step(0.45, fract(a * 6.0 / 3.1416 * max(size_m * 0.5, 1.0) * 0.5 - TIME * 1.2));
		edge *= mix(0.65, 1.0, dash);
		fill = step(r, progress);
		front = smoothstep(0.06, 0.0, abs(r - progress)) * step(0.01, progress);
		float v = fract((p.x + p.y) * size_m * 0.9 - TIME * 1.2);
		stripes = smoothstep(0.0, 0.1, v) * (1.0 - smoothstep(0.35, 0.45, v));
	}
	// pisca forte no fim (último quarto)
	float blink = progress > 0.72 ? 0.5 + 0.5 * sin(TIME * 30.0) : 0.0;
	float a_out = clamp(edge, 0.0, 1.0) * 0.9;
	float a_fill = fill * (0.3 + 0.25 * progress + stripes * 0.12 + blink * 0.15);
	float a_bg = 0.08 + stripes * 0.05;
	vec3 c = color.rgb;
	c = mix(c, vec3(1.0, 0.95, 0.85), front * 0.8 + clamp(edge, 0.0, 1.0) * 0.15);
	c = mix(c, vec3(1.0), flash);
	ALBEDO = c;
	ALPHA = inside * clamp(max(max(a_out, a_fill), max(a_bg, front)) + flash * 0.6, 0.0, 1.0) * alpha_mul;
}
"""
static var _shader: Shader


## Rede: tudo o que é preciso para desenhar o mesmo aviso em outro aparelho.
func pack() -> Dictionary:
	return {"shape": shape, "radius": radius, "length": length, "width": width, "half": half_angle_deg,
		"duration": duration, "color": color, "linger": linger, "safe": safe_zones, "safe_r": safe_radius,
		"id": attack_id, "visual": visual_only, "pos": global_position if is_inside_tree() else position,
		"rot": rotation.y, "effect": effect}


static func unpack(d: Dictionary) -> Telegraph:
	var t := Telegraph.new()
	t.shape = int(d.shape) as Shape
	t.radius = d.radius
	t.length = d.length
	t.width = d.width
	t.half_angle_deg = d.half
	t.duration = d.duration
	t.color = d.color
	t.linger = d.linger
	var zones: Array[Vector3] = []
	zones.assign(d.safe)
	t.safe_zones = zones
	t.safe_radius = d.safe_r
	t.attack_id = d.id
	t.effect = int(d.effect)
	t.visual_only = bool(d.visual)
	t.net_copy = true
	t.position = d.pos
	t.rotation.y = d.rot
	return t


## Cria o aviso de um ataque. origin: posição no chão; direction: para onde o ataque aponta.
static func for_attack(attack: EnemyAttack, origin: Vector3, direction: Vector3, damage_mult: float) -> Telegraph:
	var t := Telegraph.new()
	t.attack_id = attack.id
	t.duration = attack.windup
	t.damage = int(round(attack.damage * damage_mult))
	t.damage_percent = attack.damage_percent_of_target
	t.effect = attack.effect
	t.effect_duration = attack.effect_duration
	t.effect_power = attack.effect_power
	t.color = attack.color
	t.linger = attack.linger
	match attack.kind:
		EnemyAttack.Kind.CHARGE:
			t.shape = Shape.LINE
			t.length = attack.length
			t.width = attack.radius
		EnemyAttack.Kind.MEGA:
			t.shape = Shape.MEGA
			t.radius = attack.radius
		_:
			t.radius = attack.radius
			if attack.kind == EnemyAttack.Kind.MELEE and attack.cone_half_angle > 0.0:
				t.shape = Shape.CONE
				t.half_angle_deg = attack.cone_half_angle
			else:
				t.shape = Shape.CIRCLE
	t.position = Vector3(origin.x, 0.04, origin.z)
	var flat := Vector3(direction.x, 0, direction.z)
	if flat.length() > 0.01:
		t.rotation.y = atan2(flat.x, flat.z)
	return t


func _ready() -> void:
	add_to_group("telegraphs")
	_build()


func _process(delta: float) -> void:
	_t += delta
	if not _resolved:
		var p := clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
		_set_fill(p)
		if not _pre_fx_done and not visual_only and duration - _t <= 0.45:
			_pre_fx_done = true
			MobFx.before_impact(self)
		if _t >= duration:
			_resolve()
	elif linger > 0.0:
		_linger_tick += delta
		var tick := _linger_tick >= 0.5
		if tick:
			_linger_tick = 0.0
		if not net_copy:
			for player in _heroes():
				var key: int = player.get_instance_id()
				if not contains(player.global_position):
					_holding_by.erase(key)
				elif effect == EnemyAttack.Effect.ROOT:
					# prende na hora em que pisa; parado dentro (ou ainda preso) não prende de novo
					if not _holding_by.has(key):
						_holding_by[key] = true
						player.receive_attack(0, effect, effect_duration, effect_power, global_position)
				elif tick:
					player.receive_attack(0, effect, effect_duration, effect_power, global_position)
		_holding = not _holding_by.is_empty()
		if _t >= duration + linger:
			queue_free()


## True se o ponto (global) está na área perigosa.
func contains(point: Vector3) -> bool:
	var local := to_local(Vector3(point.x, global_position.y, point.z))
	var flat := Vector2(local.x, local.z)
	match shape:
		Shape.CIRCLE:
			return flat.length() <= radius
		Shape.LINE:
			return local.z >= -0.5 and local.z <= length and absf(local.x) <= width * 0.5 + 0.3
		Shape.CONE:
			if flat.length() > radius:
				return false
			if flat.length() < 0.6:
				return true
			return rad_to_deg(absf(atan2(local.x, local.z))) <= half_angle_deg
		Shape.MEGA:
			if flat.length() > radius:
				return false
			for zone in safe_zones:
				if Vector2(point.x - zone.x, point.z - zone.z).length() <= safe_radius:
					return false
			return true
	return false


## Ponto para onde fugir (usado pelo robô de testes e, no futuro, por ajudantes).
func escape_point(from: Vector3) -> Vector3:
	match shape:
		Shape.MEGA:
			var best := global_position
			var best_d := INF
			for zone in safe_zones:
				var d := from.distance_to(zone)
				if d < best_d:
					best_d = d
					best = zone
			return best
		Shape.LINE:
			var local := to_local(from)
			var side := 1.0 if local.x >= 0.0 else -1.0
			return to_global(Vector3(side * (width * 0.5 + 1.5), 0, local.z))
		_:
			var away := Vector3(from.x - global_position.x, 0, from.z - global_position.z)
			if away.length() < 0.1:
				away = Vector3(1, 0, 0)
			return global_position + away.normalized() * (radius + 1.5)


func time_left() -> float:
	return maxf(duration - _t, 0.0)


func is_pending() -> bool:
	return not _resolved and not visual_only


# ---------- interno ----------

func _resolve() -> void:
	_resolved = true
	var hit := false
	if not visual_only and not net_copy:
		for player in _heroes():
			if contains(player.global_position) and (not blockable or Layers.clear_path(get_world_3d(), global_position, player.global_position)):
				var amount := damage + int(round(damage_percent * player.health.max_health))
				player.receive_attack(amount, effect, effect_duration, effect_power, global_position, shape == Shape.MEGA)
				hit = true
				if effect == EnemyAttack.Effect.ROOT:
					_holding_by[player.get_instance_id()] = true
	resolved.emit(hit)
	if not visual_only:
		MobFx.on_resolve(self)
	# Pisca e some (ou fica como poça).
	_fill_mat.set_shader_parameter("flash", 1.0)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _fill_mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.18)
	if linger > 0.0:
		tween.parallel().tween_method(func(v: float) -> void: _fill_mat.set_shader_parameter("alpha_mul", v), 1.0, 0.6, 0.2)
	else:
		tween.parallel().tween_method(func(v: float) -> void: _fill_mat.set_shader_parameter("alpha_mul", v), 1.0, 0.0, 0.2)
		tween.tween_callback(queue_free)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null


## Todos os heróis de pé (no multijogador, a área pega qualquer um).
func _heroes() -> Array:
	if not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group("heroes").filter(func(h) -> bool: return not h.health.is_dead)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_mesh(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = _shader
	_fill_mat.set_shader_parameter("color", color)
	_fill_mat.render_priority = 1
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	match shape:
		Shape.CIRCLE, Shape.MEGA, Shape.CONE:
			quad.size = Vector2.ONE * radius * 2.0
			_fill_mat.set_shader_parameter("size_m", radius * 2.0)
			if shape == Shape.CONE:
				_fill_mat.set_shader_parameter("half_angle", deg_to_rad(half_angle_deg))
			_fill = _add_mesh(quad, _fill_mat, Vector3(0, 0.01, 0))
			if shape == Shape.CIRCLE and Vfx.tex("aviso_circulo"):
				# círculo rúnico (imagem) por cima, girando devagar
				var rq := QuadMesh.new()
				rq.size = Vector2.ONE * radius * 2.12
				rq.orientation = PlaneMesh.FACE_Y
				var rune := _add_mesh(rq, Vfx.sprite_material("aviso_circulo", Color(color.r, color.g, color.b, 0.55)), Vector3(0, 0.02, 0))
				rune.create_tween().set_loops().tween_property(rune, "rotation:y", TAU, 9.0).as_relative()
			if shape == Shape.MEGA:
				_build_safe_zones()
		Shape.LINE:
			quad.size = Vector2(width, length)
			_fill_mat.set_shader_parameter("is_line", 1.0)
			_fill_mat.set_shader_parameter("size_m", width)
			_fill_mat.set_shader_parameter("length_m", length)
			_fill = _add_mesh(quad, _fill_mat, Vector3(0, 0.01, length * 0.5))
	_set_fill(0.0)


func _set_fill(p: float) -> void:
	if _fill_mat:
		_fill_mat.set_shader_parameter("progress", p)


func _build_safe_zones() -> void:
	var safe_mat := _mat(Color(0.43, 0.86, 0.48, 0.55))
	for zone in safe_zones:
		var local := to_local(zone)
		var disc := CylinderMesh.new()
		disc.top_radius = safe_radius
		disc.bottom_radius = safe_radius
		disc.height = 0.06
		disc.radial_segments = 32
		_add_mesh(disc, safe_mat, Vector3(local.x, 0.03, local.z))
		var beam := CylinderMesh.new()
		beam.top_radius = 0.15
		beam.bottom_radius = safe_radius * 0.8
		beam.height = 3.0
		var beam_mat := _mat(Color(0.43, 0.86, 0.48, 0.18))
		_add_mesh(beam, beam_mat, Vector3(local.x, 1.5, local.z))


static func _cone_mesh(r: float, half_deg: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 20
	var half := deg_to_rad(half_deg)
	for i in steps:
		var a0 := -half + (2.0 * half) * i / steps
		var a1 := -half + (2.0 * half) * (i + 1) / steps
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a0), 0, cos(a0)) * r)
		verts.append(Vector3(sin(a1), 0, cos(a1)) * r)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
