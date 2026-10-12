extends Node3D
## Controle da run (fase 3).
## Uma run = 5 andares gerados aleatoriamente. Em cada andar: entrar nas salas, limpar as de combate
## (as portas fecham até o último inimigo cair), abrir baús, usar a fonte e achar o portal de saída.
## No portal, escolhe 1 entre 3 buffs e desce. No 5º andar, o chefe está na sala mais distante.
## Todo loot vai para o inventário na hora: mesmo perdendo, a run rende avanço.
##
## PC: WASD anda · Espaço ataca · 1/2/3 troca herói · R nova run · C forja espada · G salva

const FLOORS := 5
const ROOMS_PER_FLOOR := [6, 7, 8, 8, 8]
const BOSS_ID := &"rei_ossudo"
## Inimigos que podem aparecer a partir de cada andar.
const ENEMY_POOL := [
	{"id": &"esqueleto", "from_floor": 1, "weight": 5},
	{"id": &"rato_gigante", "from_floor": 1, "weight": 4},
	{"id": &"esqueleto_bruto", "from_floor": 3, "weight": 1},
]
const HERO_KEYS := {KEY_1: &"guardiao", KEY_2: &"batedora", KEY_3: &"arcanista"}

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
	_hud.restart_requested.connect(func() -> void: new_run())
	_hud.buff_chosen.connect(_on_buff_chosen)
	_player.died.connect(_on_player_died)
	new_run()


func _process(_delta: float) -> void:
	_player.touch_move = _hud.move_vector()
	_player.touch_attack = _hud.attack_held()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if HERO_KEYS.has(event.keycode):
		_player.set_hero(ItemDB.get_hero(HERO_KEYS[event.keycode]))
		_hud.show_toast("Herói: " + _player.hero.display_name)
		return
	match event.keycode:
		KEY_R:
			new_run()
		KEY_C:
			var recipe := ItemDB.get_recipe(&"forjar_espada_ferro")
			var result := Crafting.craft(recipe, GameState.inventory, GameState.professions, ItemDB.catalog)
			_hud.show_toast("Forjou: Espada de Ferro!" if result.ok else "Não deu: " + result.reason)
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
	_stats = {"kills": 0, "loot": {}, "started": Time.get_ticks_msec(), "buffs": []}
	_hud.hide_panel()
	_player.clear_buffs()
	_player.revive(Vector3(0, 0.1, 0))
	floor_number = 0
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
	for group in ["enemies", "pickups"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()


# ---------- salas ----------

func _on_room_entered(room: DungeonRoom) -> void:
	if _run_over or builder == null or not builder.rooms.has(room):
		return
	_current_room = room
	room.visited = true
	_hud.minimap.set_current(room.index)
	if room.cleared or _alive > 0:
		return
	room.close_doors()
	if room.type == DungeonLayout.RoomType.BOSS:
		_spawn(BOSS_ID, room, 1.0)
		_spawn(&"rato_gigante", room, 1.0)
		_spawn(&"rato_gigante", room, 1.0)
		_hud.show_toast("O Rei Ossudo acordou!", Color("e05555"))
	else:
		var count := 2 + floor_number + _rng.randi_range(0, 1)
		var hp_mult := 1.0 + 0.15 * (floor_number - 1)
		for i in count:
			_spawn(_pick_enemy(), room, hp_mult)


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


func _spawn(enemy_id: StringName, room: DungeonRoom, hp_mult: float) -> void:
	var data := ItemDB.get_enemy(enemy_id)
	if data == null:
		push_error("Inimigo inexistente: %s" % enemy_id)
		return
	var enemy := Enemy.create(data, hp_mult)
	enemy.is_boss = enemy_id == BOSS_ID
	add_child(enemy)
	enemy.global_position = room.random_point(_rng, _player.global_position, 5.0)
	enemy.died.connect(_on_enemy_died)
	_alive += 1


func _on_enemy_died(enemy: Enemy) -> void:
	_stats.kills += 1
	_alive -= 1
	if _alive > 0 or _current_room == null or _current_room.cleared:
		return
	_current_room.cleared = true
	_current_room.open_doors()
	if _current_room.type == DungeonLayout.RoomType.BOSS:
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
			for drop in table.roll(_rng):
				var pickup := LootPickup.create(ItemDB.get_item(drop.item_id), drop.qty)
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

func on_loot_collected(item: ItemData, qty: int) -> void:
	_stats.loot[item.display_name] = _stats.loot.get(item.display_name, 0) + qty


func _on_player_died() -> void:
	_finish(false)


func _finish(victory: bool) -> void:
	if _run_over:
		return
	_run_over = true
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
	lines.append("Tudo já está no inventário.   (semente %d)" % run_seed)
	_hud.show_panel("Vitória!" if victory else "Você caiu", "\n".join(lines), "Nova run")
