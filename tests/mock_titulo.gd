extends SceneTree
## Prévias da tela de título (3 opções de nome/logotipo) sobre o Salão dos Portais.
##   godot --path . --fixed-fps 60 --script res://tests/mock_titulo.gd -- out=/pasta

var _out := "/tmp"
var _layer: CanvasLayer

const GOLD := """
shader_type canvas_item;
// Letras em ouro: degradê de cima (claro) para baixo (escuro) e um brilho que corre devagar.
uniform float altura = 160.0;
uniform vec4 topo : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 meio : source_color = vec4(0.95, 0.75, 0.38, 1.0);
uniform vec4 base : source_color = vec4(0.62, 0.38, 0.14, 1.0);
varying vec2 pos;
void vertex() { pos = VERTEX; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = clamp(pos.y / altura, 0.0, 1.0);
	vec3 c = t < 0.5 ? mix(topo.rgb, meio.rgb, t * 2.0) : mix(meio.rgb, base.rgb, (t - 0.5) * 2.0);
	float shine = smoothstep(0.06, 0.0, abs(fract(pos.x / 900.0 - TIME * 0.15) - 0.5 + (t - 0.5) * 0.3));
	c += vec3(1.0, 0.95, 0.8) * shine * 0.5;
	COLOR = vec4(c, tex.a * COLOR.a);
}
"""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.trim_prefix("out=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://game/scenes/hub.tscn")
	await _frames(20)
	var hub = current_scene
	hub.get_node("HubUI").visible = false
	for c in hub.get_node("HubUI").get_children():
		if c is CanvasItem:
			c.visible = false
	hub.get_node("Player").visible = false
	var cam: Camera3D = hub.get_node("Camera")
	cam.set_script(null)
	cam.fov = 55.0
	cam.global_position = Vector3(0, 3.0, 7.5)
	cam.look_at(Vector3(0, 3.6, -12), Vector3.UP)
	# a Pedra do Encontro (cristal e placa) fica na frente dos portais: some só nesta tela
	var hall = hub.get_node("Town/Salao")
	for n in hall.get_children():
		if n is Node3D and absf(n.position.x) < 2.0 and n.position.z > -6.0 and n.position.z < 1.5 and n.position.y > 0.05:
			n.visible = false
	for opt in ["A", "B", "C"]:
		if _layer:
			_layer.queue_free()
		_layer = CanvasLayer.new()
		_layer.layer = 10
		root.add_child(_layer)
		_vignette()
		match opt:
			"A":
				_logo_a()
			"B":
				_logo_b()
			"C":
				_logo_c()
		await _frames(12)
		root.get_viewport().get_texture().get_image().save_png("%s/titulo_%s.png" % [_out, opt])
	quit(0)


# ---------- peças ----------

func _vignette() -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
void fragment() {
	vec2 p = UV - vec2(0.5, 0.42);
	float v = smoothstep(0.25, 0.85, length(p * vec2(1.2, 1.6)));
	COLOR = vec4(0.01, 0.02, 0.05, 0.25 + v * 0.6);
}
"""
	m.shader = s
	r.material = m
	_layer.add_child(r)
	# "Toque para começar" embaixo
	var t := _text("Toque para começar", 26, Color("cfe9ff"))
	t.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.offset_top = -80
	t.offset_bottom = -40
	_layer.add_child(t)


func _text(s: String, size: int, color: Color, outline := 8) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://game/ui/fontes/marcellus_sc.ttf"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07))
	l.add_theme_constant_override("outline_size", outline)
	return l


## Título em ouro: uma camada de brilho azul atrás (sombra borrada), contorno escuro e o ouro.
func _gold_title(s: String, size: int, at_y: float, spacing := 0) -> Control:
	var box := Control.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = at_y
	box.offset_left = -640
	box.offset_right = 640
	box.custom_minimum_size = Vector2(1280, size * 1.4)
	_layer.add_child(box)
	for layer in [["glow", Color(0.35, 0.75, 1.0, 0.35), 34], ["dark", Color(0.03, 0.04, 0.09), 14], ["gold", Color.WHITE, 0]]:
		var l := _text(s, size, layer[1], layer[2])
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.add_theme_constant_override("outline_size", layer[2])
		if spacing != 0:
			var f := FontVariation.new()
			f.base_font = load("res://game/ui/fontes/marcellus_sc.ttf")
			f.spacing_glyph = spacing
			l.add_theme_font_override("font", f)
		if layer[0] == "glow":
			l.add_theme_color_override("font_color", Color(0, 0, 0, 0))
			l.add_theme_color_override("font_outline_color", layer[1])
		elif layer[0] == "dark":
			l.add_theme_color_override("font_color", Color(0, 0, 0, 0))
			l.add_theme_color_override("font_outline_color", layer[1])
		else:
			var m := ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = GOLD
			m.shader = sh
			m.set_shader_parameter("altura", size * 1.25)
			l.material = m
			l.add_theme_constant_override("outline_size", 0)
		box.add_child(l)
	return box


func _tex_rect(path: String, size: Vector2, at: Vector2, color := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.size = size
	t.position = at - size * 0.5
	t.modulate = color
	_layer.add_child(t)
	return t


## Linha fina dourada com um losango no meio (enfeite entre título e subtítulo).
func _ornament(y: float, half: float) -> void:
	for side in [-1, 1]:
		var line := ColorRect.new()
		line.color = Color(0.85, 0.66, 0.36, 0.9)
		line.size = Vector2(half, 2)
		line.position = Vector2(640 + (18 if side > 0 else -18 - half), y)
		_layer.add_child(line)
	_tex_rect("res://game/ui/abissal/selo_losango.png", Vector2(30, 30), Vector2(640, y + 1), Color(1, 0.85, 0.5))


# ---------- opções ----------

## A: "Encantados" grande, em ouro, com o subtítulo numa faixa (placa) logo abaixo.
func _logo_a() -> void:
	_gold_title("Encantados", 128, 120)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiStyle.plate())
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.offset_top = 300
	_layer.add_child(plate)
	plate.add_child(_text("Os Portais do Folclore", 32, Color("ffd98a"), 6))


## B: "Encante" numa palavra só, bem espaçada, com o anel do portal atrás e enfeites finos.
func _logo_b() -> void:
	_tex_rect("res://game/ui/abissal/anel.png", Vector2(420, 420), Vector2(640, 230), Color(0.55, 0.85, 1.0, 0.45))
	_gold_title("Encante", 150, 120, 14)
	_ornament(330, 230)
	var sub := _text("Lendas do Brasil", 28, Color("cfe9ff"), 6)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub.offset_top = 350
	_layer.add_child(sub)


## C: "Reinos Encantados" em duas linhas (a de cima menor), estilo brasão de MMORPG.
func _logo_c() -> void:
	_tex_rect("res://game/ui/abissal/selo_losango.png", Vector2(120, 120), Vector2(640, 95), Color(1, 0.85, 0.5))
	_tex_rect("res://game/ui/abissal/selo_brilho.png", Vector2(120, 120), Vector2(640, 95), Color(0.55, 0.85, 1.0))
	_gold_title("Reinos", 72, 150, 10)
	_gold_title("Encantados", 120, 215)
	_ornament(390, 260)
