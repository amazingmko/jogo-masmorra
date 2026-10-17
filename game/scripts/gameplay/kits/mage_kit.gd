class_name MageKit
extends HeroKit
## Encantado do Rio (mago da água).
##  Passiva     Encharcar: cada disparo deixa o inimigo encharcado por 4 s.
##  Habilidade  Espelho do Rio: se teletransporta 5 m para onde aponta e deixa uma cópia de água
##              que explode quando um inimigo encosta (e encharca quem pega).
##  Ultimate    Pororoca: uma onda atravessa a sala, arrasta os inimigos e joga contra a parede;
##              quem bate na parede leva dano extra (o dobro se estiver encharcado).
##  Passiva     Ricochete: a cada 4 disparos, o seguinte quica em mais 2 inimigos.

const SOAK_TIME := 4.0
const BLINK_DISTANCE := 5.0
const BLINK_COOLDOWN := 9.0
const CLONE_DAMAGE := 1.5    # explosão da cópia: 150% do dano do cajado
const WAVE_DAMAGE := 1.2     # onda: 120% ao passar
const SLAM_DAMAGE := 1.5     # bater na parede: 150% (300% encharcado)
const RICOCHET_EVERY := 4
const RICOCHET_BOUNCES := 2
const COLOR := Color("4db8ff")

var _shots := 0


func skill_name() -> String:
	return "Espelho"


func skill_cooldown() -> float:
	return BLINK_COOLDOWN


func skill_color() -> Color:
	return COLOR


func ultimate_name() -> String:
	return "Pororoca"


func describe() -> PackedStringArray:
	return PackedStringArray([
		"Encharcar (passiva): cada disparo deixa o inimigo encharcado por %d s." % SOAK_TIME,
		"Espelho do Rio (habilidade, %d s): teletransporta %d m para onde aponta e deixa uma cópia de água que explode quando um inimigo encosta." % [BLINK_COOLDOWN, BLINK_DISTANCE],
		"Pororoca (ultimate): uma onda atravessa a sala e joga os inimigos contra a parede; bater na parede dói, e o dobro em quem está encharcado.",
		"Ricochete (passiva): a cada %d disparos, o seguinte quica em mais %d inimigos." % [RICOCHET_EVERY, RICOCHET_BOUNCES],
	])


func _use_skill() -> bool:
	var origin := player.global_position
	var dir := player.facing()
	dir.y = 0.0
	if dir.length() < 0.1:
		return false
	dir = dir.normalized()
	# Não atravessa parede: para um pouco antes do que o raio encontrar.
	var space := player.get_world_3d().direct_space_state
	var from := origin + Vector3(0, 0.6, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * BLINK_DISTANCE, Layers.WORLD)
	var hit := space.intersect_ray(query)
	var dist := BLINK_DISTANCE
	if not hit.is_empty():
		dist = maxf(from.distance_to(hit.position) - 0.6, 0.0)
	var clone := WaterClone.new()
	clone.owner_player = player
	clone.damage = maxi(int(round(player.weapon_stats.damage * CLONE_DAMAGE)), 1)
	clone.soak_time = SOAK_TIME
	player.get_parent().add_child(clone)
	clone.global_position = Vector3(origin.x, 0.0, origin.z)
	player.global_position = origin + dir * dist
	player.reset_physics_interpolation()
	Vfx.particles(player.get_parent(), origin + Vector3(0, 1.0, 0), "faisca", 14, 0.4, COLOR, 0.35, Vector2(1.5, 3.0), 180.0, -3.0)
	Vfx.particles(player.get_parent(), player.global_position + Vector3(0, 1.0, 0), "faisca", 14, 0.4, COLOR, 0.35, Vector2(1.5, 3.0), 180.0, -3.0)
	return true


func _use_ultimate() -> void:
	var wave := Pororoca.new()
	wave.direction = player.facing()
	wave.damage = maxi(int(round(player.weapon_stats.damage * WAVE_DAMAGE)), 1)
	wave.slam_damage = maxi(int(round(player.weapon_stats.damage * SLAM_DAMAGE)), 1)
	player.get_parent().add_child(wave)
	wave.global_position = player.global_position - wave.direction.normalized() * 2.0
	Fx.float_text(player.get_parent(), player.global_position + Vector3(0, 3.0, 0), "POROROCA!", COLOR)


func on_run_start() -> void:
	super()
	_shots = 0


func modify_projectile(p: Projectile) -> void:
	p.on_hit = _on_projectile_hit
	_shots += 1
	if _shots > RICOCHET_EVERY:
		_shots = 0
		p.bounces = RICOCHET_BOUNCES


func _on_projectile_hit(enemy: Node3D, _p: Projectile) -> void:
	if is_instance_valid(enemy) and enemy.has_method("soak"):
		enemy.soak(SOAK_TIME)
