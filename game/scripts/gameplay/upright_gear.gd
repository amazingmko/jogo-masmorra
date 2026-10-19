class_name UprightGear
extends Node3D
## Cajado/bengala que fica de pé na mão: segue a posição da mão, mas não gira com o pulso.
## As animações de magia do Mixamo são de mão aberta (sem cajado): presa ao osso, a arma
## ficaria deitada para o lado. Aqui ela fica em pé, inclinada um pouco para a frente e
## acompanhando de leve para onde a mão vai (no golpe, o cajado avança junto).

var model: Node3D        # o modelo do herói (para saber a frente dele)
var grip := Vector3.ZERO # ponto do modelo da arma que fica na mão (unidades do arquivo)
var k := 1.0             # escala do modelo da arma
var lean := 0.18         # inclinação para a frente (radianos)
var follow := 0.35       # quanto o topo acompanha o movimento da mão
var _prev := Vector3.INF
var _swing := Vector3.ZERO
var _owner_hero: Node
var _fallen := 0.0


func _process(delta: float) -> void:
	var hand: Node3D = get_parent()
	if hand == null or not is_instance_valid(model):
		return
	var at := hand.global_position
	var fwd := model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# o topo do cajado vai um pouco atrás do movimento da mão (balanço do golpe)
	if _prev != Vector3.INF and delta > 0.0:
		var vel := (at - _prev) / delta
		vel.y = 0.0
		_swing = _swing.lerp(vel * 0.06, clampf(delta * 10.0, 0.0, 1.0))
	_prev = at
	# morreu: o cajado tomba junto (deita para a frente)
	if _owner_hero == null:
		_owner_hero = model.get_parent()
		while _owner_hero and not ("health" in _owner_hero):
			_owner_hero = _owner_hero.get_parent()
	var dead: bool = _owner_hero != null and _owner_hero.health != null and _owner_hero.health.is_dead
	_fallen = move_toward(_fallen, 1.0 if dead else 0.0, delta * 2.5)
	var up := (Vector3.UP + fwd * lean + _swing.limit_length(0.6) * follow).normalized()
	up = up.slerp((fwd * 0.97 + Vector3.UP * 0.03).normalized(), _fallen)
	var right := up.cross(fwd).normalized()
	var back := right.cross(up).normalized()
	var b := Basis(right, up, back)
	global_transform = Transform3D(b.scaled_local(Vector3.ONE * k), at - b * (grip * k))
