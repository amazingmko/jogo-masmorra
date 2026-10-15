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
		"form": [KEY_Q, KEY_K],  # habilidade da classe (Druida: forma; tanque: Provocar)
		"ultimate": [KEY_F, KEY_L],
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
	# Movimento suave em telas de 90/120/144 Hz (a física roda a 60 por segundo).
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)
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
	var it := _item(id, name, "Peça de armadura, fabricada pelos artesãos.",
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
	# Reagentes da Amazônia (ver replica/tematica-amazonica.md). Só eles caem nas masmorras.
	_save_item(_item("minerio_ferro", "Minério de Ferro", "Veios de ferro nas pedras da terra firme. Ferreiro.", K.MATERIAL, R.COMMON, 1, 999))
	_save_item(_item("madeira_lei", "Madeira de Lei", "Ipê e maçaranduba, duras como pedra. Ferreiro, Curtidor e Tecelã.", K.MATERIAL, R.COMMON, 1, 999))
	_save_item(_item("latex_seringueira", "Látex de Seringueira", "Borracha que impermeabiliza couro e tecido. Curtidor e Tecelã.", K.MATERIAL, R.COMMON, 1, 999))
	_save_item(_item("couro_jacare", "Couro de Jacaré", "Couro grosso e resistente. Curtidor.", K.MATERIAL, R.COMMON, 1, 999))
	_save_item(_item("fibra_tucum", "Fibra de Tucum", "Fibra de palmeira, fina e forte. Tecelã.", K.MATERIAL, R.COMMON, 1, 999))
	_save_item(_item("oleo_andiroba", "Óleo de Andiroba", "Óleo que cura e protege. Erveira.", K.MATERIAL, R.COMMON, 1, 999))
	_save_item(_item("semente_guarana", "Semente de Guaraná", "Dá energia e foco. Erveira.", K.MATERIAL, R.RARE, 1, 999))
	_save_item(_item("pena_arara", "Pena de Arara", "Pena colorida e rara. Pedida nas peças Raras ou melhores.", K.MATERIAL, R.RARE, 1, 999))
	_save_item(_item("pelo_mapinguari", "Pelo de Mapinguari", "Só o chefe deixa. Pedido nas peças Épicas e Lendárias.", K.MATERIAL, R.EPIC, 2, 999))
	_save_item(_item("muiraquita", "Muiraquitã", "Amuleto de pedra verde. Só o chefe no Mítico deixa, e raramente. Peças Lendárias.", K.MATERIAL, R.LEGENDARY, 3, 999))
	_save_item(_item("pocao_vida", "Garrafada de Cura", "Garrafada de andiroba. Recupera vida.", K.CONSUMABLE, R.COMMON, 1, 20, {"heal": 20}))

	var S := GameEnums.Slot
	var P := GameEnums.PrimaryStat
	# Tanque: lança de alcance maior, golpes mais lentos e menos dano (a força dele é aguentar).
	_weapon("lanca_ipe", "Lança de Ipê", "Lança de madeira de lei com ponta de pedra verde. Alcance bom, golpes firmes.", "lanca", P.STRENGTH,
		{"damage": 60, "attack_speed": 1.3, "attack_range": 2.3})
	_weapon("arco_simples", "Arco Simples", "Leve, para ataques à distância.", "arco", P.AGILITY,
		{"damage": 50, "attack_speed": 3.0, "attack_range": 11.0, "projectile_speed": 20.0})
	_weapon("cajado_aprendiz", "Cajado de Aprendiz", "Canaliza magia básica.", "cajado", P.INTELLECT,
		{"damage": 90, "attack_speed": 1.5, "attack_range": 10.0, "projectile_speed": 13.0})
	_weapon("cajado_raiz", "Cajado de Raiz", "Raiz viva que chama os espíritos da mata. A Druida luta com ele em forma de bicho.",
		"cajado_raiz", P.AGILITY, {"damage": 60, "attack_speed": 2.0, "attack_range": 1.9})
	_equipment_ids = ["lanca_ipe", "arco_simples", "cajado_aprendiz", "cajado_raiz"]
	# Escudo: só tanques usam. Muita armadura e chance de bloquear.
	var shield := _item("escudo_casco", "Escudo de Casco", "Casco de tracajá com aro de madeira de lei. Só tanques: dá armadura e chance de bloquear.",
		ItemData.Kind.ARMOR, GameEnums.Rarity.COMMON, 1, 1)
	shield.slot = S.OFFHAND
	shield.armor_type = GameEnums.ArmorType.PLATE
	_save_item(shield)
	_equipment_ids.append("escudo_casco")

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
		hp: int, shield: int, energy: int, speed: float, weapon: String, armor := 0, block := 0.0) -> void:
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
	h.base_armor = armor
	h.block_chance = block
	# Modelo 3D, quando já existe (arte gerada com IA, preparada em game/art/herois/).
	var model_path := "res://game/art/herois/%s.glb" % id
	if ResourceLoader.exists(model_path):
		h.model = load(model_path)
	_save(h, "res://game/data/heroes/%s.tres" % id)


func _make_heroes() -> void:
	var H := GameEnums.HeroClass
	var E := GameEnums.Element
	var P := GameEnums.PrimaryStat
	_hero("icamiaba", "Icamiaba", "Guerreira da lenda das Icamiabas. Tanque: aguenta pancada, bloqueia com o escudo e segura os inimigos. Lança e escudo, força, placa.", H.TANK, E.NEUTRAL, P.STRENGTH, "lanca", 170, 100, 120, 4.0, "lanca_ipe",
		60, 0.12)
	_hero("mateira", "Mateira", "Caçadora da mata, rápida, ataca de longe. Agilidade, couro.", H.RANGER, E.NATURE, P.AGILITY, "arco", 90, 30, 180, 5.5, "arco_simples")
	_hero("druida", "Druida da Mata", "Guardiã da mata que vira bicho: Onça (golpes rápidos), Sucuri (aperta e prende, aguenta mais) e Boto (jatos d'água de longe, cura sem parar). Agilidade, couro.",
		H.DRUID, E.NATURE, P.AGILITY, "cajado_raiz", 110, 35, 160, 5.2, "cajado_raiz")
	_hero("encantado", "Encantado do Rio", "Magia das águas encantadas. Frágil, mas poderoso. Inteligência, tecido.", H.MAGE, E.WATER, P.INTELLECT, "cajado", 80, 20, 220, 5.0, "cajado_aprendiz")


func _profession(id: String, name: String, desc: String) -> void:
	var p := ProfessionData.new()
	p.id = StringName(id)
	p.display_name = name
	p.description = desc
	p.max_level = 100
	p.base_xp = 60
	p.xp_growth = 1.045
	_save(p, "res://game/data/professions/%s.tres" % id)


func _make_professions() -> void:
	_profession("ferreiro", "Ferreiro", "Forja lanças, escudos e armaduras de placa com ferro e madeira de lei.")
	_profession("curtidor", "Curtidor", "Trabalha o couro de jacaré: armaduras de couro e arcos.")
	_profession("tecela", "Tecelã", "Tece fibra de tucum: armaduras de tecido e cajados.")
	_profession("erveira", "Erveira", "Prepara garrafadas com óleos e sementes da mata.")


func _recipe(id: String, name: String, result: String, ingredients: Dictionary,
		profession: String, level: int, xp: int, rarity: int = 0, needs_base: bool = false) -> void:
	var r := RecipeData.new()
	r.id = StringName(id)
	r.display_name = name
	r.result_item_id = StringName(result)
	r.ingredients = ingredients
	r.profession_id = StringName(profession)
	r.required_level = level
	r.xp_reward = xp
	r.result_rarity = rarity
	r.requires_base = needs_base
	_save(r, "res://game/data/recipes/%s.tres" % id)


## Quem fabrica cada peça e com quais reagentes: [profissão, reagente principal, secundário].
const CRAFT_SOURCES := {
	"lanca_ipe": ["ferreiro", "madeira_lei", "minerio_ferro"],
	"escudo_casco": ["ferreiro", "madeira_lei", "couro_jacare"],
	"arco_simples": ["curtidor", "madeira_lei", "couro_jacare"],
	"cajado_aprendiz": ["tecela", "madeira_lei", "fibra_tucum"],
	"cajado_raiz": ["curtidor", "madeira_lei", "latex_seringueira"],
	"placa": ["ferreiro", "minerio_ferro", "madeira_lei"],
	"couro": ["curtidor", "couro_jacare", "latex_seringueira"],
	"tecido": ["tecela", "fibra_tucum", "latex_seringueira"],
}
## Peso de cada slot no custo (igual ao do ItemFactory: arma e peito custam mais).
const COST_WEIGHT := [1.2, 0.8, 1.0, 0.6, 0.9, 0.6, 1.0]
const RARITY_SUFFIX := ["comum", "raro", "epico", "lendario"]
## Por raridade: multiplicador dos reagentes base, nível de profissão exigido e XP.
const CHAIN_MULT := [1, 3, 6, 10]
const CHAIN_LEVEL := [1, 5, 20, 40]
const CHAIN_XP := [30, 80, 200, 500]


func _make_recipes() -> void:
	# Cada peça tem 4 receitas em cadeia: Comum → Raro (pede a Comum) → Épico → Lendário.
	for item_id in _equipment_ids:
		var item: ItemData = load("res://game/data/items/%s.tres" % item_id)
		var key: String = item_id if CRAFT_SOURCES.has(item_id) else ["tecido", "couro", "placa"][item.armor_type]
		var src: Array = CRAFT_SOURCES[key]
		var w: float = COST_WEIGHT[item.slot]
		for r in 4:
			var m: int = CHAIN_MULT[r]
			var ing := {
				src[1]: maxi(int(round(14 * w)) * m, 1),
				src[2]: maxi(int(round(8 * w)) * m, 1),
			}
			if r >= 1:
				ing["pena_arara"] = maxi(int(round([0, 2, 4, 6][r] * w)), 1)
			if r >= 2:
				ing["pelo_mapinguari"] = maxi(int(round([0, 0, 3, 6][r] * w)), 1)
			if r == 3:
				ing["muiraquita"] = 1
			_recipe("%s_%s" % [item_id, RARITY_SUFFIX[r]], "%s (%s)" % [item.display_name, GameEnums.RARITY_NAMES[r]],
				item_id, ing, src[0], CHAIN_LEVEL[r], int(round(CHAIN_XP[r] * w)), r, r > 0)
	_recipe("preparar_garrafada", "Garrafada de Cura", "pocao_vida",
		{"oleo_andiroba": 3}, "erveira", 1, 15)


func _entry(item_id: String, weight: int, min_qty: int, max_qty: int) -> DropEntry:
	var e := DropEntry.new()
	e.item_id = StringName(item_id)
	e.weight = weight
	e.min_qty = min_qty
	e.max_qty = max_qty
	return e


func _table(id: String, rolls: int, nothing: int, entries: Array[DropEntry], extra: Array[StringName] = []) -> void:
	var t := DropTable.new()
	t.id = StringName(id)
	t.rolls = rolls
	t.nothing_weight = nothing
	t.entries = entries
	t.extra_tables = extra
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

	# Inimigos, baús e chefe deixam só reagentes. O chefe deixa bem mais, e os troféus dele.
	_table("mata_comum", 1, 30, [
		_entry("minerio_ferro", 35, 1, 2),
		_entry("madeira_lei", 35, 1, 2),
		_entry("latex_seringueira", 20, 1, 2),
	])
	_table("mata_bichos", 1, 40, [
		_entry("couro_jacare", 40, 1, 2),
		_entry("fibra_tucum", 35, 1, 2),
		_entry("latex_seringueira", 20, 1, 2),
		_entry("oleo_andiroba", 10, 1, 1),
		_entry("pena_arara", 4, 1, 1),
	])
	_table("bau", 3, 0, [
		_entry("minerio_ferro", 18, 2, 3),
		_entry("madeira_lei", 18, 2, 3),
		_entry("couro_jacare", 18, 2, 3),
		_entry("fibra_tucum", 18, 2, 3),
		_entry("latex_seringueira", 12, 1, 2),
		_entry("pena_arara", 10, 1, 2),
		_entry("oleo_andiroba", 8, 1, 2),
		_entry("semente_guarana", 5, 1, 1),
	])
	_table("chefe_mapinguari", 6, 0, [
		_entry("minerio_ferro", 20, 3, 5),
		_entry("madeira_lei", 20, 3, 5),
		_entry("couro_jacare", 20, 3, 5),
		_entry("fibra_tucum", 20, 3, 5),
		_entry("latex_seringueira", 10, 2, 3),
		_entry("pena_arara", 10, 2, 3),
	], [&"trofeus_chefe"])
	# Baú grande do Covil Furioso: perto do que o chefe deixa, com Pelo de Mapinguari garantido.
	_table("bau_covil", 6, 0, [
		_entry("minerio_ferro", 18, 3, 5),
		_entry("madeira_lei", 18, 3, 5),
		_entry("couro_jacare", 18, 3, 5),
		_entry("fibra_tucum", 18, 3, 5),
		_entry("latex_seringueira", 14, 2, 4),
		_entry("pena_arara", 14, 2, 3),
		_entry("semente_guarana", 6, 1, 2),
	], [&"trofeus_chefe"])
	# Troféus: sempre sorteados junto com o chefe. A Muiraquitã só no Mítico.
	var muiraquita := _entry("muiraquita", 10, 1, 1)
	muiraquita.min_difficulty = 3
	_table("trofeus_chefe", 2, 0, [
		_entry("pelo_mapinguari", 90, 1, 2),
		muiraquita,
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
		attacks: Array[EnemyAttack], boss := false, extra: Dictionary = {}) -> void:
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
	for key in extra:
		e.set(key, extra[key])
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


## Terra Firme: bichos da mata com habilidades do comportamento real, e o Mapinguari da lenda.
func _make_enemies() -> void:
	var E := GameEnums.Element
	var K := EnemyAttack.Kind
	var F := EnemyAttack.Effect
	var M := EnemyData.Movement
	var RED := Color("e05555")
	var ORANGE := Color("ff8a3d")
	var POISON := Color("8be06b")
	var ROOT := Color("b483e8")
	var WEB := Color("e8e0cf")
	var FEAR := Color("ffd34d")
	var NUT := Color("b07a45")

	# Queixada: anda em bando e investe junto; quando um parte, os outros vão atrás.
	_enemy("queixada", "Queixada", E.NEUTRAL, Color("4a403a"), 0.85, 170, 3.0, M.CHASE, 1.3, "mata_comum", 3, [
		_atk("dentada", "Dentada", K.MELEE, 0, 1.8, 0.45, 1.6, 12, RED, {"radius": 1.7, "cone_half_angle": 55.0, "recover": 0.5, "weight": 8}),
		_atk("investida_bando", "Investida do Bando", K.CHARGE, 3.0, 8.0, 0.7, 6.0, 26, ORANGE,
			{"length": 6.5, "radius": 1.2, "speed": 15.0, "recover": 0.6, "weight": 8, "rally_radius": 7.0}),
		_atk("estouro", "Estouro da Manada", K.CHARGE, 4.0, 11.0, 0.8, 9.0, 30, ORANGE,
			{"length": 9.0, "radius": 1.3, "speed": 17.0, "recover": 0.8, "weight": 5, "rally_radius": 10.0, "min_threat": 0.5}),
	], false, {"group_min": 2, "group_max": 3, "quadruped": true, "eye_count": 2})

	# Formiga-de-fogo: pequena, rápida, em grupo; a ferroada envenena e chama as outras (feromônio).
	_enemy("formiga_fogo", "Formiga-de-Fogo", E.FIRE, Color("b8432a"), 0.55, 60, 4.6, M.SKITTER, 0.9, "mata_bichos", 1, [
		_atk("ferroada", "Ferroada", K.MELEE, 0, 1.3, 0.3, 1.1, 6, POISON,
			{"radius": 1.2, "recover": 0.3, "effect": F.POISON, "effect_duration": 3.0, "effect_power": 5}),
		_atk("formigueiro", "Ataque do Formigueiro", K.CHARGE, 1.5, 4.5, 0.4, 5.0, 6, POISON,
			{"length": 3.5, "radius": 0.9, "speed": 14.0, "recover": 0.4, "weight": 6, "rally_radius": 6.0,
			"effect": F.POISON, "effect_duration": 3.0, "effect_power": 5, "min_threat": 0.4}),
	], false, {"group_min": 3, "group_max": 4, "quadruped": true, "eye_count": 2})

	# Macaco-prego: fica longe e arremessa coisas (usa pedras como ferramenta) e derruba ouriços de castanha.
	_enemy("macaco_prego", "Macaco-Prego", E.NATURE, Color("8a6440"), 0.8, 140, 3.2, M.KITE, 7.0, "mata_comum", 3, [
		_atk("pedrada", "Pedrada", K.PROJECTILE, 2.5, 12.0, 0.5, 2.0, 10, WEB, {"speed": 15.0, "recover": 0.4, "weight": 10}),
		_atk("ourico", "Ouriço de Castanha", K.GROUND_AOE, 2.0, 11.0, 0.9, 5.0, 16, NUT,
			{"radius": 1.4, "count": 2, "recover": 0.5, "weight": 7}),
		_atk("tapa", "Tapa", K.MELEE, 0, 1.6, 0.4, 3.0, 7, RED, {"radius": 1.6, "recover": 0.3, "weight": 6}),
		_atk("chuva_ourico", "Chuva de Ouriços", K.GROUND_AOE, 2.0, 12.0, 1.0, 8.0, 14, NUT,
			{"radius": 1.4, "count": 4, "recover": 0.6, "weight": 6, "min_threat": 0.4}),
	], false, {"eye_count": 2})

	# Aranha-caranguejeira: picada venenosa, teia que prende e os pelos urticantes que ela solta (deixam lento).
	_enemy("aranha_caranguejeira", "Aranha-Caranguejeira", E.NATURE, Color("3a2a22"), 0.9, 160, 3.6, M.SKITTER, 1.3, "mata_bichos", 3, [
		_atk("picada", "Picada Venenosa", K.MELEE, 0, 1.7, 0.4, 1.4, 8, POISON,
			{"radius": 1.5, "recover": 0.4, "effect": F.POISON, "effect_duration": 3.0, "effect_power": 6}),
		_atk("teia", "Teia", K.PROJECTILE, 2.5, 10.0, 0.6, 5.0, 4, WEB,
			{"speed": 11.0, "recover": 0.4, "effect": F.ROOT, "effect_duration": 1.2, "weight": 8}),
		_atk("pelos", "Pelos Urticantes", K.FAN, 2.0, 8.0, 0.6, 6.0, 5, Color("d8c39a"),
			{"speed": 12.0, "count": 5, "spread_deg": 30.0, "recover": 0.4, "effect": F.SLOW, "effect_duration": 2.5, "effect_power": 40, "weight": 6}),
		_atk("armadilha_teia", "Armadilha de Teia", K.GROUND_AOE, 2.0, 9.0, 0.9, 8.0, 2, WEB,
			{"radius": 1.3, "count": 2, "linger": 5.0, "recover": 0.5, "effect": F.ROOT, "effect_duration": 1.0, "weight": 5, "min_threat": 0.5}),
	], false, {"quadruped": true, "eye_count": 6})

	# Jararaca: fica de tocaia, quase invisível, e dá o bote quando o herói chega perto.
	_enemy("jararaca", "Jararaca", E.NATURE, Color("6b6a3a"), 0.7, 150, 3.4, M.CHASE, 1.4, "mata_comum", 4, [
		_atk("bote_cobra", "Bote", K.CHARGE, 1.5, 5.0, 0.35, 3.5, 16, POISON,
			{"length": 4.0, "radius": 0.9, "speed": 18.0, "recover": 0.6, "weight": 10, "effect": F.POISON, "effect_duration": 4.0, "effect_power": 8}),
		_atk("picada_cobra", "Picada", K.MELEE, 0, 1.5, 0.35, 1.8, 8, POISON,
			{"radius": 1.4, "recover": 0.4, "weight": 6, "effect": F.POISON, "effect_duration": 3.0, "effect_power": 6}),
		_atk("veneno_forte", "Veneno Hemorrágico", K.MELEE, 0, 1.6, 0.45, 6.0, 10, POISON,
			{"radius": 1.5, "recover": 0.5, "weight": 5, "effect": F.POISON, "effect_duration": 4.0, "effect_power": 14, "min_threat": 0.5}),
	], false, {"quadruped": true, "eye_count": 2, "ambush_range": 4.5})

	# Onça-pintada: caça de emboscada, camuflada; bote longo, mordida no crânio e o esturro que assusta.
	_enemy("onca_pintada", "Onça-Pintada", E.NEUTRAL, Color("c99a3a"), 1.25, 650, 3.4, M.STRAFE, 2.5, "mata_comum", 8, [
		_atk("bote_onca", "Bote", K.CHARGE, 3.0, 9.0, 0.6, 5.0, 32, ORANGE,
			{"length": 8.0, "radius": 1.4, "speed": 18.0, "recover": 0.8, "weight": 9}),
		_atk("patada", "Patada", K.MELEE, 0, 2.0, 0.4, 1.8, 18, RED,
			{"radius": 2.0, "cone_half_angle": 70.0, "recover": 0.4, "weight": 10}),
		_atk("mordida_cranio", "Mordida no Crânio", K.MELEE, 0, 2.2, 0.75, 4.0, 38, RED,
			{"radius": 2.2, "cone_half_angle": 35.0, "recover": 0.7, "weight": 6}),
		_atk("esturro", "Esturro", K.MELEE, 0, 4.5, 0.8, 10.0, 6, FEAR,
			{"radius": 4.5, "recover": 0.5, "weight": 5, "effect": F.FEAR, "effect_duration": 1.0, "min_threat": 0.55}),
	], false, {"quadruped": true, "eye_count": 2, "stalker": true, "spotted": true})

	# Mapinguari: gigante peludo de cinco olhos na testa e boca na barriga; fedor e grito que assusta caçadores.
	_enemy("mapinguari", "Mapinguari", E.NATURE, Color("5a3a2a"), 2.3, 3600, 2.7, M.STRAFE, 3.0, "chefe_mapinguari", 60, [
		_atk("garras", "Garras", K.MELEE, 0, 3.8, 0.7, 2.5, 30, RED,
			{"radius": 3.8, "cone_half_angle": 70.0, "recover": 0.6, "weight": 10}),
		_atk("bocarra", "Bocarra do Ventre", K.MELEE, 0, 3.0, 0.9, 6.0, 40, Color("c0392b"),
			{"radius": 3.0, "cone_half_angle": 45.0, "recover": 0.8, "weight": 8, "heal_percent_max_health": 0.03,
			"exposes_weak_spot": 3.0}),
		_atk("investida_mapinguari", "Investida Devastadora", K.CHARGE, 3.0, 12.0, 0.8, 6.0, 35, ORANGE,
			{"length": 10.0, "radius": 2.2, "speed": 16.0, "recover": 0.9, "weight": 8}),
		_atk("cinco_olhos", "Olhar dos Cinco Olhos", K.FAN, 3.0, 16.0, 0.7, 5.0, 16, Color("ffb347"),
			{"count": 5, "spread_deg": 28.0, "speed": 14.0, "recover": 0.4, "below_health": 0.85, "weight": 8}),
		_atk("estouro_queixadas", "Estouro de Queixadas", K.SUMMON, 0, 30.0, 1.0, 16.0, 0, ORANGE,
			{"count": 3, "summon_id": &"queixada", "below_health": 0.75, "recover": 0.5, "weight": 6}),
		_atk("fedor", "Fedor do Mapinguari", K.GROUND_AOE, 0, 30.0, 1.0, 8.0, 8, POISON,
			{"count": 3, "radius": 2.2, "linger": 5.0, "below_health": 0.7, "recover": 0.5, "weight": 6,
			"effect": F.POISON, "effect_duration": 3.0, "effect_power": 10}),
		_atk("grito", "Grito Estrondoso", K.MELEE, 0, 7.0, 1.0, 12.0, 15, FEAR,
			{"radius": 7.0, "below_health": 0.6, "recover": 0.6, "weight": 8, "effect": F.FEAR, "effect_duration": 1.3}),
		_atk("arvores", "Árvores Derrubadas", K.GROUND_AOE, 0, 30.0, 1.0, 6.0, 25, NUT,
			{"count": 5, "radius": 1.7, "below_health": 0.6, "recover": 0.5, "weight": 8}),
		_atk("bafo", "Bafo do Mapinguari", K.MEGA, 0, 40.0, 3.5, 22.0, 40, Color("c9b23a"),
			{"radius": 10.5, "count": 2, "damage_percent_of_target": 0.6, "below_health": 0.45, "recover": 1.2, "weight": 30,
			"effect": F.POISON, "effect_duration": 4.0, "effect_power": 12}),
	], true, {"eye_count": 5, "belly_mouth": true, "hide_damage_mult": 0.5})


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
