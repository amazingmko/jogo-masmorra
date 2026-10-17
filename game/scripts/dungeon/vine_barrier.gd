class_name VineBarrier
extends StaticBody3D
## Porta da clareira durante a luta: cipós com espinhos que brotam do chão e fecham a passagem.
## Aberta: sem colisão e escondida. close()/open() animam o crescimento.

var width := 3.6
var _shape: CollisionShape3D
var _vines: Node3D
var _tween: Tween


func setup(door_width: float, thickness: float) -> void:
	width = door_width
	collision_layer = Layers.WORLD
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(door_width, 2.0, thickness)
	_shape.shape = box
	_shape.position.y = 1.0
	_shape.disabled = true
	add_child(_shape)
	_vines = Node3D.new()
	add_child(_vines)
	var vine := StandardMaterial3D.new()
	vine.albedo_color = Color("3d5a22")
	vine.roughness = 1.0
	var thorn := StandardMaterial3D.new()
	thorn.albedo_color = Color("8a2e2a")
	thorn.emission_enabled = true
	thorn.emission = Color("c0392b")
	thorn.emission_energy_multiplier = 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var count := int(door_width / 0.45)
	for i in count:
		var x := -door_width * 0.5 + (i + 0.5) * door_width / count
		var stalk := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.09
		cyl.height = rng.randf_range(1.3, 2.0)
		cyl.radial_segments = 5
		stalk.mesh = cyl
		stalk.material_override = vine
		stalk.position = Vector3(x, cyl.height * 0.5, rng.randf_range(-0.15, 0.15))
		stalk.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.3, 0.3))
		_vines.add_child(stalk)
		for k in 3:  # espinhos vermelhos
			var spike := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.04
			cone.height = 0.16
			cone.radial_segments = 4
			spike.mesh = cone
			spike.material_override = thorn
			spike.position = Vector3(0, (k - 1) * 0.35, 0.05)
			spike.rotation = Vector3(PI * 0.5, rng.randf() * TAU, 0)
			stalk.add_child(spike)
	_vines.scale = Vector3(1, 0.01, 1)
	visible = false


func close() -> void:
	_shape.set_deferred("disabled", false)
	visible = true
	_animate(1.0, 0.35)


func open() -> void:
	_shape.set_deferred("disabled", true)
	_animate(0.01, 0.3)


func _animate(to: float, time: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_vines, "scale:y", to, time).set_trans(Tween.TRANS_BACK if to > 0.5 else Tween.TRANS_SINE)
	if to < 0.5:
		_tween.tween_callback(func() -> void: visible = false)
