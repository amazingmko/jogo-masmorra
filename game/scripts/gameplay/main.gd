extends Node3D
## Controle da run (fase 3).
## Uma run = 5 andares gerados aleatoriamente. Em cada andar: entrar nas salas, limpar as de combate
## (as portas fecham até o último inimigo cair), abrir baús, usar a fonte e achar o portal de saída.
## No portal, escolhe 1 entre 3 buffs e desce. No 5º andar, o chefe está na sala mais distante.
## Todo loot e XP vão para o herói na hora: mesmo perdendo, a run rende avanço.
## O herói e o equipamento vêm do hub (GameState.selected_hero).
##
## PC: WASD anda · Espaço ataca · R nova run · G salva

const FLOORS := 5
const ROOMS_PER_FLOOR := [6, 7, 8, 8, 8]
const BOSS_ID := &"rei_ossudo"
## Inimigos que podem aparecer a partir de cada andar (peso = chance relativa).
const ENEMY_POOL := [
	{"id": &"esqueleto", "from_floor": 1, "weight": 5},
	{"id": &"rato_gigante", "from_floor": 1, "weight": 4},
	{"id": &"esqueleto_arqueiro", "from_floor": 1, "weight": 3},
	{"id": &"aranha_cripta", "from_floor": 2, "weight": 3},
	{"id": &"xama_ossos", "from_floor": 3, "weight": 2},
	{"id": &"esqueleto_bruto", "from_floor": 3, "weight": 2},
]
## Quanto o dano e a vida dos inimigos crescem por andar.
const DAMAGE_PER_FLOOR := 0.10
const HEALTH_PER_FLOOR := 0.15
const HUB_SCENE := "res://game/scenes/hub.tscn"
## XP extra por sala limpa e por vencer o chefe.
const XP_ROOM_CLEAR := 4
const XP_RUN_VICTORY := 50

var run_seed := 0
var floor_number := 0
var layout: DungeonLayout
var builder: DungeonBuilder

var _rng := RandomNumberGenerator.new()
var _current_room: DungeonRoom
var _alive := 0
var _run_over := false
var _run_id := 0
var _stats := {}

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _dungeon: Node3D = $Dungeon
@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	add_to_group("loot_listeners")
	_hud.bind_player(_player)
	_hud.restart_requested.connect(_back_to_hub)
	GameState.leveled_up.connect(_on_leveled_up)
	_hud.buff_chosen.connect(_on_buff_chosen)
	_player.died.connect(_on_player_died)
	new_run()


func _process(_delta: float) -> void:
	_player.touch_move = _hud.move_vector()
	_player.touch_attack = _hud.attack_held()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R:
			new_run()
		KEY_G:
			_hud.show_toast("Jogo salvo." if GameState.save() else "Falha ao salvar.")


# ---------- run e andares ----------

## Começa uma run nova. Com seed > 0, repete exatamente a mesma masmorra (útil para bugs).
func new_run(seed: int = 0) -> void:
	get_tree().paused = false
	_run_id += 1
	_run_over = false
	_rng.seed = seed if seed > 0 else randi()
	run_seed = _rng.seed
	_stats = {"kills": 0, "loot": {}, "started": Time.get_ticks_msec(), "buffs": [], "xp": 0,
		"level_start": GameState.level_of(_player.hero_id), "best": {}}
	_hud.hide_panel()
	_player.clear_buffs()
	_player.revive(Vector3(0, 0.1, 0))
	floor_number = 0
	_next_floor()


## Atalho para testes: pula direto para um andar (ex.: 5 para enfrentar o chefe).
func debug_jump_to_floor(target: int) -> void:
	floor_number = clampi(target, 1, FLOORS) - 1
	_next_floor()


func _next_floor() -> void:
	floor_number += 1
	_clear_floor()
	layout = DungeonLayout.new()
	layout.generate(_rng, ROOMS_PER_FLOOR[floor_number - 1], floor_number == FLOORS)
	builder = DungeonBuilder.new()
	builder.build(layout, _dungeon, _rng)
	for room in builder.rooms:
		room.player_entered.connect(_on_room_entered)
	for prop in builder.props.values():
		prop.activated.connect(_on_prop_activated)

	_current_room = null
	_alive = 0
	var start := builder.rooms[layout.start_index]
	_player.global_position = start.center() + Vector3(0, 0.1, 0)
	_player.velocity = Vector3.ZERO
	_camera.snap()
	_hud.minimap.show_layout(layout)
	_hud.set_wave("Andar %d/%d" % [floor_number, FLOORS])
	_hud.show_toast("Andar %d — encontre o %s" % [floor_number,
		"chefe" if floor_number == FLOORS else "portal azul"], Color("4db8ff"))
	GameState.save()


func _clear_floor() -> void:
	for child in _dungeon.get_children():
		child.queue_free()
	_hud.hide_boss()
	for group in ["enemies", "pickups", "telegraphs", "enemy_projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()


# ---------- salas ----------

func _on_room_entered(room: DungeonRoom) -> void:
	if _run_over or builder == null or not builder.rooms.has(room):
		return
	# O sensor pode disparar por engano no quadro em que o herói troca de andar:
	# só vale se o herói estiver mesmo dentro da sala.
	if not room.contains(_player.global_position):
		return
	_current_room = room
	room.visited = true
	_hud.minimap.set_current(room.index)
	if room.cleared or _alive > 0:
		return
	room.close_doors()
	if room.type == DungeonLayout.RoomType.BOSS:
		var boss := _spawn(BOSS_ID, room)
		if boss:
			_hud.show_boss(boss)
		_hud.show_toast("O Rei Ossudo acordou!", Color("e05555"))
	else:
		# 3–4 inimigos no 1º andar, até 5–6 no 5º: a dificuldade vem mais da variedade que do número.
		var count := 3 + floor_number / 2 + _rng.randi_range(0, 1)
		for i in count:
			_spawn(_pick_enemy(), room)


func _pick_enemy() -> StringName:
	var options: Array = []
	var total := 0
	for e in ENEMY_POOL:
		if floor_number >= e.from_floor:
			options.append(e)
			total += e.weight
	var roll := _rng.randi_range(1, total)
	for e in options:
		roll -= e.weight
		if roll <= 0:
			return e.id
	return options[0].id


func _spawn(enemy_id: StringName, room: DungeonRoom, at: Vector3 = Vector3.INF, summoned: bool = false) -> Enemy:
	var data := ItemDB.get_enemy(enemy_id)
	if data == null:
		push_error("Inimigo inexistente: %s" % enemy_id)
		return null
	# O chefe já é desenhado para o último andar: não recebe o reforço por andar.
	var level := 0 if data.is_boss else floor_number - 1
	var enemy := Enemy.create(data, 1.0 + HEALTH_PER_FLOOR * level, 1.0 + DAMAGE_PER_FLOOR * level)
	enemy.is_summon = summoned
	enemy.threat = room_threat(room, data.is_boss)
	enemy.loot_context = _loot_context("boss" if enemy.is_boss else "normal")
	enemy.home_room = room
	room.alive += 1
	add_child(enemy)
	enemy.global_position = at if at != Vector3.INF else room.random_point(_rng, _player.global_position, 5.0)
	enemy.died.connect(_on_enemy_died)
	enemy.summon_requested.connect(_on_summon_requested)
	enemy.announced.connect(func(_e: Enemy, text: String) -> void: _hud.show_toast(text, Color("ffa53d")))
	_alive += 1
	return enemy


## Perigo da sala, de 0 a 1: sobe com o andar e com a distância da entrada.
## Controla o comportamento dos inimigos (sequências de ataques, esquivas, recuos e magias extras).
## As dificuldades Difícil/Heroico/Mítico vão somar a este valor na fase 4b.
func room_threat(room: DungeonRoom, boss: bool = false) -> float:
	if boss:
		return 1.0
	var floor_part := float(floor_number - 1) / float(FLOORS - 1)
	var depth_part := 0.0
	if layout and room:
		var max_depth := 1
		for r in layout.rooms:
			max_depth = maxi(max_depth, int(r.depth))
		depth_part = float(layout.rooms[room.index].depth) / float(max_depth)
	return clampf(floor_part * 0.8 + depth_part * 0.2, 0.0, 1.0)


func _on_summon_requested(enemy: Enemy, summon_id: StringName, count: int, at: Vector3) -> void:
	var room: DungeonRoom = enemy.home_room
	if room == null or not is_instance_valid(room) or _run_over:
		return
	for i in count:
		var angle := TAU * i / maxi(count, 1) + _rng.randf_range(-0.4, 0.4)
		var spot := at + Vector3(cos(angle), 0, sin(angle)) * 2.5
		if not room.contains(spot):
			spot = room.random_point(_rng, _player.global_position, 3.0)
		_spawn(summon_id, room, spot + Vector3(0, 0.1, 0), true)
	_hud.show_toast("%s chamou reforços!" % enemy.data.display_name, Color("e05555"))


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	if not enemy.is_summon:
		_stats.kills += 1
		_give_xp(enemy.data.xp_reward)
	if enemy.is_boss:
		_hud.hide_boss()
		# Com o chefe caído, os ajudantes dele se desfazem.
		for other in get_tree().get_nodes_in_group("enemies"):
			if other.home_room == enemy.home_room:
				other.dismiss()
	var room: DungeonRoom = enemy.home_room
	if room == null or not is_instance_valid(room):
		return
	room.alive -= 1
	if room.alive > 0 or room.cleared:
		return
	room.cleared = true
	room.open_doors()
	_give_xp(XP_ROOM_CLEAR)
	if room.type == DungeonLayout.RoomType.BOSS:
		var run := _run_id
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if run == _run_id and not _run_over:
				_finish(true))
		_hud.show_toast("O Rei Ossudo caiu! Recolha o loot.", Color("ffa53d"))
	else:
		_hud.show_toast("Sala limpa!", Color("6fdc7b"))


func _on_prop_activated(prop: RoomProp) -> void:
	match prop.kind:
		RoomProp.Kind.CHEST:
			var table := ItemDB.get_drop_table(&"bau")
			for drop in LootRoller.roll(table, ItemDB.catalog, _rng, _loot_context("chest")):
				var pickup := LootPickup.create(drop.item, drop.qty, drop.instance)
				add_child(pickup)
				pickup.global_position = prop.global_position + Vector3(_rng.randf_range(-1.5, 1.5), 0.4, _rng.randf_range(1.0, 2.0))
			_hud.show_toast("Baú aberto!", Color("e8c26a"))
		RoomProp.Kind.FOUNTAIN:
			_player.health.heal(_player.health.max_health)
			_hud.show_toast("A fonte restaurou sua vida.", Color("6fdc7b"))
		RoomProp.Kind.PORTAL:
			_offer_buffs()


# ---------- buffs ----------

func _offer_buffs() -> void:
	var available: Array[BuffData] = []
	for b: BuffData in ItemDB.catalog.buffs.values():
		if not _player.buffs.has(b):
			available.append(b)
	if available.is_empty():
		_next_floor()
		return
	# Embaralha com o gerador da run, para a mesma semente oferecer os mesmos buffs.
	for i in range(available.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := available[i]
		available[i] = available[j]
		available[j] = tmp
	var options: Array[BuffData] = available.slice(0, 3)
	get_tree().paused = true
	_hud.show_buff_choice(options, "Escolha uma bênção para o andar %d" % (floor_number + 1))


func _on_buff_chosen(buff: BuffData) -> void:
	_player.apply_buff(buff)
	_stats.buffs.append(buff.display_name)
	get_tree().paused = false
	_next_floor()


# ---------- fim da run ----------

func on_loot_collected(item: ItemData, qty: int, instance: Dictionary = {}) -> void:
	if instance.is_empty():
		_stats.loot[item.display_name] = _stats.loot.get(item.display_name, 0) + qty
		return
	# Equipamento: conta por raridade e guarda a melhor peça para o resumo.
	var r := int(instance.rarity)
	var key := "peça %s" % GameEnums.rarity_name(r)
	_stats.loot[key] = _stats.loot.get(key, 0) + 1
	if _stats.best.is_empty() or r > int(_stats.best.rarity):
		_stats.best = instance


## Contexto de loot: nível de item cresce com o andar (Normal: 1 a 10).
func _loot_context(profile: String) -> Dictionary:
	var ilvl := clampi(floor_number * 2 - _rng.randi_range(0, 1), 1, 10)
	return {"ilvl": ilvl, "profile": profile, "hero": _player.hero}


func _give_xp(amount: int) -> void:
	if amount <= 0:
		return
	_stats.xp += amount
	GameState.add_xp(_player.hero_id, amount)


func _on_leveled_up(hero_id: StringName, new_level: int) -> void:
	if hero_id == _player.hero_id:
		_hud.show_toast("Subiu para o nível %d!" % new_level, Color("ffd34d"))
		_hud.refresh_hero(_player.hero)


func _back_to_hub() -> void:
	get_tree().paused = false
	GameState.save()
	get_tree().change_scene_to_file(HUB_SCENE)


func _on_player_died() -> void:
	_finish(false)


func _finish(victory: bool) -> void:
	if _run_over:
		return
	_run_over = true
	if victory:
		_give_xp(XP_RUN_VICTORY)
	GameState.save()
	var seconds: int = (Time.get_ticks_msec() - int(_stats.started)) / 1000
	var lines := PackedStringArray()
	lines.append("Andar alcançado: %d/%d   ·   Inimigos derrotados: %d   ·   Tempo: %d:%02d" % [
		floor_number, FLOORS, _stats.kills, seconds / 60, seconds % 60])
	if not _stats.buffs.is_empty():
		lines.append("Bênçãos: " + ", ".join(PackedStringArray(_stats.buffs)))
	var loot_parts := PackedStringArray()
	for name in _stats.loot:
		loot_parts.append("%d× %s" % [_stats.loot[name], name])
	lines.append("Loot: " + (", ".join(loot_parts) if not loot_parts.is_empty() else "nada desta vez"))
	if not _stats.best.is_empty():
		lines.append("Melhor peça: %s (%s)" % [ItemFactory.display_name(_stats.best, ItemDB.catalog),
			GameEnums.rarity_name(int(_stats.best.rarity))])
	var level_now := GameState.level_of(_player.hero_id)
	var level_text := "nível %d" % level_now
	if level_now > int(_stats.level_start):
		level_text = "subiu do nível %d para o %d!" % [_stats.level_start, level_now]
	lines.append("+%d XP · %s · tudo já está no inventário   (semente %d)" % [_stats.xp, level_text, run_seed])
	_hud.show_panel("Vitória!" if victory else "Você caiu", "\n".join(lines), "Voltar à base")
