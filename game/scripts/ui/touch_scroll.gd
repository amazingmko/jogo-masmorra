class_name TouchScroll
extends Node
## Rolar arrastando o dedo em qualquer lugar da lista (não só na barrinha), com embalo ao soltar.
## Filho de um ScrollContainer. Usa os eventos de mouse (no celular o Godot cria um mouse a partir
## do toque), então funciona igual no PC e no celular. Se o dedo arrastou mais que DRAG_START, ao
## soltar não vale como toque no botão de baixo (rolar não compra nem equipa nada sem querer).

const DRAG_START := 14.0
const FRICTION := 5.0      # quanto o embalo perde por segundo
const MIN_SPEED := 30.0

var _scroll: ScrollContainer
var _down := false
var _dragging := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _velocity := 0.0
var _last_t := 0.0
var _clock := 0.0  # tempo de jogo (o embalo usa o mesmo relógio dos quadros)


static func attach(scroll: ScrollContainer) -> TouchScroll:
	var t := TouchScroll.new()
	t.name = "TouchScroll"
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	# o arrasto embutido do Godot fica desligado (senão rolaria em dobro no celular)
	scroll.scroll_deadzone = 100000
	scroll.add_child(t)
	return t


func _ready() -> void:
	_scroll = get_parent() as ScrollContainer
	_hint = _MoreHint.new()
	_hint.top_level = true  # fora do layout da lista: só desenha por cima da borda de baixo
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.z_index = 5
	_scroll.add_child.call_deferred(_hint)


## "Tem mais embaixo": a borda de baixo da lista escurece e mostra uma setinha, enquanto houver
## o que rolar (como as listas do Genshin e do Clash, que mostram a próxima linha cortada).
var _hint: Control
const HINT_HEIGHT := 46.0


class _MoreHint extends Control:
	var t := 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var dark := Color(0.02, 0.03, 0.05, 0.85)
		var clear := Color(0.02, 0.03, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([clear, clear, dark, dark]))
		var cx := w * 0.5
		var cy := h - 14.0 + sin(t * 4.0) * 2.0
		var gold := Color("f2c56b")
		draw_polyline(PackedVector2Array([Vector2(cx - 9, cy - 4), Vector2(cx, cy + 4), Vector2(cx + 9, cy - 4)]), gold, 3.0, true)


func _update_hint(delta: float) -> void:
	if _hint == null or not is_instance_valid(_hint) or not _hint.is_inside_tree():
		return
	var bar := _scroll.get_v_scroll_bar()
	var more := _scroll.is_visible_in_tree() and bar.max_value - bar.page - _scroll.scroll_vertical > 4.0
	_hint.visible = more
	if not more:
		return
	var r := _scroll.get_global_rect()
	var bar_w := bar.size.x if bar.visible else 0.0
	_hint.global_position = Vector2(r.position.x, r.end.y - HINT_HEIGHT)
	_hint.size = Vector2(r.size.x - bar_w, HINT_HEIGHT)
	_hint.t += delta
	_hint.queue_redraw()


func _input(event: InputEvent) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _scroll.get_global_rect().has_point(event.position) and _can_scroll():
				_down = true
				_dragging = false
				_start = event.position
				_last = event.position
				_velocity = 0.0
				_last_t = _clock
		elif _down:
			_down = false
			if _dragging:
				_dragging = false
				# soltou depois de rolar: não é um toque. O "soltar" de verdade vai para fora da tela,
				# assim o botão onde o dedo começou solta sem disparar (e não fica preso apertado).
				get_viewport().set_input_as_handled()
				var fake := InputEventMouseButton.new()
				fake.button_index = MOUSE_BUTTON_LEFT
				fake.pressed = false
				fake.position = Vector2(-10000, -10000)
				fake.global_position = fake.position
				Input.parse_input_event(fake)
	elif event is InputEventMouseMotion and _down:
		var pos: Vector2 = event.position
		if not _dragging and pos.distance_to(_start) > DRAG_START:
			_dragging = true
		if _dragging:
			var dy := pos.y - _last.y
			_scroll.scroll_vertical = int(_scroll.scroll_vertical - dy)
			var now := _clock
			var dt := maxf(now - _last_t, 1.0 / 120.0)
			_velocity = lerpf(_velocity, -dy / dt, 0.5)
			_last_t = now
		_last = pos


func _process(delta: float) -> void:
	_clock += delta
	_update_hint(delta)
	if _down or absf(_velocity) < MIN_SPEED or _scroll == null:
		_velocity = 0.0 if not _down else _velocity
		return
	_scroll.scroll_vertical = int(_scroll.scroll_vertical + _velocity * delta)
	_velocity *= maxf(1.0 - FRICTION * delta, 0.0)


func _can_scroll() -> bool:
	var bar := _scroll.get_v_scroll_bar()
	return bar != null and bar.max_value > bar.page + 1.0
