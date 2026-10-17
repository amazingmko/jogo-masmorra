class_name Lighting
## Ajustes de luz compartilhados.
##
## No renderizador Mobile, a sombra do sol escurecia o objeto inteiro (pedras, troncos, plantas,
## inimigos): só o chão ficava iluminado. Por isso só o chão recebe a sombra do sol; os objetos
## continuam projetando a sombra deles no chão normalmente.


## Desliga "receber sombra" em todos os materiais do nó e dos filhos (malhas e MultiMesh).
static func no_shadow_receive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		_fix(mi.material_override)
		for i in mi.get_surface_override_material_count():
			_fix(mi.get_surface_override_material(i))
		if mi.mesh:
			mesh_no_shadow_receive(mi.mesh)
	elif node is MultiMeshInstance3D:
		var mmi := node as MultiMeshInstance3D
		_fix(mmi.material_override)
		if mmi.multimesh and mmi.multimesh.mesh:
			mesh_no_shadow_receive(mmi.multimesh.mesh)
	for child in node.get_children():
		no_shadow_receive(child)


static func mesh_no_shadow_receive(mesh: Mesh) -> void:
	for i in mesh.get_surface_count():
		_fix(mesh.surface_get_material(i))


static func _fix(mat: Material) -> void:
	if mat is BaseMaterial3D:
		(mat as BaseMaterial3D).disable_receive_shadows = true
	if mat and mat.next_pass:
		_fix(mat.next_pass)
