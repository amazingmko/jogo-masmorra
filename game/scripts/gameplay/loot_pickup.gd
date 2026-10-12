class_name LootPickup
extends Area3D
## Item caído no chão. É puxado para o herói quando ele chega perto e entra no inventário.
## Avisa quem estiver no grupo "loot_listeners" com on_loot_collected(item, qty, instance).
## Equipamentos carregam a peça já gerada (instance); materiais vêm só com quantidade.
const MAGNET_RADIUS := 2.5
const MAGNET_SPEED := 9.0

var item: ItemData
var qty := 1
var instance: Dictionary = {}

var _player: Node3D
var _visual: MeshInstance3D
var _age := 0.0
var _collected := false


static func create(item_data: ItemData, amount: int, piece: Dictionary = {}) -> LootPickup:
	var p := LootPickup.new()
	p.item = item_data
	p.qty = amount
	p.instance = piece
	return p


func rarity() -> int:
	return int(instance.get("rarity", item.rarity)) if not instance.is_empty() else int(item.rarity)


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = Layers.PICKUPS
	collision_mask = Layers.PLAYER
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	add_child(shape)

	_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	var size := 0.42 if item.is_equipment() else 0.3
	box.size = Vector3.ONE * size
	_visual.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameEnums.rarity_color(rarity())
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.6
	_visual.material_override = mat
	_visual.rotation_degrees = Vector3(30, 0, 30)
	add_child(_visual)

	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")
	# Pulinho ao cair.
	_visual.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _physics_process(delta: float) -> void:
	_age += delta
	_visual.rotation.y += 2.0 * delta
	_visual.position.y = 0.1 * sin(_age * 4.0)
	if _player and _age > 0.35 and not _player.health.is_dead:
		var to_player := _player.global_position + Vector3(0, 0.6, 0) - global_position
		if to_player.length() < MAGNET_RADIUS:
			global_position += to_player.normalized() * minf(MAGNET_SPEED * delta, to_player.length())
	# Se o herói já estava em cima quando o item caiu, o "entrou" não dispara: confere aqui.
	if _age > 0.35 and not _collected:
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	if _collected or _age < 0.35 or not body.is_in_group("player"):
		return
	_collected = true
	if instance.is_empty():
		GameState.inventory.add(item, qty)
	else:
		GameState.inventory.add_equipment(instance)
	get_tree().call_group("loot_listeners", "on_loot_collected", item, qty, instance)
	queue_free()
