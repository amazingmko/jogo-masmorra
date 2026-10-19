class_name BotoForm
extends Node3D
## Visual do Despertar do Boto (ultimate da Druida): o boto-cor-de-rosa nadando no ar dentro de uma
## bolha de água. O corpo ondula de cima para baixo (como um boto nadando) por código.

const MODEL := "res://game/art/herois/boto.glb"
const LENGTH := 1.5        # do focinho ao rabo (m)
const HEIGHT := 1.05       # altura do meio da bolha
const BUBBLE_ALPHA := 0.7

var _boto: Node3D
var _bubble: MeshInstance3D
var _bubble_mat: StandardMaterial3D
var _t := 0.0
var _pose: BotoPose


func _ready() -> void:
	# bolha de água
	_bubble = MeshInstance3D.new()
	if Vfx.tex("bolha"):
		# bolha pintada (imagem) sempre virada para a câmera, com o boto dentro
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 2.3
		_bubble.mesh = q
		_bubble_mat = Vfx.sprite_material("bolha", Color(1, 1, 1, BUBBLE_ALPHA), true)
		_bubble_mat.render_priority = 1  # desenha depois do boto (fica por cima, transparente)
	else:
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 1.7
		sm.radial_segments = 20
		sm.rings = 10
		_bubble.mesh = sm
		_bubble_mat = StandardMaterial3D.new()
		_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_bubble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bubble_mat.albedo_color = Color(0.45, 0.8, 1.0, 0.18)
	_bubble.material_override = _bubble_mat
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.position.y = HEIGHT
	add_child(_bubble)
	# boto
	if ResourceLoader.exists(MODEL):
		var scene: Node3D = load(MODEL).instantiate()
		_boto = Node3D.new()
		add_child(_boto)
		_boto.add_child(scene)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			var box: AABB = (meshes[0] as MeshInstance3D).get_aabb()
			var k := LENGTH / maxf(maxf(box.size.x, box.size.z), 0.001)
			scene.scale = Vector3.ONE * k
			scene.position = -box.get_center() * k
			for mi: MeshInstance3D in meshes:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_boto.position.y = HEIGHT
		var skels := scene.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			_pose = BotoPose.new()
			skels[0].add_child(_pose)
	# brilho verde das marcas de folha (o modelo já tem a pintura; aqui só uma aura leve)
	Vfx.particles(self, global_position + Vector3(0, HEIGHT, 0), "folha", 6, 1.4, Color(0.6, 1.0, 0.6, 0.7), 0.18, Vector2(0.2, 0.5), 180.0, 0.0, true, false, 0.7)
	scale = Vector3.ONE * 0.2
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _boto:
		_boto.position.y = HEIGHT + sin(_t * 2.2) * 0.08
		_boto.rotation.x = sin(_t * 2.2 + 0.8) * 0.08
	_bubble.position.y = HEIGHT + sin(_t * 2.2) * 0.04
	var wob := 1.0 + sin(_t * 3.1) * 0.03
	_bubble.scale = Vector3(wob, 2.0 - wob, wob)
	var base_a := BUBBLE_ALPHA if Vfx.tex("bolha") else 0.16
	_bubble_mat.albedo_color.a = base_a + sin(_t * 4.0) * 0.05


## Ondinha na bolha a cada Canto.
func pulse() -> void:
	var t := _bubble.create_tween()
	t.tween_property(_bubble, "scale", Vector3.ONE * 1.12, 0.07)
	t.tween_property(_bubble, "scale", Vector3.ONE, 0.15)


func vanish() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 0.1, 0.2)
	t.tween_callback(queue_free)
