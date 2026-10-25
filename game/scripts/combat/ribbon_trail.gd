class_name RibbonTrail
extends MeshInstance3D
## Rastro de fita atrás de algo que se move (lança, harpia mergulhando, disparos).
## Guarda as últimas posições do alvo e monta uma fita deitada no chão (a câmera é de cima),
## mais larga na ponta nova e afinando na velha. Quando o alvo some, a fita encolhe e se apaga.

var target: Node3D
var width := 0.5
var color := Color(1.0, 0.8, 0.4)
var life := 0.25           # segundos que um ponto fica no rastro
var up_facing := true      # fita deitada (vista de cima); senão, em pé
var _points: Array = []    # [posição, idade]
var _mesh := ImmediateMesh.new()
var _mat: ShaderMaterial
var _fade := 1.0


static func follow(node: Node3D, w: float, c: Color, seconds := 0.25) -> RibbonTrail:
	var t := RibbonTrail.new()
	t.target = node
	t.width = w
	t.color = c
	t.life = seconds
	# fica na cena (não no objeto): o rastro continua no lugar quando o objeto some
	var root: Node = node.get_tree().current_scene if node.is_inside_tree() else node.get_parent()
	if root == null:
		root = node.get_parent()
	root.add_child(t)
	return t


func _ready() -> void:
	top_level = true
	mesh = _mesh
	_mat = FxKit.material("trail", {"color": color})
	_mat.render_priority = 3
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	for p in _points:
		p[1] += delta
	while not _points.is_empty() and _points[0][1] > life:
		_points.pop_front()
	if is_instance_valid(target) and target.is_inside_tree():
		var at: Vector3 = target.global_position
		if _points.is_empty() or (_points[-1][0] as Vector3).distance_to(at) > 0.05:
			_points.append([at, 0.0])
	elif _points.is_empty():
		queue_free()
		return
	_rebuild()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	var n := _points.size()
	if n < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for k in n:
		var i := n - 1 - k                      # da ponta nova para a velha
		var p: Vector3 = _points[i][0]
		var q: Vector3 = _points[maxi(i - 1, 0)][0] if i > 0 else p
		var r: Vector3 = _points[mini(i + 1, n - 1)][0]
		var dir := (r - q)
		dir.y = 0.0 if up_facing else dir.y
		if dir.length() < 0.001:
			dir = Vector3.FORWARD
		var side := dir.normalized().cross(Vector3.UP if up_facing else Vector3.RIGHT).normalized()
		var t := float(k) / float(n - 1)
		var w := width * (1.0 - t * 0.7) * 0.5
		_mesh.surface_set_uv(Vector2(t, 0.0))
		_mesh.surface_add_vertex(p - side * w)
		_mesh.surface_set_uv(Vector2(t, 1.0))
		_mesh.surface_add_vertex(p + side * w)
	_mesh.surface_end()
