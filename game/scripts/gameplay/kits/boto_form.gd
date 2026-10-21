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
var _bubble_mat: ShaderMaterial
var _t := 0.0
var _pose: BotoPose


func _ready() -> void:
	# bolha de água de verdade (a mesma da Bolha Protetora): borda acesa, reflexo de arco-íris,
	# superfície tremendo; o boto nada dentro
	_bubble = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	_bubble.mesh = sm
	var sh := Shader.new()
	sh.code = MageKit.BUBBLE_SHADER
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = sh
	_bubble_mat.render_priority = 1
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
	if is_inside_tree():
		FxKit.ground_wave(get_parent(), global_position, 2.6, Color(1.0, 0.6, 0.85), 0.4, 0.0, 0.0, Color(0.85, 0.95, 1.0))
		Vfx.particles(get_parent(), global_position + Vector3(0, 0.4, 0), "respingo", 14, 0.6, Color(1, 1, 1, 0.9), 0.6, Vector2(2.0, 4.0), 50.0, -9.0, false)
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


## Ondinha na bolha a cada Canto.
func pulse() -> void:
	if is_inside_tree():
		FxKit.ground_wave(get_parent(), global_position, 2.2, Color(1.0, 0.65, 0.9), 0.3)
	var t := _bubble.create_tween()
	t.tween_property(_bubble, "scale", Vector3.ONE * 1.12, 0.07)
	t.tween_property(_bubble, "scale", Vector3.ONE, 0.15)


func vanish() -> void:
	if is_inside_tree():
		Vfx.particles(get_parent(), global_position + Vector3(0, HEIGHT, 0), "respingo", 16, 0.6, Color(0.85, 0.95, 1.0, 0.9), 0.5, Vector2(2.0, 4.5), 180.0, -8.0, false)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 0.1, 0.2)
	t.tween_callback(queue_free)
