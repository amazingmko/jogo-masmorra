extends SceneTree
## Rolagem no celular: arrastar a lista da Oficina rola (sem escolher a peça onde o dedo começou),
## o embalo continua depois de soltar, e um toque curto continua escolhendo a peça.
##   godot --path . --script res://tests/flow_rolagem.gd   (precisa de tela/xvfb: usa a interface)

var _fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok: " if ok else "FALHOU: ") + what)
	if not ok:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func _run() -> void:
	change_scene_to_file("res://game/scenes/hub.tscn")
	await _frames(10)
	var ui = current_scene.get_node("HubUI")
	ui._open(&"artesao")
	await _frames(10)
	var scrolls: Array = ui.find_children("*", "ScrollContainer", true, false)
	var left: ScrollContainer = null
	for s in scrolls:
		if s.is_visible_in_tree() and s.get_node_or_null("TouchScroll") and s.get_v_scroll_bar().max_value > s.get_v_scroll_bar().page + 1:
			if left == null or s.global_position.x < left.global_position.x:
				left = s  # a lista das peças (a da esquerda)
	check(left != null, "a lista da Oficina tem rolagem por arrasto")
	if left == null:
		quit(1)
		return
	var bar := left.get_v_scroll_bar()
	print("  rolagem máxima da lista: %d px" % int(bar.max_value - bar.page))
	check(bar.get_minimum_size().x >= 20.0, "barra larga para o dedo (%.0f px)" % bar.get_minimum_size().x)
	# toque curto escolhe (antes de qualquer arrasto), na lista das peças (a mais à esquerda)
	var item_start = ui._craft_item
	var pieces: ScrollContainer = null
	for s in scrolls:
		if s.is_visible_in_tree() and s.get_node_or_null("TouchScroll") and (pieces == null or s.global_position.x < pieces.global_position.x):
			pieces = s
	var r0 := pieces.get_global_rect()
	var tap0 := Vector2(r0.position.x + r0.size.x * 0.5, r0.position.y + 90)
	_move(tap0)
	await _frames(2)
	_mouse(tap0, true)
	await _frames(2)
	_mouse(tap0, false)
	await _frames(5)
	check(ui._craft_item != item_start, "toque curto escolhe a peça (%s -> %s)" % [item_start, ui._craft_item])
	scrolls = ui.find_children("*", "ScrollContainer", true, false)
	left = null
	for s in scrolls:
		if s.is_visible_in_tree() and s.get_node_or_null("TouchScroll") and s.get_v_scroll_bar().max_value > s.get_v_scroll_bar().page + 1:
			if left == null or s.global_position.x < left.global_position.x:
				left = s  # a lista das peças (a da esquerda)
	var item0 = ui._craft_item
	var r := left.get_global_rect()
	var start := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.8)
	_mouse(start, true)
	await _frames(1)
	for i in 6:
		_move(start - Vector2(0, 15 * (i + 1)))
		await _frames(1)
	_mouse(start - Vector2(0, 90), false)
	await _frames(1)
	var after_drag := left.scroll_vertical
	var ts = left.get_node("TouchScroll")
	print("  velocidade ao soltar: %.0f, preso %s" % [ts._velocity, ts._down])
	check(after_drag >= 70, "arrastar 90 px para cima rolou a lista (%d px)" % after_drag)
	await _frames(20)
	check(left.scroll_vertical > after_drag, "o embalo continua depois de soltar (%d -> %d)" % [after_drag, left.scroll_vertical])
	await _frames(5)
	check(ui._craft_item == item0, "rolar não escolheu a peça onde o dedo começou")
	print("fim: ", "TUDO OK" if _fails == 0 else "COM FALHAS")
	quit(0 if _fails == 0 else 1)
