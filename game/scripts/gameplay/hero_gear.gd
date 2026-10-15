class_name HeroGear
extends RefCounted
## Prende a arma e o escudo nos ossos da mão/antebraço do modelo do herói (esqueleto Mixamo).
## As armas são modelos separados (game/art/armas), para poderem mudar com o equipamento fabricado.
##
## Por arma:
##   bone    osso onde prende
##   offset  posição em metros no espaço do osso (Y do osso aponta para os dedos / para a mão)
##   basis   para onde vão os eixos X, Y, Z do modelo da arma, no espaço do osso
##   size    tamanho final (metros) do maior lado do modelo
##   grip    ponto do modelo da arma (nas unidades do arquivo) que fica no offset

const GEAR := {
	&"icamiaba": [
		{  # lança: ponta (lado -X do modelo) para a frente da mão
			"scene": "res://game/art/armas/lanca_icamiaba.glb",
			"bone": "mixamorig_RightHand",
			"offset": Vector3(0.0, 0.085, 0.02),
			"basis": Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)),
			"size": 1.7,
			"grip": Vector3(0.12, 0.1, 0.0),
		},
		{  # escudo: preso por fora do antebraço esquerdo, frente (+Z do modelo) para fora
			"scene": "res://game/art/armas/escudo_icamiaba.glb",
			"bone": "mixamorig_LeftForeArm",
			"offset": Vector3(0.0, 0.14, -0.07),
			"basis": Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)),
			"size": 0.7,
			"grip": Vector3(0.0, 0.49, -0.1),
		},
	],
	&"mateira": [
		{  # arco: na mão esquerda, braços (lado X do modelo) para cima e para baixo, barriga do arco para a frente
			"scene": "res://game/art/armas/arco_mateira.glb",
			"bone": "mixamorig_LeftHand",
			"offset": Vector3(0.0, 0.08, 0.0),
			"basis": Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)),
			"size": 1.3,
			"grip": Vector3(0.0, 0.03, 0.0),
		},
	],
}


## Disparo à distância: em que fração da animação de ataque a flecha sai (a mão solta a corda).
## Medido na animação (distância entre as mãos salta na soltura). Sem valor, sai na hora do toque.
const RELEASE := {
	&"mateira": 0.73,
}


## Postura de arqueiro: na animação de disparo o quadril fica de lado e a flecha sai a este
## ângulo (radianos) à frente do peito. Usado para girar o tronco quando ela atira andando.
const AIM_STANCE := {
	&"mateira": 0.14,  # ~8°: andando, o braço do arco já aponta quase para a frente das pernas
}


## Prende as peças do herói no modelo. Devolve os nós criados (para trocar depois).
static func attach(model: Node, hero_id: StringName) -> Array[Node3D]:
	var made: Array[Node3D] = []
	if not GEAR.has(hero_id):
		return made
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return made
	var skeleton: Skeleton3D = found[0]
	# O esqueleto do Mixamo vem dentro de um nó com escala 100 (centímetros); o "mount" desfaz isso.
	var inherited := skeleton.transform.basis.get_scale().x
	var p := skeleton.get_parent()
	while p is Node3D:
		inherited *= (p as Node3D).scale.x
		if p == model:
			break
		p = p.get_parent()
	for piece in GEAR[hero_id]:
		if not ResourceLoader.exists(piece.scene) or skeleton.find_bone(piece.bone) < 0:
			continue
		var holder := BoneAttachment3D.new()
		holder.name = "Gear_" + String(piece.bone)
		holder.bone_name = piece.bone
		skeleton.add_child(holder)
		var mount := Node3D.new()
		mount.scale = Vector3.ONE / inherited
		holder.add_child(mount)
		var item: Node3D = load(piece.scene).instantiate()
		var aabb := _aabb(item)
		var k: float = piece.size / maxf(aabb.get_longest_axis_size(), 0.001)
		var b: Basis = piece.basis
		item.transform = Transform3D(b.scaled_local(Vector3.ONE * k), piece.offset - b * (piece.grip * k))
		mount.add_child(item)
		made.append(holder)
	return made


static func _aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D)
		if m.mesh == null:
			continue
		var b := m.transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
