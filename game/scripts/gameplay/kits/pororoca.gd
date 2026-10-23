class_name Pororoca
extends Node3D
## Pororoca (ultimate do Encantado): uma onda larga que atravessa a sala na direção em que ele
## mira. Quem a onda pega leva dano e é arremessado para a frente; se bater na parede, leva
## mais dano (o dobro se estiver encharcado). Ver Enemy.hurl.

const SPEED := 11.0
const LENGTH := 16.0
const WIDTH := 7.0
const THROW := 8.0

var direction := Vector3.FORWARD
var damage := 60
var slam_damage := 80
var width := WIDTH
var throw := THROW
## Ressaca: fração do dano da onda que volta depois (0 = não volta).
var backwash := 0.0
var on_slam := Callable()
var returning := false
var _traveled := 0.0
var _hit := {}
var _wave: MeshInstance3D
var _wave_mat: ShaderMaterial
var _wake: MeshInstance3D
var _wake_mat: ShaderMaterial
const HEIGHT := 2.3


func _ready() -> void:
	add_to_group("floor_effects")
	direction.y = 0.0
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	look_at(global_position + direction, Vector3.UP)
	var h := HEIGHT if not returning else HEIGHT * 0.65
	# a onda: lâmina curva com shader de água (WaveMesh); a crista olha para a frente (-Z do nó)
	_wave = MeshInstance3D.new()
	_wave.mesh = WaveMesh.build(width * 1.05, h, 1.7)
	_wave.rotation.y = PI
	_wave_mat = WaveMesh.material(width * 1.05)
	_wave_mat.set_shader_parameter("rise", 0.0)
	_wave.material_override = _wave_mat
	_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wave)
	# nasce do chão: sobe rápido e passa um pouco do ponto (antecipação de desenho animado)
	var up := create_tween()
	up.tween_method(func(v: float) -> void: _wave_mat.set_shader_parameter("rise", v), 0.0, 1.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# rastro de espuma molhando o chão por onde passou
	_wake = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_wake.mesh = plane
	_wake_mat = WaveMesh.wake_material(width)
	_wake.material_override = _wake_mat
	_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wake.position = Vector3(0, 0.05, 0)
	_wake.scale = Vector3(width * 0.95, 1.0, 0.01)
	add_child(_wake)
	# respingos saindo da crista e espuma na frente
	var crest := Vector3(0, h * 0.8, -0.5)
	var spray := Vfx.particles(self, crest, "respingo", 14, 0.5, Color(1, 1, 1, 0.85), 0.8, Vector2(1.5, 3.5), 50.0, -9.0, true, false)
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spray.emission_box_extents = Vector3(width * 0.45, 0.15, 0.2)
	spray.direction = Vector3(0, 1, -0.6)
	var foam := Vfx.particles(self, Vector3(0, 0.3, -0.9), "faisca", 34, 0.45, Color(0.85, 0.97, 1.0), 0.3, Vector2(1.0, 3.0), 70.0, -6.0, true, false)
	foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	foam.emission_box_extents = Vector3(width * 0.5, 0.1, 0.2)
	# no lançamento: a água brota do chão
	if not returning:
		var gush := Vfx.particles(get_parent(), global_position + Vector3(0, 0.2, 0), "respingo", 16, 0.5, Color(1, 1, 1, 0.9), 0.8, Vector2(2.0, 4.0), 40.0, -10.0)
		gush.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		gush.emission_box_extents = Vector3(width * 0.4, 0.1, 0.3)


var _splashes_this_frame := 0


func _physics_process(delta: float) -> void:
	_splashes_this_frame = 0
	var step := SPEED * delta
	global_position += direction * step
	_traveled += step
	# o rastro vai de onde ela nasceu até as costas da onda (fica parado no chão)
	_wake.scale.z = maxf(_traveled, 0.01)
	_wake.position.z = _traveled * 0.5 + 0.9
	_wake_mat.set_shader_parameter("length_m", _traveled)
	var right := direction.cross(Vector3.UP)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(enemy.get_instance_id()):
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if absf(to.dot(direction)) <= 0.9 and absf(to.dot(right)) <= width * 0.5:
			_hit[enemy.get_instance_id()] = true
			enemy.take_hit(damage, false, direction)
			if enemy.has_method("hurl"):
				enemy.hurl(direction, throw, slam_damage, on_slam)
	if _traveled >= LENGTH:
		set_physics_process(false)
		if backwash > 0.0 and not returning:
			# Ressaca: a água volta, menor, e acerta de novo.
			var back := Pororoca.new()
			back.direction = -direction
			back.damage = maxi(int(round(damage * backwash)), 1)
			back.slam_damage = maxi(int(round(slam_damage * backwash)), 1)
			back.width = width * 0.8
			back.throw = throw * 0.5
			back.returning = true
			back.on_slam = on_slam
			get_parent().add_child(back)
			back.global_position = global_position
		_crash()


## A onda arrebenta: a crista some primeiro, a água espalha e o rastro seca.
func _crash() -> void:
	var front := global_position + direction * 0.8 + Vector3(0, 0.6, 0)
	var burst := Vfx.particles(get_parent(), front, "respingo", 22, 0.7, Color(1, 1, 1, 0.9), 0.9, Vector2(2.0, 5.0), 70.0, -10.0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	burst.emission_box_extents = Vector3(width * 0.4, 0.2, 0.3)
	Vfx.particles(get_parent(), front, "faisca", 24, 0.6, Color(0.8, 0.95, 1.0), 0.35, Vector2(2.0, 4.5), 120.0, -8.0)
	var t := create_tween().set_parallel()
	t.tween_method(func(v: float) -> void: _wave_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.35)
	t.tween_method(func(v: float) -> void: _wave_mat.set_shader_parameter("rise", v), 1.0, 0.55, 0.35)
	t.tween_method(func(v: float) -> void: _wake_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.6)
	t.chain().tween_callback(queue_free)


## Água estourando em quem a onda pega.
func _splash(at: Vector3) -> void:
	Vfx.sprite(get_parent(), at + Vector3(0, 0.9, 0), "respingo", 1.6, Color(0.9, 0.97, 1.0, 0.95), 0.3)
	Vfx.particles(get_parent(), at + Vector3(0, 0.8, 0), "faisca", 10, 0.4, Color(0.75, 0.93, 1.0), 0.3, Vector2(2.0, 4.0), 160.0, -8.0)
