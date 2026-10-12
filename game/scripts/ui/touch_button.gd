class_name TouchButton
extends Control
## Botão redondo que aceita vários dedos ao mesmo tempo (um no joystick, outro aqui).
## O Button comum do Godot só reconhece o primeiro dedo, por isso este existe.

signal pressed_changed(is_pressed: bool)

@export var text: String = "ATACAR"
@export var color: Color = Color("e8c26a")

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
	fill.a = 0.75 if is_pressed else 0.4
	draw_circle(center, r, fill)
	draw_arc(center, r, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0, true)
	var font := get_theme_default_font()
	var font_size := 22
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center - Vector2(text_size.x * 0.5, -font_size * 0.35), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
