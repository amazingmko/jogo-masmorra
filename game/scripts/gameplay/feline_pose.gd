class_name FelinePose
extends QuadPose
## Onça: andar de felino feito por código (o esqueleto é o da queixada encaixado nela, sem as
## animações de javali). Por cima dos ataques do QuadPose:
##  - andar: sequência lateral (trás-esq, frente-esq, trás-dir, frente-dir), passadas longas,
##    pata que sobe dobra cotovelo/joelho e o pulso; ombros sobem e descem, cabeça firme;
##  - correr: galope (as duas de trás quase juntas, depois as duas da frente), coluna dobra e estica;
##  - rabo comprido solto: balança, a ponta curva para cima e acompanha o corpo com atraso.
## "fase" anda com a distância (o passo acompanha o chão); "andando" 0..1; "correndo" 0..1.

var fase := 0.0
var andando := 0.0
var correndo := 0.0

var _legs: Array = []   # {top (ombro/quadril), up, low, paw, frente(bool), off_andar, off_correr}
var _back := -1         # coluna de trás (pelve)
var _front_spine := -1
var _root := -1
var _up_local := Vector3.UP    # "cima" no espaço do pai do osso raiz
var _len := 1.0                # tamanho do bicho no espaço do esqueleto
var _fwd := Vector3.FORWARD


func _process_modification_with_delta(delta: float) -> void:
	super(delta)
	var sk := get_skeleton()
	if sk == null or _legs.is_empty():
		return
	var walk := clampf(andando, 0.0, 1.0)
	var run := clampf(correndo, 0.0, 1.0) * walk
	var amp := lerpf(0.38, 0.6, run)
	var gait := TAU * fase
	for leg in _legs:
		var off: float = lerpf(leg.off_andar, leg.off_correr, run)
		var p := TAU * (fase + off)
		var swing := sin(p) * amp * walk
		var lift := maxf(cos(p), 0.0) * walk        # sobe enquanto a pata vai para a frente
		var plant := maxf(-cos(p), 0.0) * walk      # apoiada, empurrando
		# omoplata/quadril: balança junto com a perna (o ombro do gato sobe quando a pata apoia)
		_pitch(sk, leg.top, swing * 0.35 + (0.1 * plant if leg.frente else -0.06 * plant))
		if leg.frente:
			_pitch(sk, leg.up, swing * 0.75)
			_pitch(sk, leg.low, -0.75 * lift - 0.08 * plant)   # cotovelo dobra, pata recolhe
			_pitch(sk, leg.paw, -0.9 * lift + 0.15 * plant)    # o pulso dobra (andar macio de gato)
		else:
			_pitch(sk, leg.up, swing * 0.7)
			_pitch(sk, leg.low, -0.6 * lift + 0.1 * plant)     # joelho
			_pitch(sk, leg.paw, 0.7 * lift - 0.15 * plant)     # jarrete
	# coluna: no andar ondula de lado (ombros para um lado, quadril para o outro) e rola um pouco;
	# no galope dobra e estica
	var side_wave := sin(gait) * walk * (1.0 - run)
	_yaw(sk, _front_spine, side_wave * 0.09)
	_yaw(sk, _spine, side_wave * 0.06)
	_yaw(sk, _back, -side_wave * 0.1)
	_roll(sk, _front_spine, sin(gait + 0.6) * 0.05 * walk * (1.0 - run))
	_roll(sk, _back, -sin(gait + 0.6) * 0.05 * walk * (1.0 - run))
	_pitch(sk, _front_spine, (sin(gait * 2.0) * 0.03 * (1.0 - run) + sin(gait) * 0.14 * run) * walk)
	_pitch(sk, _back, -sin(gait) * 0.16 * run * walk)
	# o corpo sobe e desce duas vezes por passada (uma vez no galope); parado, respira
	if _root >= 0:
		var bob := (absf(sin(gait)) * 0.05 * (1.0 - run) + maxf(sin(gait), 0.0) * 0.12 * run) * walk
		bob += sin(_t * 1.8) * 0.01 * (1.0 - walk)
		sk.set_bone_pose_position(_root, sk.get_bone_pose_position(_root) + _up_local * bob * _len)
	# cabeça: mais baixa e firme no andar de caça, compensa o balanço e olha um pouco para os lados
	_pitch(sk, _neck, -sin(gait * 2.0) * 0.04 * walk - 0.12 * walk - 0.05 * run)
	_pitch(sk, _head, 0.1 * walk + sin(gait * 2.0) * 0.03 * walk)
	_yaw(sk, _neck, -side_wave * 0.1 + sin(_t * 0.7) * 0.12 * (1.0 - walk))
	# rabo: cada pedaço segue o anterior com atraso; a ponta curva para cima
	for i in _tail_extra.size():
		var lag := float(i + 1) * 0.7
		var sway := sin(_t * lerpf(1.6, 3.0, walk) - lag) * lerpf(0.22, 0.12, run)
		_yaw(sk, _tail_extra[i], sway)
		_pitch(sk, _tail_extra[i], 0.12 + 0.1 * float(i) + 0.15 * run)
	_yaw(sk, _tail, sin(_t * 1.6) * 0.12)
	_pitch(sk, _tail, 0.1 + 0.35 * run)


func _find_bones(sk: Skeleton3D) -> void:
	super(sk)
	own_tail = true   # o rabo é todo daqui
	_back = sk.find_bone("pelvis")
	_front_spine = sk.find_bone("body_top0")
	_root = sk.find_bone("body")
	var head_p := _rest_pos(sk, _head)
	var back_p := _rest_pos(sk, _back)
	_fwd = (head_p - back_p).normalized()
	_len = head_p.distance_to(back_p)
	# o osso raiz não tem pai: "cima" já está no espaço do esqueleto
	_up_local = _up_axis
	# sequência lateral no andar; galope: trás juntas, frente juntas meia volta depois
	var offs := {
		"hind_left": [0.0, 0.0], "front_left": [0.25, 0.5],
		"hind_right": [0.5, 0.08], "front_right": [0.75, 0.58],
	}
	for k in offs:
		var top := sk.find_bone("leg_%s_top0" % k)
		if top < 0:
			continue
		_legs.append({
			"top": top,
			"up": sk.find_bone("leg_%s_top1" % k),
			"low": sk.find_bone("leg_%s_bot0" % k),
			"paw": sk.find_bone("leg_%s_bot1" % k),
			"frente": k.begins_with("front"),
			"off_andar": offs[k][0], "off_correr": offs[k][1],
		})


## Rola o osso em volta do eixo frente-trás do bicho.
func _roll(sk: Skeleton3D, bone: int, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.001:
		return
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var axis_local := (pg.basis.inverse() * _fwd).normalized()
	sk.set_bone_pose_rotation(bone, Quaternion(axis_local, angle) * sk.get_bone_pose_rotation(bone))
