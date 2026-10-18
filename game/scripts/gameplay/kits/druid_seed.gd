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
	# flor que abre e some
	var flower := Node3D.new()
	p.add_child(flower)
	flower.global_position = at + Vector3(0, 0.25, 0)
	for i in 5:
		var petal := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.06
		sm.radial_segments = 6
		sm.rings = 2
		petal.mesh = sm
		petal.material_override = _mat(Color(1.0, 0.55, 0.8) if i % 2 == 0 else Color(1.0, 0.85, 0.95))
		var a := TAU * i / 5.0
		petal.position = Vector3(cos(a) * 0.13, 0, sin(a) * 0.13)
		petal.rotation.y = -a
		petal.scale = Vector3(1.0, 1.0, 1.6)
		flower.add_child(petal)
	flower.scale = Vector3.ONE * 0.2
	var t := flower.create_tween()
	t.tween_property(flower, "scale", Vector3.ONE * 1.6, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.25)
	t.tween_property(flower, "scale", Vector3.ZERO, 0.25)
	t.tween_callback(flower.queue_free)
	Vfx.particles(p, at + Vector3(0, 0.4, 0), "folha", 8, 0.8, Color(1.0, 0.7, 0.9, 0.95), 0.25, Vector2(1.0, 2.5), 80.0, -2.0)
	Vfx.particles(p, at + Vector3(0, 0.3, 0), "faisca", 10, 0.5, Color(0.7, 1.0, 0.6, 0.9), 0.22, Vector2(0.5, 2.0), 120.0, -0.5)
	queue_free()


func wither() -> void:
	remove_from_group("druid_seeds")
	var t := create_tween()
	t.tween_property(_sprout, "scale", Vector3.ZERO, 0.3)
	t.tween_callback(queue_free)


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
