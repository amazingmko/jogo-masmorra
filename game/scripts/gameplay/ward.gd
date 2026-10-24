class_name Ward
extends StaticBody3D
## Protegido de uma Provação (o totem da aldeia, as mudas do viveiro): os bichos o tratam como um
## herói (grupo "heroes"), mas preferem ele (target_priority) e ele não anda nem revida.
## Tem a mesma "cara" que o inimigo espera de um herói: health, receive_attack e velocity.

signal destroyed(ward: Ward)

## Metros "a menos" na conta de quem está mais perto: com 6, um bicho a 9 m do totem e a 4 m do
## herói vai no totem.
var target_priority := 6.0
var velocity := Vector3.ZERO
var health: Health
var display_name := ""
var _height := 1.0
var _visual: Node3D
var _flash := 0.0


static func create(model: String, max_hp: int, height: float, name_text: String, radius := 0.6, model_scale := 1.0) -> Ward:
	var w := Ward.new()
	w.display_name = name_text
	w._height = height
	w.collision_layer = Layers.PLAYER
	w.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height * 0.5
	w.add_child(shape)
	var path := "res://game/art/ambiente/%s.glb" % model
	if ResourceLoader.exists(path):
		w._visual = (load(path) as PackedScene).instantiate()
		w.add_child(w._visual)
		var box := _bounds(w._visual, Transform3D.IDENTITY)
		if box.size.y > 0.01:
			w._visual.scale = Vector3.ONE * (height / box.size.y) * model_scale
			w._visual.position.y = -box.position.y * w._visual.scale.y
	w.health = Health.new()
	w.health.max_health = maxi(max_hp, 1)
	w.add_child(w.health)
	w.add_to_group("heroes")
	w.add_to_group("wards")
	return w


## Caixa de todas as malhas do modelo (para deixar com a altura pedida, pé no chão).
static func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var here: Transform3D = xf * ((n as Node3D).transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = here * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := _bounds(c, here)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out


func _ready() -> void:
	health.health = health.max_health
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	EnemyHealthBar.attach(self, health, _height + 0.45, true)


func _process(delta: float) -> void:
	if _flash <= 0.0 or _visual == null:
		return
	_flash -= delta
	_visual.rotation.z = 0.06 * sin(_flash * 50.0) * maxf(_flash, 0.0) / 0.2


func receive_attack(amount: int, _effect: int, _duration: float, _power: int, _from: Vector3, _ignore := false) -> void:
	if health.is_dead:
		return
	health.take_damage(amount, false, true)


func heal_fraction(frac: float) -> void:
	var amount := int(round(health.max_health * frac))
	if amount > 0 and not health.is_dead and health.health < health.max_health:
		health.heal(amount)
		Fx.float_text(get_parent(), global_position + Vector3(0, 1.6, 0), "+%d" % amount, Color("6fdc7b"))


func _on_damaged(amount: int) -> void:
	_flash = 0.2
	Fx.damage_number(get_parent(), global_position + Vector3(0, 1.4, 0), amount, false, Color("ff9a6b"))


func _on_died() -> void:
	remove_from_group("heroes")
	FxKit.impact(get_parent(), global_position + Vector3(0, 0.6, 0), 1.6, Color("c98b4a"), 0.3)
	if _visual:
		var t := create_tween()
		t.tween_property(_visual, "scale", _visual.scale * Vector3(1.0, 0.15, 1.0), 0.35)
	destroyed.emit(self)
