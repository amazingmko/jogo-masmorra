class_name TouchButton
extends Control
## Botão redondo que aceita vários dedos ao mesmo tempo (um no joystick, outro aqui).
## O Button comum do Godot só reconhece o primeiro dedo, por isso este existe.

signal pressed_changed(is_pressed: bool)

@export var text: String = "ATACAR"
@export var color: Color = Color("e8c26a")
## Anel de progresso em volta (recarga ou carga da ultimate): 0 a 1. Negativo = sem anel.
var progress := -1.0
## Apagado (ainda não dá para usar).
var dimmed := false
@export var font_size := 22
## Fonte do texto (vazio = a do tema).
var font: Font

var is_pressed := false
var _touch_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _contains(event.position):
			_touch_index = event.index
			_set_pressed(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_set_pressed(false)


func _contains(pos: Vector2) -> bool:
	var r := get_global_rect()
	return pos.distance_to(r.get_center()) <= minf(r.size.x, r.size.y) * 0.5


func _set_pressed(value: bool) -> void:
	is_pressed = value
	pressed_changed.emit(value)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var fill := color
	fill.a = 0.75 if is_pressed else (0.15 if dimmed else 0.4)
	draw_circle(center, r, fill)
	draw_arc(center, r, 0.0, TAU, 48, Color(1, 1, 1, 0.35 if dimmed else 0.7), 3.0, true)
	if progress >= 0.0:
		draw_arc(center, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 48, color.lightened(0.3), 7.0, true)
	var f: Font = font if font else get_theme_default_font()
	var text_size := f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(f, center - Vector2(text_size.x * 0.5, -font_size * 0.35), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.55 if dimmed else 1.0))


## Atualiza o desenho só quando algo muda.
func set_state(new_progress: float, new_dimmed: bool, new_text: String) -> void:
	if is_equal_approx(new_progress, progress) and new_dimmed == dimmed and new_text == text:
		return
	progress = new_progress
	dimmed = new_dimmed
	text = new_text
	queue_redraw()
