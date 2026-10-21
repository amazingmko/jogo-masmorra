class_name NightEyes
extends Node3D
## Olhos brilhando no escuro (noite): dois pontinhos na cabeça do bicho, que seguem o osso da
## cabeça e ficam lado a lado em relação à frente do corpo.

var enemy: Node3D
var bone_names: Array = []
var color := Color(1.0, 0.82, 0.3)
var _skeleton: Skeleton3D
var _bone := -1
var _eyes: Array[MeshInstance3D] = []
var _size := 1.0


func _ready() -> void:
	top_level = true
	var sks := enemy.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_skeleton = sks[0]
		for n in bone_names:
			_bone = _skeleton.find_bone(n)
			if _bone >= 0:
				break
	_size = clampf(enemy.data.body_scale if "data" in enemy and enemy.data else 1.0, 0.6, 2.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = Vfx.tex("faisca")
	mat.albedo_color = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2, 1.0)  # bem forte (soma luz)
	for i in 2:
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.34 * _size
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_eyes.append(mi)
	var blink := create_tween().set_loops()
	blink.tween_interval(randf_range(2.0, 4.0))
	blink.tween_property(self, "scale", Vector3(1, 0.1, 1), 0.06)
	blink.tween_property(self, "scale", Vector3.ONE, 0.08)


func _process(_d: float) -> void:
	if not is_instance_valid(enemy):
		queue_free()
		return
	if enemy.get("state") == Enemy.State.DEAD:
		visible = false
		return
	var body: Node3D = enemy.get("_body")
	var basis: Basis = body.global_basis if body else enemy.global_basis
	var right := basis.x.normalized()
	var fwd := basis.z.normalized()
	var head: Vector3
	if _skeleton and _bone >= 0:
		head = _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone).origin
		head += fwd * 0.12 * _size + Vector3.UP * 0.05 * _size
	else:
		head = enemy.global_position + Vector3.UP * 1.1 * _size + fwd * 0.3 * _size
	global_transform = Transform3D(Basis(), head)
	_eyes[0].position = right * 0.09 * _size
	_eyes[1].position = -right * 0.09 * _size
