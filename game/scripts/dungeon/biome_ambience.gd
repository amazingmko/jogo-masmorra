class_name BiomeAmbience
extends Node3D
## Atmosfera da Terra Firme: luz filtrada pela copa (sol morno e esverdeado), sombra fresca,
## neblina baixa ao longe, vagalumes e folhas caindo em volta da heroína.
## Tudo compatível com o renderizador Mobile (neblina comum, sem neblina volumétrica nem glow).

const FIREFLY_COLOR := Color(0.85, 1.0, 0.45, 0.9)

var target: Node3D
var _fireflies: CPUParticles3D
var _leaves: CPUParticles3D


static func apply(world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var env := world.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d140c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5d7a5a")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("223524")
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	sun.light_color = Color("ffe9b8")
	sun.light_energy = 1.15
	sun.shadow_opacity = 0.75


func _ready() -> void:
	_fireflies = _particles(36, 4.5, Vector3(13, 1.6, 10), Vector3(0, 1.4, 0))
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.05
	_fireflies.initial_velocity_max = 0.3
	_fireflies.direction = Vector3.UP
	_fireflies.spread = 180.0
	_fireflies.scale_amount_min = 0.6
	_fireflies.scale_amount_max = 1.0
	var fade := Gradient.new()  # acende e apaga devagar
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	_fireflies.color_ramp = fade
	_fireflies.mesh = _quad("faisca", FIREFLY_COLOR, true, 0.16)

	_leaves = _particles(16, 5.0, Vector3(14, 0.4, 11), Vector3(0, 3.2, 0))
	_leaves.gravity = Vector3(0.25, -0.55, 0)
	_leaves.initial_velocity_min = 0.0
	_leaves.initial_velocity_max = 0.2
	_leaves.angular_velocity_min = -90.0
	_leaves.angular_velocity_max = 90.0
	_leaves.scale_amount_min = 0.7
	_leaves.scale_amount_max = 1.0
	_leaves.particle_flag_rotate_y = true
	_leaves.mesh = _quad("folha", Color(0.75, 0.8, 0.5, 0.9), false, 0.22)


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = Vector3(target.global_position.x, 0.0, target.global_position.z)


func _particles(amount: int, lifetime: float, box: Vector3, offset: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false  # ficam no mundo: a heroína anda por entre eles
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.position = offset
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _quad(texture_name: String, color: Color, additive: bool, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = Vfx.tex(texture_name)
	q.material = m
	return q
