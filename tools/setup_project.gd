extends SceneTree
## Gera os dados de exemplo, as cenas da fundação e o mapa de controles.
## Rodar uma vez (já foi rodado; os arquivos gerados estão no repositório):
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
	}
	for action in actions:
		var events := []
		for key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
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
	_item("espada_ferro", "Espada de Ferro", "Simples e confiável.", K.WEAPON, GameEnums.Rarity.COMMON, 1, 1, {"damage": 6, "attack_speed": 1.0})
	_item("arco_simples", "Arco Simples", "Leve, para ataques à distância.", K.WEAPON, GameEnums.Rarity.COMMON, 1, 1, {"damage": 4, "attack_speed": 1.4})
	_item("cajado_aprendiz", "Cajado de Aprendiz", "Canaliza magia básica.", K.WEAPON, GameEnums.Rarity.COMMON, 1, 1, {"damage": 5, "attack_speed": 0.9})
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
	_buff("armadura_extra", "Pele de Pedra", "+1 de armadura máxima.", "max_armor", 1.0, M.ADD)
	_buff("cadencia", "Mãos Ligeiras", "Ataques 10% mais rápidos.", "attack_speed", 1.10, M.MULTIPLY)
	_buff("recarga_rapida", "Mente Afiada", "Habilidade recarrega 25% mais rápido.", "skill_cooldown", 0.75, M.MULTIPLY)


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
	_add(root, sun, root)

	_add_box(root, "Floor", Vector3(24, 0.5, 24), Vector3(0, -0.25, 0), Color("4a4458"))
	# Pilares só para dar noção de escala e testar colisão.
	var pillar_color := Color("7a6f94")
	for pos in [Vector3(-5, 1, -4), Vector3(5, 1, -4), Vector3(-5, 1, 5), Vector3(5, 1, 5)]:
		_add_box(root, "Pillar", Vector3(1.2, 2, 1.2), pos, pillar_color)

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
	_add(root, hud, root)
	var label := Label.new()
	label.name = "Info"
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color("f2ecff"))
	label.add_theme_color_override("font_outline_color", Color("1a1526"))
	label.add_theme_constant_override("outline_size", 6)
	_add(hud, label, root)

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
