class_name WaterClone
extends Node3D
## Espelho do Rio (Encantado): cópia de água deixada para trás. Quando um inimigo encosta,
## explode em água: dano em volta e encharca quem pegou. Some sozinha depois de um tempo.

const LIFETIME := 6.0
const TRIGGER := 1.4
const RADIUS := 3.0

var owner_player: Player
var damage := 50
var soak_time := 4.0
var lifetime := LIFETIME
var radius := RADIUS
var foam_chance := 0.0    # Espuma: quem pega a explosão erra ataques
var slip_chance := 0.0
var _left := LIFETIME
var _body: MeshInstance3D
var _model: Node3D

## A cópia é o próprio modelo do Encantado, parado na pose em que ele estava, feito de água.
const WATER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;
uniform sampler2D ripple : source_color, repeat_enable, filter_linear_mipmap;
uniform float fade = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec2 uv = UV * 3.0 + vec2(TIME * 0.08, TIME * 0.21);
	vec3 rip = texture(ripple, uv).rgb;
	ALBEDO = mix(vec3(0.18, 0.5, 0.95), vec3(0.85, 0.97, 1.0), rim) + rip * 0.25;
	ALPHA = clamp((0.38 + rim * 0.6) * fade, 0.0, 1.0);
}
"""
static var _water_shader: Shader


func _ready() -> void:
	add_to_group("floor_effects")
	_left = lifetime
	_body = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	_body.mesh = capsule
	_body.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.7, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.3
	mat.roughness = 0.2
	_body.material_override = mat
	add_child(_body)
	if is_instance_valid(owner_player) and owner_player._model:
		_copy_model()
	Vfx.particles(self, Vector3(0, 0.9, 0), "faisca", 6, 0.8, Color(0.5, 0.8, 1.0, 0.8), 0.2, Vector2(0.1, 0.4), 180.0, -1.0, true, false)


## Copia já (a pose de agora, antes do passo de dança do Espelho); o lugar é acertado no quadro
## seguinte, quando a cópia já está onde o Encantado estava.
func _copy_model() -> void:
	var src: Node3D = owner_player._model
	var dup := src.duplicate() as Node3D
	# sem animação: congela a pose do momento (copiada osso por osso)
	for n in dup.find_children("*", "AnimationTree", true, false) + dup.find_children("*", "AnimationPlayer", true, false):
		n.free()
	add_child(dup)
	# o lugar da cópia: onde o modelo estava, com a escala e o giro dele (acertado no quadro seguinte)
	var src_offset: Vector3 = src.global_position - owner_player.global_position
	var src_basis: Basis = src.global_transform.basis
	_place_model.call_deferred(dup, src_basis, src_offset)
	var src_sk := src.find_children("*", "Skeleton3D", true, false)
	var dup_sk := dup.find_children("*", "Skeleton3D", true, false)
	for k in mini(src_sk.size(), dup_sk.size()):
		for b in (src_sk[k] as Skeleton3D).get_bone_count():
			(dup_sk[k] as Skeleton3D).set_bone_pose(b, (src_sk[k] as Skeleton3D).get_bone_pose(b))
	var mat := water_material()
	for mi: MeshInstance3D in dup.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model = dup
	_body.visible = false


func _place_model(dup: Node3D, src_basis: Basis, src_offset: Vector3) -> void:
	if is_instance_valid(dup):
		dup.global_transform = Transform3D(src_basis, global_position + src_offset)


static func water_material() -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	mat.set_shader_parameter("ripple", Vfx.tex("escamas_agua"))
	return mat


func _physics_process(delta: float) -> void:
	_left -= delta
	_body.position.y = 0.85 + sin(_left * 4.0) * 0.05
	if _left <= 0.0:
		queue_free()
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() <= TRIGGER:
			_explode()
			return


## Explode agora (Iara: o Encantado voltou para cá).
func burst() -> void:
	if is_physics_processing():
		_explode()


func _explode() -> void:
	set_physics_process(false)
	var kit: MageKit = owner_player.kit as MageKit if is_instance_valid(owner_player) else null
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		if to.length() <= radius and Layers.clear_path(get_world_3d(), global_position, enemy.global_position):
			if kit:
				kit.soak_enemy(enemy)
			elif enemy.has_method("soak"):
				enemy.soak(soak_time)
			enemy.take_hit(damage, false, to)
			if foam_chance > 0.0 and enemy.has_method("foam"):
				enemy.foam(foam_chance, 3.0)
	Vfx.particles(get_parent(), global_position + Vector3(0, 0.6, 0), "faisca", 26, 0.6, Color(0.5, 0.8, 1.0), 0.45, Vector2(3.0, 6.0), 180.0, -9.0)
	Vfx.ground_ring(get_parent(), global_position, "onda_choque", Color(0.4, 0.75, 1.0), radius * 2.0, 0.4)
	Vfx.sprite(get_parent(), global_position + Vector3(0, 0.9, 0), "respingo", radius * 1.6, Color(1, 1, 1, 0.95), 0.4, 1.4)
	Vfx.sprite(get_parent(), global_position + Vector3(0, 0.1, 0), "respingo", radius * 2.0, Color(1, 1, 1, 0.8), 0.45, 1.3, false, randf() * TAU)
	queue_free()


## Cópia Atiradora: dispara uma bolinha d'água no inimigo mais perto.
func shoot(dmg: int, on_hit: Callable) -> void:
	if not is_physics_processing():
		return
	var best: Node3D = null
	var best_d := 9.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: float = enemy.global_position.distance_to(global_position)
		if d < best_d and not enemy.health.is_dead:
			best_d = d
			best = enemy
	if best == null or not is_instance_valid(owner_player):
		return
	var to := best.global_position - global_position
	to.y = 0.0
	var stats := WeaponStats.new()
	stats.damage = dmg
	stats.projectile_speed = owner_player.weapon_stats.projectile_speed
	stats.attack_range = 10.0
	var p := Projectile.create(to.normalized(), stats, GameEnums.Element.WATER, 0.0, RandomNumberGenerator.new())
	p.on_hit = on_hit
	get_parent().add_child(p)
	var at := global_position + Vector3(0, 1.0, 0) + to.normalized() * 0.4
	p.global_position = at
	p.origin = at
