class_name HubStation
extends Area3D
## Ponto de interação do hub (portal, baú, quadro de heróis, artesão).
## Quando o herói chega perto, avisa a interface para mostrar o botão de ação.

signal presence_changed(station: HubStation, inside: bool)

var station_id: StringName
var title := ""
## Texto do botão de ação (ex.: "ABRIR", "ENTRAR").
var action_text := "ABRIR"
## Portais: a região que este portal abre (o painel do portal já vem com ela escolhida).
var region := ""
var label_color := Color("ffd98a")
var label_height := 3.2
## Nome flutuando em cima (o Salão dos Portais usa placas fixas no lugar).
var show_label := true


static func create(id: StringName, station_title: String, action: String) -> HubStation:
	var s := HubStation.new()
	s.station_id = id
	s.title = station_title
	s.action_text = action
	s.name = String(id).capitalize()
	return s


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.4
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	add_child(shape)

	if not show_label:
		_connect_presence()
		return
	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = UiStyle.title_font()
	label.font_size = 56
	label.outline_size = 14
	label.outline_modulate = Color(0.03, 0.05, 0.1, 0.9)
	label.pixel_size = 0.009
	label.modulate = label_color
	label.no_depth_test = true
	label.position = Vector3(0, label_height, 0)
	add_child(label)

	_connect_presence()


func _connect_presence() -> void:
	body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			presence_changed.emit(self, true))
	body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			presence_changed.emit(self, false))
