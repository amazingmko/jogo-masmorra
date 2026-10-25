extends Node3D
## Tela de título: o Salão dos Portais ao fundo (câmera passeando devagar), o logotipo ENCANTE
## e "Toque para começar". Qualquer toque, clique ou tecla leva ao hub.

const HUB_SCENE := "res://game/scenes/hub.tscn"
const LOGO := "res://game/ui/marca/logo_encante.png"

var _cam: Camera3D
var _t := 0.0
var _leaving := false
var _hint: Label
var _logo: TextureRect


func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	add_child(world)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	HubHall.apply_environment(world, sun)
	var hall := HubHall.new()
	hall.title_mode = true
	add_child(hall)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	add_child(_cam)
	_cam.current = true
	_place_camera()
	_build_ui()


func _place_camera() -> void:
	var sway := sin(_t * 0.25) * 1.2
	_cam.position = Vector3(sway, 3.4, 8.5)
	_cam.look_at(Vector3(sway * 0.3, 4.6, -12.0), Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	_place_camera()
	if _hint:
		_hint.modulate.a = 0.55 + 0.45 * sin(_t * 2.6)
	if _logo:
		_logo.pivot_offset = _logo.size * 0.5
		_logo.scale = Vector2.ONE * (1.0 + 0.012 * sin(_t * 1.3))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.42);
	float v = smoothstep(0.25, 0.85, length(p * vec2(1.2, 1.6)));
	COLOR = vec4(0.01, 0.02, 0.05, 0.2 + v * 0.6);
}
"""
	m.shader = sh
	shade.material = m
	layer.add_child(shade)
	_logo = TextureRect.new()
	_logo.texture = load(LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.anchor_left = 0.12
	_logo.anchor_right = 0.88
	_logo.anchor_top = 0.03
	_logo.anchor_bottom = 0.5
	layer.add_child(_logo)
	_hint = Label.new()
	_hint.text = "Toque para começar"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.title_label(_hint, 28, Color("cfe9ff"))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = -90
	_hint.offset_bottom = -44
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hint)
	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	if version == "":
		return
	var ver := Label.new()
	ver.text = "v%s" % version
	UiStyle.title_label(ver, 14, UiStyle.TEXT_DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -16
	ver.offset_bottom = -10
	layer.add_child(ver)


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if go:
		start()


func start() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(HUB_SCENE)
