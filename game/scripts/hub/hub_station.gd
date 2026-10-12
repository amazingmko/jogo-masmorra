class_name HubStation
extends Area3D
## Ponto de interação do hub (portal, baú, quadro de heróis, artesão).
## Quando o herói chega perto, avisa a interface para mostrar o botão de ação.

signal presence_changed(station: HubStation, inside: bool)

var station_id: StringName
var title := ""
## Texto do botão de ação (ex.: "ABRIR", "ENTRAR").
var action_text := "ABRIR"


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

	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.008
	label.modulate = Color("f2ecff")
	label.position = Vector3(0, 3.2, 0)
	add_child(label)

	body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			presence_changed.emit(self, true))
	body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("player"):
			presence_changed.emit(self, false))
