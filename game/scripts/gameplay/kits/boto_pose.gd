class_name BotoPose
extends SkeletonModifier3D
## Boto nadando: onda de cima para baixo da cabeça ao rabo (boto e golfinho nadam batendo o rabo
## na vertical, ao contrário da cobra, que ondula de lado).

var _chain: Array[int] = []
var _t := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _chain.is_empty():
		var i := 0
		while sk.find_bone("coluna%d" % i) >= 0:
			_chain.append(sk.find_bone("coluna%d" % i))
			i += 1
	_t += delta
	var n := _chain.size()
	for k in n:
		var u := float(k) / maxf(float(n - 1), 1.0)
		var amp := lerpf(0.03, 0.22, u * u)
		var angle := sin(_t * 6.0 - u * 3.2) * amp
		var bone := _chain[k]
		var parent := sk.get_bone_parent(bone)
		var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
		var axis := (pg.basis.inverse() * Vector3.RIGHT).normalized()
		sk.set_bone_pose_rotation(bone, Quaternion(axis, angle) * sk.get_bone_pose_rotation(bone))
