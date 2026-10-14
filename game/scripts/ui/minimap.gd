class_name Minimap
extends Control
## Minimapa do andar: mostra salas visitadas e as portas vizinhas já vistas, centrado na sala atual.

const CELL_PX := 18.0
const GAP_PX := 9.0
const TYPE_COLORS := {
	DungeonLayout.RoomType.START: Color("9a93ad"),
	DungeonLayout.RoomType.COMBAT: Color("cfc8de"),
	DungeonLayout.RoomType.TREASURE: Color("e8c26a"),
	DungeonLayout.RoomType.REST: Color("6fdc7b"),
	DungeonLayout.RoomType.EXIT: Color("4db8ff"),
	DungeonLayout.RoomType.BOSS: Color("e05555"),
}

const DEN_COLOR := Color("ff3b3b")

var _layout: DungeonLayout
var _visited := {}
var _current := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func show_layout(layout: DungeonLayout) -> void:
	_layout = layout
	_visited.clear()
	_current = -1
	queue_redraw()


func set_current(room_index: int) -> void:
	_current = room_index
	_visited[room_index] = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.08, 0.15, 0.55))
	if _layout == null or _current < 0:
		return
	var known := {}
	for i in _visited:
		known[i] = true
		for n in _layout.rooms[i].links:
			known[n] = true

	var step := CELL_PX + GAP_PX
	var origin: Vector2i = _layout.rooms[_current].cell
	var mid := size * 0.5

	# Ligações primeiro, para ficarem por baixo das salas.
	for i in known:
		for n in _layout.rooms[i].links:
			if known.has(n) and (_visited.has(i) or _visited.has(n)):
				var a := mid + Vector2(_layout.rooms[i].cell - origin) * step
				var b := mid + Vector2(_layout.rooms[n].cell - origin) * step
				draw_line(a, b, Color(1, 1, 1, 0.35), 3.0)

	for i in known:
		var pos := mid + Vector2(_layout.rooms[i].cell - origin) * step
		var rect := Rect2(pos - Vector2.ONE * CELL_PX * 0.5, Vector2.ONE * CELL_PX)
		var den: bool = _layout.rooms[i].get("den", false)
		if _visited.has(i):
			draw_rect(rect, DEN_COLOR if den else TYPE_COLORS.get(_layout.rooms[i].type, Color.WHITE))
		else:
			# O covil aparece em vermelho mesmo antes de entrar: é escolha do jogador encarar.
			draw_rect(rect, DEN_COLOR if den else Color(1, 1, 1, 0.5), false, 3.0 if den else 2.0)
		if i == _current:
			draw_rect(rect.grow(3.0), Color.WHITE, false, 2.0)
