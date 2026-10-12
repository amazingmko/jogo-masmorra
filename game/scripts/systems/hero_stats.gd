class_name HeroStats
extends RefCounted
## Calcula os atributos finais de um herói: base + nível + equipamento + bênçãos da run.
## Não depende de cena nem de autoload: dá para testar sozinho.

var max_health := 100
var max_shield := 30
var primary := 10      # valor do atributo principal da classe
var vigor := 0
var armor := 0
var crit_chance := 0.05
var haste := 0.0       # % de velocidade de ataque
var luck := 0.0        # % de recursos extras (usado nas recompensas)
var move_speed := 5.0
var weapon := WeaponStats.new()
## Fração do dano recebido que a armadura bloqueia (0 a 0.75).
var damage_reduction := 0.0
## Soma dos atributos de cada peça, para mostrar na tela.
var totals := {}


## equipped: {slot(int): instance(Dictionary)}. buffs: Array[BuffData].
static func compute(hero: HeroData, level: int, equipped: Dictionary, catalog: ItemCatalog, buffs: Array = []) -> HeroStats:
	var s := HeroStats.new()
	var primary_key: String = GameEnums.PRIMARY_KEYS[hero.primary_stat]
	var sum := {}
	for slot in equipped:
		var inst: Dictionary = equipped[slot]
		for key in inst.get("stats", {}):
			sum[key] = sum.get(key, 0) + int(inst.stats[key])
	s.totals = sum

	var lvl_bonus := maxi(level - 1, 0)
	s.primary = hero.base_primary + lvl_bonus * Progression.PRIMARY_PER_LEVEL + int(sum.get(primary_key, 0))
	s.vigor = lvl_bonus * Progression.VIGOR_PER_LEVEL + int(sum.get("vigor", 0))
	s.armor = int(sum.get("armor", 0))

	# Arma: a equipada, ou a inicial da classe como molde comum de nível 1.
	var weapon_inst: Dictionary = equipped.get(GameEnums.Slot.WEAPON, {})
	var weapon_template := catalog.get_item(StringName(weapon_inst.get("item_id", hero.starting_weapon_id)))
	s.weapon = WeaponStats.from_item(weapon_template)
	if not weapon_inst.is_empty():
		s.weapon.damage = int(weapon_inst.stats.get("damage", s.weapon.damage))

	var base_health := float(hero.max_health + s.vigor * 10)
	var base_damage := float(s.weapon.damage) * (1.0 + s.primary / 100.0)
	var base_crit := hero.crit_chance + float(sum.get("crit", 0)) / 100.0
	s.haste = float(sum.get("haste", 0))
	s.luck = float(sum.get("luck", 0))

	s.max_health = int(round(_apply(buffs, &"max_health", base_health)))
	s.max_shield = int(round(_apply(buffs, &"max_shield", float(hero.max_shield))))
	s.weapon.damage = maxi(int(round(_apply(buffs, &"damage", base_damage))), 1)
	s.weapon.attack_speed = _apply(buffs, &"attack_speed", s.weapon.attack_speed * (1.0 + s.haste / 100.0))
	s.weapon.attack_range = _apply(buffs, &"attack_range", s.weapon.attack_range)
	s.move_speed = _apply(buffs, &"move_speed", hero.move_speed)
	s.crit_chance = clampf(_apply(buffs, &"crit_chance", base_crit), 0.0, 1.0)
	s.damage_reduction = clampf(float(s.armor) / (float(s.armor) + 200.0), 0.0, 0.75)
	return s


## Bênçãos: primeiro somam, depois multiplicam.
static func _apply(buffs: Array, stat: StringName, base: float) -> float:
	var add := 0.0
	var mult := 1.0
	for b in buffs:
		if b.stat != stat:
			continue
		if b.mode == BuffData.Mode.ADD:
			add += b.amount
		else:
			mult *= b.amount
	return (base + add) * mult
