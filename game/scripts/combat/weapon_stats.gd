class_name WeaponStats
extends RefCounted
## Lê os atributos de combate de uma arma (campo "stats" do ItemData) com valores padrão.
## Chaves usadas no stats:
##   damage            dano por golpe ou disparo
##   attack_speed      ataques por segundo
##   attack_range      alcance (corpo a corpo) ou distância máxima do disparo
##   projectile_speed  0 = corpo a corpo; maior que 0 = dispara projétil

var damage: int = 3
var attack_speed: float = 1.5
var attack_range: float = 1.8
var projectile_speed: float = 0.0


static func from_item(item: ItemData) -> WeaponStats:
	var w := WeaponStats.new()
	if item == null:
		return w
	w.damage = int(item.stats.get("damage", w.damage))
	w.attack_speed = float(item.stats.get("attack_speed", w.attack_speed))
	w.attack_range = float(item.stats.get("attack_range", w.attack_range))
	w.projectile_speed = float(item.stats.get("projectile_speed", w.projectile_speed))
	return w


func is_ranged() -> bool:
	return projectile_speed > 0.0


func cooldown() -> float:
	return 1.0 / maxf(attack_speed, 0.1)


## Distância em que a auto-mira procura alvos.
func aim_range() -> float:
	return attack_range if is_ranged() else attack_range + 4.0
