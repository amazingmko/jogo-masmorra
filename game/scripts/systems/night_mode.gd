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
	for m: StandardMaterial3D in _glow_mats.values():
		m.emission_energy_multiplier = 1.6 * k  # os cogumelos acendem junto com o anoitecer


# ---------- olhos ----------

func _add_eyes(enemy: Node3D) -> void:
	var eyes := NightEyes.new()
	eyes.name = "OlhosNoite"
	eyes.enemy = enemy
	eyes.bone_names = EYE_BONES
	eyes.color = EYE_COLOR
	enemy.add_child(eyes)


# ---------- cogumelos e água ----------

var _glow_mats := {}


func _mushrooms(on: bool) -> void:
	if dungeon == null:
		return
	for mmi: MultiMeshInstance3D in dungeon.find_children("Decor_*", "MultiMeshInstance3D", true, false):
		if String(mmi.get_meta("kind", "")) != "cogumelos":
			continue
		if not on:
			mmi.material_override = null
			continue
		var mesh := mmi.multimesh.mesh if mmi.multimesh else null
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		if not _glow_mats.has(mesh):
			var src := mesh.surface_get_material(0) as StandardMaterial3D
			var m := (src.duplicate() if src else StandardMaterial3D.new()) as StandardMaterial3D
			m.emission_enabled = true
			m.emission = Color(0.35, 1.0, 0.55)
			m.emission_energy_multiplier = 1.6 * amount
			if src and src.albedo_texture:
				m.emission_texture = src.albedo_texture
			_glow_mats[mesh] = m
		mmi.material_override = _glow_mats[mesh]


func _water(k: float) -> void:
	if dungeon == null:
		return
	for w: MeshInstance3D in dungeon.find_children("Agua", "MeshInstance3D", true, false):
		var m := w.material_override as ShaderMaterial
		if m:
			m.set_shader_parameter("lua", k)
