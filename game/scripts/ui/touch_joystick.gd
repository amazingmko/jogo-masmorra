class_name TouchJoystick
extends Control
## Joystick de toque "flutuante": aparece onde o dedo encosta dentro da área (metade esquerda da tela).
## No PC, funciona com o mouse (o projeto emula toque a partir do mouse).

## Direção atual, de comprimento 0 a 1.
var value := Vector2.ZERO

@export var radius: float = 90.0
@export var deadzone: float = 0.12

var _touch_index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func release() -> void:
	_touch_index = -1
	value = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and get_global_rect().has_point(event.position):
			_touch_index = event.index
			_center = event.position
			_move_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_move_knob(event.position)


func _move_knob(pos: Vector2) -> void:
	var offset := pos - _center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob = _center + offset
	var raw := offset / radius
	value = raw if raw.length() > deadzone else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center_local: Vector2
	var knob_local: Vector2
	var alpha := 0.25
	if _touch_index >= 0:
		center_local = _center - global_position
		knob_local = _knob - global_position
		alpha = 0.6
	else:
		# Posição de descanso: canto inferior esquerdo, para mostrar que o joystick existe.
		center_local = Vector2(radius + 60.0, size.y - radius - 60.0)
		knob_local = center_local
	var base := _tex("joystick_base")
	var knob := _tex("joystick_pino")
	if base and knob:
		var a2 := 0.55 if _touch_index < 0 else 0.9
		draw_texture_rect(base, Rect2(center_local - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(1, 1, 1, a2))
		var kr := radius * 0.46
		draw_texture_rect(knob, Rect2(knob_local - Vector2(kr, kr), Vector2(kr, kr) * 2.0), false, Color(1, 1, 1, minf(a2 + 0.1, 1.0)))
		return
	draw_circle(center_local, radius, Color(1, 1, 1, alpha * 0.25))
	draw_arc(center_local, radius, 0.0, TAU, 48, Color(1, 1, 1, alpha), 3.0, true)
	draw_circle(knob_local, radius * 0.42, Color(1, 1, 1, alpha + 0.15))


static var _texs := {}


static func _tex(name: String) -> Texture2D:
	if not _texs.has(name):
		var path := UiStyle.dir() + name + ".png"
		_texs[name] = load(path) if ResourceLoader.exists(path) else null
	return _texs[name]
