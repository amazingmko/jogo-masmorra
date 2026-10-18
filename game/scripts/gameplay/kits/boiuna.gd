class_name Boiuna
extends Node3D
## Boiuna, a Cobra-Grande do rio (talento máximo do Encantado): no lugar da Pororoca, uma cobra
## de água circula em volta dele por alguns segundos, mordendo quem chega perto (dano, encharca e
## empurra para fora). No fim, avança como uma Pororoca na direção em que ele mira.

const RING := 3.0          # raio do círculo da cobra
const REACH := 1.6         # quanto para dentro/fora do círculo ela pega
const SEGMENTS := 12
const TURN_SPEED := 2.6    # radianos por segundo
const BITE_EVERY := 0.5

var owner_player: Player
var kit: MageKit
var duration := 6.0
var damage := 30
var _t := 0.0
var _bite := 0.0
var _segments: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("floor_effects")
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.62, 0.95, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.55, 1.0)
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.15
	for i in SEGMENTS:
		var seg := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := lerpf(0.55, 0.2, float(i) / SEGMENTS)  # cabeça grossa, rabo fino
		sphere.radius = r
		sphere.height = r * 2.0
		seg.mesh = sphere
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(seg)
		_segments.append(seg)
	Vfx.particles(_segments[0], Vector3.ZERO, "faisca", 12, 0.5, Color(0.85, 0.95, 1.0), 0.25, Vector2(0.5, 1.5), 180.0, -3.0, true, false)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(owner_player):
		global_position = owner_player.global_position
	for i in _segments.size():
		var a := _t * TURN_SPEED - i * 0.28
		var h := 0.6 + sin(_t * 6.0 - i * 0.7) * 0.25
		_segments[i].position = Vector3(cos(a) * RING, h, sin(a) * RING)
	_bite -= delta
	if _bite <= 0.0:
		_bite = BITE_EVERY
		_bite_around()
	if _t >= duration:
		set_process(false)
		if kit and is_instance_valid(owner_player):
			kit.launch_wave(owner_player.facing(), owner_player.global_position)
		queue_free()


func _bite_around() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.health.is_dead:
			continue
		var to: Vector3 = enemy.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if absf(d - RING) <= REACH:
			if kit:
				kit.soak_enemy(enemy)
			enemy.take_hit(damage, false, to)
			if enemy.has_method("push"):
				enemy.push(to, 1.2)
