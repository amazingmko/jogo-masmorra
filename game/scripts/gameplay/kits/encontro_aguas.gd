class_name EncontroAguas
extends Node3D
## Encontro das Águas (talento final da Pororoca, Encantado do Rio): em vez de uma onda, saem
## duas, uma de cada lado, em diagonal: o Rio Negro (escuro, encharca quem pega) e o Solimões
## (barrento, bate mais forte). Elas se chocam à frente do Encantado e, como no encontro de verdade,
## não se misturam: viram um redemoinho de duas cores que puxa os inimigos para o meio, atordoa e
## causa dano alto (o dobro em quem está encharcado).

const MEET_DISTANCE := 7.0   # o choque: 7 m à frente
const SIDE := 4.0            # cada onda nasce 4 m para o lado
const WAVE_WIDTH := 3.2
const WAVE_DAMAGE := 0.7     # cada onda: 70% do dano do cajado (Solimões: +50%)
const PULL_RADIUS := 4.5
const BURST_DAMAGE := 2.0    # o redemoinho: 200% (400% encharcado)
const SWIRL_TIME := 2.2
const WAVE_SPEED := 6.0      # mais devagar que a Pororoca (11 m/s): ~1,4 s até o choque

var owner_player: Node3D
var kit: Node
var direction := Vector3.FORWARD
var weapon_damage := 30
var stun_time := 1.5
var width_mult := 1.0
var _arrived := 0
var _meet := Vector3.ZERO
var _burst_done := false


func _ready() -> void:
	add_to_group("floor_effects")
	direction.y = 0.0
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	_meet = global_position + direction * MEET_DISTANCE
	var right := direction.cross(Vector3.UP).normalized()
	# Rio Negro pela esquerda, Solimões pela direita (como se vê de Manaus descendo o rio)
	for side in [-1.0, 1.0]:
		var start: Vector3 = global_position + right * SIDE * side - direction * 0.5
		var to_meet: Vector3 = _meet - start
		to_meet.y = 0.0
		var wave := Pororoca.new()
		wave.tint = "negro" if side < 0.0 else "solimoes"
		wave.direction = to_meet.normalized()
		wave.width = WAVE_WIDTH * width_mult
		wave.damage = maxi(int(round(weapon_damage * WAVE_DAMAGE * (1.0 if side < 0.0 else 1.5))), 1)
		wave.slam_damage = wave.damage
		wave.throw = 1.5  # leva junto, sem arremessar longe (o redemoinho é que puxa)
		wave.max_length = maxf(to_meet.length() - 0.6, 1.0)
		wave.speed = WAVE_SPEED
		wave.on_arrive = _on_wave_arrived
		if side < 0.0 and kit and kit.has_method("soak_enemy"):
			wave.on_hit = kit.soak_enemy
		wave.position = start  # o pai (a arena) fica na origem
		get_parent().add_child(wave)


func _on_wave_arrived(_w: Node3D) -> void:
	_arrived += 1
	if _arrived >= 2 and not _burst_done:
		_burst_done = true
		_burst.call_deferred()


## O choque: redemoinho que puxa, e logo depois o dano e o atordoamento.
func _burst() -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	Fx.float_text(parent, _meet + Vector3(0, 2.6, 0), "ENCONTRO DAS ÁGUAS!", Color("e8c08a"))
	_swirl_visual(parent)
	Vfx.particles(parent, _meet + Vector3(0, 0.6, 0), "respingo", 26, 0.8, Color(0.25, 0.15, 0.08, 0.95), 1.0, Vector2(2.5, 6.0), 70.0, -10.0)
	Vfx.particles(parent, _meet + Vector3(0, 0.6, 0), "respingo", 26, 0.8, Color(0.85, 0.65, 0.4, 0.95), 1.0, Vector2(2.5, 6.0), 70.0, -10.0)
	var caught: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.health.is_dead:
			continue
		var to: Vector3 = _meet - e.global_position
		to.y = 0.0
		if to.length() > PULL_RADIUS:
			continue
		caught.append(e)
		if not e.is_boss and to.length() > 0.6:
			e._knockback = to.normalized() * sqrt(60.0 * (to.length() - 0.5))
	await get_tree().create_timer(0.5, false).timeout
	if not is_inside_tree():
		return
	var dmg := maxi(int(round(weapon_damage * BURST_DAMAGE)), 1)
	for e in caught:
		if not is_instance_valid(e) or e.health.is_dead:
			continue
		var soaked: bool = e.has_method("is_soaked") and e.is_soaked()
		e.take_hit(dmg * (2 if soaked else 1), soaked, Vector3.ZERO)
		if not e.health.is_dead:
			e.stun(stun_time)
		if kit and kit.has_method("on_encontro_hit"):
			kit.on_encontro_hit(e)
	Vfx.ground_ring(parent, _meet, "onda_choque", Color(0.9, 0.7, 0.45), PULL_RADIUS * 2.0, 0.4)
	get_tree().create_timer(SWIRL_TIME, false).timeout.connect(queue_free)


const SWIRL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Redemoinho do encontro: metade cor de chá escuro (Rio Negro), metade barrenta (Solimões),
// separadas por uma linha que serpenteia e gira; espuma clara na linha e na borda.
uniform float age = 0.0;
uniform vec3 negro : source_color = vec3(0.1, 0.055, 0.025);
uniform vec3 solimoes : source_color = vec3(0.72, 0.5, 0.26);
uniform vec3 espuma : source_color = vec3(0.93, 0.86, 0.72);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) { discard; }
	float a = atan(p.y, p.x) + r * 5.0 - age * 9.0;
	float seam = sin(a) + 0.25 * sin(a * 3.0 + age * 4.0);
	vec3 c = mix(negro, solimoes, smoothstep(-0.06, 0.06, seam));
	float foam = 1.0 - smoothstep(0.0, 0.1, abs(seam));
	c = mix(c, espuma, foam * 0.8);
	float edge = smoothstep(0.85, 0.97, r);
	c = mix(c, espuma, edge * 0.6);
	ALBEDO = c;
	float life = 1.0 - smoothstep(0.65, 1.0, age);
	ALPHA = life * (1.0 - smoothstep(0.92, 1.0, r)) * 0.92;
}
"""
static var _swirl_shader: Shader


## Aquecimento (tela de carregamento): compila o redemoinho antes da 1ª vez no jogo.
static func warm(parent: Node3D, at: Vector3) -> void:
	var e := EncontroAguas.new()
	e._meet = at
	e._swirl_visual(parent)
	e.free()


func _swirl_visual(parent: Node) -> void:
	if _swirl_shader == null:
		_swirl_shader = Shader.new()
		_swirl_shader.code = SWIRL_SHADER
	var disk := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(PULL_RADIUS * 2.0, PULL_RADIUS * 2.0)
	disk.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = _swirl_shader
	m.render_priority = 2
	disk.material_override = m
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disk.add_to_group("floor_effects")
	parent.add_child(disk)
	disk.global_position = _meet + Vector3(0, 0.07, 0)
	disk.scale = Vector3.ONE * 0.2
	var t := disk.create_tween().set_parallel()
	t.tween_property(disk, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("age", v), 0.0, 1.0, SWIRL_TIME + 0.4)
	t.chain().tween_callback(disk.queue_free)
