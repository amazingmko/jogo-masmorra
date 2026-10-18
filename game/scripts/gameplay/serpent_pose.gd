class_name SerpentPose
extends SkeletonModifier3D
## Cobra (corrente de ossos da cabeça ao rabo, feita por tools/autorig.py): rasteja com uma onda que
## corre do pescoço para o rabo. O modelo vem em "S"; aqui cada osso recebe a direção da onda no
## lugar da curva do modelo, então ela se estica e ondula enquanto anda.
##   "fase" anda com a distância percorrida (a onda acompanha o chão, sem deslizar).
## Ataque: na preparação encolhe em "S" bem fechado (a cabeça recua); no bote estica tudo.

var fase := 0.0
var andando := 0.0
var ataque := 0.0
var investindo := false

var _ready_bones := false
var _chain: Array[int] = []
var _rest_heading: Array[float] = []
var _t := 0.0

const ONDAS := 1.3          # quantas ondas cabem no corpo


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_bones:
		_find(sk)
	if _chain.is_empty():
		return
	_t += delta
	var prep := maxf(-ataque, 0.0)
	var hit := maxf(ataque, 0.0)
	var walk := clampf(andando, 0.0, 1.0)
	var n := _chain.size()
	var straight := atan2(0.0, -1.0)   # o corpo vai para trás da cabeça (-Z)
	var prev_des := 0.0
	var prev_rest := 0.0
	for i in n:
		var u := float(i) / float(n - 1)
		# amplitude: pouca no pescoço, cheia do meio para trás
		var amp := lerpf(0.12, 0.55, smoothstep(0.0, 0.45, u))
		amp *= lerpf(0.55, 1.0, walk)
		amp += prep * 0.5 * (1.0 - u)        # encolhe a frente em S para dar o bote
		amp *= 1.0 - 0.75 * hit               # no bote, estica
		var wave := sin(u * TAU * ONDAS - fase - _t * 0.6 * (1.0 - walk))
		var des := straight + amp * wave
		if investindo:
			des = straight + amp * 0.35 * wave
		var rest: float = _rest_heading[i]
		var delta_angle: float
		if i == 0:
			delta_angle = wrapf(des - rest, -PI, PI)
		else:
			delta_angle = wrapf((des - prev_des) - (rest - prev_rest), -PI, PI)
		prev_des = des
		prev_rest = rest
		_rot_up(sk, _chain[i], delta_angle)


func _find(sk: Skeleton3D) -> void:
	_ready_bones = true
	var i := 0
	while true:
		var b := sk.find_bone("coluna%d" % i)
		if b < 0:
			break
		_chain.append(b)
		i += 1
	for k in _chain.size():
		var b := _chain[k]
		var a := sk.get_bone_global_rest(b).origin
		var nxt: Vector3
		if k + 1 < _chain.size():
			nxt = sk.get_bone_global_rest(_chain[k + 1]).origin
		else:
			nxt = a + sk.get_bone_global_rest(b).basis.y
		var d := nxt - a
		_rest_heading.append(atan2(d.x, d.z))


func _rot_up(sk: Skeleton3D, bone: int, angle: float) -> void:
	if absf(angle) < 0.0005:
		return
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var local_axis := (pg.basis.inverse() * Vector3.UP).normalized()
	sk.set_bone_pose_rotation(bone, Quaternion(local_axis, angle) * sk.get_bone_pose_rotation(bone))
