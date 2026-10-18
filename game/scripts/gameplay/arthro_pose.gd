class_name ArthroPose
extends SkeletonModifier3D
## Aranha e formiga (esqueleto feito por tools/autorig.py, sem animação pronta): o andar e os ataques
## são calculados aqui, a cada quadro.
## Andar: as patas se alternam em dois grupos (como os bichos de verdade): metade apoia e empurra para
## trás enquanto a outra metade sobe e avança. "fase" anda com a distância percorrida.
## Ataques ("ataque" -1 preparando ... +1 golpe):
##   golpe 0 picada/ferroada · 2 salto/armadilha · 3 disparo (teia, pelos) · 6 investida

var fase := 0.0
var andando := 0.0
var ataque := 0.0
var golpe := 0
var investindo := false
var formiga := false        # ferroada com o abdômen (formiga) x picada com as presas (aranha)

var _ready_bones := false
var _thorax := -1
var _head := -1
var _abdomen := -1
var _legs: Array = []       # {bones, side (+1 esq), rank (0 = da frente), grupo, d (direção da pata)}
var _antennae: Array = []
var _t := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if not _ready_bones:
		_find(sk)
	_t += delta
	var up := Vector3.UP
	var side_axis := Vector3.RIGHT
	var prep := maxf(-ataque, 0.0)
	var hit := maxf(ataque, 0.0)
	var walk := clampf(andando, 0.0, 1.0)
	var front_lift := 0.0
	var body_pitch := 0.0      # negativo = ergue a frente
	var abd_pitch := 0.0       # positivo = ergue a ponta do abdômen
	var head_pitch := 0.0
	var crouch := 0.0
	match golpe:
		0:
			if formiga:
				# ferroada: curva o abdômen por baixo e para a frente
				abd_pitch = -0.9 * prep - 0.4 * hit
				head_pitch = 0.2 * prep - 0.2 * hit
			else:
				# ameaça: ergue as patas da frente e a frente do corpo; depois crava as presas
				front_lift = 0.9 * prep - 0.4 * hit
				body_pitch = -0.3 * prep + 0.25 * hit
				head_pitch = 0.3 * hit
		2:
			crouch = 0.5 * prep - 0.3 * hit
			front_lift = 0.4 * hit
		3:
			# ergue o abdômen e solta (teia, pelos, ácido)
			abd_pitch = 0.7 * prep - 0.3 * hit
			body_pitch = 0.1 * prep
		5:
			front_lift = 0.6 * prep
			body_pitch = -0.2 * prep
	if investindo:
		body_pitch += 0.12
	var speed_mult := 1.6 if investindo else 1.0
	for leg in _legs:
		var ph: float = fase * speed_mult + (PI if leg.grupo == 1 else 0.0)
		var swing := sin(ph) * 0.38 * walk
		var lift := maxf(cos(ph), 0.0) * 0.45 * walk
		# parado: um tremido leve de pata, cada uma no seu tempo
		lift += sin(_t * 2.3 + leg.rank * 1.7 + leg.side) * 0.03 * (1.0 - walk)
		if leg.rank <= (1 if not formiga else 0):
			lift += front_lift * (1.0 if leg.rank == 0 else 0.7)
		lift -= crouch * 0.5
		var d: Vector3 = leg.d
		# avançar a ponta: girar em volta do "cima" com o sinal do lado
		_rot(sk, leg.bones[0], up, swing * -signf(d.x))
		_rot(sk, leg.bones[0], d.cross(up).normalized(), lift)
		# o joelho dobra um pouco mais quando a pata sobe
		_rot(sk, leg.bones[1], d.cross(up).normalized(), -lift * 0.5)
	for a in _antennae:
		_rot(sk, a.bones[0], up, sin(_t * 5.0 + a.side) * 0.25)
		_rot(sk, a.bones[0], a.d.cross(up).normalized(), sin(_t * 3.7 + a.side * 2.0) * 0.2 + 0.2 * prep)
	_rot(sk, _thorax, side_axis, body_pitch + sin(fase * 2.0) * 0.03 * walk)
	_rot(sk, _abdomen, side_axis, abd_pitch + sin(_t * 1.6) * 0.04)
	_rot(sk, _head, side_axis, head_pitch)


func _find(sk: Skeleton3D) -> void:
	_ready_bones = true
	_thorax = sk.find_bone("torax")
	_head = sk.find_bone("cabeca")
	_abdomen = sk.find_bone("abdomen")
	for b in sk.get_bone_count():
		var nm := sk.get_bone_name(b)
		if not nm.ends_with("_0"):
			continue
		var base := nm.trim_suffix("_0")
		var bones := [b, sk.find_bone(base + "_1"), sk.find_bone(base + "_2")]
		var root := sk.get_bone_global_rest(b).origin
		var knee := sk.get_bone_global_rest(bones[2]).origin
		var d := knee - root
		d.y = 0.0
		d = d.normalized() if d.length() > 0.001 else Vector3.RIGHT
		var side := 1.0 if base.ends_with("_e") else -1.0
		var entry := {"bones": bones, "side": side, "d": d, "rank": 0, "grupo": 0}
		if base.begins_with("antena"):
			_antennae.append(entry)
		else:
			entry.rank = int(base.trim_prefix("pata").get_slice("_", 0)) - 1
			_legs.append(entry)
	# grupos alternados: pata 1 esquerda com pata 2 direita, e assim por diante
	for leg in _legs:
		leg.grupo = (leg.rank + (0 if leg.side > 0 else 1)) % 2


## Gira o osso em volta de um eixo do espaço do esqueleto, por cima da pose atual.
func _rot(sk: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.0005 or axis.length() < 0.5:
		return
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var local_axis := (pg.basis.inverse() * axis).normalized()
	sk.set_bone_pose_rotation(bone, Quaternion(local_axis, angle) * sk.get_bone_pose_rotation(bone))
