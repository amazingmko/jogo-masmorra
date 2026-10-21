class_name DruidSeed
extends Node3D
## Muda plantada pela Semente da Druida. Fica no chão por um tempo; o Florescer (ou o fim do
## Boto) faz todas abrirem em flor de uma vez. Talentos: curam por perto (Muda Viva) e mordem
## inimigos que passam (Muda Carnívora).

var kit: DruidKit
var life := 8.0
var _age := 0.0
var _bite_acc := 0.0
var _sprout: Node3D
var _leaves: Array[MeshInstance3D] = []

const LEAF := Color(0.36, 0.72, 0.28)
const STEM := Color(0.3, 0.5, 0.2)


func _ready() -> void:
	add_to_group("druid_seeds")
	add_to_group("floor_effects")
	_sprout = Node3D.new()
	add_child(_sprout)
	_sprout.scale = Vector3.ONE * 0.05
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.025
	cyl.height = 0.32
	cyl.radial_segments = 5
	cyl.rings = 1
	stem.mesh = cyl
	stem.position.y = 0.16
	stem.material_override = _mat(STEM)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprout.add_child(stem)
	for i in 3:
		var leaf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.05
		sm.radial_segments = 6
		sm.rings = 2
		leaf.mesh = sm
		leaf.material_override = _mat(LEAF.lightened(0.1 * i))
		var a := TAU * i / 3.0
		leaf.position = Vector3(cos(a) * 0.08, 0.26 + 0.04 * i, sin(a) * 0.08)
		leaf.rotation = Vector3(0.5 * sin(a), a, 0.5 * cos(a))
		leaf.scale = Vector3(1.0, 1.0, 1.8)
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sprout.add_child(leaf)
		_leaves.append(leaf)
	# brilho verde no chão: dá para ver as mudas no meio da luta
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.7
	quad.orientation = PlaneMesh.FACE_Y
	ring.mesh = quad
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_texture = Vfx.tex("anel_som")
	rm.albedo_color = Color(0.5, 1.0, 0.45, 0.5)
	ring.material_override = rm
	ring.position.y = 0.04
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	create_tween().tween_property(_sprout, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# o anel do chão pulsa devagar (a muda está viva)
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(ring, "scale", Vector3.ONE * 1.25, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ring, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	if is_inside_tree():
		FxKit.ground_wave(get_parent(), global_position, 0.9, Color(0.5, 1.0, 0.45), 0.25)
		MobFx.chunks(get_parent(), global_position + Vector3(0, 0.1, 0), Color(0.35, 0.25, 0.15), 4, 0.05, Vector2(1.0, 2.0))


func _process(delta: float) -> void:
	_age += delta
	_sprout.rotation.z = sin(_age * 2.5) * 0.08
	if _age >= life:
		wither()
		return
	if kit == null or not is_instance_valid(kit.player):
		return
	kit.on_seed_tick(self, delta)


## Abre em flor: efeito, cura e o que os talentos mandarem (feito pelo kit).
func bloom() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group("druid_seeds")
	var p := get_parent()
	var at := global_position
	# flor de maracujá em 3D: as pétalas abrem de pé para deitadas, a coroa roxa gira, e tudo
	# cai e some; pólen sobe e uma onda verde corre pelo chão
	_flower(p, at)
	FxKit.ground_wave(p, at, 1.8, Color(0.55, 1.0, 0.5), 0.35, 0.0, 0.0, Color(1.0, 0.9, 1.0))
	Vfx.particles(p, at + Vector3(0, 0.5, 0), "faisca", 10, 1.0, Color(1.0, 0.95, 0.6), 0.2, Vector2(0.4, 1.2), 30.0, 0.6)
	Vfx.particles(p, at + Vector3(0, 0.4, 0), "folha", 8, 0.8, Color(1.0, 0.7, 0.9, 0.95), 0.25, Vector2(1.0, 2.5), 80.0, -2.0)
	Vfx.particles(p, at + Vector3(0, 0.3, 0), "faisca", 10, 0.5, Color(0.7, 1.0, 0.6, 0.9), 0.22, Vector2(0.5, 2.0), 120.0, -0.5)
	queue_free()


func wither() -> void:
	remove_from_group("druid_seeds")
	var t := create_tween()
	t.tween_property(_sprout, "scale", Vector3.ZERO, 0.3)
	t.tween_callback(queue_free)


const PETAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform vec3 tip : source_color = vec3(0.98, 0.96, 1.0);
uniform vec3 base : source_color = vec3(0.86, 0.72, 0.98);
uniform float fade = 1.0;
void fragment() {
	// pétala: forma de gota arredondada (base estreita, ponta larga), com nervura no meio
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y);
	float w = sin(p.y * 3.1416) * (0.55 + 0.45 * p.y);
	if (abs(p.x) > w || p.y < 0.02) discard;
	float vein = smoothstep(0.06, 0.0, abs(p.x)) * 0.25;
	vec3 c = mix(base, tip, smoothstep(0.1, 0.8, p.y)) - vein;
	ALBEDO = c;
	if (fade < 0.999) {
		float n = fract(sin(dot(floor(UV * 12.0), vec2(12.9, 78.2))) * 43758.5);
		if (n > fade) discard;
	}
}
"""
static var _petal_shader: Shader


## A flor de maracujá: 8 pétalas brancas-lilás que abrem, a coroa de filamentos roxos e o miolo.
static func _flower(parent: Node, at: Vector3) -> void:
	if _petal_shader == null:
		_petal_shader = Shader.new()
		_petal_shader.code = PETAL_SHADER
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3(0, 0.08, 0)
	root.rotation.y = randf() * TAU
	var pm := ShaderMaterial.new()
	pm.shader = _petal_shader
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.62)
	quad.center_offset = Vector3(0, 0.31, 0)     # gira pela base
	var petals: Array[Node3D] = []
	for i in 8:
		var hinge := Node3D.new()
		hinge.rotation.y = TAU * i / 8.0
		root.add_child(hinge)
		var petal := MeshInstance3D.new()
		petal.mesh = quad
		petal.material_override = pm
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		petal.position = Vector3(0, 0, 0.06)
		petal.rotation.x = deg_to_rad(10.0)          # fechada: quase de pé
		hinge.add_child(petal)
		petals.append(petal)
	# coroa: anel de filamentos roxos (raios finos), miolo verde-amarelo
	var corona := MeshInstance3D.new()
	var cq := QuadMesh.new()
	cq.size = Vector2.ONE * 0.75
	cq.orientation = PlaneMesh.FACE_Y
	corona.mesh = cq
	corona.material_override = FxKit.material("impact", {"color": Color(0.55, 0.2, 0.75), "spikes": 22.0, "progress": 0.25})
	corona.position.y = 0.06
	corona.scale = Vector3.ONE * 0.1
	root.add_child(corona)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.1
	core.mesh = sm
	core.material_override = _mat(Color(0.75, 0.85, 0.3))
	core.position.y = 0.09
	root.add_child(core)
	var t := root.create_tween().set_parallel()
	for petal in petals:
		t.tween_property(petal, "rotation:x", deg_to_rad(80.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(corona, "scale", Vector3.ONE, 0.3).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(root, "rotation:y", root.rotation.y + 0.9, 1.0)
	t.chain().tween_interval(0.25)
	t.chain().tween_method(func(v: float) -> void: pm.set_shader_parameter("fade", v), 1.0, 0.0, 0.35)
	t.parallel().tween_property(corona, "scale", Vector3.ZERO, 0.3)
	t.parallel().tween_property(core, "scale", Vector3.ZERO, 0.3)
	t.chain().tween_callback(root.queue_free)


static var _mats := {}


static func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.disable_receive_shadows = true
		_mats[key] = m
	return _mats[key]
