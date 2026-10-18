class_name QuadPose
extends SkeletonModifier3D
## Ataques dos quadrúpedes por cima da animação de andar/parado (o esqueleto do Anything World só
## traz idle, walk e run): mexe pescoço, cabeça, coluna e uma pata da frente.
## O inimigo preenche "ataque" (-1 preparando ... 0 ... +1 golpe), "golpe" e "investindo";
## este modificador roda depois da animação, a cada quadro.
##   golpe 0 bote/mordida · 1 patada · 2 salto/pancada · 5 rugido/esturro · 6 investida (cabeça baixa)

var ataque := 0.0
var golpe := 0
var investindo := false
var own_tail := false        # a subclasse (FelinePose) cuida do rabo

var _ready_bones := false
var _neck := -1
var _head := -1
var _spine := -1      # coluna da frente (ombros)
var _paw := -1        # pata da frente direita (topo)
var _tail := -1
var _tail_extra: Array[int] = []   # rabo comprido (onça): balança solto
var _side := Vector3.RIGHT   # eixo lateral do bicho, no espaço do esqueleto
var _sign := 1.0             # sinal que faz "ângulo positivo" erguer o focinho
var _up_axis := Vector3.UP   # "cima" do bicho no espaço do esqueleto
var _t := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_bones:
		_find_bones(sk)
	_t += delta
	var prep := maxf(-ataque, 0.0)
	var hit := maxf(ataque, 0.0)
	var neck := 0.0
	var head := 0.0
	var spine := 0.0
	var paw := 0.0
	var tail := sin(_t * 3.0) * 0.08
	match golpe:
		0:  # bote: ergue a cabeça e recua, depois crava para a frente e para baixo
			neck = 0.35 * prep - 0.55 * hit
			head = 0.2 * prep - 0.3 * hit
			spine = 0.08 * prep - 0.1 * hit
			tail += 0.4 * prep
		1:  # patada: ergue a pata da frente e desce de lado
			paw = 1.1 * prep - 0.5 * hit
			neck = -0.1 * prep + 0.1 * hit
			spine = 0.1 * prep
		2:  # salto: empina a frente e cai por cima
			spine = 0.35 * prep - 0.25 * hit
			neck = 0.15 * prep - 0.35 * hit
			paw = 0.6 * prep - 0.3 * hit
		5:  # rugido/esturro: cabeça para cima e para a frente, treme
			var shake := sin(_t * 40.0) * 0.04 * prep
			neck = 0.3 * prep + shake
			head = 0.35 * prep + shake
			tail += 0.5 * prep
		6:  # investida: baixa a cabeça (presas para a frente) e cava o chão com a pata
			neck = -0.4 * prep
			head = -0.15 * prep
			paw = sin(_t * 13.0) * 0.55 * prep
	if investindo:
		neck = minf(neck, -0.3)
		head = minf(head, -0.12)
	_pitch(sk, _spine, spine)
	_pitch(sk, _neck, neck)
	_pitch(sk, _head, head)
	_pitch(sk, _paw, paw)
	_pitch(sk, _tail, tail)
	if not own_tail:
		for i in _tail_extra.size():
			_yaw(sk, _tail_extra[i], sin(_t * 2.2 - i * 0.8) * 0.18)
			_pitch(sk, _tail_extra[i], 0.08 + 0.1 * prep)


func _find_bones(sk: Skeleton3D) -> void:
	_ready_bones = true
	_neck = sk.find_bone("neck0")
	_head = sk.find_bone("head0")
	_spine = sk.find_bone("body_top1")
	if _spine < 0:
		_spine = sk.find_bone("body_top0")
	_paw = sk.find_bone("leg_front_right_top0")
	_tail = sk.find_bone("tail0")
	for i in range(1, 6):
		var b := sk.find_bone("tail%d" % i)
		if b >= 0:
			_tail_extra.append(b)
	# eixos tirados da pose de descanso: frente = da pelve para a cabeça; lado = da pata direita
	# para a esquerda. "Cima" = o que sobra; ângulo positivo leva a frente para cima.
	var head_p := _rest_pos(sk, _head if _head >= 0 else _neck)
	var back_p := _rest_pos(sk, sk.find_bone("pelvis"))
	var left_p := _rest_pos(sk, sk.find_bone("leg_front_left_top0"))
	var right_p := _rest_pos(sk, _paw)
	var fwd := (head_p - back_p).normalized()
	var side := (left_p - right_p)
	side = (side - fwd * side.dot(fwd)).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	_side = side
	var up := fwd.cross(side).normalized()
	# girar fwd em volta de side: fwd vai para side.cross(fwd) quando o ângulo é positivo
	_sign = 1.0 if side.cross(fwd).dot(up) > 0.0 else -1.0
	# "cima" de verdade: o lado oposto ao dos cascos
	var feet := _rest_pos(sk, sk.find_bone("leg_front_left_bot2"))
	if (feet - head_p).dot(up) > 0.0:
		_sign = -_sign
		up = -up
	_up_axis = up


func _rest_pos(sk: Skeleton3D, bone: int) -> Vector3:
	return sk.get_bone_global_rest(bone).origin if bone >= 0 else Vector3.ZERO


## Gira o osso em volta do eixo lateral do bicho (no espaço do esqueleto), na pose atual.
func _pitch(sk: Skeleton3D, bone: int, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.001:
		return
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var axis_local := (pg.basis.inverse() * _side).normalized()
	var rot := sk.get_bone_pose_rotation(bone)
	sk.set_bone_pose_rotation(bone, Quaternion(axis_local, angle * _sign) * rot)


func _yaw(sk: Skeleton3D, bone: int, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.001:
		return
	var up := _up_axis   # "cima" do bicho no espaço do esqueleto
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var axis_local := (pg.basis.inverse() * up).normalized()
	sk.set_bone_pose_rotation(bone, Quaternion(axis_local, angle) * sk.get_bone_pose_rotation(bone))
