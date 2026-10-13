class_name Fx
extends RefCounted
## Efeitos visuais simples e reutilizáveis: números de dano, piscar ao apanhar, rastro de golpe.


## Número que sobe e some acima de quem apanhou.
static func damage_number(parent: Node, at: Vector3, amount: int, crit: bool, color: Color = Color.WHITE) -> void:
	var label := Label3D.new()
	label.text = ("%d!" % amount) if crit else str(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96 if crit else 64
	label.outline_size = 16
	label.modulate = Color("ffd34d") if crit else color
	label.pixel_size = 0.006
	parent.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.2, 0.2), 0.0, 0.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3(0, 1.0, 0), 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


## Texto curto que sobe e some (ex.: "esquiva").
static func float_text(parent: Node, at: Vector3, text: String, color: Color = Color.WHITE) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 14
	label.modulate = color
	label.pixel_size = 0.006
	parent.add_child(label)
	label.global_position = at
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", at + Vector3(0, 0.9, 0), 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


## Pisca a malha em branco por um instante.
static func flash(material: StandardMaterial3D, base_color: Color, flash_color: Color = Color.WHITE) -> void:
	if material == null:
		return
	material.albedo_color = flash_color
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(material):
			material.albedo_color = base_color)


## Arco rápido mostrando a área do golpe corpo a corpo.
static func slash(parent: Node, origin: Vector3, direction: Vector3, reach: float) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = reach
	shape.bottom_radius = reach
	shape.height = 0.05
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.35)
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.global_position = origin + direction * (reach * 0.5) + Vector3(0, 0.6, 0)
	mesh.scale = Vector3(0.6, 1.0, 0.6)
	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.12)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.chain().tween_callback(mesh.queue_free)
