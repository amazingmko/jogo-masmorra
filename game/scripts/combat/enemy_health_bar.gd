class_name EnemyHealthBar
extends MeshInstance3D
## Barrinha de vida em cima do inimigo, para não poluir a tela:
##  - comuns: aparece quando ele leva dano e some sozinha depois de alguns segundos sem apanhar;
##  - furiosos (elite): fica sempre à mostra (embaixo do nome "Furioso").
## Chefes e a Onça Alfa já têm a barra grande no topo da tela, então não ganham esta.
## Um quadrado só com shader (billboard, sem luz): a parte cheia, o "rastro" do dano que
## acabou de levar (desce devagar) e o fundo escuro com borda.

const SHOW_SECONDS := 3.0
const FADE_SECONDS := 0.4
const WIDTH := 1.15
const HEIGHT := 0.17

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, blend_mix;
uniform float fill = 1.0;
uniform float trail = 1.0;
uniform float alpha = 1.0;
uniform vec4 fill_color : source_color = vec4(0.88, 0.25, 0.22, 1.0);
uniform vec2 px = vec2(0.014, 0.14);  // espessura da borda em UV (x, y)
void vertex() {
	// billboard: o quadrado sempre de frente para a câmera, mantendo a escala do nó
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 uv = UV;
	bool border = uv.x < px.x || uv.x > 1.0 - px.x || uv.y < px.y || uv.y > 1.0 - px.y;
	float x = (uv.x - px.x) / (1.0 - 2.0 * px.x);
	vec3 c = vec3(0.06, 0.05, 0.05);
	if (!border) {
		if (x <= fill) {
			c = fill_color.rgb * (1.08 - 0.25 * uv.y);  // um leve degradê de cima para baixo
		} else if (x <= trail) {
			c = vec3(1.0, 0.9, 0.7);
		} else {
			c = vec3(0.16, 0.13, 0.12);
		}
	}
	ALBEDO = c;
	ALPHA = alpha * (border ? 0.95 : 0.9);
}
"""
static var _shader: Shader

var always := false
var _health: Health
var _timer := 0.0
var _trail := 1.0
var _mat: ShaderMaterial


static func attach(enemy: Node3D, health: Health, height: float, keep_visible: bool) -> EnemyHealthBar:
	var bar := EnemyHealthBar.new()
	bar.name = "BarraVida"
	bar.always = keep_visible
	bar._health = health
	bar.position = Vector3(0, height, 0)
	enemy.add_child(bar)
	return bar


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	mesh = quad
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 10  # desenhada depois das manchas do chão (também transparentes)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if always:
		_mat.set_shader_parameter("fill_color", Color("ff4d3d"))
	if _health:
		_health.damaged.connect(_on_damaged)
		_health.changed.connect(_on_changed)
		_health.died.connect(_on_died)
	_update_fill()
	visible = always
	_set_alpha(1.0)


func _process(delta: float) -> void:
	if _health == null:
		return
	var fill := _fill()
	# o rastro claro do dano desce até a vida atual
	_trail = move_toward(_trail, fill, delta * 0.8) if _trail > fill else fill
	_mat.set_shader_parameter("trail", _trail)
	if always:
		return
	if _timer > 0.0:
		_timer -= delta
		_set_alpha(clampf(_timer / FADE_SECONDS, 0.0, 1.0))
		if _timer <= 0.0:
			visible = false


func is_showing() -> bool:
	return visible and (always or _timer > 0.0)


func _fill() -> float:
	return clampf(float(_health.health) / maxf(float(_health.max_health), 1.0), 0.0, 1.0)


func _update_fill() -> void:
	_mat.set_shader_parameter("fill", _fill())


func _on_damaged(_amount: int) -> void:
	_update_fill()
	if not always:
		visible = true
		_timer = SHOW_SECONDS + FADE_SECONDS
		_set_alpha(1.0)


func _on_changed(_hp: int, _max_hp: int, _a: int, _b: int) -> void:
	_update_fill()


func _on_died() -> void:
	queue_free()


func _set_alpha(a: float) -> void:
	_mat.set_shader_parameter("alpha", a)
