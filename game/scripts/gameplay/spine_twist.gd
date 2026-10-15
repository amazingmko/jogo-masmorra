class_name SpineTwist
extends SkeletonModifier3D
## Gira o tronco (Spine, Spine1, Spine2) em volta do eixo vertical, depois da animação.
## Usado ao atirar andando: as pernas seguem o movimento e o tronco vira para o alvo.
## angle: radianos (sentido de rotation.y). weight: 0 = sem torção, 1 = torção inteira.

const BONES := ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]

var angle := 0.0
var weight := 0.0
var _ids: Array[int] = []


func _ready() -> void:
	var sk := get_skeleton()
	if sk:
		for b in BONES:
			var i := sk.find_bone(b)
			if i >= 0:
				_ids.append(i)


func _process_modification_with_delta(_delta: float) -> void:
	_apply()


func _process_modification() -> void:
	_apply()


func _apply() -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty() or absf(weight * angle) < 0.001:
		return
	var step := Quaternion(Vector3.UP, angle * weight / float(_ids.size()))
	for i in _ids:
		# Gira no espaço do esqueleto (vertical de verdade), convertendo para o espaço do pai.
		var parent := sk.get_bone_parent(i)
		var parent_rot := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var local := sk.get_bone_pose_rotation(i)
		sk.set_bone_pose_rotation(i, (parent_rot.inverse() * step * parent_rot * local).normalized())
