extends SceneTree
## Gera os dados de exemplo, as cenas, o mapa de controles e as camadas de colisão.
## ATENÇÃO: rodar de novo SOBRESCREVE os dados em game/data/ e as cenas.
## Já foi rodado; os arquivos gerados estão no repositório. Comando:
##   godot --headless --path . --script res://tools/setup_project.gd
## Depois disso, edite tudo pelo editor do Godot.



var _done := false


# Roda no primeiro quadro, depois que os autoloads (ItemDB, GameState...) existem;
# sem eles, o script da cena principal não compila.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_build()
	quit()
	return true


func _build() -> void:
	_setup_input_map()
	_make_items()
	_make_heroes()
	_make_professions()
	_make_recipes()
	_make_drop_tables()
	_make_buffs()
	_make_enemies()
	_make_player_scene()
	_make_main_scene()
	_make_hub_scene()
	ProjectSettings.set_setting("application/run/main_scene", "res://game/scenes/hub.tscn")
	ProjectSettings.save()
	print("setup_project: concluído")


# ---------- controles ----------

func _setup_input_map() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_SPACE, KEY_J],
	}
	for action in actions:
		var events := []
		for key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	# No PC, o mouse faz as vezes do dedo (para testar o joystick de toque).
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)
	var layer_names := ["mundo", "jogador", "inimigos", "coletaveis"]
	for i in layer_names.size():
		ProjectSettings.set_setting("layer_names/3d_physics/layer_%d" % (i + 1), layer_names[i])
	ProjectSettings.save()


# ---------- dados ----------

func _item(id: String, name: String, desc: String, kind: ItemData.Kind, rarity: int,
		tier: int, max_stack: int, stats: Dictionary = {}) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(id)
	it.display_name = name
	it.description = desc
	it.kind = kind
	it.rarity = rarity
	it.tier = tier
	it.max_stack = max_stack
	it.stats = stats
	return it


func _save_item(it: ItemData) -> void:
	_save(it, "res://game/data/items/%s.tres" % it.id)


func _armor(id: String, name: String, slot: int, armor_type: int) -> void:
	var it := _item(id, name, "Peça de armadura. Raridade, nível e atributos são sorteados quando cai.",
		ItemData.Kind.ARMOR, GameEnums.Rarity.COMMON, 1, 1)
	it.slot = slot
	it.armor_type = armor_type
	_save_item(it)


func _weapon(id: String, name: String, desc: String, weapon_type: String, primary: int, stats: Dictionary) -> void:
	var it := _item(id, name, desc, ItemData.Kind.WEAPON, GameEnums.Rarity.COMMON, 1, 1, stats)
	it.slot = GameEnums.Slot.WEAPON
	it.weapon_type = StringName(weapon_type)
	it.primary_stat = primary
	_save_item(it)


## Ids de todos os moldes de equipamento (usados na tabela "equipamento").
var _equipment_ids: Array[String] = []


func _make_items() -> void:
	var K := ItemData.Kind
	var R := GameEnums.Rarity
	_save_item(_item("fragmento_osso", "Fragmento de Osso", "Restos de mortos-vivos. Base de muitas receitas.", K.MATERIAL, R.COMMON, 1, 99))
	_save_item(_item("minerio_ferro", "Minério de Ferro", "Encontrado nas paredes das masmorras rasas.", K.MATERIAL, R.COMMON, 1, 99))
	_save_item(_item("couro_rasgado", "Couro Rasgado", "Pode ser trabalhado em armaduras de couro.", K.MATERIAL, R.COMMON, 1, 99))
	_save_item(_item("erva_vermelha", "Erva Vermelha", "Planta que cresce no escuro. Usada em poções.", K.MATERIAL, R.COMMON, 1, 99))
	_save_item(_item("pocao_vida", "Poção de Vida", "Recupera 20 de vida.", K.CONSUMABLE, R.COMMON, 1, 20, {"heal": 20}))

	var S := GameEnums.Slot
	var P := GameEnums.PrimaryStat
	_weapon("espada_ferro", "Espada de Ferro", "Simples e confiável.", "espada", P.STRENGTH,
		{"damage": 80, "attack_speed": 2.0, "attack_range": 1.9})
	_weapon("arco_simples", "Arco Simples", "Leve, para ataques à distância.", "arco", P.AGILITY,
		{"damage": 50, "attack_speed": 3.0, "attack_range": 11.0, "projectile_speed": 20.0})
	_weapon("cajado_aprendiz", "Cajado de Aprendiz", "Canaliza magia básica.", "cajado", P.INTELLECT,
		{"damage": 90, "attack_speed": 1.5, "attack_range": 10.0, "projectile_speed": 13.0})
	_equipment_ids = ["espada_ferro", "arco_simples", "cajado_aprendiz"]

	var A := GameEnums.ArmorType
	var pieces := {
		A.CLOTH: [["capuz_tecido", "Capuz de Tecido"], ["tunica_tecido", "Túnica de Tecido"], ["luvas_tecido", "Luvas de Tecido"],
			["calca_tecido", "Calça de Tecido"], ["sandalias_tecido", "Sandálias de Tecido"]],
		A.LEATHER: [["capuz_couro", "Capuz de Couro"], ["armadura_couro", "Gibão de Couro"], ["luvas_couro", "Luvas de Couro"],
			["calca_couro", "Calça de Couro"], ["botas_couro", "Botas de Couro"]],
		A.PLATE: [["elmo_placa", "Elmo de Placa"], ["peitoral_placa", "Peitoral de Placa"], ["manoplas_placa", "Manoplas de Placa"],
			["grevas_placa", "Grevas de Placa"], ["botas_placa", "Botas de Placa"]],
	}
	var slots := [S.HEAD, S.CHEST, S.HANDS, S.LEGS, S.FEET]
	for armor_type in pieces:
		for i in 5:
			var entry: Array = pieces[armor_type][i]
			_armor(entry[0], entry[1], slots[i], armor_type)
			_equipment_ids.append(entry[0])


func _hero(id: String, name: String, desc: String, cls: int, element: int, primary: int, weapon_type: String,
		hp: int, shield: int, energy: int, speed: float, weapon: String) -> void:
	var h := HeroData.new()
	h.id = StringName(id)
	h.display_name = name
	h.description = desc
	h.hero_class = cls
	h.element = element
	h.primary_stat = primary
	h.weapon_type = StringName(weapon_type)
	h.max_health = hp
	h.max_shield = shield
	h.base_primary = 10
	h.max_energy = energy
	h.move_speed = speed
	h.starting_weapon_id = StringName(weapon)
	_save(h, "res://game/data/heroes/%s.tres" % id)


func _make_heroes() -> void:
	var H := GameEnums.HeroClass
	var E := GameEnums.Element
	var P := GameEnums.PrimaryStat
	_hero("guardiao", "Guardião", "Aguenta pancada e protege o grupo. Força, placa.", H.TANK, E.NEUTRAL, P.STRENGTH, "espada", 120, 50, 120, 4.5, "espada_ferro")
	_hero("batedora", "Batedora", "Rápida, ataca de longe. Agilidade, couro.", H.RANGER, E.NATURE, P.AGILITY, "arco", 90, 30, 180, 5.5, "arco_simples")
	_hero("arcanista", "Arcanista", "Frágil, mas com magia poderosa. Inteligência, tecido.", H.MAGE, E.FIRE, P.INTELLECT, "cajado", 80, 20, 220, 5.0, "cajado_aprendiz")


func _make_professions() -> void:
	var smith := ProfessionData.new()
	smith.id = &"ferreiro"
	smith.display_name = "Ferreiro"
	smith.description = "Forja armas e armaduras de metal."
	_save(smith, "res://game/data/professions/ferreiro.tres")
	var alch := ProfessionData.new()
	alch.id = &"alquimista"
	alch.display_name = "Alquimista"
	alch.description = "Prepara poções e elixires."
	_save(alch, "res://game/data/professions/alquimista.tres")


func _recipe(id: String, name: String, result: String, ingredients: Dictionary,
		profession: String, level: int, xp: int) -> void:
	var r := RecipeData.new()
	r.id = StringName(id)
	r.display_name = name
	r.result_item_id = StringName(result)
	r.ingredients = ingredients
	r.profession_id = StringName(profession)
	r.required_level = level
	r.xp_reward = xp
	_save(r, "res://game/data/recipes/%s.tres" % id)


func _make_recipes() -> void:
	_recipe("forjar_espada_ferro", "Espada de Ferro", "espada_ferro",
		{"minerio_ferro": 5, "fragmento_osso": 2}, "ferreiro", 1, 40)
	_recipe("costurar_armadura_couro", "Armadura de Couro", "armadura_couro",
		{"couro_rasgado": 6}, "", 0, 0)
	_recipe("preparar_pocao_vida", "Poção de Vida", "pocao_vida",
		{"erva_vermelha": 3}, "alquimista", 1, 15)


func _entry(item_id: String, weight: int, min_qty: int, max_qty: int) -> DropEntry:
	var e := DropEntry.new()
	e.item_id = StringName(item_id)
	e.weight = weight
	e.min_qty = min_qty
	e.max_qty = max_qty
	return e


func _table(id: String, rolls: int, nothing: int, entries: Array[DropEntry]) -> void:
	var t := DropTable.new()
	t.id = StringName(id)
	t.rolls = rolls
	t.nothing_weight = nothing
	t.entries = entries
	_save(t, "res://game/data/drop_tables/%s.tres" % id)


func _sub(table_id: String, weight: int, min_qty: int = 1, max_qty: int = 1) -> DropEntry:
	var e := DropEntry.new()
	e.table_id = StringName(table_id)
	e.weight = weight
	e.min_qty = min_qty
	e.max_qty = max_qty
	return e


func _make_drop_tables() -> void:
	# Tabela-mãe de equipamentos: não cai mais nas masmorras (todo equipamento é fabricado).
	# Fica guardada para recompensas futuras e para os testes do sorteio de peças.
	var equip: Array[DropEntry] = []
	for id in _equipment_ids:
		equip.append(_entry(id, 10, 1, 1))
	_table("equipamento", 1, 0, equip)

	# Inimigos, baús e chefe deixam só reagentes. O chefe deixa bem mais.
	_table("esqueleto", 1, 30, [
		_entry("fragmento_osso", 55, 1, 2),
		_entry("minerio_ferro", 35, 1, 2),
	])
	_table("rato_gigante", 1, 40, [
		_entry("couro_rasgado", 55, 1, 2),
		_entry("erva_vermelha", 35, 1, 1),
	])
	_table("bau", 3, 0, [
		_entry("minerio_ferro", 30, 2, 4),
		_entry("fragmento_osso", 25, 2, 3),
		_entry("couro_rasgado", 25, 2, 3),
		_entry("erva_vermelha", 15, 1, 2),
		_entry("pocao_vida", 5, 1, 1),
	])
	_table("chefe_rei_ossudo", 6, 0, [
		_entry("minerio_ferro", 30, 3, 6),
		_entry("fragmento_osso", 30, 3, 6),
		_entry("couro_rasgado", 25, 3, 5),
		_entry("erva_vermelha", 15, 2, 4),
	])


func _buff(id: String, name: String, desc: String, stat: String, amount: float, mode: int) -> void:
	var b := BuffData.new()
	b.id = StringName(id)
	b.display_name = name
	b.description = desc
	b.stat = StringName(stat)
	b.amount = amount
	b.mode = mode
	_save(b, "res://game/data/buffs/%s.tres" % id)


func _make_buffs() -> void:
	var M := BuffData.Mode
	_buff("pele_de_pedra", "Pele de Pedra", "+10 de escudo máximo.", "max_shield", 10.0, M.ADD)
	_buff("coracao_forte", "Coração Forte", "+20 de vida máxima.", "max_health", 20.0, M.ADD)
	_buff("furia", "Fúria", "+20% de dano.", "damage", 1.2, M.MULTIPLY)
	_buff("maos_ligeiras", "Mãos Ligeiras", "Ataques 20% mais rápidos.", "attack_speed", 1.2, M.MULTIPLY)
	_buff("passos_leves", "Passos Leves", "Anda 12% mais rápido.", "move_speed", 1.12, M.MULTIPLY)
	_buff("olho_afiado", "Olho Afiado", "+10% de chance de crítico.", "crit_chance", 0.10, M.ADD)
	_buff("longo_alcance", "Longo Alcance", "+20% de alcance da arma.", "attack_range", 1.2, M.MULTIPLY)


func _enemy(id: String, name: String, element: int, color: Color, body_scale: float,
		hp: int, speed: float, movement: int, preferred: float, drop_table: String, xp: int,
		attacks: Array[EnemyAttack], boss := false) -> void:
	var e := EnemyData.new()
	e.id = StringName(id)
	e.display_name = name
	e.element = element
	e.color = color
	e.body_scale = body_scale
	e.max_health = hp
	e.move_speed = speed
	e.movement = movement
	e.preferred_distance = preferred
	e.drop_table_id = StringName(drop_table)
	e.xp_reward = xp
	e.attacks = attacks
	e.is_boss = boss
	# Valores do golpe simples (só usados se a lista de ataques ficar vazia).
	e.damage = attacks[0].damage if not attacks.is_empty() else 10
	_save(e, "res://game/data/enemies/%s.tres" % id)


## Atalho para criar um ataque. Campos extras vão em `extra` (ex.: {"effect": ..., "count": 3}).
func _atk(id: String, name: String, kind: int, rmin: float, rmax: float, windup: float, cooldown: float,
		damage: int, color: Color, extra: Dictionary = {}) -> EnemyAttack:
	var a := EnemyAttack.new()
	a.id = StringName(id)
	a.display_name = name
	a.kind = kind
	a.range_min = rmin
	a.range_max = rmax
	a.windup = windup
	a.cooldown = cooldown
	a.damage = damage
	a.color = color
	for key in extra:
		a.set(key, extra[key])
	return a


func _make_enemies() -> void:
	var E := GameEnums.Element
	var K := EnemyAttack.Kind
	var F := EnemyAttack.Effect
	var M := EnemyData.Movement
	var RED := Color("e05555")
	var ORANGE := Color("ff8a3d")
	var POISON := Color("8be06b")
	var ROOT := Color("b483e8")
	var BONE := Color("f2ecff")

	_enemy("esqueleto", "Esqueleto", E.NEUTRAL, Color("cfc8b8"), 1.0, 240, 2.8, M.CHASE, 1.3, "esqueleto", 3, [
		_atk("golpe", "Golpe", K.MELEE, 0, 2.0, 0.55, 1.6, 15, RED, {"radius": 2.0, "cone_half_angle": 60.0, "recover": 0.5, "weight": 10}),
		_atk("estocada", "Estocada", K.CHARGE, 3.0, 6.5, 0.6, 5.0, 18, ORANGE, {"length": 5.0, "radius": 1.2, "speed": 14.0, "recover": 0.6, "weight": 6}),
		_atk("lanca_osso", "Lança de Osso", K.PROJECTILE, 3.0, 10.0, 0.6, 5.0, 12, BONE,
			{"speed": 13.0, "recover": 0.4, "weight": 6, "min_threat": 0.3}),
	])
	_enemy("rato_gigante", "Rato Gigante", E.NATURE, Color("8a6a4f"), 0.7, 120, 4.4, M.SKITTER, 1.0, "rato_gigante", 2, [
		_atk("mordida", "Mordida", K.MELEE, 0, 1.6, 0.35, 1.2, 10, RED, {"radius": 1.4, "recover": 0.4}),
		_atk("salto", "Salto", K.CHARGE, 2.5, 6.0, 0.45, 4.0, 12, ORANGE, {"length": 5.0, "radius": 1.0, "speed": 16.0, "recover": 0.5, "weight": 7}),
		_atk("praga", "Praga", K.GROUND_AOE, 2.0, 8.0, 0.8, 6.0, 5, POISON,
			{"radius": 1.4, "recover": 0.4, "linger": 3.0, "effect": F.POISON, "effect_duration": 3.0, "effect_power": 4, "weight": 5, "min_threat": 0.45}),
	])
	_enemy("esqueleto_arqueiro", "Esqueleto Arqueiro", E.NEUTRAL, Color("e3dccb"), 0.95, 160, 2.9, M.KITE, 7.5, "esqueleto", 3, [
		_atk("flecha", "Flecha", K.PROJECTILE, 2.5, 13.0, 0.5, 2.0, 10, BONE, {"speed": 15.0, "recover": 0.4, "weight": 10}),
		_atk("saraivada", "Saraivada", K.FAN, 3.0, 12.0, 0.8, 5.0, 10, ORANGE, {"speed": 13.0, "count": 3, "spread_deg": 22.0, "recover": 0.6, "weight": 6}),
		_atk("chute", "Chute", K.MELEE, 0, 1.8, 0.4, 3.0, 8, RED, {"radius": 1.8, "recover": 0.3, "weight": 8}),
		_atk("flecha_gelida", "Flecha Gélida", K.PROJECTILE, 2.5, 13.0, 0.6, 6.0, 9, Color("4db8ff"),
			{"speed": 14.0, "recover": 0.4, "effect": F.SLOW, "effect_duration": 2.0, "effect_power": 35, "weight": 6, "min_threat": 0.35}),
	])
	_enemy("aranha_cripta", "Aranha da Cripta", E.NATURE, Color("4f6b3a"), 0.8, 150, 4.0, M.SKITTER, 1.2, "rato_gigante", 3, [
		_atk("picada", "Picada Venenosa", K.MELEE, 0, 1.7, 0.4, 1.4, 8, POISON,
			{"radius": 1.5, "recover": 0.4, "effect": F.POISON, "effect_duration": 4.0, "effect_power": 6}),
		_atk("cuspe", "Cuspe Ácido", K.GROUND_AOE, 2.0, 9.0, 0.9, 5.0, 6, POISON,
			{"radius": 1.7, "recover": 0.5, "linger": 4.0, "effect": F.POISON, "effect_duration": 3.0, "effect_power": 6, "weight": 8}),
		_atk("teia", "Teia", K.PROJECTILE, 2.5, 10.0, 0.6, 7.0, 4, BONE,
			{"speed": 11.0, "recover": 0.4, "effect": F.ROOT, "effect_duration": 1.0, "weight": 5, "min_threat": 0.5}),
	])
	_enemy("xama_ossos", "Xamã de Ossos", E.NEUTRAL, Color("8e7cc3"), 1.0, 180, 2.5, M.KITE, 8.0, "esqueleto", 5, [
		_atk("raio", "Raio Sombrio", K.PROJECTILE, 2.5, 13.0, 0.55, 2.4, 11, ROOT, {"speed": 12.0, "recover": 0.4, "weight": 10}),
		_atk("raizes", "Raízes de Osso", K.PROJECTILE, 2.5, 12.0, 0.7, 4.5, 8, ROOT,
			{"speed": 10.0, "recover": 0.5, "effect": F.ROOT, "effect_duration": 1.2, "weight": 8}),
		_atk("nuvem", "Nuvem Tóxica", K.GROUND_AOE, 2.0, 12.0, 1.1, 6.0, 8, POISON,
			{"radius": 2.2, "recover": 0.6, "linger": 4.0, "effect": F.POISON, "effect_duration": 3.0, "effect_power": 6, "weight": 7}),
		_atk("chuva_ossos", "Chuva de Ossos", K.GROUND_AOE, 2.0, 12.0, 1.0, 7.0, 12, BONE,
			{"count": 3, "radius": 1.5, "recover": 0.6, "weight": 6, "min_threat": 0.6}),
	])
	_enemy("esqueleto_bruto", "Esqueleto Bruto", E.NEUTRAL, Color("9e8f7a"), 1.5, 700, 2.2, M.CHASE, 1.8, "esqueleto", 8, [
		_atk("esmagar", "Esmagar", K.MELEE, 0, 2.8, 0.9, 3.0, 30, RED, {"radius": 2.8, "recover": 0.9}),
		_atk("investida", "Investida", K.CHARGE, 3.0, 8.0, 0.8, 6.0, 30, ORANGE, {"length": 7.0, "radius": 1.8, "speed": 15.0, "recover": 1.0, "weight": 7}),
		_atk("tremor", "Tremor", K.NOVA, 0, 6.0, 0.9, 7.0, 14, BONE,
			{"count": 8, "speed": 8.0, "recover": 0.7, "weight": 5, "min_threat": 0.55}),
	])
	_enemy("rei_ossudo", "Rei Ossudo", E.NEUTRAL, Color("d6b25e"), 2.1, 4500, 2.8, M.STRAFE, 2.8, "chefe_rei_ossudo", 60, [
		_atk("varredura", "Varredura", K.MELEE, 0, 3.8, 0.7, 2.5, 30, RED,
			{"radius": 3.8, "cone_half_angle": 70.0, "recover": 0.6, "weight": 10}),
		_atk("investida_real", "Investida Real", K.CHARGE, 3.0, 12.0, 0.8, 6.0, 35, ORANGE,
			{"length": 10.0, "radius": 2.2, "speed": 16.0, "recover": 0.9, "weight": 8}),
		_atk("lancas_rei", "Lanças do Rei", K.FAN, 3.0, 16.0, 0.7, 5.0, 18, BONE,
			{"count": 5, "spread_deg": 30.0, "speed": 13.0, "below_health": 0.75, "recover": 0.4, "weight": 7}),
		_atk("chamado", "Chamado dos Mortos", K.SUMMON, 0, 30.0, 1.0, 14.0, 0, ROOT,
			{"count": 2, "summon_id": &"esqueleto", "below_health": 0.85, "recover": 0.5, "weight": 6}),
		_atk("onda_ossos", "Onda de Ossos", K.NOVA, 0, 30.0, 0.9, 7.0, 15, BONE,
			{"count": 12, "speed": 9.0, "below_health": 0.6, "recover": 0.6, "weight": 8}),
		_atk("espinhos", "Espinhos da Cripta", K.GROUND_AOE, 0, 30.0, 1.0, 6.0, 25, RED,
			{"count": 5, "radius": 1.6, "below_health": 0.6, "recover": 0.5, "weight": 8}),
		_atk("juizo", "Juízo do Rei", K.MEGA, 0, 40.0, 3.5, 22.0, 40, Color("ff5a36"),
			{"radius": 10.5, "count": 2, "damage_percent_of_target": 0.6, "below_health": 0.45, "recover": 1.2, "weight": 30}),
	], true)


# ---------- cenas ----------

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


func _make_player_scene() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://game/scripts/gameplay/player.gd"))

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.6
	shape.shape = capsule_shape
	shape.position.y = 0.8
	_add(player, shape, player)

	var body := Node3D.new()
	body.name = "Body"
	_add(player, body, player)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position.y = 0.8
	mesh.material_override = _material(Color("e8c26a"))
	_add(body, mesh, player)

	# "Nariz" para ver para onde o herói está virado.
	var nose := MeshInstance3D.new()
	nose.name = "Facing"
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.4)
	nose.mesh = box
	nose.position = Vector3(0, 1.1, 0.45)
	nose.material_override = _material(Color("2b2240"))
	_add(body, nose, player)

	var health := Health.new()
	health.name = "Health"
	health.invulnerability_time = 0.6
	_add(player, health, player)

	_pack(player, "res://game/scenes/player.tscn")


func _make_main_scene() -> void:
	var root := Node3D.new()
	root.name = "Main"
	root.set_script(load("res://game/scripts/gameplay/main.gd"))

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1526")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6b5f8a")
	env.ambient_light_energy = 0.6
	env_node.environment = env
	_add(root, env_node, root)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	_add(root, sun, root)

	# A masmorra é gerada a cada andar dentro deste nó (ver main.gd e game/scripts/dungeon/).
	var dungeon := Node3D.new()
	dungeon.name = "Dungeon"
	_add(root, dungeon, root)

	var player_scene: PackedScene = load("res://game/scenes/player.tscn")
	var player := player_scene.instantiate()
	player.name = "Player"
	_add(root, player, root)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.set_script(load("res://game/scripts/gameplay/camera_follow.gd"))
	cam.set("target_path", NodePath("../Player"))
	cam.position = Vector3(0, 11, 7.5)
	cam.rotation_degrees = Vector3(-55, 0, 0)
	cam.fov = 50.0
	_add(root, cam, root)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://game/scripts/ui/hud.gd"))
	_add(root, hud, root)

	_pack(root, "res://game/scenes/main.tscn")


func _make_hub_scene() -> void:
	var root := Node3D.new()
	root.name = "Hub"
	root.set_script(load("res://game/scripts/hub/hub.gd"))

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1526")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7a6f9a")
	env.ambient_light_energy = 0.7
	env_node.environment = env
	_add(root, env_node, root)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	_add(root, sun, root)

	# A vila é montada por código em hub.gd (chão, muros, estações).
	var town := Node3D.new()
	town.name = "Town"
	_add(root, town, root)

	var player_scene: PackedScene = load("res://game/scenes/player.tscn")
	var player := player_scene.instantiate()
	player.name = "Player"
	_add(root, player, root)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.set_script(load("res://game/scripts/gameplay/camera_follow.gd"))
	cam.set("target_path", NodePath("../Player"))
	cam.position = Vector3(0, 11, 7.5)
	cam.rotation_degrees = Vector3(-55, 0, 0)
	cam.fov = 50.0
	_add(root, cam, root)

	var ui := CanvasLayer.new()
	ui.name = "HubUI"
	ui.set_script(load("res://game/scripts/hub/hub_ui.gd"))
	_add(root, ui, root)

	_pack(root, "res://game/scenes/hub.tscn")


func _add_box(parent: Node, base_name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = base_name
	body.position = pos
	_add(parent, body, parent, true)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	_add(body, mesh, parent)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	_add(body, col, parent)


func _add(parent: Node, child: Node, owner_node: Node, unique_name := false) -> void:
	parent.add_child(child, unique_name)
	child.owner = owner_node


func _pack(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Falha ao empacotar %s" % path)
		return
	_save(packed, path)
	root.free()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Falha ao salvar %s (erro %d)" % [path, err])
