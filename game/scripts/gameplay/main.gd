extends Node3D
## Controle da run (fase 3).
## Uma run = 10 andares gerados aleatoriamente. Em cada andar: entrar nas salas, limpar as de combate
## (as portas fecham até o último inimigo cair), abrir baús, usar a fonte e achar o portal de saída.
## No portal, desce direto (a força vem do equipamento fabricado, não de bênçãos da run).
## Andar 5: a Onça-Pintada Alfa (mini-chefe) e o Acampamento: voltar à base com o que já tem ou descer.
## Andar 10: o chefe (Mapinguari), na sala mais distante.
## Todo loot e XP vão para o herói na hora: mesmo perdendo, a run rende avanço.
## O herói e o equipamento vêm do hub (GameState.selected_hero).
##
## PC: WASD anda · Espaço ataca · R nova run · G salva

const FLOORS := 10
const ROOMS_PER_FLOOR := [5, 6, 6, 7, 6, 7, 7, 8, 8, 8]
const BOSS_ID := &"mapinguari"
## Mini-chefe no meio do mundo, e o acampamento depois dele.
const MINIBOSS_FLOOR := 5
const MINIBOSS_ID := &"onca_alfa"
## A noite cai no Acampamento: a 2ª metade do mundo é de noite (mais perigosa, rende mais).
const NIGHTFALL_SECONDS := 4.0
const NIGHT_REWARD := 1.3
## Terra Firme: bichos que podem aparecer a partir de cada andar (peso = chance relativa).
## Queixadas e formigas nascem em grupo (EnemyData.group_min/max).
const ENEMY_POOL := [
	{"id": &"queixada", "from_floor": 1, "weight": 5},
	{"id": &"formiga_fogo", "from_floor": 1, "weight": 4},
	{"id": &"macaco_prego", "from_floor": 1, "weight": 3},
	{"id": &"aranha_caranguejeira", "from_floor": 3, "weight": 3},
	{"id": &"jararaca", "from_floor": 4, "weight": 2},
	{"id": &"onca_pintada", "from_floor": 6, "weight": 2},
]
## Quanto o dano e a vida dos inimigos crescem por andar (10 andares: no 10º, +81% de vida e +54% de dano).
const DAMAGE_PER_FLOOR := 0.06
const HEALTH_PER_FLOOR := 0.09
const HUB_SCENE := "res://game/scenes/hub.tscn"
## XP extra por sala limpa e por vencer o chefe.
const XP_ROOM_CLEAR := 4
const XP_RUN_VICTORY := 50
## Furioso (elite): mais vida, mais dano, mais agressivo; deixa o dobro de reagentes e o triplo de XP.
const ELITE_HEALTH := 2.5
const ELITE_DAMAGE := 1.5
const ELITE_XP := 3
## Segundos entre o fim de uma onda e a chegada da próxima (com aviso no chão).
const WAVE_DELAY := 1.4
## Covil Furioso: chance por andar (+ por andar e por dificuldade) e quantas ondas, todas de furiosos.
const DEN_CHANCE := 0.03
const DEN_CHANCE_PER_FLOOR := 0.01
const DEN_CHANCE_PER_DIFFICULTY := 0.02
const DEN_WAVES := 2

## Multijogador: quanto os inimigos crescem por número de jogadores (índice = jogadores).
const MP_HEALTH := [1.0, 1.0, 1.7, 2.4, 3.1]
const MP_DAMAGE := [1.0, 1.0, 1.15, 1.25, 1.35]
const MP_WAVE := [1.0, 1.0, 1.4, 1.75, 2.1]
const MP_ELITE := [0.0, 0.0, 0.10, 0.15, 0.20]
const MP_BOSS_PER_EXTRA := 0.9
const NET_HERO_HZ := 20.0
const NET_ENEMY_HZ := 15.0
const REVIVE_TIME := 3.0
const REVIVE_RANGE := 1.8

var run_seed := 0
## Dificuldade da run (GameState.run_difficulty, escolhida no portal) e se a energia foi gasta.
var difficulty := 0
var full_rewards := true
## Só para testes: garante um Covil Furioso em cada andar.
var force_den := false
var floor_number := 0
var layout: DungeonLayout
var builder: DungeonBuilder

var _rng := RandomNumberGenerator.new()
var _changing_floor := false  # entre entrar no portal e o andar novo ficar pronto
var _current_room: DungeonRoom
var _alive := 0
var _run_over := false
var _run_id := 0
var _stats := {}
## Tela de carregamento curta a cada andar: esconde a montagem do andar e o "aquecimento" dos
## efeitos (no 1º andar da sessão), que no celular dariam travadinhas.
static var _warmed := false
var _loading: CanvasLayer
var _loading_fade: ColorRect
var _loading_label: Label
var _loading_hiding := false
var _loading_frames := 0
var _warmup: Warmup
var night: NightMode
## Multijogador (ver Net): cópias dos outros heróis, bichos por número de rede, envio de estado.
var _replicas := {}
var _net_enemies := {}
var _next_net_id := 1
var _hero_send_t := 0.0
var _enemy_send_t := 0.0
var _ready_peers := {}
var _revive_t := {}
var _down_check_t := 0.0

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _dungeon: Node3D = $Dungeon
@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	# Suavização da física só no herói e nos inimigos (o resto é estático ou rápido demais para notar).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("loot_listeners")
	_hud.bind_player(_player)
	_hud.restart_requested.connect(_back_to_hub)
	GameState.leveled_up.connect(_on_leveled_up)
	_player.died.connect(_on_player_died)
	# Atmosfera da Terra Firme (luz, neblina, vagalumes e folhas em volta da heroína).
	BiomeAmbience.apply($WorldEnvironment, $Sun)
	var ambience := BiomeAmbience.new()
	ambience.name = "Ambiente"
	ambience.target = _player
	add_child(ambience)
	night = NightMode.new()
	night.name = "Noite"
	add_child(night)
	night.setup($WorldEnvironment, $Sun, _player, _dungeon, ambience)
	_build_loading()
	if Net.active:
		_make_replicas()
		Net.disconnected.connect(_on_net_disconnected)
	new_run(int(Net.run.get("seed", 0)) if Net.active else 0)
	if Net.is_client():
		Net.send_to(1, "net_ready", [])


func _process(_delta: float) -> void:
	_player.touch_move = _hud.move_vector()
	_player.touch_attack = _hud.attack_held()
	_update_loading()
	if Net.active:
		_net_tick(_delta)
	# reserva de modelos: na tela de carregamento enche rápido; jogando, um por quadro só
	# quando não tem luta (sem bicho vivo e sem onda chegando)
	if _loading and _loading.visible:
		RigPool.top_up(6)
	elif _alive <= 0 and (_current_room == null or not _current_room.wave_pending):
		RigPool.top_up(1)


## Quais modelos de bicho deixar prontos neste andar (os que podem aparecer, ~1 onda de cada).
func _plan_rig_pool() -> void:
	var targets := {}
	for e in ENEMY_POOL:
		if floor_number >= e.from_floor:
			var data := ItemDB.get_enemy(e.id)
			if data == null:
				continue
			var path := Enemy.RIG_PATH % (data.model_id if data.model_id != &"" else data.id)
			if ResourceLoader.exists(path):
				targets[path] = clampi(data.group_max * 2, 3, 8)
	RigPool.set_targets(targets)


func _exit_tree() -> void:
	RigPool.clear()


# ---------- tela de carregamento ----------

func _build_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 50
	_loading.name = "Carregando"
	add_child(_loading)
	_loading_fade = ColorRect.new()
	_loading_fade.color = Color("0d140c")
	_loading_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(_loading_fade)
	_loading_label = Label.new()
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading_label.add_theme_font_size_override("font_size", 34)
	_loading_label.add_theme_color_override("font_color", Color("cfe8b0"))
	_loading_fade.add_child(_loading_label)
	_loading.visible = false


func _show_loading() -> void:
	if _loading == null:
		return
	_loading.visible = true
	_loading_fade.modulate.a = 1.0
	_loading_label.text = "Andar %d" % floor_number
	_loading_frames = 0
	if not _warmed:
		_warmed = true
		_warmup = Warmup.start(self, _player)


func _update_loading() -> void:
	if _loading == null or not _loading.visible:
		return
	_loading_frames += 1
	var warming := (is_instance_valid(_warmup) and not _warmup.done()) or RigPool.missing() > 0
	# some quando já passaram 3 quadros e o aquecimento (efeitos e reserva de modelos) acabou;
	# antes só sumia exatamente no 3º quadro, e se o aquecimento passasse dele a tela ficava presa
	if _loading_frames >= 3 and not warming and not _loading_hiding:
		_loading_hiding = true
		var t := create_tween()
		t.tween_property(_loading_fade, "modulate:a", 0.0, 0.35)
		t.tween_callback(func() -> void:
			_loading.visible = false
			_loading_hiding = false)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_R:
			new_run()
		KEY_G:
			_hud.show_toast("Jogo salvo." if GameState.save() else "Falha ao salvar.")
		KEY_T:
			if OS.is_debug_build():
				spawn_training_dummies()
		KEY_N:
			if OS.is_debug_build():  # teste: alterna dia/noite
				night.set_night(not night.is_night, 1.5)


## Só na versão de desenvolvimento (tecla T): 3 bonecos de treino perto do herói. Andam e
## reagem como inimigos de verdade (atordoar, puxar, prender...), mas não machucam, não
## desviam e têm vida enorme, para dar tempo de ver os talentos funcionando.
func spawn_training_dummies() -> void:
	var data := ItemDB.get_enemy(&"queixada")
	for i in 3:
		var dummy := Enemy.create(data, 2000.0, 0.0)
		dummy.is_summon = true
		dummy.training_dummy = true
		add_child(dummy)
		var angle := TAU * i / 3.0
		dummy.global_position = _player.global_position + Vector3(cos(angle), 0, sin(angle)) * (3.0 + 3.0 * i) + Vector3(0, 0.1, 0)
		dummy.reset_physics_interpolation()
	_hud.show_toast("Bonecos de treino: não machucam e quase não morrem (somem ao trocar de andar)", Color("8fd3ff"))


# ---------- run e andares ----------

## Começa uma run nova. Com seed > 0, repete exatamente a mesma masmorra (útil para bugs).
func new_run(seed: int = 0) -> void:
	get_tree().paused = false
	_run_id += 1
	_run_over = false
	difficulty = clampi(int(Net.run.get("difficulty", GameState.run_difficulty)) if Net.active else GameState.run_difficulty, 0, 3)
	full_rewards = GameState.run_full_rewards
	_rng.seed = seed if seed > 0 else randi()
	run_seed = _rng.seed
	_stats = {"kills": 0, "loot": {}, "started": Time.get_ticks_msec(), "buffs": [], "xp": 0,
		"level_start": GameState.level_of(_player.hero_id), "best": {}}
	_hud.hide_panel()
	_player.start_run()
	_player.revive(Vector3(0, 0.1, 0))
	floor_number = 0
	_next_floor()


## Atalho para testes: pula direto para um andar (ex.: 5 para enfrentar o chefe).
func debug_jump_to_floor(target: int) -> void:
	floor_number = clampi(target, 1, FLOORS) - 1
	_next_floor()


## Portal: a tela de carregamento aparece antes, e o andar novo é montado por trás dela
## (sem a tela "congelar" no andar velho enquanto monta).
func _portal_to_next_floor() -> void:
	if _changing_floor or _run_over:
		return
	_changing_floor = true
	_hud.hide_panel()  # a pergunta do acampamento, se ficou aberta
	var run := _run_id
	if _loading:
		_loading.visible = true
		_loading_fade.modulate.a = 0.0
		_loading_label.text = "Andar %d" % (floor_number + 1)
		var t := create_tween()
		t.tween_property(_loading_fade, "modulate:a", 1.0, 0.15)
		await t.finished
		await get_tree().process_frame
	if run == _run_id and not _run_over:
		_next_floor()
	_changing_floor = false


func _next_floor() -> void:
	floor_number += 1
	_clear_floor()
	if Net.active:
		# todos os aparelhos montam o mesmo andar: a semente vem da run e do número do andar
		_rng.seed = hash("%d:%d" % [run_seed, floor_number])
		_net_enemies.clear()
	layout = DungeonLayout.new()
	layout.generate(_rng, ROOMS_PER_FLOOR[floor_number - 1], _is_boss_floor())
	_maybe_place_den()
	builder = DungeonBuilder.new()
	builder.build(layout, _dungeon, _rng)
	Lighting.no_shadow_receive(_dungeon)  # o chão (shader) continua recebendo a sombra
	for room in builder.rooms:
		room.player_entered.connect(_on_room_entered)
	for idx in builder.props:
		builder.props[idx].activated.connect(_on_prop_activated)
		builder.props[idx].set_meta("net_key", "r%d" % idx)

	# 2ª metade do mundo (depois do Acampamento): noite
	night.set_night(floor_number > MINIBOSS_FLOOR)
	_current_room = null
	_alive = 0
	var start := builder.rooms[layout.start_index]
	_player.global_position = start.center() + _arrival_offset(Net.my_id()) + Vector3(0, 0.1, 0)
	for peer in _replicas:
		var r: Player = _replicas[peer]
		r.global_position = start.center() + _arrival_offset(peer) + Vector3(0, 0.1, 0)
		r.net_pos = r.global_position
		r.reset_physics_interpolation()
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_camera.snap()
	if Net.active and _player.health.is_dead and not _run_over:
		# no grupo, quem caiu volta de pé no andar novo (com metade da vida)
		_player.revive(_player.global_position)
		_player.health.set_current(_player.health.max_health / 2, _player.health.max_health)
	_player.start_floor()
	_plan_rig_pool()
	_show_loading()
	_hud.minimap.show_layout(layout)
	_hud.set_floor(floor_number, FLOORS, difficulty, full_rewards)
	_hud.show_toast("Encontre %s" % ["o chefe" if floor_number == FLOORS else ("a Onça Alfa" if floor_number == MINIBOSS_FLOOR else "o portal azul")], Color("4db8ff"))
	GameState.save()


func _clear_floor() -> void:
	for child in _dungeon.get_children():
		child.queue_free()
	_hud.hide_boss()
	# floor_effects: armadilhas, harpia e outros poderes deixados no chão (não passam de andar).
	for group in ["enemies", "pickups", "telegraphs", "enemy_projectiles", "player_projectiles", "floor_effects"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()


# ---------- salas ----------

func _on_room_entered(room: DungeonRoom) -> void:
	if _run_over or builder == null or not builder.rooms.has(room):
		return
	# O sensor pode disparar por engano no quadro em que o herói troca de andar:
	# só vale se o herói estiver mesmo dentro da sala.
	if Net.is_client():
		# quem decide a luta é o anfitrião; aqui só o mapa
		if room.contains(_player.global_position):
			_current_room = room
			room.visited = true
			_hud.minimap.set_current(room.index)
		return
	var someone_in := room.contains(_player.global_position)
	for peer in _replicas:
		someone_in = someone_in or room.contains(_replicas[peer].global_position)
	if not someone_in:
		return
	if Net.is_host() and _ready_peers.size() < _replicas.size():
		return  # espera todo mundo terminar de carregar
	if room.contains(_player.global_position):
		_current_room = room
		room.visited = true
		_hud.minimap.set_current(room.index)
	if room.cleared or _alive > 0 or room.wave_pending:
		return
	room.close_doors()
	if Net.is_host():
		Net.send("net_room", [room.index, "close"])
		_pull_heroes_into(room)
	if room.is_den:
		# Covil Furioso: tudo furioso, duas ondas, baú grande no fim.
		room.wave_number = 1
		room.waves_left = DEN_WAVES - 1
		room.wave_total = DEN_WAVES
		_toast_all("COVIL FURIOSO! Só furiosos aqui. Vença e leve o baú grande.", Color("ff3b3b"))
		_spawn_wave(room, 3 + floor_number / 2, [])
	elif room.type == DungeonLayout.RoomType.BOSS:
		var mini := floor_number == MINIBOSS_FLOOR
		var boss := _spawn(MINIBOSS_ID if mini else BOSS_ID, room)
		if boss:
			_hud.show_boss(boss)
			_toast_all("A %s ruge no meio da mata!" % boss.data.display_name if mini
				else "O %s acordou! Que fedor..." % boss.data.display_name, Color("e05555"))
	else:
		# A luta da sala pode se estender: depois da 1ª onda, chegam de 1 a 4 ondas extras,
		# com mais chance e mais ondas nos andares fundos e nas dificuldades altas.
		room.wave_number = 1
		room.waves_left = _roll_extra_waves()
		room.wave_total = 1 + room.waves_left
		_spawn_wave(room, wave_budget(), [])


## Talvez transforme uma sala de combate fora do caminho principal num Covil Furioso.
## Devolve o índice da sala (ou -1). Prefere becos sem saída, para ser uma escolha do jogador.
func _maybe_place_den() -> int:
	var chance := DEN_CHANCE + DEN_CHANCE_PER_FLOOR * floor_number + DEN_CHANCE_PER_DIFFICULTY * difficulty
	if force_den or _rng.randf() < chance:
		var main_path := layout.path(layout.start_index, layout.goal_index)
		var options: Array[int] = []
		var dead_ends: Array[int] = []
		for i in layout.room_count():
			if layout.rooms[i].type != DungeonLayout.RoomType.COMBAT or main_path.has(i):
				continue
			options.append(i)
			if layout.rooms[i].links.size() == 1:
				dead_ends.append(i)
		var pool := dead_ends if not dead_ends.is_empty() else options
		if pool.is_empty():
			return -1
		var pick: int = pool[_rng.randi_range(0, pool.size() - 1)]
		layout.rooms[pick]["den"] = true
		var run := _run_id
		get_tree().create_timer(1.5, false).timeout.connect(func() -> void:
			if run == _run_id:
				_hud.show_toast("Há um Covil Furioso neste andar (vermelho no mapa). Arrisca?", Color("ff3b3b")))
		return pick
	return -1


## Se só sobraram bichos de tocaia ainda dormindo (jararaca meio apagada no canto), eles acordam e
## vêm: senão o herói podia ficar preso numa sala de portas fechadas sem achar o último bicho.
func _wake_hidden_leftovers(room: DungeonRoom) -> void:
	var left := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.home_room == room and e.state != Enemy.State.DEAD:
			if e._awake:
				return
			left.append(e)
	if left.is_empty():
		return
	var run := _run_id
	get_tree().create_timer(1.5, false).timeout.connect(func() -> void:
		if run != _run_id:
			return
		for e in left:
			if is_instance_valid(e) and not e._awake:
				e._wake())


## Acampamento (andar 5, depois da Onça Alfa): a fogueira leva de volta à base com tudo o que já
## foi coletado; o portal desce para a segunda metade do mundo.
func _spawn_camp(room: DungeonRoom, base := Vector3.INF, side := Vector3.ZERO) -> void:
	if base == Vector3.INF:
		# do lado da sala oposto ao herói (se nascessem em cima dele, disparariam sozinhos)
		var away: Vector3 = room.center() - _player.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.5 else Vector3.FORWARD
		base = room.center() + away * 2.5
		side = Vector3(-away.z, 0, away.x)
		if Net.is_host():
			Net.send("net_camp", [room.index, base, side])
	var camp := RoomProp.create(RoomProp.Kind.CAMP)
	camp.set_meta("net_key", "camp")
	_dungeon.add_child(camp)
	camp.global_position = base - side * 2.2
	camp.activated.connect(_on_prop_activated)
	var portal := RoomProp.create(RoomProp.Kind.PORTAL)
	portal.set_meta("net_key", "campportal")
	_dungeon.add_child(portal)
	portal.global_position = base + side * 2.2
	portal.activated.connect(_on_prop_activated)
	_hud.show_toast("A noite caiu na mata... Fogueira: voltar à base com o que coletou. Portal: descer na escuridão.", Color("ffb54d"))
	night.set_night(true, NIGHTFALL_SECONDS)
	_stats.camp = true


## Baú grande do covil: aparece no meio da sala quando o último furioso cai.
func _spawn_den_chest(room: DungeonRoom) -> void:
	if Net.is_host():
		Net.send("net_den_chest", [room.index])
	var chest := RoomProp.create(RoomProp.Kind.CHEST)
	chest.set_meta("net_key", "den%d" % room.index)
	chest.set_meta("table", "bau_covil")
	chest.scale = Vector3.ONE * 1.5
	_dungeon.add_child(chest)
	chest.global_position = room.center()
	chest.activated.connect(_on_prop_activated)
	builder.props[room.index] = chest
	_give_xp(XP_ROOM_CLEAR * 5)
	_hud.show_toast("Covil vencido! Abra o baú grande.", Color("e8c26a"))
	_stats.dens = int(_stats.get("dens", 0)) + 1


## Quantas ondas extras a sala vai ter (0 = só a primeira).
func _roll_extra_waves() -> int:
	var chance := clampf(0.3 + 0.05 * (floor_number - 1) + 0.12 * difficulty, 0.0, 0.95)
	if _rng.randf() >= chance:
		return 0
	var most := 1 + mini(3, (floor_number - 1) / 3 + difficulty)
	return _rng.randi_range(1, most)


## Vagas da 1ª onda de uma sala: 3 no 1º andar, chegando a 7-8 no 10º.
func wave_budget() -> int:
	return int(round((3 + (floor_number - 1) / 2 + _rng.randi_range(0, 1)) * MP_WAVE[mini(Net.count(), 4)]))


## Andar com sala de chefe (o mini-chefe no 5º, o chefe no 10º).
func _is_boss_floor() -> bool:
	return floor_number == FLOORS or floor_number == MINIBOSS_FLOOR


## Chance de um inimigo da onda vir furioso.
func _elite_chance(wave: int) -> float:
	return clampf(0.04 + 0.035 * (floor_number - 1) + 0.08 * difficulty + 0.05 * (wave - 1) + MP_ELITE[mini(Net.count(), 4)], 0.0, 0.8)


## Põe uma onda na sala. budget = "vagas": um grupo ocupa vagas conforme a vida somada
## (4 formigas valem 1 vaga; 3 queixadas valem 3). spots: pontos já avisados no chão.
## Os itens do baú saltam um por quadro (todos de uma vez davam uma travadinha no celular).
func _drop_chest_loot(drops: Array, at: Vector3) -> void:
	var run := _run_id
	for drop in drops:
		await get_tree().process_frame
		if run != _run_id or _run_over:
			return
		var pickup := LootPickup.create(drop.item, drop.qty, drop.instance)
		add_child(pickup)
		pickup.global_position = at + Vector3(_rng.randf_range(-1.5, 1.5), 0.4, _rng.randf_range(1.0, 2.0))


## Monta a onda e faz os bichos aparecerem um por quadro (todos no mesmo quadro davam uma
## travadinha no celular). Enquanto a fila não acaba, a sala fica "com onda pendente".
func _spawn_wave(room: DungeonRoom, budget: int, spots: Array) -> void:
	var elite_left := 1 if _rng.randf() < _elite_chance(room.wave_number) else 0
	if room.is_den:
		elite_left = 999
	if difficulty == 3 and room.wave_number > 1 and _rng.randf() < 0.3:
		elite_left += 1
	var queue: Array = []
	var spot_i := 0
	while budget > 0:
		var data := ItemDB.get_enemy(_pick_enemy())
		var size := _rng.randi_range(data.group_min, maxi(data.group_min, data.group_max))
		var cost := 1 if size == 1 else maxi(int(round(size * data.max_health / 200.0)), 1)
		if cost > budget and size > 1:
			size = maxi(1, size - (cost - budget))
			cost = mini(cost, budget)
		var first: Vector3 = spots[spot_i] if spot_i < spots.size() else room.random_point(_rng, _player.global_position, 5.0)
		spot_i += 1
		for i in size:
			var spot := first
			if i > 0:
				spot = first + Vector3(_rng.randf_range(-1.6, 1.6), 0, _rng.randf_range(-1.6, 1.6))
				if not room.contains(spot):
					spot = first
			var elite := elite_left > 0 and (i == 0 or room.is_den)
			if elite:
				elite_left -= 1
			queue.append([data.id, spot, elite])
		budget -= cost
	room.wave_pending = true
	var run := _run_id
	for k in queue.size():
		if k > 0:
			# um bicho a cada 2 quadros: o custo de cada um não se soma num quadro só
			await get_tree().process_frame
			await get_tree().process_frame
			if run != _run_id or _run_over or not is_instance_valid(room):
				return
		var job: Array = queue[k]
		_spawn(job[0], room, job[1], false, job[2])
	room.wave_pending = false


## Fim de uma onda: avisa no chão onde os próximos vão aparecer e solta a onda depois de um instante.
func _start_next_wave(room: DungeonRoom) -> void:
	room.wave_pending = true
	room.waves_left -= 1
	room.wave_number += 1
	# Ondas extras são um pouco menores que a primeira: 1–2 vagas no 1º andar, 3–4 no 5º.
	var budget := 1 + floor_number / 2 + _rng.randi_range(0, 1)
	var spots := []
	for i in budget:
		var p := room.random_point(_rng, _player.global_position, 4.0)
		spots.append(p)
		var mark := Telegraph.new()
		mark.shape = Telegraph.Shape.CIRCLE
		mark.radius = 1.1
		mark.color = Color("ff8a3d")
		mark.visual_only = true
		mark.duration = WAVE_DELAY
		mark.position = Vector3(p.x, 0.04, p.z)
		add_child(mark)
		if Net.is_host():
			Net.send("net_telegraph", [mark.pack(), 0, -1])
	_toast_all("Mais bichos chegando! Onda %d de %d" % [room.wave_number, room.wave_total], Color("ff8a3d"))
	var run := _run_id
	get_tree().create_timer(WAVE_DELAY, false).timeout.connect(func() -> void:
		if run != _run_id or _run_over or not is_instance_valid(room):
			return
		room.wave_pending = false
		_spawn_wave(room, budget, spots))


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


func _spawn(enemy_id: StringName, room: DungeonRoom, at: Vector3 = Vector3.INF, summoned: bool = false,
		elite: bool = false) -> Enemy:
	var data := ItemDB.get_enemy(enemy_id)
	if data == null:
		push_error("Inimigo inexistente: %s" % enemy_id)
		return null
	# O chefe já é desenhado para o último andar: não recebe o reforço por andar.
	var level := 0 if data.is_boss else floor_number - 1
	var n := mini(Net.count(), 4)
	var mp_hp: float = (1.0 + MP_BOSS_PER_EXTRA * (n - 1)) if data.is_boss else MP_HEALTH[n]
	var enemy := Enemy.create(data, (1.0 + HEALTH_PER_FLOOR * level) * Difficulty.HEALTH_MULT[difficulty] * mp_hp,
		(1.0 + DAMAGE_PER_FLOOR * level) * Difficulty.DAMAGE_MULT[difficulty] * MP_DAMAGE[n])
	enemy.is_summon = summoned
	enemy.threat = room_threat(room, data.is_boss)
	if elite and not data.is_boss:
		enemy.elite = true
		enemy.health_multiplier *= ELITE_HEALTH
		enemy.damage_multiplier *= ELITE_DAMAGE
		enemy.threat = minf(enemy.threat + 0.25, 1.0)
	enemy.loot_context = _loot_context("boss" if enemy.is_boss else "normal")
	enemy.home_room = room
	room.alive += 1
	add_child(enemy)
	enemy.global_position = at if at != Vector3.INF else room.random_point(_rng, _player.global_position, 5.0)
	if night.is_night:
		night.on_enemy_spawned(enemy)
	enemy.reset_physics_interpolation()
	if Net.is_host():
		enemy.net_id = _next_net_id
		_next_net_id += 1
		_net_enemies[enemy.net_id] = enemy
		Net.send("net_spawn", [enemy.net_id, enemy_id, enemy.global_position, enemy.elite, enemy.health_multiplier,
			enemy.damage_multiplier, summoned, room.index if room else -1])
	enemy.died.connect(_on_enemy_died)
	enemy.summon_requested.connect(_on_summon_requested)
	enemy.announced.connect(func(_e: Enemy, text: String) -> void: _hud.show_toast(text, Color("ffa53d")))
	_alive += 1
	return enemy


## Perigo da sala, de 0 a 1: sobe com o andar e com a distância da entrada.
## Controla o comportamento dos inimigos (sequências de ataques, esquivas, recuos e magias extras).
## Difícil, Heroico e Mítico somam um bônus (Difficulty.THREAT_BONUS).
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
	return clampf(floor_part * 0.8 + depth_part * 0.2 + Difficulty.THREAT_BONUS[difficulty], 0.0, 1.0)


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
		MobFx.summon_dust(_dungeon, spot)
	pass  # o próprio inimigo anuncia o ataque (signal announced)


func _on_enemy_died(enemy: Enemy) -> void:
	if Net.is_host():
		Net.send("net_enemy_died", [enemy.net_id])
	_net_enemies.erase(enemy.net_id)
	if Net.is_client():
		# boneco do anfitrião: aqui só XP, abate e o que cai para este jogador
		if not enemy.is_summon:
			_stats.kills += 1
			_player.on_enemy_killed(enemy.elite)
			_give_xp(enemy.data.xp_reward * (ELITE_XP if enemy.elite else 1))
		if enemy.is_boss:
			_hud.hide_boss()
		return
	_alive -= 1
	if not enemy.is_summon:
		_stats.kills += 1
		_player.set_meta("last_killed", enemy)
		_player.on_enemy_killed(enemy.elite)
		_give_xp(enemy.data.xp_reward * (ELITE_XP if enemy.elite else 1))
		if enemy.elite:
			_stats.elites = int(_stats.get("elites", 0)) + 1
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
	if room.alive > 0 and not room.cleared:
		_wake_hidden_leftovers(room)
	if room.alive > 0 or room.cleared or room.wave_pending:
		return
	if room.waves_left > 0 and room.type != DungeonLayout.RoomType.BOSS:
		_start_next_wave(room)
		return
	room.cleared = true
	if room.is_den:
		# Fora do sinal de física em que o último inimigo morreu (Godot não deixa criar áreas ali).
		_spawn_den_chest.call_deferred(room)
	room.open_doors()
	if Net.is_host():
		Net.send("net_room", [room.index, "open"])
	_give_xp(XP_ROOM_CLEAR)
	if room.type == DungeonLayout.RoomType.BOSS and floor_number == MINIBOSS_FLOOR:
		_spawn_camp.call_deferred(room)
	elif room.type == DungeonLayout.RoomType.BOSS:
		var run := _run_id
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if run == _run_id and not _run_over:
				_finish_all(true))
		_toast_all("O %s caiu! Recolha os reagentes." % ItemDB.get_enemy(BOSS_ID).display_name, Color("ffa53d"))
	else:
		_toast_all("Sala limpa!" if room.wave_total <= 1 else "Sala limpa! %d ondas vencidas." % room.wave_total,
			Color("6fdc7b"))


func _on_prop_activated(prop: RoomProp) -> void:
	if Net.is_host():
		Net.send("net_prop", [String(prop.get_meta("net_key", ""))])
	if Net.is_client() and prop.kind in [RoomProp.Kind.PORTAL, RoomProp.Kind.CAMP]:
		return  # o anfitrião decide (manda o andar novo ou o fim)
	match prop.kind:
		RoomProp.Kind.CHEST:
			var table := ItemDB.get_drop_table(StringName(prop.get_meta("table", "bau")))
			_hud.show_toast("Baú aberto!", Color("e8c26a"))
			_drop_chest_loot.call_deferred(LootRoller.roll(table, ItemDB.catalog, _rng, _loot_context("chest")), prop.global_position)
		RoomProp.Kind.FOUNTAIN:
			if not _player.health.is_dead:
				_player.health.heal(_player.health.max_health)
			_hud.show_toast("A fonte restaurou sua vida.", Color("6fdc7b"))
		RoomProp.Kind.PORTAL:
			# Fora da colisão do portal: montar o andar novo dentro dela não é permitido.
			if Net.is_host():
				Net.send("net_floor", [])
			_portal_to_next_floor.call_deferred()
		RoomProp.Kind.CAMP:
			_hud.ask("Acampamento", "Voltar à base agora, levando tudo o que coletou?\nOu continuar descendo até o chefe pelo portal.",
				"Voltar à base", "Continuar", func(back: bool) -> void:
					if back:
						_finish_all(false, true)
					else:
						prop.used = false)  # dá para usar a fogueira de novo (saindo e voltando a ela)


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


## Contexto de loot: dificuldade (mais reagentes e troféus) e energia (recompensa completa ou não).
func _loot_context(profile: String) -> Dictionary:
	var ilvl := clampi(floor_number - _rng.randi_range(0, 1), 1, 10)
	return {"ilvl": ilvl, "profile": profile, "hero": _player.hero, "difficulty": difficulty,
		"reward_mult": Difficulty.REWARD_MULT[difficulty] * (NIGHT_REWARD if night and night.is_night else 1.0),
		"full_rewards": full_rewards, "night": night != null and night.is_night}


func _give_xp(amount: int) -> void:
	if amount <= 0:
		return
	amount = int(round(amount * Difficulty.XP_MULT[difficulty]))
	_stats.xp += amount
	GameState.add_xp(_player.hero_id, amount)


func _on_leveled_up(hero_id: StringName, new_level: int) -> void:
	if hero_id == _player.hero_id:
		_hud.show_toast("Subiu para o nível %d!" % new_level, Color("ffd34d"))
		_hud.refresh_hero(_player.hero)


func _back_to_hub() -> void:
	get_tree().paused = false
	if Net.active:
		Net.leave()
	GameState.save()
	get_tree().change_scene_to_file(HUB_SCENE)


func _on_player_died() -> void:
	if Net.active and not _replicas.is_empty():
		# no grupo: cai e espera um parceiro levantar (a run só acaba se todos caírem)
		_hud.show_toast("Você caiu! Um parceiro pode te levantar (ficar perto de você por %d s)." % int(REVIVE_TIME), Color("ff6b6b"))
		_send_hero_state()
		return
	_finish(false)


## camp: saiu pelo acampamento (andar 5) levando o que coletou; não conta como vitória.
func _finish(victory: bool, camp := false) -> void:
	if _run_over:
		return
	_run_over = true
	if camp:
		_give_xp(XP_RUN_VICTORY / 2)
	if victory:
		_give_xp(XP_RUN_VICTORY)
		var first_clear := GameState.highest_cleared < difficulty
		GameState.record_clear(difficulty)
		if first_clear and difficulty < 3:
			_hud.show_toast("%s liberado no portal (se o equipamento alcançar)!" % Difficulty.name_of(difficulty + 1),
				Difficulty.color_of(difficulty + 1))
	GameState.save()
	var seconds: int = (Time.get_ticks_msec() - int(_stats.started)) / 1000
	var level_now := GameState.level_of(_player.hero_id)
	var tags := [[Difficulty.name_of(difficulty), "chefe", Difficulty.color_of(difficulty)],
		["Andar %d/%d" % [floor_number, FLOORS], "mapa"],
		["%d derrotados" % _stats.kills, "espada", Color("ffcf6b")],
		["%d:%02d" % [seconds / 60, seconds % 60], ""],
		["+%d XP" % _stats.xp, "xp", Color("8fe38f")],
		["Nível %d" % level_now, "nivel", Color("ffd25a") if level_now > int(_stats.level_start) else Color(0, 0, 0, 0)]]
	var lines := PackedStringArray()
	if not full_rewards:
		lines.append("Sem energia: reagentes reduzidos e sem troféus do chefe.")
	var loot_parts := PackedStringArray()
	for name in _stats.loot:
		loot_parts.append("%d× %s" % [_stats.loot[name], name])
	lines.append("Loot: " + (", ".join(loot_parts) if not loot_parts.is_empty() else "nada desta vez"))
	if not _stats.best.is_empty():
		lines.append("Melhor peça: %s (%s)" % [ItemFactory.display_name(_stats.best, ItemDB.catalog),
			GameEnums.rarity_name(int(_stats.best.rarity))])
	if not _stats.buffs.is_empty():
		lines.append("Bênçãos: " + ", ".join(PackedStringArray(_stats.buffs)))
	if level_now > int(_stats.level_start):
		lines.append("Subiu do nível %d para o %d!" % [_stats.level_start, level_now])
	_hud.set_panel_chips(tags)
	_hud.show_panel("Vitória!" if victory else ("De volta do acampamento" if camp else "Você caiu"), "\n".join(lines), "Voltar à base")


# ---------- multijogador ----------

const PLAYER_SCENE := "res://game/scenes/player.tscn"


## Cópias dos heróis dos outros jogadores (seguem o que chega pela rede).
func _make_replicas() -> void:
	for peer in Net.players:
		if int(peer) == Net.my_id():
			continue
		var r: Player = load(PLAYER_SCENE).instantiate()
		r.remote_peer = int(peer)
		r.profile = Net.players[peer]
		r.name = "Heroi_%d" % int(peer)
		add_child(r)
		_replicas[int(peer)] = r


## Onde cada jogador chega no andar (lado a lado, sem um em cima do outro).
func _arrival_offset(peer: int) -> Vector3:
	if not Net.active:
		return Vector3.ZERO
	return Vector3((Net.index_of(peer) - (Net.count() - 1) * 0.5) * 1.3, 0, 0)


func _toast_all(text: String, color: Color) -> void:
	_hud.show_toast(text, color)
	if Net.is_host():
		Net.send("net_toast", [text, color])


func _finish_all(victory: bool, camp := false) -> void:
	if Net.is_host():
		Net.send("net_finish", [victory, camp])
	_finish(victory, camp)


## Quem ficou fora da sala quando as portas fecharam vem para dentro (ninguém fica preso fora):
## para logo depois da porta por onde ia entrar, ao lado de quem já entrou.
func _pull_heroes_into(room: DungeonRoom) -> void:
	var slot := 1
	if not room.contains(_player.global_position):
		_player.global_position = room.entry_point(_player.global_position, slot)
		_player.velocity = Vector3.ZERO
		_player.reset_physics_interpolation()
		slot += 1
	for peer in _replicas:
		var at: Vector3 = _replicas[peer].global_position
		if not room.contains(at):
			Net.send_to(peer, "net_teleport", [room.entry_point(at, slot)])
			slot += 1


func _net_tick(delta: float) -> void:
	_hero_send_t -= delta
	if _hero_send_t <= 0.0:
		_hero_send_t = 1.0 / NET_HERO_HZ
		_send_hero_state()
	if Net.is_host():
		_enemy_send_t -= delta
		if _enemy_send_t <= 0.0:
			_enemy_send_t = 1.0 / NET_ENEMY_HZ
			_send_enemy_state()
		# todos caídos: fim da run para todos
		_down_check_t -= delta
		if _down_check_t <= 0.0 and not _run_over:
			_down_check_t = 0.5
			var all_down := _player.health.is_dead
			for peer in _replicas:
				all_down = all_down and _replicas[peer].health.is_dead
			if all_down:
				_finish_all(false)
	_tick_revive(delta)


func _send_hero_state() -> void:
	var p := _player
	Net.stream("net_hero", [p.global_position, p.velocity, p.facing(), p._body.rotation.y,
		p.touch_attack or Input.is_action_pressed("attack"), p.health.health, p.health.max_health,
		p.health.armor, p.health.max_armor, p.health.is_dead])


func _send_enemy_state() -> void:
	var data := PackedFloat32Array()
	for id in _net_enemies:
		var e: Enemy = _net_enemies[id]
		if not is_instance_valid(e) or e.state == Enemy.State.DEAD:
			continue
		data.append_array([float(id), e.global_position.x, e.global_position.z, e._body.rotation.y,
			float(e.health.health), float(e.health.max_health), float(e.state)])
	if not data.is_empty():
		Net.stream("net_enemies", [data])


## Levantar parceiro: ficar perto de quem caiu por alguns segundos.
func _tick_revive(delta: float) -> void:
	if _player.health.is_dead:
		_revive_t.clear()
		return
	for peer in _replicas:
		var r: Player = _replicas[peer]
		if not r.health.is_dead or r.global_position.distance_to(_player.global_position) > REVIVE_RANGE:
			_revive_t.erase(peer)
			continue
		var before: float = _revive_t.get(peer, 0.0)
		var now := before + delta
		_revive_t[peer] = now
		if int(before * 2.0) != int(now * 2.0):
			Fx.float_text(self, r.global_position + Vector3(0, 1.6, 0), "levantando %d%%" % int(minf(now / REVIVE_TIME, 1.0) * 100), Color("6fdc7b"))
		if now >= REVIVE_TIME:
			_revive_t.erase(peer)
			Net.send_to(peer, "net_revive", [])


func _on_net_disconnected(reason: String) -> void:
	_hud.show_toast(reason, Color("ff6b6b"))
	get_tree().create_timer(2.5).timeout.connect(_back_to_hub)


# --- chegam pela rede (o 1º argumento é sempre quem mandou) ---

func net_ready(sender: int) -> void:
	_ready_peers[sender] = true


func net_peer_left(peer: int) -> void:
	if _replicas.has(peer):
		_replicas[peer].queue_free()
		_replicas.erase(peer)
		_ready_peers.erase(peer)
		_hud.show_toast("Um jogador saiu da partida.", Color("ffb54d"))


func net_hero(sender: int, pos: Vector3, vel: Vector3, facing_dir: Vector3, yaw: float, attacking: bool,
		hp: int, max_hp: int, arm: int, max_arm: int, dead: bool) -> void:
	var r: Player = _replicas.get(sender)
	if r == null or not is_instance_valid(r):
		return
	r.apply_net_state(pos, vel, facing_dir, yaw, attacking)
	if dead and not r.health.is_dead:
		r.health.untouchable = false
		r.health.death_save = false
		r.health.take_damage(r.health.health + r.health.armor + 999999, false, true)
	elif not dead and r.health.is_dead:
		r.revive(pos)
	r.health.set_current(hp, max_hp, arm, max_arm)


func net_skill(sender: int, at: Vector3, facing_dir: Vector3) -> void:
	var r: Player = _replicas.get(sender)
	if r:
		r.net_use(false, at, facing_dir)


func net_ultimate(sender: int, at: Vector3, facing_dir: Vector3) -> void:
	var r: Player = _replicas.get(sender)
	if r:
		r.net_use(true, at, facing_dir)


func net_hit(_sender: int, amount: int, effect: int, dur: float, power: int, from: Vector3, ignore: bool) -> void:
	_player.receive_attack(amount, effect, dur, power, from, ignore)


func net_teleport(_sender: int, at: Vector3) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func net_revive(_sender: int) -> void:
	if not _player.health.is_dead:
		return
	_player.revive(_player.global_position)
	_player.health.set_current(_player.health.max_health / 2, _player.health.max_health)
	Vfx.heal(_player, true)
	_hud.show_toast("Um parceiro te levantou!", Color("6fdc7b"))
	_send_hero_state()


func net_toast(_sender: int, text: String, color: Color) -> void:
	_hud.show_toast(text, color)


func net_spawn(_sender: int, id: int, enemy_id: StringName, at: Vector3, elite: bool, hp_mult: float,
		dmg_mult: float, summoned: bool, room_index: int) -> void:
	var data := ItemDB.get_enemy(enemy_id)
	if data == null or builder == null:
		return
	var enemy := Enemy.create(data, hp_mult, dmg_mult)
	enemy.elite = elite and not data.is_boss
	enemy.is_summon = summoned
	enemy.puppet = true
	enemy.net_id = id
	enemy.net_pos = at
	enemy.loot_context = _loot_context("boss" if data.is_boss else "normal")
	if room_index >= 0 and room_index < builder.rooms.size():
		enemy.home_room = builder.rooms[room_index]
	add_child(enemy)
	enemy.global_position = at
	enemy.reset_physics_interpolation()
	if night.is_night:
		night.on_enemy_spawned(enemy)
	enemy.died.connect(_on_enemy_died)
	_net_enemies[id] = enemy
	if data.is_boss:
		_hud.show_boss(enemy)


func net_enemies(_sender: int, data: PackedFloat32Array) -> void:
	var i := 0
	while i + 6 < data.size():
		var e: Enemy = _net_enemies.get(int(data[i]))
		if e and is_instance_valid(e) and e.state != Enemy.State.DEAD:
			e.net_pos = Vector3(data[i + 1], e.global_position.y, data[i + 2])
			e.net_yaw = data[i + 3]
			e.health.set_current(int(data[i + 4]), int(data[i + 5]))
			e.net_state = int(data[i + 6])
		i += 7


func net_enemy_died(_sender: int, id: int) -> void:
	var e: Enemy = _net_enemies.get(id)
	if e and is_instance_valid(e) and e.state != Enemy.State.DEAD:
		e.health.untouchable = false
		e.health.take_damage(e.health.health + 999999, false, true)


func net_telegraph(_sender: int, packed: Dictionary, enemy_id: int, attack_index: int) -> void:
	var t := Telegraph.unpack(packed)
	add_child(t)
	var e: Enemy = _net_enemies.get(enemy_id)
	if e and is_instance_valid(e) and attack_index >= 0:
		e.net_attack_visual(attack_index)


func net_enemy_shot(_sender: int, enemy_id: int, attack_index: int, at: Vector3, dir: Vector3) -> void:
	var e: Enemy = _net_enemies.get(enemy_id)
	if e == null or not is_instance_valid(e) or attack_index < 0 or attack_index >= e._attacks.size():
		return
	var p := EnemyProjectile.create(e._attacks[attack_index], dir, 0.0)
	p.net_copy = true
	add_child(p)
	p.global_position = at


func net_room(_sender: int, index: int, what: String) -> void:
	if builder == null or index < 0 or index >= builder.rooms.size():
		return
	var room: DungeonRoom = builder.rooms[index]
	if what == "close":
		room.close_doors()
	elif what == "open":
		room.cleared = true
		room.open_doors()
		_give_xp(XP_ROOM_CLEAR)


func _find_prop(key: String) -> RoomProp:
	if key == "":
		return null
	for n in _dungeon.get_children():
		if n is RoomProp and String(n.get_meta("net_key", "")) == key:
			return n
	return null


func net_prop(_sender: int, key: String) -> void:
	var prop := _find_prop(key)
	if prop:
		prop.activate()


func net_floor(_sender: int) -> void:
	_portal_to_next_floor()


func net_camp(_sender: int, index: int, base: Vector3, side: Vector3) -> void:
	if builder and index >= 0 and index < builder.rooms.size():
		_spawn_camp(builder.rooms[index], base, side)


func net_den_chest(_sender: int, index: int) -> void:
	if builder and index >= 0 and index < builder.rooms.size():
		_spawn_den_chest(builder.rooms[index])


func net_finish(_sender: int, victory: bool, camp: bool) -> void:
	_finish(victory, camp)
