class_name NightMode
extends Node
## A noite na mata (andares 6 a 10, depois do Acampamento). Com a câmera de cima não se vê céu,
## então a noite aparece pela luz:
##  - luz de lua: a sala azulada e escura; o sol vira lua fraca e fria;
##  - tocha do herói: uma luz quente em volta dele;
##  - bordas da tela escurecidas: só se enxerga bem perto do herói;
##  - olhos dos bichos brilhando no escuro;
##  - mais vaga-lumes, cogumelos acesos e a lua refletida no igarapé.
## O anoitecer é uma transição de alguns segundos (no Acampamento).

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
uniform float radius = 0.30;
uniform float soft = 0.40;
uniform vec4 tint : source_color = vec4(0.015, 0.025, 0.07, 1.0);
void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5, 0.52);
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float d = length(uv);
	COLOR = vec4(tint.rgb, smoothstep(radius, radius + soft, d) * 0.8 * amount);
}
"""
## Valores da noite (o dia é o que BiomeAmbience.apply deixou).
const NIGHT := {
	"ambient_light_color": Color("40528a"), "ambient_light_energy": 0.68,
	"fog_light_color": Color("0a1230"), "fog_density": 0.012,
	"adjustment_saturation": 0.8, "background_color": Color("03060f"),
}
const MOON_COLOR := Color("9db8ff")
const MOON_ENERGY := 0.55
const EYE_BONES := ["mixamorig_Head", "head0", "cabeca", "coluna0"]
const EYE_COLOR := Color(1.0, 0.8, 0.25)

var env: Environment
var sun: DirectionalLight3D
var player: Node3D
var dungeon: Node3D
var ambience: Node

var is_night := false
var amount := 0.0          # 0 = dia, 1 = noite (anima no anoitecer)
var _day := {}
var _sun_color: Color
var _sun_energy := 1.0
var _vignette: ShaderMaterial
var _lamp: OmniLight3D
var _tween: Tween


func setup(world: WorldEnvironment, sun_light: DirectionalLight3D, hero: Node3D, dungeon_root: Node3D, amb: Node) -> void:
	env = world.environment
	sun = sun_light
	player = hero
	dungeon = dungeon_root
	ambience = amb
	for k in NIGHT:
		_day[k] = env.get(k)
	_sun_color = sun.light_color
	_sun_energy = sun.light_energy
	var layer := CanvasLayer.new()
	layer.name = "Noite"
	layer.layer = -1  # embaixo da HUD
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	_vignette.shader = sh
	rect.material = _vignette
	layer.add_child(rect)
	add_child(layer)
	_lamp = OmniLight3D.new()
	_lamp.name = "Tocha"
	_lamp.light_color = Color(1.0, 0.75, 0.45)
	_lamp.omni_range = 7.0
	_lamp.omni_attenuation = 1.2
	_lamp.position = Vector3(0, 1.6, 0)
	_lamp.light_cull_mask = 0xFFFFF & ~Layers.WATER_VISUAL  # não reflete no igarapé
	_lamp.light_energy = 0.0
	_lamp.visible = false
	hero.add_child(_lamp)
	_apply(0.0)


## Liga/desliga a noite. seconds > 0: transição (anoitecer).
func set_night(on: bool, seconds := 0.0) -> void:
	is_night = on
	if _tween:
		_tween.kill()
	if seconds <= 0.0:
		_apply(1.0 if on else 0.0)
	else:
		_tween = create_tween()
		_tween.tween_method(_apply, amount, 1.0 if on else 0.0, seconds).set_trans(Tween.TRANS_SINE)
	refresh_floor()


## Coisas do andar (montadas a cada andar novo): olhos dos bichos, cogumelos, água.
func refresh_floor() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		on_enemy_spawned(e)
	_mushrooms(is_night)
	_water(amount)


func on_enemy_spawned(enemy: Node3D) -> void:
	var eyes: Node3D = enemy.get_node_or_null("OlhosNoite")
	if is_night and eyes == null:
		_add_eyes(enemy)
	elif eyes:
		eyes.visible = is_night


func _apply(k: float) -> void:
	amount = k
	for key in NIGHT:
		var a = _day[key]
		var b = NIGHT[key]
		env.set(key, lerp(a, b, k))
	sun.light_color = _sun_color.lerp(MOON_COLOR, k)
	sun.light_energy = lerpf(_sun_energy, MOON_ENERGY, k)
	_vignette.set_shader_parameter("amount", k)
	_lamp.visible = k > 0.01
	_lamp.light_energy = 2.2 * k
	if ambience and ambience.has_method("set_night"):
		ambience.set_night(k)
	_water(k)
	_spore_alpha(k)  # os esporos dos cogumelos acendem junto com o anoitecer


# ---------- olhos ----------

func _add_eyes(enemy: Node3D) -> void:
	var eyes := NightEyes.new()
	eyes.name = "OlhosNoite"
	eyes.enemy = enemy
	eyes.bone_names = EYE_BONES
	eyes.color = EYE_COLOR
	enemy.add_child(eyes)


# ---------- cogumelos e água ----------

## Cogumelos à noite: o modelo continua com a pintura dele; o que acende são esporos verdes
## flutuando em cima de cada um (um MultiMesh de pontinhos de luz por grupo de cogumelos).
const SPORE_COLOR := Color(0.55, 1.0, 0.65)
var _spores: Array[MultiMeshInstance3D] = []
var _spore_mat: StandardMaterial3D


func _mushrooms(on: bool) -> void:
	for n in _spores:
		if is_instance_valid(n):
			n.queue_free()
	_spores.clear()
	if dungeon == null or not on:
		return
	if _spore_mat == null:
		_spore_mat = StandardMaterial3D.new()
		_spore_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spore_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spore_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spore_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_spore_mat.albedo_texture = Vfx.tex("faisca")
		_spore_mat.vertex_color_use_as_albedo = true
		_spore_mat.albedo_color = SPORE_COLOR * 1.6
		_spore_mat.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = _spore_mat
	for mmi: MultiMeshInstance3D in dungeon.find_children("Decor_*", "MultiMeshInstance3D", true, false):
		if String(mmi.get_meta("kind", "")) != "cogumelos" or mmi.multimesh == null:
			continue
		var count := mmi.multimesh.instance_count
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = count * 3
		var rng := RandomNumberGenerator.new()
		rng.seed = count * 7919
		for i in count:
			var at: Vector3 = mmi.multimesh.get_instance_transform(i).origin
			for j in 3:
				var off := Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(0.2, 0.55), rng.randf_range(-0.18, 0.18))
				mm.set_instance_transform(i * 3 + j, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.5, 1.1)), at + off))
				mm.set_instance_color(i * 3 + j, Color(1, 1, 1, 0.0))
		var node := MultiMeshInstance3D.new()
		node.name = "Esporos"
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.add_child(node)
		_spores.append(node)
	_spore_alpha(amount)


## Os esporos acendem com o anoitecer e piscam devagar, cada um no seu tempo.
func _spore_alpha(k: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for node in _spores:
		if not is_instance_valid(node):
			continue
		var mm := node.multimesh
		for i in mm.instance_count:
			var blink := 0.55 + 0.45 * sin(t * 1.3 + i * 2.39)
			mm.set_instance_color(i, Color(1, 1, 1, k * blink))


func _process(_delta: float) -> void:
	if amount > 0.01 and not _spores.is_empty():
		_spore_alpha(amount)


func _water(k: float) -> void:
	if dungeon == null:
		return
	for w: MeshInstance3D in dungeon.find_children("Agua", "MeshInstance3D", true, false):
		var m := w.material_override as ShaderMaterial
		if m:
			m.set_shader_parameter("lua", k)
