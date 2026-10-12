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
		tier: int, max_stack: int, stats: Dictionary = {}) -> void:
	var it := ItemData.new()
	it.id = StringName(id)
	it.display_name = name
	it.description = desc
	it.kind = kind
	it.rarity = rarity
	it.tier = tier
	it.max_stack = max_stack
	it.stats = stats
	_save(it, "res://game/data/items/%s.tres" % id)


func _make_items() -> void:
	var K := ItemData.Kind
	_item("fragmento_osso", "Fragmento de Osso", "Restos de mortos-vivos. Base de muitas receitas.", K.MATERIAL, GameEnums.Rarity.COMMON, 1, 99)
	_item("minerio_ferro", "Minério de Ferro", "Encontrado nas paredes das masmorras rasas.", K.MATERIAL, GameEnums.Rarity.COMMON, 1, 99)
	_item("couro_rasgado", "Couro Rasgado", "Pode ser costurado em armaduras leves.", K.MATERIAL, GameEnums.Rarity.COMMON, 1, 99)
	_item("erva_vermelha", "Erva Vermelha", "Planta que cresce no escuro. Usada em poções.", K.MATERIAL, GameEnums.Rarity.COMMON, 1, 99)
	_item("pocao_vida", "Poção de Vida", "Recupera 2 de vida.", K.CONSUMABLE, GameEnums.Rarity.COMMON, 1, 20, {"heal": 2})
	_item("espada_ferro", "Espada de Ferro", "Simples e confiável.", K.WEAPON, GameEnums.Rarity.COMMON, 1, 1, {"damage": 8, "attack_speed": 2.0, "attack_range": 1.9})
	_item("arco_simples", "Arco Simples", "Leve, para ataques à distância.", K.WEAPON, GameEnums.Rarity.COMMON, 1, 1, {"damage": 5, "attack_speed": 3.0, "attack_range": 11.0, "projectile_speed": 20.0})
	_item("cajado_aprendiz", "Cajado de Aprendiz", "Canaliza magia básica.", K.WEAPON, GameEnums.Rarity.COMMON, 1, 1, {"damage": 9, "attack_speed": 1.5, "attack_range": 10.0, "projectile_speed": 13.0})
	_item("armadura_couro", "Armadura de Couro", "Proteção leve.", K.ARMOR, GameEnums.Rarity.UNCOMMON, 1, 1, {"armor": 2})


func _hero(id: String, name: String, desc: String, cls: int, element: int,
		hp: int, armor: int, energy: int, speed: float, weapon: String) -> void:
	var h := HeroData.new()
	h.id = StringName(id)
	h.display_name = name
	h.description = desc
	h.hero_class = cls
	h.element = element
	h.max_health = hp
	h.max_armor = armor
	h.max_energy = energy
	h.move_speed = speed
	h.starting_weapon_id = StringName(weapon)
	_save(h, "res://game/data/heroes/%s.tres" % id)


func _make_heroes() -> void:
	var H := GameEnums.HeroClass
	var E := GameEnums.Element
	_hero("guardiao", "Guardião", "Aguenta pancada e protege o grupo.", H.TANK, E.NEUTRAL, 8, 5, 120, 4.5, "espada_ferro")
	_hero("batedora", "Batedora", "Rápida, ataca de longe.", H.RANGER, E.NATURE, 5, 3, 180, 5.5, "arco_simples")
	_hero("arcanista", "Arcanista", "Frágil, mas com magia poderosa.", H.MAGE, E.FIRE, 4, 2, 220, 5.0, "cajado_aprendiz")


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


func _make_drop_tables() -> void:
	_table("esqueleto", 1, 30, [
		_entry("fragmento_osso", 50, 1, 2),
		_entry("minerio_ferro", 30, 1, 2),
		_entry("espada_ferro", 2, 1, 1),
	])
	_table("rato_gigante", 1, 40, [
		_entry("couro_rasgado", 50, 1, 2),
		_entry("erva_vermelha", 30, 1, 1),
	])
	_table("bau", 3, 0, [
		_entry("minerio_ferro", 30, 2, 4),
		_entry("fragmento_osso", 25, 2, 3),
		_entry("couro_rasgado", 20, 2, 3),
		_entry("erva_vermelha", 15, 1, 2),
		_entry("pocao_vida", 10, 1, 1),
		_entry("armadura_couro", 6, 1, 1),
		_entry("espada_ferro", 4, 1, 1),
		_entry("arco_simples", 4, 1, 1),
		_entry("cajado_aprendiz", 4, 1, 1),
	])
	_table("chefe_rei_ossudo", 3, 0, [
		_entry("minerio_ferro", 40, 2, 4),
		_entry("fragmento_osso", 40, 2, 4),
		_entry("armadura_couro", 10, 1, 1),
		_entry("espada_ferro", 10, 1, 1),
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
	_buff("pele_de_pedra", "Pele de Pedra", "+1 de armadura máxima.", "max_armor", 1.0, M.ADD)
	_buff("coracao_forte", "Coração Forte", "+2 de vida máxima.", "max_health", 2.0, M.ADD)
	_buff("furia", "Fúria", "+20% de dano.", "damage", 1.2, M.MULTIPLY)
	_buff("maos_ligeiras", "Mãos Ligeiras", "Ataques 20% mais rápidos.", "attack_speed", 1.2, M.MULTIPLY)
	_buff("passos_leves", "Passos Leves", "Anda 12% mais rápido.", "move_speed", 1.12, M.MULTIPLY)
	_buff("olho_afiado", "Olho Afiado", "+10% de chance de crítico.", "crit_chance", 0.10, M.ADD)
	_buff("longo_alcance", "Longo Alcance", "+20% de alcance da arma.", "attack_range", 1.2, M.MULTIPLY)


func _enemy(id: String, name: String, element: int, color: Color, body_scale: float,
		hp: int, damage: int, speed: float, attack_range: float, windup: float, recover: float,
		drop_table: String) -> void:
	var e := EnemyData.new()
	e.id = StringName(id)
	e.display_name = name
	e.element = element
	e.color = color
	e.body_scale = body_scale
	e.max_health = hp
	e.damage = damage
	e.move_speed = speed
	e.attack_range = attack_range
	e.windup_time = windup
	e.recover_time = recover
	e.drop_table_id = StringName(drop_table)
	_save(e, "res://game/data/enemies/%s.tres" % id)


func _make_enemies() -> void:
	var E := GameEnums.Element
	_enemy("esqueleto", "Esqueleto", E.NEUTRAL, Color("cfc8b8"), 1.0, 24, 1, 2.6, 1.3, 0.6, 0.8, "esqueleto")
	_enemy("rato_gigante", "Rato Gigante", E.NATURE, Color("8a6a4f"), 0.7, 12, 1, 4.2, 1.0, 0.45, 0.7, "rato_gigante")
	_enemy("esqueleto_bruto", "Esqueleto Bruto", E.NEUTRAL, Color("9e8f7a"), 1.5, 70, 2, 2.0, 1.8, 0.9, 1.2, "esqueleto")
	_enemy("rei_ossudo", "Rei Ossudo", E.NEUTRAL, Color("d6b25e"), 2.1, 320, 2, 2.3, 2.6, 1.0, 1.0, "chefe_rei_ossudo")


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
